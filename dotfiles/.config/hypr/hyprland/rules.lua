local workspaces = require("hyprland.workspaces")

-------------------------------------------------------
-- Window rules
-------------------------------------------------------

-- Browser
hl.window_rule({
    match = { class = "firefox" },
    no_initial_focus = true,
    focus_on_activate = false
})

hl.window_rule({
    match = {
        class = "firefox",
        title = "[Pp]rivate [Bb]rowsing"
    },
    no_screen_share = true
})

-- Browser modals
local modal_titles = {
    "[Ss]ave [Ii]mage",
    "[Ss]ave [Aa]s",
    "[Ss]ave [Tt]o",
    "[Ff]ile [Uu]pload",
}

for _, modal_title in ipairs(modal_titles) do
    local match = {
        class = "xdg-desktop-portal-gtk",
        title = ".*" .. modal_title .. ".*"
    }

    hl.window_rule({
        match = match,
        float = true,
        center = true,
        size = { "monitor_w*0.5", "monitor_h*0.5" }
    })
end

-- Steam
hl.window_rule({
    match = { class = "steam" },
    no_initial_focus = true,
    focus_on_activate = false
})

hl.window_rule({
    match = {
        initial_class = "steam",
        initial_title = "negative:^([Ss]team|steamapp.*|steam_app.*)$"
    },
    float = true
})

-- Steam games
hl.window_rule({
    match = { initial_class = "^(steam_app_.*)" },
    workspace = "name:games silent",
    content = "game", -- Enables the "game" auto modes for vrr, direct_scanout and no_break_fs_vrr
    float = false,
    no_initial_focus = true,
    focus_on_activate = false,
    fullscreen_state = "2 2",
    idle_inhibit = "focus", -- "always" stops the screen locking while a game is left running in the background
    render_unfocused = true,
    no_anim = true,
    no_blur = true,
    no_dim = true,
    no_shadow = true,
    opaque = true,
    immediate = true,
})

-- Discord
hl.window_rule({
    match = { class = "discord" },
    no_initial_focus = true,
    focus_on_activate = false
})

-- Quickshell's settings window (Super+I)
hl.window_rule({
    match = {
        class = "org.quickshell",
        title = "Settings"
    },
    float = true,
    center = true,
    size = { 1000, 680 }
})

-- Quickshell's Bluetooth pairing requests
hl.window_rule({
    match = {
        class = "org.quickshell",
        title = "Bluetooth pairing"
    },
    float = true,
    center = true
})

-------------------------------------------------------
-- Workspace placement
-------------------------------------------------------

-- Which monitor (role) and workspace apps open on; with no second screen connected they use
-- the same workspace on the main one (see workspaces.lua)
workspaces.place({ class = "steam" }, "main", 1)
workspaces.place({ class = "firefox" }, "second", 1)
workspaces.place({ class = "discord" }, "second", 2)
workspaces.place({ class = "^([Tt]eam[Ss]peak.*|ts3client.*)$" }, "second", 2)
