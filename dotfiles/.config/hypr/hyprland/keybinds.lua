-------------------------------------------------------
-- Vars
-------------------------------------------------------

local mainMod = "SUPER"

-------------------------------------------------------
-- Window control
-------------------------------------------------------

-- Change focus, arrow keys and vim binds
hl.bind(mainMod .. " + LEFT", hl.dsp.focus({ direction = "left" }), { description = "Move focus to left" })
hl.bind(mainMod .. " + RIGHT", hl.dsp.focus({ direction = "right" }), { description = "Move focus to right" })
hl.bind(mainMod .. " + UP", hl.dsp.focus({ direction = "up" }), { description = "Move focus up" })
hl.bind(mainMod .. " + DOWN", hl.dsp.focus({ direction = "down" }), { description = "Move focus down" })

hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }), { description = "Move focus to left" })
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }), { description = "Move focus to right" })
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }), { description = "Move focus up" })
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }), { description = "Move focus down" })

-- Move window (within workspace), arrow keys and vim binds
hl.bind(mainMod .. " + SHIFT + LEFT", hl.dsp.window.move({ direction = "left" }), { description = "Move window left" })
hl.bind(mainMod .. " + SHIFT + RIGHT", hl.dsp.window.move({ direction = "right" }), { description = "Move window right" })
hl.bind(mainMod .. " + SHIFT + UP", hl.dsp.window.move({ direction = "up" }), { description = "Move window up" })
hl.bind(mainMod .. " + SHIFT + DOWN", hl.dsp.window.move({ direction = "down" }), { description = "Move window down" })

hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }), { description = "Move window left" })
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }), { description = "Move window right" })
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }), { description = "Move window up" })
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }), { description = "Move window down" })

-- Fullscreen
hl.bind(mainMod .. " + F11", hl.dsp.window.fullscreen_state({ internal = 1, client = 0, action = "toggle" }), { description = "Toggle maximise window" })
hl.bind(mainMod .. " + RETURN", hl.dsp.window.fullscreen_state({ internal = 2, client = 2, action = "toggle" }), { description = "Toggle fullscreen window" })

-- Toggle floating
hl.bind(mainMod .. " + F", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle window floating" })

-- Closing windows
hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { description = "Quit window" })
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.kill(), { description = "Kill window" })

-- Dragging windows
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { description = "Drag window" })

-------------------------------------------------------
-- Workspace control
-------------------------------------------------------

for i = 1, 10 do
	local key = i % 10
    local kp = "KP_" .. key -- Keypad keys

	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }), { description = "Move focus to workspace N" })
	hl.bind(mainMod .. " + ALT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }), { description = "Send window to workspace N" })

    hl.bind(mainMod .. " + " .. kp, hl.dsp.focus({ workspace = i }), { description = "Move focus to workspace N" })
    hl.bind(mainMod .. " + ALT + " .. kp, hl.dsp.window.move({ workspace = i, follow = false }), { description = "Send window to workspace N" })
end

hl.bind(mainMod .. " + G", hl.dsp.workspace.toggle_special("games"))

-------------------------------------------------------
-- Session control
-------------------------------------------------------

hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd("pkill rofi || ~/.config/rofi/scripts/system-menu.sh"), { description = "Toggle system control menu" })
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("loginctl lock-session"), { description = "Lock session" })

-------------------------------------------------------
-- Application shortcuts
-------------------------------------------------------

hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("pkill rofi || rofi -show drun -theme ~/.config/rofi/launcher.rasi"), { description = "Toggle application launcher" })

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("kitty -1"), { description = "Open Terminal" })
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("kitty bash -c yazi", { float = true, center = true, size = { "monitor_w*0.5", "monitor_h*0.5" } }), { description = "Open File Explorer" })
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("librewolf || firefox"), { description = "Open web browser (LibreWolf or Firefox)" })
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("code"), { description = "Open Code Editor" })
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("steam"), { description = "Open Steam" })
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("discord"), { description = "Open Discord" })

hl.bind("CONTROL + SHIFT + ESCAPE", hl.dsp.exec_cmd("kitty bash -c btop", { float = true, center = true, size = { "monitor_w*0.5", "monitor_h*0.5" } }), { description = "Open btop" })

-- Waybar toggle
hl.bind("CONTROL + ESCAPE", hl.dsp.exec_cmd("pkill waybar || waybar"), { description = "Toggle waybar" })

-------------------------------------------------------
-- Screenshot shortcuts
-------------------------------------------------------

-- Screenshot rofi menu
hl.bind("PRINT", hl.dsp.exec_cmd("pkill rofi || ~/.config/rofi/scripts/screenshot-menu.sh"), { description = "Toggle screenshot menu" })

-- Select area, saves unedited file, copies to clipboard, then opens file in swappy
hl.bind(mainMod .. " + PRINT", function()
    local file = "$HOME/Pictures/screenshots/snip-" .. os.date("%Y%m%d_%H%M%S-") .. math.random(32767) .. ".png"
    local grim = "grim -g \"$(slurp)\" \"" .. file .. "\""
    local message = " && notify-send -i \"" .. file .. "\" \"Screenshot saved to '" .. file .. "'\""
    local copy = " && wl-copy < \"" .. file .. "\""
    local swappy = " && swappy -f \"" .. file .. "\""

    hl.dispatch(hl.dsp.exec_cmd(grim .. message .. copy .. swappy))
end, { description = "Screenshot - Select area" })

-- Full screen saves file, copies to clipboard
hl.bind("ALT + PRINT", function()
    local file = "$HOME/Pictures/screenshots/full-" .. os.date("%Y%m%d_%H%M%S-") .. math.random(32767) .. ".png"
    local grim = "grim \"" .. file .. "\""
    local message = " && notify-send -i \"" .. file .. "\" \"Screenshot saved to '" .. file .. "'\""
    local copy = " && wl-copy < \"" .. file .. "\""

    hl.dispatch(hl.dsp.exec_cmd(grim .. message .. copy))
end, { description = "Screenshot - fullscreen" })

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
