-------------------------------------------------------
-- General config
-------------------------------------------------------

-- A colour from the colour scheme (Quickshell's ColourScheme writes it, and sets the borders live
-- when it changes), or `fallback`
local function scheme_colour(name, fallback)
    local file = io.open((os.getenv("HOME") or "") .. "/.cache/colours/colours.json", "r")
    if not file then
        return fallback
    end
    local text = file:read("a")
    file:close()
    local hex = text:match('"' .. name .. '":%s*"#(%x%x%x%x%x%x)"')
    return hex and ("rgb(" .. hex .. ")") or fallback
end

hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 10,
        border_size = 2,
        col = {
            active_border = scheme_colour("accent", "rgba(251,73,52,1)"),
            inactive_border = scheme_colour("color5", "rgba(211,134,155,1)")
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
        focus_on_activate = true,
        -- A restarted Quickshell (or hyprlock) can take over a lock whose locker died
        allow_session_lock_restore = true,
        -- Black, rather than the "lockscreen died" message, while it does (ms)
        lockdead_screen_delay = 4000,
        vrr = 3 -- Only for fullscreen windows with video or game content
    },
    render = {
        direct_scanout = 2 -- Only for game content
    }
})
