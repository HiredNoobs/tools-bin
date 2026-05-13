-------------------------------------------------------
-- Vars
-------------------------------------------------------

local mainMod = "SUPER"

-------------------------------------------------------
-- Window control
-------------------------------------------------------

-- Change focus, arrow keys and vim binds
hl.bind(mainMod .. " + LEFT", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + RIGHT", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + UP", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + DOWN", hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))

-- Move window (within workspace), arrow keys and vim binds
hl.bind(mainMod .. " + SHIFT + LEFT", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + RIGHT", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + UP", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + DOWN", hl.dsp.window.move({ direction = "down" }))

hl.bind(mainMod .. " + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + L", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + J", hl.dsp.window.move({ direction = "down" }))

-- Fullscreen
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen_state({ internal = 1, client = 0, action = "toggle" })) -- Maximise but don't inform app
hl.bind(mainMod .. " + RETURN", hl.dsp.window.fullscreen_state({ internal = 2, client = 2, action = "toggle" })) -- Fullscreen, inform app

-- Toggle floating
hl.bind(mainMod .. " + D", hl.dsp.window.float({ action = "toggle" }))

-- Closing windows
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.kill())

-- Dragging windows
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag())

-------------------------------------------------------
-- Workspace control
-------------------------------------------------------

for i = 1, 10 do
	local key = i % 10
    local kp = "KP_" .. key -- Keypad keys

	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + ALT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }))

    hl.bind(mainMod .. " + " .. kp, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + ALT + " .. kp, hl.dsp.window.move({ workspace = i, follow = false }))
end

-------------------------------------------------------
-- Session control
-------------------------------------------------------

hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd("pkill rofi || ~/.config/rofi/scripts/system-menu.sh"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("systemctl suspend"))

-------------------------------------------------------
-- Application shortcuts
-------------------------------------------------------

hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("pkill rofi || rofi -show drun -theme ~/.config/rofi/launcher.rasi"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("kitty -1"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("kitty -1 bash -c yazi"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("librewolf || firefox"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("code"))
hl.bind("CONTROL + SHIFT + ESCAPE", hl.dsp.exec_cmd("kitty -1 bash -c btop", { float = true }))

-- Screenshots
hl.bind("PRINT", hl.dsp.exec_cmd("pkill rofi || ~/.config/rofi/scripts/screenshot-menu.sh"))
hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd("grimblast --notify copysave screen ~/Pictures/screenshots/$(date +%Y%m%d-%H%M%S).png"))
hl.bind(mainMod .. " + SHIFT + PRINT", hl.dsp.exec_cmd("grimblast --notify copysave active ~/Pictures/screenshots/$(date +%Y%m%d-%H%M%S).png"))
hl.bind(mainMod .. " + ALT + PRINT", hl.dsp.exec_cmd("grimblast --freeze --notify copysave area ~/Pictures/screenshots/$(date +%Y%m%d-%H%M%S).png"))


-- Waybar toggle
hl.bind("CONTROL + ESCAPE", hl.dsp.exec_cmd("pkill waybar || waybar"))

-------------------------------------------------------
-- Media control
-------------------------------------------------------

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pamixer -i 5", { repeating = true }))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pamixer -d 5 ", { repeating = true }))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("pamixer --default-source -m"))
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("pamixer -t"))

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"))
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"))

-------------------------------------------------------
-- Brightness control
-------------------------------------------------------

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s +5%", { repeating = true }))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 5%-", { repeating = true }))
