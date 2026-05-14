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
-- Workspace rules
-------------------------------------------------------

hl.workspace_rule({
    workspace = "special:games",
    monitor = "eDP-1"
})
