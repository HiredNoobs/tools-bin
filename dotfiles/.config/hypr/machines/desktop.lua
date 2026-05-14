-------------------------------------------------------
-- Monitors
-------------------------------------------------------

hl.monitor({ output = "DP-1", mode = "2560x1440@165", position = "0x0", scale = 1 })
hl.monitor({ output = "DP-2", mode = "1920x1080@60", position = "2560x0", scale = 1 })

-------------------------------------------------------
-- Workspace rules
-------------------------------------------------------

hl.workspace_rule({
    workspace = "special:games",
    monitor = "DP-1"
})
