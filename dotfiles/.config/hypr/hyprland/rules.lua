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

    hl.window_rule({ match = match, float = true })
    hl.window_rule({ match = match, center = true })
end

-- Steam & games
hl.window_rule({
    match = { class = "steam" },
    workspace = "1 silent",
    no_initial_focus = true,
    focus_on_activate = false
})

hl.window_rule({
    name = "steam-games",
    match = { initial_class = "steam_app_\\d" },
    workspace = "special:games silent",
    render_unfocused = true,
    no_blur = true,
    no_dim = true,
    no_shadow = true,
    opaque = true,
    content = "game",
    immediate = true,
})

hl.window_rule({
    name = "float-steam-children",
    match = {
        initial_class = "steam",
        initial_title = "negative:^(steam|steamapp.*)$"
    },
    float = true
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
