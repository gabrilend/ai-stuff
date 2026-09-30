--[[
Special Effects and Missiles (Issue 530)

The art WC3 plays for spells, buffs and scripts, as the game's data:

  effects   a model (an .mdl/.mdx path) at a point, or attached to a
            unit at one of its model's attachment points ("origin",
            "overhead", "chest", "hand left" ...). It plays its Birth,
            then Stand; destroyed, it plays Death and goes. Timed ones
            destroy themselves
  missiles  a model flying from a unit to a unit (homing) or a point at a
            speed, with an arc; something happens when it arrives
  art       which models an ability or buff plays, from its data: the
            map's own change first (war3map.w3a / .w3h), else the stock
            profile's (the install's). Abilities: CasterArt, TargetArt,
            EffectArt, SpecialArt, Areaeffectart, Missileart (with
            Missilespeed, Missilearc), and where they attach
            (Casterattach, Targetattach ...). Buffs: TargetArt,
            EffectArt, SpecialArt and their attachments

The game keeps effects and missiles as records (g.effects, g.missiles):
the map viewer draws them with the model renderer (and marks where a
model isn't found); tests and the script see the same records.

    effects.init(game)
    local fx = game.add_effect(path, { x =, y =, z = } or { unit =, attach = "overhead" }, { duration = 2 })
    game.destroy_effect(fx)
    game.launch(path, from_unit, { unit = target } or { x =, y = }, speed, arc, on_arrive)
    game.ability_art(id, level, "caster")  -- { paths }, attach point
    effects.update(game, dt)
]]

local effects = {}

effects.DEATH_LINGER = 1.5       -- seconds a destroyed effect stays for its Death
effects.MISSILE_SPEED = 1000     -- when the data gives none

-- the ability and buff art fields: kind -> code, profile name, attach code, attach name
effects.ABILITY_ART = {
    caster = { "acat", "CasterArt", "acap", "Casterattach" },
    target = { "atat", "TargetArt", "ata0", "Targetattach" },
    effect = { "aeat", "EffectArt", nil, nil },
    special = { "asat", "SpecialArt", "aspt", "Specialattach" },
    area = { "aaea", "Areaeffectart", nil, nil },
    missile = { "amat", "Missileart", nil, nil },
    lightning = { "alig", "LightningEffect", nil, nil },
}
effects.BUFF_ART = {
    target = { "ftat", "TargetArt", "fta0", "Targetattach" },
    effect = { "feat", "EffectArt", nil, nil },
    special = { "fsat", "SpecialArt", "fspt", "Specialattach" },
}

