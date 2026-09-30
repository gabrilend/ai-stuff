--[[
Buffs (Issue 529)

What spells and auras leave on units, and what it does to them. A buff is
kept on its unit until it runs out (or is dispelled, or its unit dies):

  { id = "BHbd" (its buff id, what the script asks about), source = unit,
    ends = game time (nil: until removed), aura = true (kept alive by an
    aura's refreshes),
    stun, invulnerable, invisible,             -- flags
    move, attack,                              -- speed factors: -0.5 is half
    armor, damage,                             -- armour, damage factor
    hp_regen, mana_regen,                      -- per second
    dps }                                      -- damage per second

Buffs of the same id don't stack: a new one replaces the old (the longer
stays). Each tick every unit's buffs are summed into what the rest of the
game reads:

  u.stunned, u.buff_invulnerable, u.invisible
  u.speed_mult, u.attack_mult     (1 + the sum of the move / attack factors)
  u.armor_bonus, u.damage_mult    (armour added; damage factor)
  u.hp_regen_bonus, u.mana_regen_bonus

    buffs.add(game, unit, spec)     -> the buff
    buffs.remove(game, unit, id)    -- by id (or all with id nil)
    buffs.has(unit, id)
    buffs.update(game, dt)
]]

local buffs = {}

-- {{{ buffs.add / remove / has
function buffs.add(g, u, spec)
    if not u or u.alive == false then return nil end
    u.buffs = u.buffs or {}
    local b = {}
    for k, v in pairs(spec) do b[k] = v end
    b.id = b.id or "Bxxx"
    if b.duration and not b.ends then b.ends = g.time + b.duration end
    for i, old in ipairs(u.buffs) do
        if old.id == b.id then
            -- the same buff again: the longer lasting stays
            if old.ends == nil or (b.ends and old.ends > b.ends and not b.aura) then return old end
            -- an aura refreshing keeps its art playing
            if old.art and old.aura and b.aura then
                b.art = old.art
                u.buffs[i] = b
                buffs.sum(u)
                return b
            end
            if g.on_buff_removed then g.on_buff_removed(u, old) end
            u.buffs[i] = b
            buffs.sum(u)
            if g.on_buff_added then g.on_buff_added(u, b) end
            return b
        end
    end
    u.buffs[#u.buffs + 1] = b
    buffs.sum(u)
    -- its art while it lasts (effects.lua, issue 530)
    if g.on_buff_added then g.on_buff_added(u, b) end
    return b
end

function buffs.remove(g, u, id)
    if not u or not u.buffs then return 0 end
    local keep, n = {}, 0
    for _, b in ipairs(u.buffs) do
        if id == nil or b.id == id then
            n = n + 1
            if g and g.on_buff_removed then g.on_buff_removed(u, b) end
        else
            keep[#keep + 1] = b
        end
    end
    u.buffs = keep
    buffs.sum(u)
    return n
end

function buffs.has(u, id)
    for _, b in ipairs(u and u.buffs or {}) do
        if b.id == id then return b end
    end
    return nil
end
-- }}}

-- {{{ buffs.sum
-- A unit's buffs into the numbers the game reads
function buffs.sum(u)
    local stun, inv, invis = false, false, false
    local move, attack, armor, damage, hpr, mpr = 0, 0, 0, 0, 0, 0
    for _, b in ipairs(u.buffs or {}) do
        stun = stun or b.stun == true
        inv = inv or b.invulnerable == true
        invis = invis or b.invisible == true
        move = move + (b.move or 0)
        attack = attack + (b.attack or 0)
        armor = armor + (b.armor or 0)
        damage = damage + (b.damage or 0)
        hpr = hpr + (b.hp_regen or 0)
        mpr = mpr + (b.mana_regen or 0)
    end
    u.stunned = stun or nil
    u.buff_invulnerable = inv or nil
    -- (a unit invisible by its own nature stays so)
    if invis then u.invisible = true elseif u.invisible_by_buff then u.invisible = nil end
    u.invisible_by_buff = invis or nil
    u.speed_mult = math.max(0.1, 1 + move)
    u.attack_mult = math.max(0.1, 1 + attack)
    u.armor_bonus = armor
    u.damage_mult = math.max(0, 1 + damage)
    u.hp_regen_bonus, u.mana_regen_bonus = hpr, mpr
    if stun then u.swing = nil end
end
-- }}}

-- {{{ buffs.update
function buffs.update(g, dt)
    for _, u in ipairs(g.units) do
        local list = u.buffs
        if list and #list > 0 then
            if u.alive == false then
                for _, b in ipairs(list) do
                    if g.on_buff_removed then g.on_buff_removed(u, b) end
                end
                u.buffs = {}
                buffs.sum(u)
            else
                local keep, changed = {}, false
                for _, b in ipairs(list) do
                    if b.dps and b.dps > 0 and g.spell_damage then
                        g.spell_damage(b.source or u, u, b.dps * dt)
                    end
                    if b.ends and g.time >= b.ends then
                        changed = true
                        if g.on_buff_removed then g.on_buff_removed(u, b) end
                        if b.on_end then b.on_end(g, u, b) end
                    else
                        keep[#keep + 1] = b
                    end
                end
                if changed then
                    u.buffs = keep
                    buffs.sum(u)
                end
            end
        end
    end
end
-- }}}

return buffs
