#!/usr/bin/env python3
"""Bluetooth pairing agent for Quickshell (services/BluetoothAgent.qml starts it).

BlueZ asks its agent to confirm pairing codes, enter PINs and allow incoming pairing; without
one, phones and keyboards can't pair. Each request goes to the shell as a JSON line on stdout,
and the shell answers on stdin with "<id> accept [value]" or "<id> reject". Devices you accept
are trusted, so they reconnect without asking. Exits when the shell does (stdin closes).
"""

import json
import sys

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

BLUEZ = "org.bluez"
AGENT_PATH = "/org/quickshell/bluetooth_agent"
CAPABILITY = "KeyboardDisplay"


class Rejected(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Rejected"


class Canceled(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Canceled"


bus = None
loop = None
# Request id -> (kind, device path, reply, error)
pending = {}
next_id = 0


def send(message):
    print(json.dumps(message), flush=True)


def device_property(path, name, default=None):
    try:
        props = dbus.Interface(bus.get_object(BLUEZ, path), "org.freedesktop.DBus.Properties")
        return props.Get("org.bluez.Device1", name)
    except dbus.DBusException:
        return default


def device_name(path):
    return str(device_property(path, "Alias", str(path).rsplit("/", 1)[-1]))


def trust(path):
    try:
        props = dbus.Interface(bus.get_object(BLUEZ, path), "org.freedesktop.DBus.Properties")
        props.Set("org.bluez.Device1", "Trusted", dbus.Boolean(True))
    except dbus.DBusException:
        pass


def ask(kind, device, reply, error, **extra):
    """Passes a request to the shell; BlueZ gets its answer when the shell replies."""
    global next_id
    next_id += 1
    pending[next_id] = (kind, device, reply, error)
    send({"id": next_id, "type": kind, "device": device_name(device), **extra})


class Agent(dbus.service.Object):
    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Release(self):
        pass

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="s",
                         async_callbacks=("reply", "error"))
    def RequestPinCode(self, device, reply, error):
        ask("pin", device, reply, error)

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="u",
                         async_callbacks=("reply", "error"))
    def RequestPasskey(self, device, reply, error):
        ask("passkey", device, reply, error)

    # The device (e.g. a keyboard) needs this typed on it; nothing to answer
    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        send({"id": 0, "type": "display", "device": device_name(device), "code": str(pincode)})

    @dbus.service.method("org.bluez.Agent1", in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        send({"id": 0, "type": "display", "device": device_name(device),
              "code": f"{int(passkey):06d}", "entered": int(entered)})

    @dbus.service.method("org.bluez.Agent1", in_signature="ou", out_signature="",
                         async_callbacks=("reply", "error"))
    def RequestConfirmation(self, device, passkey, reply, error):
        ask("confirm", device, reply, error, code=f"{int(passkey):06d}")

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="",
                         async_callbacks=("reply", "error"))
    def RequestAuthorization(self, device, reply, error):
        ask("authorize", device, reply, error)

    # A paired, trusted device using a service (audio, file transfer…) needs no asking
    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="",
                         async_callbacks=("reply", "error"))
    def AuthorizeService(self, device, uuid, reply, error):
        if device_property(device, "Paired", False) or device_property(device, "Trusted", False):
            reply()
        else:
            ask("authorize", device, reply, error)

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Cancel(self):
        for kind, device, reply, error in pending.values():
            error(Canceled("Canceled"))
        pending.clear()
        send({"id": 0, "type": "cancel"})


def on_answer(source, condition):
    line = sys.stdin.readline()
    if not line:
        loop.quit()
        return False
    parts = line.split(maxsplit=2)
    if len(parts) < 2 or not parts[0].isdigit():
        return True
    request = pending.pop(int(parts[0]), None)
    if request is None:
        return True
    kind, device, reply, error = request
    value = parts[2].strip() if len(parts) > 2 else ""
    if parts[1] != "accept":
        error(Rejected("Rejected"))
        return True
    try:
        if kind == "pin":
            reply(value)
        elif kind == "passkey":
            reply(dbus.UInt32(int(value)))
        else:
            reply()
        trust(device)
    except ValueError:
        error(Rejected("Not a number"))
    return True


def register(*_):
    """Registers as the default agent; again whenever bluetoothd (re)starts."""
    try:
        manager = dbus.Interface(bus.get_object(BLUEZ, "/org/bluez"), "org.bluez.AgentManager1")
        manager.RegisterAgent(AGENT_PATH, CAPABILITY)
        manager.RequestDefaultAgent(AGENT_PATH)
        send({"id": 0, "type": "ready"})
    except dbus.DBusException as e:
        send({"id": 0, "type": "error", "message": e.get_dbus_message()})


def main():
    global bus, loop
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()
    Agent(bus, AGENT_PATH)
    bus.watch_name_owner(BLUEZ, lambda owner: owner and register())
    GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP, on_answer)
    loop = GLib.MainLoop()
    loop.run()


if __name__ == "__main__":
    main()
