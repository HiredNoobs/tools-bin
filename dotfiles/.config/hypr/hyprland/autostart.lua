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

    -- Status bar
    hl.exec_cmd("waybar")

    -- Notifications
    hl.exec_cmd("dunst")

    -- Wallpaper
    hl.exec_cmd("swaybg -i ~/.cache/current-wallpaper -m fill")

    -- Authentication agent
    hl.exec_cmd("systemctl --user start hyprpolkitagent")

    -- Idle manager
    hl.exec_cmd("hypridle")

    -- DBus environment
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

    -- Auto mount USB devices
    hl.exec_cmd("udiskie")
end)
