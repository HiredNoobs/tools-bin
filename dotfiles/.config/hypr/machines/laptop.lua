-------------------------------------------------------
-- Monitors
-------------------------------------------------------

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-------------------------------------------------------
-- General config
-------------------------------------------------------

hl.config({
    input = {
        touchpad = {
            natural_scroll = true
        }
    }
})

hl.gesture({fingers = 3, direction = "horizontal", action = "workspace"})

-------------------------------------------------------
-- Workspaces
-------------------------------------------------------

-- The built-in screen is main; an external one becomes the second (see workspaces.lua)
require("hyprland.workspaces").roles = { main = "eDP-1" }
