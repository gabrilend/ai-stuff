--[[
JASS natives: the camera (Issue 904)

A camera setup (CreateCameraSetup, as the World Editor's cameras are made)
is a handle holding its fields (CAMERA_FIELD_TARGET_DISTANCE, ROTATION,
ANGLE_OF_ATTACK, FIELD_OF_VIEW, ZOFFSET, ROLL, FARZ) and where it looks.
Applying one, panning, setting a field or going back to the game camera
asks the local player's view to move: V.camera = { x, y, distance,
rotation, aoa, fov, duration, reset } (only what was asked), counted in
V.camera_asked, and a world with an on_camera(request) function hears it
(the window moves its view: demo/wc3map/main.lua). Requests for other
players are left alone.

Loaded after the other native modules, so these replace their no-ops.
]]

return function(V, N, T)
    V.camera_asked = 0
    local function real(name) V.noop[name] = nil end
    local function mine(p) return p == nil or p.id == V.local_id end
    local FIELDS = { CAMERA_FIELD_TARGET_DISTANCE = "distance", CAMERA_FIELD_ROTATION = "rotation",
                     CAMERA_FIELD_ANGLE_OF_ATTACK = "aoa", CAMERA_FIELD_FIELD_OF_VIEW = "fov",
                     CAMERA_FIELD_ZOFFSET = "zoffset", CAMERA_FIELD_ROLL = "roll", CAMERA_FIELD_FARZ = "farz" }
    -- common.j's numbers for the fields, when a script converts them
    local BY_NUMBER = { [0] = "CAMERA_FIELD_TARGET_DISTANCE", "CAMERA_FIELD_FARZ", "CAMERA_FIELD_ANGLE_OF_ATTACK",
                        "CAMERA_FIELD_FIELD_OF_VIEW", "CAMERA_FIELD_ROLL", "CAMERA_FIELD_ROTATION",
                        "CAMERA_FIELD_ZOFFSET" }
    local function field(f) return FIELDS[f] or FIELDS[BY_NUMBER[f] or ""] end

    local function ask(req)
        V.camera = req
        V.camera_asked = V.camera_asked + 1
        if V.world and V.world.on_camera then pcall(V.world.on_camera, req) end
    end

    -- {{{ setups
    N.CreateCameraSetup = function()
        return V:handle({ kind = "camerasetup", fields = {}, x = 0, y = 0 })
    end
    N.CameraSetupSetField = function(c, f, value)
        local k = field(f)
        if type(c) == "table" and k then c.fields[k] = value end
    end
    N.CameraSetupGetField = function(c, f)
        local k = field(f)
        return type(c) == "table" and k and c.fields[k] or 0
    end
    N.CameraSetupSetDestPosition = function(c, x, y) if type(c) == "table" then c.x, c.y = x, y end end
    N.CameraSetupGetDestPositionX = function(c) return type(c) == "table" and c.x or 0 end
    N.CameraSetupGetDestPositionY = function(c) return type(c) == "table" and c.y or 0 end
    N.CameraSetupGetDestPositionLoc = function(c) return N.Location(N.CameraSetupGetDestPositionX(c), N.CameraSetupGetDestPositionY(c)) end
    local function apply(c, duration)
        if type(c) ~= "table" then return end
        local f = c.fields
        ask({ x = c.x, y = c.y, distance = f.distance, rotation = f.rotation, aoa = f.aoa, fov = f.fov,
              duration = duration or 0, setup = c })
    end
    N.CameraSetupApply = function(c, pan) apply(c, 0) end
    N.CameraSetupApplyWithZ = function(c) apply(c, 0) end
    N.CameraSetupApplyForceDuration = function(c, pan, duration) apply(c, duration) end
    N.CameraSetupApplyForPlayer = function(pan, c, p, duration) if mine(p) then apply(c, duration) end end
    for _, n in ipairs({ "CreateCameraSetup", "CameraSetupSetField", "CameraSetupGetField", "CameraSetupSetDestPosition",
                         "CameraSetupGetDestPositionX", "CameraSetupGetDestPositionY", "CameraSetupApply",
                         "CameraSetupApplyWithZ", "CameraSetupApplyForceDuration", "CameraSetupApplyForPlayer" }) do
        real(n)
    end
    T.CameraSetupGetField = "real"
    T.CameraSetupGetDestPositionX = "real"
    T.CameraSetupGetDestPositionY = "real"
    -- }}}

    -- {{{ panning, fields, the game camera
    N.SetCameraPosition = function(x, y) ask({ x = x, y = y, duration = 0 }) end
    N.SetCameraQuickPosition = function() end
    N.PanCameraTo = function(x, y) ask({ x = x, y = y, duration = 0.5 }) end
    N.PanCameraToTimed = function(x, y, t) ask({ x = x, y = y, duration = t or 0 }) end
    N.PanCameraToWithZ = N.PanCameraTo
    N.PanCameraToTimedWithZ = function(x, y, z, t) ask({ x = x, y = y, duration = t or 0 }) end
    N.SmartCameraPanBJ = function(p, loc, t) if mine(p) and loc then ask({ x = loc.x, y = loc.y, duration = t or 0 }) end end
    N.PanCameraToLocForPlayer = function(p, loc) if mine(p) and loc then ask({ x = loc.x, y = loc.y, duration = 0.5 }) end end
    N.PanCameraToTimedLocForPlayer = function(p, loc, t) if mine(p) and loc then ask({ x = loc.x, y = loc.y, duration = t or 0 }) end end
    N.SetCameraPositionForPlayer = function(p, x, y) if mine(p) then ask({ x = x, y = y, duration = 0 }) end end
    N.SetCameraPositionLocForPlayer = function(p, loc) if mine(p) and loc then ask({ x = loc.x, y = loc.y, duration = 0 }) end end
    N.SetCameraField = function(f, value, t)
        local k = field(f)
        if k then ask({ [k] = value, duration = t or 0 }) end
    end
    N.SetCameraFieldForPlayer = function(p, f, value, t) if mine(p) then N.SetCameraField(f, value, t) end end
    N.ResetToGameCamera = function(t) ask({ reset = true, duration = t or 0 }) end
    N.ResetToGameCameraForPlayer = function(p, t) if mine(p) then N.ResetToGameCamera(t) end end
    N.GetCameraTargetPositionX = function()
        if V.world and V.world.camera then return (V.world.camera()) end
        return V.camera and V.camera.x or 0
    end
    N.GetCameraTargetPositionY = function()
        if V.world and V.world.camera then return select(2, V.world.camera()) end
        return V.camera and V.camera.y or 0
    end
    N.GetCameraField = function(f)
        local k = field(f)
        return V.camera and k and V.camera[k] or 0
    end
    for _, n in ipairs({ "SetCameraPosition", "SetCameraQuickPosition", "PanCameraTo", "PanCameraToTimed",
                         "PanCameraToWithZ", "PanCameraToTimedWithZ", "SmartCameraPanBJ", "PanCameraToLocForPlayer",
                         "PanCameraToTimedLocForPlayer", "SetCameraPositionForPlayer", "SetCameraPositionLocForPlayer",
                         "SetCameraField", "SetCameraFieldForPlayer", "ResetToGameCamera", "ResetToGameCameraForPlayer" }) do
        real(n)
    end
    -- }}}
end
