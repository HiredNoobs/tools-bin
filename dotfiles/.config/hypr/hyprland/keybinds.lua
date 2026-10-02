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

-- Dragging and resizing windows
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Drag window" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window" })

-------------------------------------------------------
-- Workspace control
-------------------------------------------------------

-- Workspaces are per monitor: N is workspace N on the main monitor, and adding CONTROL means
-- the second monitor (its workspaces sit on the main one while it's unplugged). See
-- workspaces.lua
local workspaces = require("hyprland.workspaces")

for i = 1, 10 do
    local key = i % 10
    local kp = "KP_" .. key -- Keypad keys

    local function send(target)
        return function()
            hl.dispatch(hl.dsp.window.move({ workspace = target(i), follow = false }))
        end
    end

    local function show_main()
        hl.dispatch(hl.dsp.focus({ workspace = workspaces.main(i) }))
    end

    -- Keeps a focused game focused (see workspaces.lua)
    local function show_second()
        workspaces.show_second(i)
    end

    for _, k in ipairs({ key, kp }) do
        hl.bind(mainMod .. " + " .. k, show_main, { description = "Show workspace N on the main monitor" })
        hl.bind(mainMod .. " + ALT + " .. k, send(workspaces.main), { description = "Send window to workspace N on the main monitor" })
        hl.bind(mainMod .. " + CONTROL + " .. k, show_second, { description = "Show workspace N on the second monitor" })
        hl.bind(mainMod .. " + CONTROL + ALT + " .. k, send(workspaces.second), { description = "Send window to workspace N on the second monitor" })
    end
end

-- Overview of every monitor's workspaces (Quickshell)
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("qs ipc call overview toggle"), { description = "Toggle workspace overview" })

-- Alt+Tab workspace switcher (Quickshell): hold Alt, tap Tab / Shift+Tab to step through recently
-- used workspaces, release Alt to go to the selected one. Each hold of Alt is one numbered
-- session, so the switcher can match a release that reaches it before the step does. Numbered
-- from the clock so a config reload doesn't reuse numbers.
local switcher = { session = os.time(), holding = false }

local function switcher_step(direction)
    return function()
        if not switcher.holding then
            switcher.holding = true
            switcher.session = switcher.session + 1
        end
        hl.dispatch(hl.dsp.exec_cmd("qs ipc call switcher " .. direction .. " " .. switcher.session))
    end
end

local function switcher_commit()
    if switcher.holding then
        switcher.holding = false
        hl.dispatch(hl.dsp.exec_cmd("qs ipc call switcher commit " .. switcher.session))
    end
end

hl.bind("ALT + TAB", switcher_step("next"), { description = "Switch to the previous workspace (hold Alt to pick)" })
hl.bind("ALT + SHIFT + TAB", switcher_step("prev"), { description = "Workspace switcher, backwards" })
-- Releasing Alt, whatever else is held, and still passed on to the app. ignore_mods should cover
-- every case; the explicit Alt and Alt+Shift ones are a safety net (a second commit does nothing)
for _, key in ipairs({ "ALT_L", "ALT_R" }) do
    for _, mods in ipairs({ "", "ALT + ", "ALT + SHIFT + " }) do
        hl.bind(mods .. key, switcher_commit, { release = true, non_consuming = true, ignore_mods = mods == "" })
    end
end

-- Games get a regular workspace rather than a special one, so tearing and direct scanout can kick in
hl.bind(mainMod .. " + G", function()
    local ws = hl.get_active_workspace()

    if ws ~= nil and ws.name == "games" then
        hl.dispatch(hl.dsp.focus({ workspace = "previous" }))
    else
        hl.dispatch(hl.dsp.focus({ workspace = "name:games" }))
    end
end, { description = "Toggle games workspace" })

-------------------------------------------------------
-- Session control
-------------------------------------------------------

hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd("qs ipc call bar panel power"), { description = "Toggle system control menu" })
hl.bind(mainMod .. " + CONTROL + L", hl.dsp.exec_cmd("loginctl lock-session"), { description = "Lock session" })

-------------------------------------------------------
-- Application shortcuts
-------------------------------------------------------

hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("qs ipc call launcher toggle"), { description = "Toggle application launcher" })
hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd("qs ipc call cheatsheet toggle"), { description = "Show keybinds" })
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("qs ipc call settings open ''"), { description = "Open settings" })

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("kitty -1"), { description = "Open Terminal" })
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("kitty bash -c yazi", { float = true, center = true, size = { "monitor_w*0.5", "monitor_h*0.5" } }), { description = "Open File Explorer" })
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("firefox"), { description = "Open web browser" })
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("code"), { description = "Open Code Editor" })
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("steam"), { description = "Open Steam" })
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("discord"), { description = "Open Discord" })

hl.bind("CONTROL + SHIFT + ESCAPE", hl.dsp.exec_cmd("kitty bash -c btop", { float = true, center = true, size = { "monitor_w*0.5", "monitor_h*0.5" } }), { description = "Open btop" })

-- Bar toggle
hl.bind("CONTROL + ESCAPE", hl.dsp.exec_cmd("qs ipc call bar toggle || qs"), { description = "Toggle bar" })

-------------------------------------------------------
-- Screenshot shortcuts
-------------------------------------------------------

-- Screenshot menu
hl.bind("PRINT", hl.dsp.exec_cmd("qs ipc call launcher screenshot"), { description = "Toggle screenshot menu" })

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

-- locked = works while the lock screen is active
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pamixer -i 5"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pamixer -d 5"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("pamixer --default-source -t"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("pamixer -t"), { locked = true })

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-------------------------------------------------------
-- Brightness control
-------------------------------------------------------

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s +5%"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 5%-"), { locked = true, repeating = true })
