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
    function nmcli(args: var, quiet: var): void {
        queue = [...queue, { args: args, quiet: quiet ?? false }];
        next();
    }

    function next(): void {
        if (busy || queue.length === 0)
            return;
        busy = true;
        if (!queue[0].quiet)
            error = "";
        quietAction = queue[0].quiet;
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

    function connectHidden(ssid: string, password: string): void {
        const args = ["device", "wifi", "connect", ssid, "hidden", "yes"];
        if (password !== "")
            args.push("password", password);
        nmcli(args);
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
        stderr: StdioCollector {
            id: actionError
        }
        onExited: code => {
            if (code !== 0 && !root.quietAction)
                root.error = actionError.text.trim().replace(/^Error: /, "") || `nmcli failed (${code})`;
            root.busy = false;
            root.refresh();
            root.next();
        }
    }
}
