require("hyprland.env")
require("hyprland.autostart")
require("hyprland.general")
require("hyprland.keybinds")
require("hyprland.rules")

local handle = io.popen("hostnamectl chassis")
local chassis = handle:read("*a")
chassis = chassis:gsub("%s+$", "")

handle:close()

-- Not every chassis has a machine file, but still surface errors from the ones that do
local ok, err = pcall(require, "machines." .. chassis)
if not ok and not err:find("module 'machines%.[^']*' not found") then
    error(err)
end

-- Monitor layout saved from the Quickshell display panel, if there is one. It's per-machine
-- local state: not in the repo, and the setup script's rsync leaves it in place
ok, err = pcall(require, "monitors")
if not ok and not err:find("module 'monitors' not found") then
    error(err)
end

-- Keyboard, mouse and touchpad settings saved from Quickshell's settings window, if any; also
-- local state, like monitors.lua
ok, err = pcall(require, "input")
if not ok and not err:find("module 'input' not found") then
    error(err)
end

-- The cursor chosen in Quickshell's settings window (Appearance), if any; also local state
ok, err = pcall(require, "appearance")
if not ok and not err:find("module 'appearance' not found") then
    error(err)
end

-- Per-monitor workspaces and app placement, now the machine file has set the monitor roles
require("hyprland.workspaces").setup()
