-------------------------------------------------------
-- Defaults
-------------------------------------------------------

hl.env("TERMINAL", "kitty")

-------------------------------------------------------
-- Compatibility and performance
-------------------------------------------------------

-- QT
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_STYLE_OVERRIDE", "kvantum")

-- Toolkit backend variables
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")

-- XDG specifications
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

-- Mozilla
hl.env("MOZ_ENABLE_WAYLAND", "1")

-------------------------------------------------------
-- Theme
-------------------------------------------------------

hl.env("HYPRCURSOR_THEME", "catppuccin-latte-red-cursors")
hl.env("HYPRCURSOR_SIZE", "32")

hl.env("XCURSOR_THEME", "catppuccin-latte-red-cursors")
hl.env("XCURSOR_SIZE", "32")
