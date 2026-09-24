require("hyprland.env")
require("hyprland.autostart")
require("hyprland.general")
require("hyprland.keybinds")
require("hyprland.rules")

local handle = io.popen("hostnamectl chassis")
local chassis = handle:read("*a")
chassis = chassis:gsub("%s+$", "")

handle:close()

pcall(require, "machines." .. chassis)
