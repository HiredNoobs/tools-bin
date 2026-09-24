-------------------------------------------------------
-- General config
-------------------------------------------------------

hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 10,
        border_size = 2,
        col = {
            active_border = "rgba(251,73,52,1)",
            inactive_border = "rgba(211,134,155,1)"
        },
        resize_on_border = true,
        allow_tearing = true,
        layout = "dwindle"
    },
    decoration = {
        rounding = 10,
        active_opacity = 0.9,
        inactive_opacity = 0.85,
        blur = {
            enabled = true,
            size = 3,
            passes = 5,
            popups = false
        },
        shadow = {
            enabled = true,
            range = 15,
            render_power = 3,
            color = "rgba(0,0,0,0.5)"
        }
    },
    input = {
        kb_layout = "gb",
        follow_mouse = 2,
        sensitivity = 0
    },
    misc = {
        disable_hyprland_logo = true,
        force_default_wallpaper = 0,
        focus_on_activate = true
    }
})
