-------------------------------------------------------
-- Window rules
-------------------------------------------------------

-- Browser
hl.window_rule({
    match = { class = "librewolf|firefox" },
    workspace = "2 silent",
    no_initial_focus = true,
    focus_on_activate = false
})

hl.window_rule({
    match = {
        class = "librewolf|firefox",
        title = "[Pp]rivate [Bbrowsing]"
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
        title = modal_title
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
    workspace = "1 silent",
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
    match = { initial_class = "^(steam_app_.*)" }, -- This one needs the ^() for some reason...?
    workspace = "special:games silent",
    no_initial_focus = true,
    focus_on_activate = false,
    fullscreen_state = "2 2",
    idle_inhibit = "always",
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
    workspace = "3 silent",
    no_initial_focus = true,
    focus_on_activate = false
})

-------------------------------------------------------
-- Layer rules
-------------------------------------------------------

-- Rofi
-- Mainly to avoid the window getting caught by screenshots
hl.layer_rule({ match = { namespace = "rofi" }, no_anim = true })

-- wlogout
hl.layer_rule({ match = { namespace = "logout_dialog" }, no_anim = true })
