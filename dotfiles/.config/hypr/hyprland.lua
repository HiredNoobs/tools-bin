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
