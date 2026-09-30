--[[
Command Card (Issue 518b)

The 4 x 3 grid of buttons at the bottom right of WC3's console, for the
unit in charge of a selection: which buttons it has, where, and their
hotkeys.

Where the map's own object data says (custom units' ability, train and
build lists; custom abilities' names, hotkeys and button positions;
custom units' button positions and hotkeys), the card follows it. The
stock commands' places below are FROM MEMORY of the game's card (the
game's CommandFunc data is on the owner's install): Move, Stop, Hold
Position, Attack across the top; Patrol under Move; Hero Abilities and
Gather at the end of the middle row; Build at the bottom left; Cancel at
the bottom right of every sub-menu.

    local commands = require("ui.wc3.commands")
    local card = commands.card(unit, db, "main")
    card[commands.slot(3, 0)]    -- Attack: { id, label, hotkey, icon, action }

A card is indexed 1-12 by slot (row * 4 + column + 1, rows from the top).
`db` answers questions about the map's objects (see demo/wc3map/main.lua):
    db.unit_list(id, code)    -> list of ids (abilities, trains, builds)
    db.unit_button(id)        -> { name, hotkey, x, y, tip, archetype } for a trainable
    db.ability_button(id)     -> { name, hotkey, x, y, tip, hero }
    db.can_learn(hero, id)    -> whether a hero can learn a skill now (optional)
    db.revivable(building)    -> the fallen heroes an altar can revive (optional)
    db.shop_stock(unit)       -> what a shop sells: { {id, kind, count, max}, ... } (optional)
    db.item_button(id)        -> { name, hotkey, x, y, tip } for an item (optional)
    db.castable(unit)         -> its abilities: { {id, level, target}, ... } (optional)
    db.ability_ready(unit, id) -> ok, why not, cooldown share left (optional)
]]

local commands = {}

-- {{{ commands.slot
function commands.slot(col, row)
    return row * 4 + col + 1
end
-- }}}

-- {{{ Stock commands (places from memory; see the header)
commands.STOCK = {
    move   = { label = "Move", hotkey = "M", col = 0, row = 0, icon = "move" },
    stop   = { label = "Stop", hotkey = "S", col = 1, row = 0, icon = "stop" },
    hold   = { label = "Hold Position", hotkey = "H", col = 2, row = 0, icon = "hold" },
    attack = { label = "Attack", hotkey = "A", col = 3, row = 0, icon = "attack" },
    patrol = { label = "Patrol", hotkey = "P", col = 0, row = 1, icon = "patrol" },
    repair = { label = "Repair", hotkey = "R", col = 2, row = 1, icon = "repair" },
    gather = { label = "Gather", hotkey = "G", col = 3, row = 1, icon = "gather" },
    learn  = { label = "Hero Abilities", hotkey = "O", col = 3, row = 1, icon = "learn" },
    rally  = { label = "Set Rally Point", hotkey = "Y", col = 3, row = 1, icon = "rally" },
    build  = { label = "Build Structure", hotkey = "B", col = 0, row = 2, icon = "build" },
    cancel = { label = "Cancel", hotkey = "ESCAPE", col = 3, row = 2, icon = "cancel" },
}

-- Tooltips for the stock commands (our own wording)
commands.TIPS = {
    move = "Walk to a point. Right-click the ground does the same.",
    stop = "Stop what the unit is doing.",
    hold = "Stand still and hold this ground.",
    attack = "Walk to a point, fighting anything hostile on the way.",
    patrol = "Walk back and forth between here and a point.",
    repair = "Mend a damaged building or machine.",
    gather = "Gather gold or lumber.",
    learn = "Spend a skill point on one of the hero's abilities.",
    rally = "Where newly trained units walk to.",
    build = "Choose a structure to build.",
    cancel = "Go back.",
}
-- }}}

