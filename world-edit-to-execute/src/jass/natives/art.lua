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

Lightning (issue 538): AddLightning(Ex), MoveLightning(Ex),
DestroyLightning, Get/SetLightningColor*, and Blizzard.j's AddLightningLoc,
MoveLightningLoc, DestroyLightningBJ, SetLightningColorBJ,
GetLastCreatedLightningBJ (bj_lastCreatedLightning). A bolt without a
height is at the ground's.

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

    -- {{{ lightning (issue 538)
    local function ground(x, y) return W.ground_at and W.ground_at(x, y) or 0 end
    local function bolt(code, x1, y1, z1, x2, y2, z2)
        local from, to = { x = x1 or 0, y = y1 or 0, z = z1 }, { x = x2 or 0, y = y2 or 0, z = z2 }
        local l = W.add_lightning and W.add_lightning(code, from, to, { kind = "script" })
            or { code = code, from = from, to = to, r = 1, g = 1, b = 1, a = 1 }
        return V:handle(l)
    end
    N.AddLightning = function(code, check, x1, y1, x2, y2)
        return bolt(code, x1, y1, ground(x1 or 0, y1 or 0), x2, y2, ground(x2 or 0, y2 or 0))
    end
    N.AddLightningEx = function(code, check, x1, y1, z1, x2, y2, z2) return bolt(code, x1, y1, z1, x2, y2, z2) end
    local function move(l, x1, y1, z1, x2, y2, z2)
        if not l then return false end
        local from, to = { x = x1 or 0, y = y1 or 0, z = z1 }, { x = x2 or 0, y = y2 or 0, z = z2 }
        if W.move_lightning then return W.move_lightning(l, from, to) end
        l.from, l.to = from, to
        return true
    end
    N.MoveLightning = function(l, check, x1, y1, x2, y2)
        return move(l, x1, y1, ground(x1 or 0, y1 or 0), x2, y2, ground(x2 or 0, y2 or 0))
    end
    N.MoveLightningEx = function(l, check, x1, y1, z1, x2, y2, z2) return move(l, x1, y1, z1, x2, y2, z2) end
    N.DestroyLightning = function(l)
        if not l then return false end
        if W.destroy_lightning then return W.destroy_lightning(l) end
        l.gone = true
        return true
    end
    N.GetLightningColorA = function(l) return l and l.a or 0 end
    N.GetLightningColorR = function(l) return l and l.r or 0 end
    N.GetLightningColorG = function(l) return l and l.g or 0 end
    N.GetLightningColorB = function(l) return l and l.b or 0 end
    N.SetLightningColor = function(l, r, g, b, a)
        if not l then return false end
        l.r, l.g, l.b, l.a = r, g, b, a
        return true
    end
    local function last(l) rawset(V.env, "bj_lastCreatedLightning", l) return l end
    N.AddLightningLoc = function(code, a, b)
        local x1, y1, x2, y2 = a and a.x or 0, a and a.y or 0, b and b.x or 0, b and b.y or 0
        return last(N.AddLightningEx(code, true, x1, y1, ground(x1, y1), x2, y2, ground(x2, y2)))
    end
    N.MoveLightningLoc = function(l, a, b)
        local x1, y1, x2, y2 = a and a.x or 0, a and a.y or 0, b and b.x or 0, b and b.y or 0
        return N.MoveLightningEx(l, true, x1, y1, ground(x1, y1), x2, y2, ground(x2, y2))
    end
    N.DestroyLightningBJ = N.DestroyLightning
    N.SetLightningColorBJ = function(l, r, g, b, a) N.SetLightningColor(l, r, g, b, a) end
    N.GetLastCreatedLightningBJ = function() return rawget(V.env, "bj_lastCreatedLightning") end
    N.GetLightningColorABJ = N.GetLightningColorA
    N.GetLightningColorRBJ = N.GetLightningColorR
    N.GetLightningColorGBJ = N.GetLightningColorG
    N.GetLightningColorBBJ = N.GetLightningColorB
    typed("real", "GetLightningColorA GetLightningColorR GetLightningColorG GetLightningColorB "
        .. "GetLightningColorABJ GetLightningColorRBJ GetLightningColorGBJ GetLightningColorBBJ")
    -- }}}
end