-- {{{ Reading art
local function split_paths(v)
    local out = {}
    if type(v) ~= "string" then return out end
    for p in v:gmatch("[^,]+") do
        p = p:match("^%s*(.-)%s*$")
        if p ~= "" and p ~= "_" and p ~= "-" then out[#out + 1] = p end
    end
    return out
end

local function read_art(S, id, level, spec)
    if not S then return {}, nil end
    local v = (S:value(id, spec[1], level))
    if v == nil and S.profile_field then v = S:profile_field(id, spec[2]) end
    local attach
    if spec[3] then
        attach = (S:value(id, spec[3], level))
        if attach == nil and S.profile_field then attach = S:profile_field(id, spec[4]) end
    end
    if type(attach) ~= "string" or attach == "" then attach = nil end
    return split_paths(v), attach
end
effects.split_paths = split_paths
-- }}}

-- {{{ effects.init
function effects.init(g)
    g.effects, g.missiles = {}, {}

    function g.ability_art(id, level, kind)
        local spec = effects.ABILITY_ART[kind]
        if not spec then return {}, nil end
        return read_art(g.data.abilities, id, level, spec)
    end
    function g.buff_art(id, kind)
        local spec = effects.BUFF_ART[kind]
        if not spec then return {}, nil end
        return read_art(g.data.buffs, id, 1, spec)
    end
    function g.missile_speed(id, level)
        local S = g.data.abilities
        local v = tonumber((S:value(id, "amsp", level)))
        if not v and S.profile_field then v = tonumber(S:profile_field(id, "Missilespeed")) end
        return v and v > 0 and v or effects.MISSILE_SPEED
    end
    function g.missile_arc(id, level)
        local S = g.data.abilities
        local v = tonumber((S:value(id, "amac", level)))
        if not v and S.profile_field then v = tonumber(S:profile_field(id, "Missilearc")) end
        return v or 0.15
    end

    -- {{{ effects
    -- where: { x, y, z } or { unit, attach }; opts: duration, facing, scale, kind
    function g.add_effect(path, where, opts)
        if not path or path == "" then return nil end
        opts = opts or {}
        local fx = { path = path, x = where.x, y = where.y, z = where.z, unit = where.unit,
                     attach = where.attach and tostring(where.attach):lower() or nil,
                     facing = opts.facing or 0, scale = opts.scale or 1, kind = opts.kind,
                     born = g.time, ends = opts.duration and (g.time + opts.duration) or nil }
        if fx.unit and not fx.x then fx.x, fx.y, fx.z = fx.unit.x, fx.unit.y, fx.unit.z end
        if not fx.z and g.ground_at and fx.x then fx.z = g.ground_at(fx.x, fx.y) end
        g.effects[#g.effects + 1] = fx
        g.effects_made = (g.effects_made or 0) + 1
        return fx
    end

    function g.destroy_effect(fx)
        if not fx or fx.dying then return end
        fx.dying = g.time
    end

    -- every art path of a kind, played where it belongs; timed
    function g.play_art(paths, where, duration, kind)
        local made = {}
        for _, p in ipairs(paths) do
            made[#made + 1] = g.add_effect(p, where, { duration = duration, kind = kind })
        end
        return made
    end
    -- }}}

    -- {{{ missiles
    -- to: { unit } (homing) or { x, y }; on_arrive(missile) when it lands
    function g.launch(path, from, to, speed, arc, on_arrive)
        local m = { path = path, x = from.x, y = from.y, z = (from.z or 0) + 60,
                    sx = from.x, sy = from.y, target = to.unit, tx = to.x or (to.unit and to.unit.x),
                    ty = to.y or (to.unit and to.unit.y), speed = speed or effects.MISSILE_SPEED,
                    arc = arc or 0.15, on_arrive = on_arrive, source = from, born = g.time, travelled = 0 }
        m.tz = (to.unit and to.unit.z or (g.ground_at and g.ground_at(m.tx, m.ty)) or 0) + (to.unit and 50 or 0)
        m.sz = m.z
        g.missiles[#g.missiles + 1] = m
        return m
    end
    -- }}}

    -- buffs show their art while they last (buffs.lua calls these)
    function g.on_buff_added(u, b)
        if b.art ~= nil or not b.id then return end
        b.art = {}
        local paths, attach = g.buff_art(b.id, "target")
        -- an aura's buff shows its ability's target art when the buff has none
        if not paths[1] and b.art_paths then paths, attach = b.art_paths, b.art_attach end
        for _, p in ipairs(paths) do
            b.art[#b.art + 1] = g.add_effect(p, { unit = u, attach = attach or "overhead" }, { kind = "buff" })
        end
    end
    function g.on_buff_removed(u, b)
        for _, fx in ipairs(b.art or {}) do g.destroy_effect(fx) end
    end
end
-- }}}

-- {{{ effects.update
function effects.update(g, dt)
    -- effects: attached ones follow their unit; timed ones end; destroyed
    -- ones linger for their Death, then go
    local keep = {}
    for _, fx in ipairs(g.effects) do
        if fx.unit then
            if fx.unit.removed or (fx.unit.alive == false and fx.kind == "buff") then g.destroy_effect(fx) end
            fx.x, fx.y, fx.z = fx.unit.x, fx.unit.y, fx.unit.z
        end
        if fx.ends and g.time >= fx.ends then g.destroy_effect(fx) end
        if not (fx.dying and g.time - fx.dying >= effects.DEATH_LINGER) then keep[#keep + 1] = fx end
    end
    g.effects = keep
    -- missiles: fly, home, arc, land
    local flying = {}
    for _, m in ipairs(g.missiles) do
        if m.target and m.target.alive ~= false and not m.target.removed then
            m.tx, m.ty = m.target.x, m.target.y
            m.tz = (m.target.z or 0) + 50
        end
        local dx, dy = m.tx - m.x, m.ty - m.y
        local d = math.sqrt(dx * dx + dy * dy)
        local step = m.speed * dt
        if d <= step then
            m.x, m.y, m.z = m.tx, m.ty, m.tz
            m.landed = true
            if m.on_arrive then m.on_arrive(m) end
        else
            m.x, m.y = m.x + dx / d * step, m.y + dy / d * step
            m.travelled = m.travelled + step
            local total = m.travelled + d
            local f = m.travelled / total
            m.z = m.sz + (m.tz - m.sz) * f + math.sin(f * math.pi) * total * m.arc
            m.facing = math.atan2(dy, dx)
            flying[#flying + 1] = m
        end
    end
    g.missiles = flying
end
-- }}}

return effects
