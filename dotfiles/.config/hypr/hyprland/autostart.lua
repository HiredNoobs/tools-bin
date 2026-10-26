-------------------------------------------------------
-- Autostart
-------------------------------------------------------

hl.on("hyprland.start", function()
    -- Theme defaults for a first login, set only while they're unset: after that they're
    -- Quickshell's Settings › Appearance choices
    local defaults = {
        ["font-name"] = "CodeNewRoman Nerd Font Propo 11",
        ["color-scheme"] = "prefer-dark",
        ["gtk-theme"] = "adw-gtk3",
        ["cursor-theme"] = "catppuccin-latte-red-cursors",
    }
    for key, value in pairs(defaults) do
        hl.exec_cmd(string.format(
            [[sh -c '[ -n "$(dconf read /org/gnome/desktop/interface/$0)" ] || gsettings set org.gnome.desktop.interface "$0" "$1"' %s '%s']],
            key, value))
    end

    hl.exec_cmd("gsettings set org.gnome.desktop.wm.preferences button-layout :")

    -- Nightlight
    hl.exec_cmd("hyprsunset --temperature 6500")

    -- Status bar, notifications, wallpaper and the authentication agent
    hl.exec_cmd("qs")

    -- Idle manager, with the timeouts set in Quickshell's settings window if there are any
    -- (hypridle.local.conf, this machine's own); otherwise hypridle.conf
    local idle = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/hypridle.local.conf"
    local file = io.open(idle, "r")
    if file then
        file:close()
        hl.exec_cmd("hypridle -c '" .. idle:gsub("'", "'\\''") .. "'")
    else
        hl.exec_cmd("hypridle")
    end
end)
