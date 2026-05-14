-------------------------------------------------------
-- Window rules
-------------------------------------------------------

-- Browser modals
local modal_titles = {
    "same image",
    "save as",
    "save to",
    "file upload",
}

for _, title in ipairs(modal_titles) do
    local match = {
        class = "xdg-desktop-portal-gtk",
        title = "(?i:.*" .. title .. ".*)"
    }

    hl.window_rule({ match = match, float = true })
    hl.window_rule({ match = match, center = true })
end

-------------------------------------------------------
-- Layer rules
-------------------------------------------------------

hl.layer_rule({ match = { namespace = "rofi" }, no_anim = true})
