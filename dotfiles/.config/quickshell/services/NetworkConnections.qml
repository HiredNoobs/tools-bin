pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// NetworkManager's saved connections through nmcli, for Settings › Network: what Quickshell's
// Networking API doesn't cover (networks out of range, IP and DNS settings, hidden networks).
// Actions run one at a time; a failure's message is kept in `error` for the page to show.
Singleton {
    id: root

    // [{ uuid, name, type ("802-11-wireless", "802-3-ethernet"…), autoconnect, active,
    //    device, lastUsed (ms, 0 if never) }]
    property var connections: []
    // The last action's error, "" if it worked
    property string error: ""
    property bool busy: false
    property var queue: []
    // The running action's failure isn't reported
    property bool quietAction: false

    function refresh(): void {
        list.running = true;
    }

    // nmcli's terse output separates fields with ":" and escapes ":" and "\" inside them
    function splitFields(line: string): var {
        const fields = [];
        let field = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length) {
                field += line[++i];
            } else if (c === ":") {
                fields.push(field);
                field = "";
            } else {
                field += c;
            }
        }
        fields.push(field);
        return fields;
    }

    // "key:value" lines (nmcli -t -f … connection/device show) to { key: value }; repeated
    // keys like IP4.DNS[1], IP4.DNS[2] become one list under IP4.DNS
    function parseShow(text: string): var {
        const result = {};
        for (const line of text.split("\n")) {
            if (line === "")
                continue;
            const [key, ...rest] = splitFields(line);
            const value = rest.join(":");
            const base = key.replace(/\[\d+\]$/, "");
            if (base !== key)
                result[base] = [...(result[base] ?? []), value];
            else
                result[key] = value;
        }
        return result;
    }

    // Runs `nmcli <args>` after any action before it, then re-reads the connections. A quiet
    // one's failure isn't reported (e.g. taking down a connection that may not be up).
    // `extra`: { input (written to its stdin, for secrets), onFail (called if it fails) }
    function nmcli(args: var, quiet: var, extra: var): void {
        queue = [...queue, Object.assign({ args: args, quiet: quiet ?? false, input: "", onFail: null }, extra ?? {})];
        next();
    }

    function next(): void {
        if (busy || queue.length === 0)
            return;
        busy = true;
        if (!queue[0].quiet)
            error = "";
        quietAction = queue[0].quiet;
        action.input = queue[0].input;
        action.onFail = queue[0].onFail;
        action.command = ["nmcli", ...queue[0].args];
        queue = queue.slice(1);
        action.running = true;
    }

    function setAutoconnect(uuid: string, on: bool): void {
        nmcli(["connection", "modify", uuid, "connection.autoconnect", on ? "yes" : "no"]);
    }

    function connect(uuid: string): void {
        nmcli(["connection", "up", uuid]);
    }

    function disconnect(uuid: string): void {
        nmcli(["connection", "down", uuid]);
    }

    function forget(uuid: string): void {
        nmcli(["connection", "delete", uuid]);
    }

    // settings: { manual, address ("192.168.1.50/24"), gateway, customDns, dns (list) }.
    // Reconnects an active connection so the change takes effect.
    function setIpv4(uuid: string, settings: var, active: bool): void {
        const args = ["connection", "modify", uuid];
        if (settings.manual)
            args.push("ipv4.method", "manual", "ipv4.addresses", settings.address, "ipv4.gateway", settings.gateway);
        else
            args.push("ipv4.method", "auto", "ipv4.addresses", "", "ipv4.gateway", "");
        if (settings.customDns)
            args.push("ipv4.dns", settings.dns.join(" "), "ipv4.ignore-auto-dns", "yes");
        else
            args.push("ipv4.dns", "", "ipv4.ignore-auto-dns", "no");
        nmcli(args);
        if (active)
            connect(uuid);
    }

    // A WireGuard .conf, named after the file (which must make a valid interface name, up to
    // 15 characters). NetworkManager would start it straight away and on every login, so it's
    // left off with auto-connect off, for you to turn on.
    function importWireguard(path: string): void {
        const file = path.replace(/^~(?=\/|$)/, Quickshell.env("HOME"));
        const name = file.split("/").pop().replace(/\.conf$/, "");
        nmcli(["connection", "import", "type", "wireguard", "file", file]);
        nmcli(["connection", "modify", name, "connection.autoconnect", "no"], true);
        nmcli(["connection", "down", name], true);
    }

    // A profile for the network, then brought up with the password on nmcli's stdin (on its
    // command line any user could read it); removed again if it doesn't connect
    function connectHidden(ssid: string, password: string): void {
        const uuid = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, c => {
            const r = Math.floor(Math.random() * 16);
            return (c === "x" ? r : (r & 3) | 8).toString(16);
        });
        const args = ["connection", "add", "type", "wifi", "con-name", ssid, "ssid", ssid, "connection.uuid", uuid, "802-11-wireless.hidden", "yes"];
        if (password !== "")
            args.push("wifi-sec.key-mgmt", "wpa-psk");
        // Not added: don't try to connect it (queued right behind)
        nmcli(args, false, { onFail: () => root.queue = root.queue.slice(1) });
        nmcli(["connection", "up", uuid, ...(password !== "" ? ["passwd-file", "/dev/stdin"] : [])], false, {
            input: password !== "" ? `802-11-wireless-security.psk:${password}\n` : "",
            onFail: () => root.nmcli(["connection", "delete", uuid], true)
        });
    }

    Component.onCompleted: refresh()

    Process {
        id: list
        command: ["nmcli", "-t", "-f", "UUID,NAME,TYPE,AUTOCONNECT,ACTIVE,DEVICE,TIMESTAMP", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.connections = text.split("\n").filter(line => line !== "").map(line => {
                    const [uuid, name, type, autoconnect, active, device, timestamp] = root.splitFields(line);
                    return {
                        uuid: uuid,
                        name: name,
                        type: type,
                        autoconnect: autoconnect === "yes",
                        active: active === "yes",
                        device: device,
                        lastUsed: Number(timestamp) * 1000
                    };
                });
            }
        }
    }

    Process {
        id: action

        property string input
        property var onFail

        stdinEnabled: true
        // The secret, then end of input
        onStarted: {
            if (input !== "")
                write(input);
            input = "";
            stdinEnabled = false;
        }
        stderr: StdioCollector {
            id: actionError
        }
        onExited: code => {
            stdinEnabled = true;
            if (code !== 0 && !root.quietAction)
                root.error = actionError.text.trim().replace(/^Error: /, "") || `nmcli failed (${code})`;
            if (code !== 0 && onFail)
                onFail();
            root.busy = false;
            root.refresh();
            root.next();
        }
    }
}
