--[[
JASS natives: special effects and spell art (Issue 530)

The script's side of demo/wc3map/effects.lua (the world's add_effect,
destroy_effect, ability_art):

  AddSpecialEffect(path, x, y), AddSpecialEffectLoc(path, loc)
  AddSpecialEffectTarget(path, widget, attach point)
  AddSpellEffect(ById)(ability, effect type, x, y) and ...Loc
  AddSpellEffectTarget(ById)(ability, effect type, widget, attach point)
  GetAbilityEffect(ById)(ability, effect type, index) -> a path
  DestroyEffect, and Blizzard.j's ...BJ forms with bj_lastCreatedEffect

Effect types (common.j's EFFECT_TYPE_*, by name or number): effect 0,
target 1, caster 2, special 3, area effect 4, missile 5, lightning 6. In
a world without effects the handles are kept and nothing is drawn.
]]

return function(V, N, T)
    local vm = require("jass.vm")
    local function typed(kind, names)
        for name in names:gmatch("%S+") do T[name] = kind end
    end
    local W = V.world
    local KIND = { [0] = "effect", "target", "caster", "special", "area", "missile", "lightning" }
    local NAMED = { EFFECT_TYPE_EFFECT = "effect", EFFECT_TYPE_TARGET = "target", EFFECT_TYPE_CASTER = "caster",
                    EFFECT_TYPE_SPECIAL = "special", EFFECT_TYPE_AREA_EFFECT = "area", EFFECT_TYPE_MISSILE = "missile",
                    EFFECT_TYPE_LIGHTNING = "lightning" }
    local function kind_of(t) return KIND[t] or NAMED[t] or "effect" end
    local function set_last(fx) rawset(V.env, "bj_lastCreatedEffect", fx) return fx end

    -- {{{ effects
    local function add(path, where)
        local fx = W.add_effect and W.add_effect(path, where, { kind = "script" })
            or { path = path, x = where.x, y = where.y, unit = where.unit, attach = where.attach }
        return V:handle(fx)
    end
    N.AddSpecialEffect = function(path, x, y) return add(path, { x = x, y = y }) end
    N.AddSpecialEffectLoc = function(path, l) return add(path, { x = l and l.x or 0, y = l and l.y or 0 }) end
    N.AddSpecialEffectTarget = function(path, w, attach) return add(path, { unit = w, attach = attach }) end
    N.DestroyEffect = function(fx)
        if not fx then return end
        if W.destroy_effect then W.destroy_effect(fx) else fx.dying = true end
    end
    N.AddSpecialEffectLocBJ = function(l, path) return set_last(N.AddSpecialEffectLoc(path, l)) end
    N.AddSpecialEffectTargetUnitBJ = function(attach, w, path) return set_last(N.AddSpecialEffectTarget(path, w, attach)) end
    N.DestroyEffectBJ = N.DestroyEffect
    N.GetLastCreatedEffectBJ = function() return rawget(V.env, "bj_lastCreatedEffect") end
    -- }}}

    -- {{{ spell art
    local function id_of(a) return type(a) == "number" and vm.id2s(a) or tostring(a or "") end
    local function art(a, t)
        if not W.ability_art then return {}, nil end
        return W.ability_art(id_of(a), 1, kind_of(t))
    end
    N.GetAbilityEffect = function(a, t, index)
        local paths = art(a, t)
        return paths[(index or 0) + 1] or ""
    end
    N.GetAbilityEffectById = N.GetAbilityEffect
    local function spell_effect(a, t, where)
        local paths, attach = art(a, t)
        if not paths[1] then return V:handle({ path = "", x = where.x, y = where.y }) end
        if where.unit and not where.attach then where.attach = attach end
        return add(paths[1], where)
    end
    N.AddSpellEffect = function(a, t, x, y) return spell_effect(a, t, { x = x, y = y }) end
    N.AddSpellEffectById = N.AddSpellEffect
    N.AddSpellEffectLoc = function(a, t, l) return spell_effect(a, t, { x = l and l.x or 0, y = l and l.y or 0 }) end
    N.AddSpellEffectByIdLoc = N.AddSpellEffectLoc
    N.AddSpellEffectTarget = function(a, t, w, attach) return spell_effect(a, t, { unit = w, attach = attach }) end
    N.AddSpellEffectTargetById = N.AddSpellEffectTarget
    typed("string", "GetAbilityEffect GetAbilityEffectById")
    -- }}}
end
