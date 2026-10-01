--[[
Console Layout (Issue 518b)

Where each part of WC3's in-game interface sits, for a screen of w x h
pixels. The arrangement follows the game's console: menu buttons at the
top left (Quests, Menu, Allies, Log), the day clock at the top centre,
resources at the top right; along the bottom, the minimap (with its five
buttons beside it), the portrait, the unit's information, the inventory
and the command card; hero buttons down the left edge and the idle-worker
button above the minimap.

    local r = layout.compute(1280, 720)
    r.card[1]   -- { x, y, w, h } of the top-left command button
]]

local layout = {}

-- {{{ layout.compute
function layout.compute(w, h)
    local r = { w = w, h = h }
    r.top = { x = 0, y = 0, w = w, h = 30 }
    r.menu = {}
    local labels = { { "Quests", "F9", "quests" }, { "Menu", "F10", "menu" },
                     { "Allies", "F11", "allies" }, { "Log", "F12", "log" } }
    for i, m in ipairs(labels) do
        r.menu[i] = { x = 6 + (i - 1) * 108, y = 3, w = 104, h = 24, label = m[1], key = m[2], panel = m[3] }
    end
    r.clock = { x = w / 2 - 60, y = 0, w = 120, h = 40 }
    r.resources = { x = w - 470, y = 0, w = 470, h = 30 }

    local ch = 192
    r.console = { x = 0, y = h - ch, w = w, h = ch }
    local base = h - ch + 8

    r.minimap_buttons = {}
    local mb = { { "signal", "G", "Signal" }, { "terrain", "T", "Terrain" },
                 { "ally_colors", "A", "Ally Colours" }, { "creeps", "R", "Creeps" },
                 { "formation", "F", "Formation Movement" } }
    for i, b in ipairs(mb) do
        r.minimap_buttons[i] = { x = 6, y = base + (i - 1) * 35, w = 26, h = 31,
                                 id = b[1], alt = b[2], label = b[3] }
    end
    r.minimap = { x = 38, y = base, w = 176, h = 176 }
    r.portrait = { x = 222, y = base, w = 124, h = 124 }
    r.vitals = { x = 222, y = base + 128, w = 124, h = 44 }
    r.info = { x = 354, y = base, w = 420, h = 176 }
    r.inventory = {}
    for i = 0, 5 do
        local col, row = i % 2, math.floor(i / 2)
        r.inventory[i + 1] = { x = 784 + col * 52, y = base + 10 + row * 54, w = 48, h = 48,
                               key = ({ "KP_7", "KP_8", "KP_4", "KP_5", "KP_1", "KP_2" })[i + 1] }
    end
    r.card = {}
    local size, gap = 58, 4
    local cx = w - 8 - 4 * size - 3 * gap
    for row = 0, 2 do
        for col = 0, 3 do
            r.card[row * 4 + col + 1] = { x = cx + col * (size + gap), y = base + row * (size + gap),
                                          w = size, h = size }
        end
    end
    r.card_area = { x = cx, y = base, w = 4 * size + 3 * gap, h = 3 * size + 2 * gap }
    r.tooltip = { x = w - 8 - 380, bottom = h - ch - 6, w = 380 }

    r.heroes = {}
    for i = 1, 3 do
        r.heroes[i] = { x = 8, y = 40 + (i - 1) * 86, w = 64, h = 64, key = "F" .. i }
    end
    r.idle = { x = 8, y = h - ch - 62, w = 52, h = 52, key = "F8" }
    r.messages = { x = 232, y = h - ch - 130, w = 720, line = 20 }
    r.panel = { x = w / 2 - 240, y = 70, w = 480, h = 420 }
    return r
end
-- }}}

-- {{{ layout.inside
function layout.inside(rect, x, y)
    return x >= rect.x and y >= rect.y and x < rect.x + rect.w and y < rect.y + rect.h
end
-- }}}

return layout