-- {{{ place
-- Put button b at (col, row) if that slot is free, else in the first free
-- slot of `order` (a list of rows to search). Returns the slot or nil.
local function place(card, b, col, row, order)
    if col and row and col >= 0 and col <= 3 and row >= 0 and row <= 2 then
        local s = commands.slot(col, row)
        if not card[s] then
            card[s] = b
            return s
        end
    end
    for _, r in ipairs(order or { 2, 1, 0 }) do
        for c = 0, 3 do
            local s = commands.slot(c, r)
            if not card[s] then
                card[s] = b
                return s
            end
        end
    end
    return nil
end
-- }}}

-- {{{ stock
local function stock(card, key, extra)
    local d = commands.STOCK[key]
    local b = { id = key, label = d.label, hotkey = d.hotkey, icon = d.icon, action = key,
                tip = commands.TIPS[key] }
    for k, v in pairs(extra or {}) do b[k] = v end
    return place(card, b, d.col, d.row)
end
-- }}}

-- {{{ commands.card
-- unit: { id, spec (a design spec: design, archetype, hero), player }
-- mode: "main" | "build" (a worker's structures) | "learn" (a hero's skills)
function commands.card(unit, db, mode)
    local card = {}
    local spec = unit.spec or {}
    mode = mode or "main"

    if mode == "build" or mode == "learn" then
        stock(card, "cancel")   -- first: the bottom right is always Cancel
        local list = mode == "build" and db.unit_list(unit.id, "ubui")
            or db.unit_list(unit.id, "uhab")
        for _, id in ipairs(list) do
            local info = (mode == "build" and db.unit_button(id) or db.ability_button(id)) or {}
            local label = info.name or id
            -- a hero skill: its next level, and whether it can be learned now
            local learnable
            if mode == "learn" and db.can_learn then
                local have = unit.abilities and unit.abilities[id] or 0
                label = string.format("%s (level %d)", label, have + 1)
                learnable = db.can_learn(unit, id)
            end
            place(card, { id = id, label = label, hotkey = info.hotkey,
                          icon = mode == "build" and "structure" or "ability",
                          action = mode, target = id, tip = info.tip,
                          disabled = mode == "learn" and db.can_learn and not learnable or nil },
                  mode == "learn" and info.rx or info.x, mode == "learn" and info.ry or info.y, { 0, 1, 2 })
        end
        return card
    end

    -- a building going up: only Cancel (issue 531)
    if spec.design == "building" and unit.building_up then
        place(card, { id = "cancel_build", label = "Cancel", hotkey = "ESCAPE", icon = "cancel",
                      action = "cancel_build", tip = "Stop building it, and get most of its cost back." }, 3, 2)
        return card
    end
    -- a building upgrading: only Cancel (issue 535)
    if spec.design == "building" and unit.upgrading then
        place(card, { id = "cancel_upgrade", label = "Cancel", hotkey = "ESCAPE", icon = "cancel",
                      action = "cancel_upgrade", tip = "Stop the upgrade, and get its cost back." }, 3, 2)
        return card
    end
    -- a shop or tavern: what it sells, with how many are in stock (issue 533)
    local sold = db.shop_stock and db.shop_stock(unit) or {}
    if #sold > 0 then
        for _, e in ipairs(sold) do
            local info = (e.kind == "unit" and db.unit_button(e.id)) or (db.item_button and db.item_button(e.id)) or {}
            place(card, { id = e.id, label = string.format("%s %s (%d)", e.kind == "unit" and "Hire" or "Buy",
                                                           info.name or e.id, e.count),
                          hotkey = info.hotkey, icon = e.kind == "unit" and "train" or "ability",
                          action = "buy", target = e.id, tip = info.tip, disabled = e.count <= 0 or nil },
                  info.x, info.y, { 0, 1, 2 })
        end
        -- who buys here: the button cycles through your units in range (issue 539)
        if db.shop_buyer then
            local buyer, items = db.shop_buyer(unit)
            local name = buyer and (buyer.name or (db.unit_button(buyer.id) or {}).name or buyer.id)
            place(card, { id = "next_buyer", label = buyer and ("Buyer: " .. name)
                              or (items and "No hero near" or "No unit near"),
                          hotkey = "U", icon = "select", action = "next_buyer",
                          tip = "Which of your units near the shop buys. Pick another." }, 0, 2)
        end
        return card
    end
    if spec.design == "building" then
        local trains = db.unit_list(unit.id, "utra")
        for _, id in ipairs(trains) do
            local info = db.unit_button(id) or {}
            place(card, { id = id, label = "Train " .. (info.name or id), hotkey = info.hotkey,
                          icon = "train", action = "train", target = id, tip = info.tip,
                          archetype = info.archetype },
                  info.x, info.y, { 0, 1 })
        end
        -- an altar's fallen heroes (issue 528)
        for _, hero in ipairs(db.revivable and db.revivable(unit) or {}) do
            place(card, { id = hero.id, label = "Revive " .. (hero.name or hero.id), icon = "train",
                          action = "revive", target = hero, tip = "Bring this hero back." }, nil, nil, { 0, 1 })
        end
        if #trains > 0 or (db.revivable and #db.revivable(unit) > 0) then stock(card, "rally") end
        -- what it researches, with the level next (issue 542)
        for _, id in ipairs(db.researches and db.researches(unit) or {}) do
            local info = db.research_button(id) or {}
            local lvl = db.next_research_level and db.next_research_level(unit, id) or 1
            local done = info.max and lvl > info.max
            place(card, { id = id, label = "Research " .. (info.name or id)
                              .. ((info.max or 1) > 1 and not done and (" (level " .. lvl .. ")") or ""),
                          hotkey = info.hotkey, icon = "ability", action = "research", target = id, tip = info.tip,
                          disabled = done or nil },
                  info.x, info.y, { 0, 1, 2 })
        end
        -- what it upgrades to (a hall's Keep, a tower's kinds: issue 535)
        for _, id in ipairs(db.upgrades and db.upgrades(unit) or {}) do
            local info = db.unit_button(id) or {}
            place(card, { id = id, label = "Upgrade to " .. (info.name or id), hotkey = info.hotkey,
                          icon = "structure", action = "upgrade", target = id, tip = info.tip },
                  info.x, info.y, { 0, 1, 2 })
        end
    else
        for _, key in ipairs({ "move", "stop", "hold", "attack", "patrol" }) do stock(card, key) end
        if spec.archetype == "worker" then
            stock(card, "gather")
            stock(card, "repair")
            if #db.unit_list(unit.id, "ubui") > 0 then stock(card, "build") end
        end
        if spec.hero then stock(card, "learn") end
    end

    -- abilities: the map's placements, else the bottom row, then the middle.
    -- With the game's abilities (issue 529): the unit's own, learned ones,
    -- with their cooldowns; passives and auras shown but not pressed
    if db.castable then
        for _, a in ipairs(db.castable(unit)) do
            local info = db.ability_button(a.id) or {}
            if not info.hidden then
                local passive = a.target == "passive" or a.target == "aura"
                local ready, why, left = true, nil, 0
                if db.ability_ready and not passive then ready, why, left = db.ability_ready(unit, a.id) end
                place(card, { id = a.id, label = (info.name or a.id) .. (a.level > 1 and (" " .. a.level) or ""),
                              hotkey = info.hotkey, icon = "ability", action = passive and "passive" or "ability",
                              target = a.id, target_kind = a.target, tip = info.tip,
                              disabled = (not passive and not ready and why ~= "not ready yet") or nil,
                              cooldown = left > 0 and left or nil },
                      info.x, info.y, { 2, 1 })
            end
        end
        return card
    end
    local abilities = db.unit_list(unit.id, spec.hero and "uhab" or "uabi")
    for _, id in ipairs(abilities) do
        local info = db.ability_button(id) or {}
        if not info.hidden then
            place(card, { id = id, label = info.name or id, hotkey = info.hotkey,
                          icon = "ability", action = "ability", target = id, tip = info.tip },
                  info.x, info.y, { 2, 1 })
        end
    end
    return card
end
-- }}}

-- {{{ commands.find_hotkey
-- The slot whose hotkey is key ("M", "ESCAPE"), or nil
function commands.find_hotkey(card, key)
    for s = 1, 12 do
        local b = card[s]
        if b and b.hotkey and b.hotkey:upper() == key then return s end
    end
    return nil
end
-- }}}

return commands
