--[[
JASS natives: fog of war (Issue 524)

The script's side of demo/wc3map/vision.lua (the world's `vision`):

  switches   FogEnable, FogMaskEnable, IsFogEnabled, IsFogMaskEnabled,
             and Blizzard.j's FogEnableOn/Off, FogMaskEnableOn/Off
  modifiers  CreateFogModifierRect/Radius/RadiusLoc (and the BJ forms,
             which start them when told to), FogModifierStart/Stop,
             DestroyFogModifier
  one-off    SetFogStateRect/Radius/RadiusLoc
  questions  IsUnitVisible/Fogged/Masked, IsVisibleToPlayer,
             IsFoggedToPlayer, IsMaskedToPlayer and their Location forms,
             IsUnitInvisible

Fog states are common.j's FOG_OF_WAR_MASKED (1), FOGGED (2) and VISIBLE
(4), as numbers or by name. In a world without vision (a bare VM, or
opts.vision = false) everything is visible and the modifiers are kept
but change nothing.
]]

return function(V, N, T)
    local function typed(kind, names)
        for name in names:gmatch("%S+") do T[name] = kind end
    end
    local function vis() return V.world and V.world.vision end
    local function state_name(s)
        if s == 1 or s == "FOG_OF_WAR_MASKED" then return "masked" end
        if s == 2 or s == "FOG_OF_WAR_FOGGED" then return "fogged" end
        return "visible"
    end
    local function rect_shape(r)
        return { x0 = r and r.minx or 0, y0 = r and r.miny or 0, x1 = r and r.maxx or 0, y1 = r and r.maxy or 0 }
    end
    local function pid(p) return p and p.id or 0 end

    -- {{{ Switches
    V.fog_enabled, V.fog_mask_enabled = true, true
    N.FogEnable = function(on)
        V.fog_enabled = on and true or false
        if vis() then vis():enable(V.fog_enabled) end
    end
    N.FogMaskEnable = function(on)
        V.fog_mask_enabled = on and true or false
        if vis() then vis():enable_mask(V.fog_mask_enabled) end
    end
    N.IsFogEnabled = function() return V.fog_enabled end
    N.IsFogMaskEnabled = function() return V.fog_mask_enabled end
    N.IsMaskEnabled = N.IsFogMaskEnabled
    N.FogEnableOn = function() N.FogEnable(true) end
    N.FogEnableOff = function() N.FogEnable(false) end
    N.FogMaskEnableOn = function() N.FogMaskEnable(true) end
    N.FogMaskEnableOff = function() N.FogMaskEnable(false) end
    typed("boolean", "IsFogEnabled IsFogMaskEnabled IsMaskEnabled")
    -- }}}

    -- {{{ Modifiers
    local function modifier(p, state, shape, after)
        local h = V:handle({ kind = "fogmodifier", player = pid(p), state = state_name(state), shape = shape,
                             after = after and true or false })
        if vis() then h.m = vis():modifier(h.player, h.state, shape, h.after) end
        return h
    end
    N.CreateFogModifierRect = function(p, state, r, shared, after) return modifier(p, state, rect_shape(r), after) end
    N.CreateFogModifierRadius = function(p, state, x, y, radius, shared, after)
        return modifier(p, state, { x = x, y = y, r = radius }, after)
    end
    N.CreateFogModifierRadiusLoc = function(p, state, loc, radius, shared, after)
        return modifier(p, state, { x = loc and loc.x or 0, y = loc and loc.y or 0, r = radius }, after)
    end
    N.FogModifierStart = function(h) if h and h.m and vis() then vis():start(h.m) end end
    N.FogModifierStop = function(h) if h and h.m and vis() then vis():stop(h.m) end end
    N.DestroyFogModifier = function(h) if h and h.m and vis() then vis():destroy(h.m); h.m = nil end end
    -- Blizzard.j: made, started if enabled, and kept as the last created
    N.CreateFogModifierRectBJ = function(enabled, p, state, r)
        local h = N.CreateFogModifierRect(p, state, r, true, false)
        if enabled then N.FogModifierStart(h) end
        rawset(V.env, "bj_lastCreatedFogModifier", h)
        return h
    end
    N.CreateFogModifierRadiusLocBJ = function(enabled, p, state, loc, radius)
        local h = N.CreateFogModifierRadiusLoc(p, state, loc, radius, true, false)
        if enabled then N.FogModifierStart(h) end
        rawset(V.env, "bj_lastCreatedFogModifier", h)
        return h
    end
    N.GetLastCreatedFogModifier = function() return rawget(V.env, "bj_lastCreatedFogModifier") end
    N.FogModifierStartBJ = N.FogModifierStart
    N.FogModifierStopBJ = N.FogModifierStop
    N.DestroyFogModifierBJ = N.DestroyFogModifier
    -- }}}

    -- {{{ One-off states
    N.SetFogStateRect = function(p, state, r)
        if vis() then vis():set_state(pid(p), state_name(state), rect_shape(r)) end
    end
    N.SetFogStateRadius = function(p, state, x, y, radius)
        if vis() then vis():set_state(pid(p), state_name(state), { x = x, y = y, r = radius }) end
    end
    N.SetFogStateRadiusLoc = function(p, state, loc, radius)
        N.SetFogStateRadius(p, state, loc and loc.x or 0, loc and loc.y or 0, radius)
    end
    -- }}}

    -- {{{ Questions
    local function point_state(p, x, y)
        if not vis() then return 2 end
        return vis():state(pid(p), x or 0, y or 0)
    end
    N.IsVisibleToPlayer = function(x, y, p) return point_state(p, x, y) == 2 end
    N.IsFoggedToPlayer = function(x, y, p) return point_state(p, x, y) == 1 end
    N.IsMaskedToPlayer = function(x, y, p) return point_state(p, x, y) == 0 end
    N.IsLocationVisibleToPlayer = function(l, p) return N.IsVisibleToPlayer(l and l.x, l and l.y, p) end
    N.IsLocationFoggedToPlayer = function(l, p) return N.IsFoggedToPlayer(l and l.x, l and l.y, p) end
    N.IsLocationMaskedToPlayer = function(l, p) return N.IsMaskedToPlayer(l and l.x, l and l.y, p) end
    N.IsUnitVisible = function(u, p)
        if not u then return false end
        if not vis() then return true end
        return vis():sees(pid(p), u, true)
    end
    N.IsUnitInvisible = function(u, p) return u ~= nil and not N.IsUnitVisible(u, p) end
    N.IsUnitFogged = function(u, p) return u ~= nil and point_state(p, u.x, u.y) == 1 end
    N.IsUnitMasked = function(u, p) return u ~= nil and point_state(p, u.x, u.y) == 0 end
    N.IsUnitVisibleBJ = function(u, p) return N.IsUnitVisible(u, p) end
    N.IsUnitInvisibleBJ = function(u, p) return N.IsUnitInvisible(u, p) end
    typed("boolean", "IsVisibleToPlayer IsFoggedToPlayer IsMaskedToPlayer IsLocationVisibleToPlayer "
        .. "IsLocationFoggedToPlayer IsLocationMaskedToPlayer IsUnitVisible IsUnitInvisible IsUnitFogged "
        .. "IsUnitMasked IsUnitVisibleBJ IsUnitInvisibleBJ")
    -- }}}
end
