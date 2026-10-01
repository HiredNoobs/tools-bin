-------------------------------------------------------
-- Per-monitor workspaces
-------------------------------------------------------

-- Each monitor has its own workspaces 1-10. Internally the main monitor uses ids 1-10, the
-- second 11-20 and so on. Binds address a monitor directly (Super+N main, Super+Ctrl+N second)
-- and the bar shows each monitor's own 1-10.
--
-- Monitors get roles (main, second, ...). The machine file names them; unnamed screens take
-- the free roles left to right. Apps can be placed on a role's workspace with place(); when that
-- role's screen isn't connected (e.g. the laptop away from home) they go to the same number on
-- the main monitor instead. Everything is re-applied when screens are plugged in or out.

local M = {}

-- Set by the machine file, e.g. { main = "DP-1", second = "DP-2" }
M.roles = {}

local role_order = { "main", "second", "third", "fourth" }
local placements = {}
-- Rules made by the last apply(), switched off before new ones are made
local active_rules = {}

-- Role -> monitor name, for the screens connected right now
local function assign()
    local monitors = hl.get_monitors()
    local connected = {}
    for _, monitor in ipairs(monitors) do
        connected[monitor.name] = true
    end

    local assigned, used = {}, {}
    for _, role in ipairs(role_order) do
        local name = M.roles[role]
        if name and connected[name] then
            assigned[role] = name
            used[name] = true
        end
    end

    -- Unnamed screens (or a named main that isn't connected) fill the free roles, left to right
    table.sort(monitors, function(a, b) return a.x < b.x or (a.x == b.x and a.y < b.y) end)
    for _, monitor in ipairs(monitors) do
        if not used[monitor.name] then
            for _, role in ipairs(role_order) do
                if not assigned[role] then
                    assigned[role] = monitor.name
                    used[monitor.name] = true
                    break
                end
            end
        end
    end

    return assigned
end

-- Workspace id for "N on the main monitor"
function M.main(n)
    return n
end

-- Workspace id for "N on the second monitor". While it's unplugged its workspaces sit on the
-- main monitor, and anything sent there goes back when it's plugged in again.
function M.second(n)
    return 10 + n
end

-- Shows the second monitor's workspace N. Normally that focuses it (the cursor moves over);
-- with a game focused, the game keeps focus and the cursor stays put.
function M.show_second(n)
    local window = hl.get_active_window()
    if not window or window.content_type ~= "game" then
        hl.dispatch(hl.dsp.focus({ workspace = M.second(n) }))
        return
    end

    -- Switching shows the workspace but focuses it, so hand focus straight back to the game,
    -- with cursor warping off throughout
    local warps_off = hl.get_config("cursor.no_warps")
    hl.config({ cursor = { no_warps = true } })
    hl.dispatch(hl.dsp.focus({ workspace = M.second(n) }))
    hl.dispatch(hl.dsp.focus({ window = "address:" .. window.address }))
    hl.config({ cursor = { no_warps = warps_off } })
end

-- Put windows matching `match` on workspace `workspace` of the monitor with `role`
function M.place(match, role, workspace)
    table.insert(placements, { match = match, role = role, workspace = workspace })
end

-- move_back: also move workspaces to their own monitor; only when a screen is plugged in, so a
-- config reload never shuffles windows around
local function apply(move_back)
    for _, rule in ipairs(active_rules) do
        rule:set_enabled(false)
    end
    active_rules = {}

    local assigned = assign()
    local function keep(rule)
        table.insert(active_rules, rule)
    end

    -- Each connected monitor's range lives on it
    for index, role in ipairs(role_order) do
        local name = assigned[role]
        if name then
            for n = 1, 10 do
                keep(hl.workspace_rule({ workspace = tostring((index - 1) * 10 + n), monitor = name }))
            end
        end
    end

    -- Games always on the main monitor
    if assigned.main then
        keep(hl.workspace_rule({ workspace = "name:games", monitor = assigned.main }))
    end

    -- Apps on their role's monitor, or the same number on main when it isn't connected
    for _, placement in ipairs(placements) do
        local target = placement.workspace
        for index, role in ipairs(role_order) do
            if role == placement.role and assigned[role] then
                target = (index - 1) * 10 + placement.workspace
            end
        end
        keep(hl.window_rule({ match = placement.match, workspace = target .. " silent" }))
    end

    -- A screen coming back gets its workspaces back (they moved to another while it was gone)
    if not move_back then
        return
    end
    for _, workspace in ipairs(hl.get_workspaces()) do
        local index = workspace.id > 0 and math.floor((workspace.id - 1) / 10) + 1 or nil
        local home = index and assigned[role_order[index] or ""]
        if home and workspace.monitor and workspace.monitor.name ~= home then
            hl.dispatch(hl.dsp.workspace.move({ workspace = workspace.id, monitor = home }))
        end
    end
end

-- Called from hyprland.lua once the machine file has set the roles
function M.setup()
    apply(false)
    hl.on("monitor.added", function() apply(true) end)
    hl.on("monitor.removed", function() apply(false) end)
end

return M
