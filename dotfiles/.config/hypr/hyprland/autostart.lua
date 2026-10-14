-------------------------------------------------------
-- Autostart
-------------------------------------------------------

hl.on("hyprland.start", function()
    -- Theme
    hl.exec_cmd("gsettings set org.gnome.desktop.interface font-name 'CodeNewRoman Nerd Font Propo 11'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme 'catppuccin-latte-red-cursors'")

    hl.exec_cmd("gsettings set org.gnome.desktop.wm.preferences button-layout :")

    -- Nightlight
    hl.exec_cmd("hyprsunset --temperature 6500")

    -- Status bar, notifications and wallpaper
    hl.exec_cmd("qs")

    -- Authentication agent
    hl.exec_cmd("systemctl --user start hyprpolkitagent")

    -- Idle manager, with the timeouts set in Quickshell's settings window if there are any
    -- (hypridle.local.conf, this machine's own); otherwise hypridle.conf
    local idle = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/hypridle.local.conf"
    local file = io.open(idle, "r")
    if file then
        file:close()
        hl.exec_cmd("hypridle -c " .. idle)
    else
        hl.exec_cmd("hypridle")
    end
end)
