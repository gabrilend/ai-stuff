--[[
The Camera Editor (Issue 904)

No test map has a war3map.w3c: their cameras are made by the script, as
the World Editor writes them ("set gg_cam_X = CreateCameraSetup()", then
CameraSetupSetField for the distance, rotation, angle of attack, field
of view, height, roll and far clip, and CameraSetupSetDestPosition for
where it looks). DAoW 5.4b makes 7 so.

  the script's   each camera found; its fields and where it looks changed
                 (the calls rewritten when saved; a field it didn't set
                 is set after it's made)
  the editor's   new cameras, kept with the triggers in war3mapEditor.lua
                 and made by EditorInitCameras; triggers apply them
                 ("Apply camera", editor/trigger_blocks.lua)
  the view       a camera set from the window's view, or the view put
                 where a camera looks (the window does that)

  E:load_cameras(), E:cameras(), E:camera_named(var)
  E:set_camera(c, key, value)          one step to undo
  E:camera_from_view(c, x, y, distance, rotation, aoa, fov)   one step
  E:new_camera(name, x, y), E:delete_camera(c)   (the editor's own only)
  E:camera_edits()                     the script's text edits (save.lua)

    require("editor.cameras")(E)    -- editor/init.lua does this
]]

local snd = require("editor.sounds")

local cameras = {}

cameras.FIELDS = { distance = "CAMERA_FIELD_TARGET_DISTANCE", rotation = "CAMERA_FIELD_ROTATION",
                   aoa = "CAMERA_FIELD_ANGLE_OF_ATTACK", fov = "CAMERA_FIELD_FIELD_OF_VIEW",
                   zoffset = "CAMERA_FIELD_ZOFFSET", roll = "CAMERA_FIELD_ROLL", farz = "CAMERA_FIELD_FARZ" }
cameras.ORDER = { "zoffset", "rotation", "aoa", "distance", "roll", "fov", "farz" }
cameras.DEFAULT = { distance = 1650, rotation = 90, aoa = 304, fov = 70, zoffset = 0, roll = 0, farz = 5000 }
local BY_FIELD = {}
for k, f in pairs(cameras.FIELDS) do BY_FIELD[f] = k end

local function num(v)
    local s = string.format("%.1f", v)
    return s
end

function cameras.scan(script)
    local list = {}
    if not script then return list end
    local pos = 1
    while true do
        local s, e, var = script:find("set%s+([%w_]+)%s*=%s*CreateCameraSetup%(%s*%)", pos)
        if not s then break end
        local c = { kind = "script", var = var, name = (var:gsub("^gg_cam_", "")), made_at = script:find("CreateCameraSetup", s, true),
                    made_to = e, setters = {} }
        local stop = script:find("CreateCameraSetup%(", e + 1) or #script
        local fend = script:find("endfunction", e + 1, true)
        if fend and fend < stop then stop = fend end
        local ev = var:gsub("%p", "%%%0")
        local p = e + 1
        while true do
            local fs, fe = script:find("CameraSetupSetField%(%s*" .. ev .. "%s*,", p)
            if not fs or fs > stop then break end
            local fc = snd.close_of(script, script:find("(", fs, true))
            if not fc then break end
            local args = snd.split_args(script:sub(fe + 1, fc - 1))
            local key = BY_FIELD[args[1]]
            if key then
                c[key] = snd.literal(args[2])
                c.setters[key] = { at = fs, to = fc, duration = args[3] }
            end
            p = fc + 1
        end
        local ds, de = script:find("CameraSetupSetDestPosition%(%s*" .. ev .. "%s*,", e + 1)
        if ds and ds < stop then
            local dc = snd.close_of(script, script:find("(", ds, true))
            if dc then
                local args = snd.split_args(script:sub(de + 1, dc - 1))
                c.x, c.y = snd.literal(args[1]), snd.literal(args[2])
                c.dest = { at = ds, to = dc, duration = args[3] }
            end
        end
        c.orig = {}
        for k in pairs(cameras.FIELDS) do c.orig[k] = c[k] end
        c.orig.x, c.orig.y = c.x, c.y
        list[#list + 1] = c
        pos = e + 1
    end
    return list
end

local function install(E)

    function E:load_cameras()
        self.camera_list = cameras.scan(self.script)
        self.trig.cameras = self.trig.cameras or {}
        for _, c in ipairs(self.trig.cameras) do c.kind = "editor" end
    end

    function E:cameras()
        local out = {}
        for _, c in ipairs(self.camera_list or {}) do out[#out + 1] = c end
        for _, c in ipairs(self.trig.cameras or {}) do out[#out + 1] = c end
        return out
    end

    function E:camera_named(var)
        for _, c in ipairs(self:cameras()) do if c.var == var then return c end end
    end

    local function mark(self, c)
        self.dirty.script = true
        if c.kind == "editor" then self.dirty.triggers = true end
    end

    function E:set_camera(c, key, value)
        local old = c[key]
        local me = self
        self.history:run({ name = string.format("Camera %s: %s", c.name, key),
            redo = function() c[key] = value; mark(me, c) end,
            undo = function() c[key] = old; mark(me, c) end })
        return true
    end

    function E:camera_from_view(c, x, y, distance, rotation, aoa, fov)
        self.history:begin("Camera " .. c.name .. " from the view")
        local vals = { x = x, y = y, distance = distance, rotation = rotation, aoa = aoa, fov = fov }
        for _, k in ipairs({ "x", "y", "distance", "rotation", "aoa", "fov" }) do
            if vals[k] and vals[k] ~= c[k] then self:set_camera(c, k, math.floor(vals[k] * 10 + 0.5) / 10) end
        end
        self.history:finish()
        return true
    end

    function E:new_camera(name, x, y)
        local blocks = require("editor.trigger_blocks")
        local base, n = blocks.safe(name or "Camera"), 1
        local var = "gg_cam_" .. base
        while self:camera_named(var) or (self.script or ""):find(var, 1, true) do
            n = n + 1
            var = "gg_cam_" .. base .. n
        end
        local c = { kind = "editor", var = var, name = var:gsub("^gg_cam_", ""), x = x or 0, y = y or 0 }
        for k, v in pairs(cameras.DEFAULT) do c[k] = v end
        local list, me = self.trig.cameras, self
        self.history:run({ name = "New camera " .. c.name,
            redo = function() list[#list + 1] = c; mark(me, c) end,
            undo = function()
                for i, x2 in ipairs(list) do if x2 == c then table.remove(list, i) break end end
                mark(me, c)
            end })
        return c
    end

    function E:delete_camera(c)
        if c.kind ~= "editor" then return false, "the script's own cameras stay (its triggers use them)" end
        local list, me, at = self.trig.cameras, self
        for i, x in ipairs(list) do if x == c then at = i end end
        if not at then return false end
        self.history:run({ name = "Delete camera " .. c.name,
            redo = function() table.remove(list, at); mark(me, c) end,
            undo = function() table.insert(list, at, c); mark(me, c) end })
        return true
    end

    -- {{{ the script's text
    local function field_call(c, key, duration)
        return "CameraSetupSetField(" .. c.var .. "," .. cameras.FIELDS[key] .. "," .. num(c[key]) .. ","
            .. (duration or "0.0") .. ")"
    end

    function E:camera_edits()
        local out = {}
        for _, c in ipairs(self.camera_list or {}) do
            local added = {}
            for _, key in ipairs(cameras.ORDER) do
                if c[key] ~= c.orig[key] and type(c[key]) == "number" then
                    local st = c.setters[key]
                    if st then out[#out + 1] = { at = st.at, to = st.to, text = field_call(c, key, st.duration) }
                    else added[#added + 1] = "call " .. field_call(c, key) end
                end
            end
            if (c.x ~= c.orig.x or c.y ~= c.orig.y) then
                local text = "CameraSetupSetDestPosition(" .. c.var .. "," .. num(c.x) .. "," .. num(c.y) .. ","
                    .. ((c.dest and c.dest.duration) or "0.0") .. ")"
                if c.dest then out[#out + 1] = { at = c.dest.at, to = c.dest.to, text = text }
                else added[#added + 1] = "call " .. text end
            end
            if #added > 0 then
                out[#out + 1] = { at = c.made_at, to = c.made_to, text = "CreateCameraSetup()\n" .. table.concat(added, "\n") }
            end
        end
        return out
    end

    function E:camera_code()
        local list = self.trig.cameras or {}
        if #list == 0 then return nil end
        local g, f = {}, { "function EditorInitCameras takes nothing returns nothing" }
        for _, c in ipairs(list) do
            g[#g + 1] = "camerasetup " .. c.var .. " = null"
            f[#f + 1] = "    set " .. c.var .. " = CreateCameraSetup()"
            for _, key in ipairs(cameras.ORDER) do
                if type(c[key]) == "number" then f[#f + 1] = "    call " .. field_call(c, key) end
            end
            f[#f + 1] = "    call CameraSetupSetDestPosition(" .. c.var .. ", " .. num(c.x) .. ", " .. num(c.y) .. ", 0.0)"
        end
        f[#f + 1] = "endfunction"
        return { globals = table.concat(g, "\n"), functions = table.concat(f, "\n"), call = "EditorInitCameras" }
    end
    -- }}}
end

return setmetatable(cameras, { __call = function(_, E) return install(E) end })
