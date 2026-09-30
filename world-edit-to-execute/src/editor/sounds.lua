--[[
The Sound Editor (Issue 907)

None of the 16 maps has a war3map.w3s: their sounds are made by the
script, as the World Editor writes them ("set gg_snd_X = CreateSound(file,
looping, 3D, stop when out of range, fade in, fade out, EAX)" then
SetSoundParamsFromLabel, SetSoundDuration, SetSoundChannel,
SetSoundVolume, SetSoundPitch on it). DAoW 5.4b makes 85 so. Its music is
a SetMapMusic / PlayMusic call with the file's path.

  the script's   each CreateSound call and its setters, found and shown;
                 file, flags, fades, EAX, label, duration, channel,
                 volume, pitch changed (the calls rewritten when saved; a
                 setter the script didn't call is added after the sound is
                 made); where each is played (PlaySoundBJ ...)
  the editor's   new sounds, kept with the triggers in war3mapEditor.lua
                 and made by EditorInitSounds (called first by
                 EditorInitTriggers); triggers play them ("Play sound",
                 editor/trigger_blocks.lua)
  music          the map's music calls, their file changed
  files          where each file is found: the map, the install, or
                 missing; its bytes, for the window to play (preview)

  E:load_sounds(), E:sounds(), E:music()
  E:set_sound(s, key, value)    one step to undo
  E:new_sound(name, file), E:delete_sound(s)   (the editor's own only)
  E:set_music(m, file)
  E:sound_file(file)            bytes, where ("map" | "install") or nil
  E:sound_edits()               the script's text edits (save.lua)

    require("editor.sounds")(E)    -- editor/init.lua does this
]]

local sounds = {}

sounds.KEYS = { "file", "looping", "is3d", "stop_out", "fade_in", "fade_out", "eax" }
sounds.SETTERS = { label = "SetSoundParamsFromLabel", duration = "SetSoundDuration", channel = "SetSoundChannel",
                   volume = "SetSoundVolume", pitch = "SetSoundPitch" }
sounds.EAX = { "DefaultEAXON", "CombatSoundsEAX", "KotoDrumsEAX", "SpellsEAX", "MissilesEAX", "HeroAcksEAX",
               "DoodadsEAX" }

-- {{{ JASS literals
-- split a call's arguments at top-level commas
local function split_args(s)
    local out, depth, cur, i, q = {}, 0, {}, 1, false
    while i <= #s do
        local c = s:sub(i, i)
        if q then
            cur[#cur + 1] = c
            if c == "\\" then cur[#cur + 1] = s:sub(i + 1, i + 1); i = i + 1
            elseif c == '"' then q = false end
        elseif c == '"' then q = true; cur[#cur + 1] = c
        elseif c == "(" then depth = depth + 1; cur[#cur + 1] = c
        elseif c == ")" then depth = depth - 1; cur[#cur + 1] = c
        elseif c == "," and depth == 0 then out[#out + 1] = table.concat(cur); cur = {}
        else cur[#cur + 1] = c end
        i = i + 1
    end
    out[#out + 1] = table.concat(cur)
    for k, v in ipairs(out) do out[k] = v:gsub("^%s+", ""):gsub("%s+$", "") end
    return out
end
sounds.split_args = split_args

-- the end of a call whose "(" is at open: the matching ")"
local function close_of(text, open)
    local depth, i, q = 0, open, false
    while i <= #text do
        local c = text:sub(i, i)
        if q then
            if c == "\\" then i = i + 1 elseif c == '"' then q = false end
        elseif c == '"' then q = true
        elseif c == "(" then depth = depth + 1
        elseif c == ")" then depth = depth - 1; if depth == 0 then return i end
        elseif c == "\n" or c == "\r" then return nil end
        i = i + 1
    end
end
sounds.close_of = close_of

function sounds.literal(s)
    if s == nil then return nil end
    if s == "true" then return true elseif s == "false" then return false end
    local str = s:match('^"(.*)"$')
    if str then return (str:gsub("\\\\", "\\"):gsub('\\"', '"')) end
    if s:match("^%$%x+$") then return tonumber(s:sub(2), 16) end
    if s:match("^0[xX]%x+$") then return tonumber(s:sub(3), 16) end
    return tonumber(s) or { expr = s }
end

function sounds.jass(v)
    if type(v) == "table" and v.expr then return v.expr end
    if type(v) == "boolean" then return tostring(v) end
    if type(v) == "string" then return '"' .. v:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"' end
    if type(v) == "number" then
        if v == math.floor(v) then return tostring(v) end
        return string.format("%.3f", v)
    end
    return "null"
end
-- }}}

-- {{{ reading the script
function sounds.scan(script)
    local list, music = {}, {}
    if not script then return list, music end
    local pos = 1
    while true do
        local s, e, var = script:find("set%s+([%w_]+)%s*=%s*CreateSound%(", pos)
        if not s then break end
        local open = e
        local close = close_of(script, open)
        if not close then pos = e + 1 else
            local args = split_args(script:sub(open + 1, close - 1))
            local call_at = script:find("CreateSound", s, true)
            local snd = { kind = "script", var = var, name = (var:gsub("^gg_snd_", "")), at = call_at, to = close,
                          setters = {} }
            for i, k in ipairs(sounds.KEYS) do snd[k] = sounds.literal(args[i]) end
            -- its setters, up to the next sound made or the function's end
            local stop = script:find("CreateSound%(", close + 1) or #script
            local fend = script:find("endfunction", close + 1, true)
            if fend and fend < stop then stop = fend end
            local ev = var:gsub("%p", "%%%0")
            for key, fn in pairs(sounds.SETTERS) do
                local fs, fe = script:find(fn .. "%(%s*" .. ev .. "%s*,", close + 1)
                if fs and fs < stop then
                    local fc = close_of(script, script:find("(", fs, true))
                    if fc then
                        local a = split_args(script:sub(fe + 1, fc - 1))
                        snd[key] = sounds.literal(a[1])
                        snd.setters[key] = { at = fs, to = fc }
                    end
                end
            end
            -- where it's played
            snd.plays = 0
            for _ in script:gmatch("PlaySound%w*%(%s*" .. ev .. "%s*[,)]") do snd.plays = snd.plays + 1 end
            for _ in script:gmatch("StartSound%(%s*" .. ev .. "%s*%)") do snd.plays = snd.plays + 1 end
            snd.orig = {}
            for _, k in ipairs(sounds.KEYS) do snd.orig[k] = snd[k] end
            for k in pairs(sounds.SETTERS) do snd.orig[k] = snd[k] end
            list[#list + 1] = snd
            pos = close + 1
        end
    end
    -- music: SetMapMusic("file", random, index) and PlayMusic("file")
    for _, fn in ipairs({ "SetMapMusic", "PlayMusic", "PlayMusicEx", "PlayThematicMusic" }) do
        local p = 1
        while true do
            local s, e = script:find(fn .. "%(%s*\"", p)
            if not s then break end
            local open = script:find("(", s, true)
            local close = close_of(script, open)
            if close then
                local args = split_args(script:sub(open + 1, close - 1))
                local file = sounds.literal(args[1])
                if type(file) == "string" then
                    local fs = script:find('"', open, true)
                    local fe = fs + #args[1] - 1
                    music[#music + 1] = { kind = "music", call = fn, file = file, orig = file, at = fs, to = fe }
                end
            end
            p = e + 1
        end
    end
    table.sort(music, function(a, b) return a.at < b.at end)
    return list, music
end
-- }}}

local function install(E)

    function E:load_sounds()
        self.sound_list, self.music_list = sounds.scan(self.script)
        self.trig = self.trig or { variables = {}, triggers = {} }
        self.trig.sounds = self.trig.sounds or {}
        for _, s in ipairs(self.trig.sounds) do s.kind = "editor" end
    end

    function E:sounds()
        local out = {}
        for _, s in ipairs(self.sound_list or {}) do out[#out + 1] = s end
        for _, s in ipairs(self.trig.sounds or {}) do out[#out + 1] = s end
        return out
    end
    function E:music() return self.music_list or {} end

    function E:sound_named(var)
        for _, s in ipairs(self:sounds()) do if s.var == var then return s end end
    end

    local function mark(self, s)
        self.dirty.script = true
        if s.kind == "editor" then self.dirty.triggers = true end
    end

    function E:set_sound(s, key, value)
        local old = s[key]
        local me = self
        self.history:run({ name = string.format("Sound %s: %s", s.name, key),
            redo = function() s[key] = value; mark(me, s) end,
            undo = function() s[key] = old; mark(me, s) end })
        return true
    end

    function E:new_sound(name, file)
        local blocks = require("editor.trigger_blocks")
        local base, n = blocks.safe(name or "Sound"), 1
        local var = "gg_snd_" .. base
        while self:sound_named(var) or (self.script or ""):find(var, 1, true) do
            n = n + 1
            var = "gg_snd_" .. base .. n
        end
        local s = { kind = "editor", var = var, name = var:gsub("^gg_snd_", ""), file = file or "", looping = false,
                    is3d = false, stop_out = false, fade_in = 10, fade_out = 10, eax = "DefaultEAXON",
                    volume = 127, channel = 0 }
        local list, me = self.trig.sounds, self
        self.history:run({ name = "New sound " .. s.name,
            redo = function() list[#list + 1] = s; mark(me, s) end,
            undo = function()
                for i, x in ipairs(list) do if x == s then table.remove(list, i) break end end
                mark(me, s)
            end })
        return s
    end

    function E:delete_sound(s)
        if s.kind ~= "editor" then return false, "the script's own sounds stay (its triggers play them)" end
        local list, me, at = self.trig.sounds, self
        for i, x in ipairs(list) do if x == s then at = i end end
        if not at then return false end
        self.history:run({ name = "Delete sound " .. s.name,
            redo = function() table.remove(list, at); mark(me, s) end,
            undo = function() table.insert(list, at, s); mark(me, s) end })
        return true
    end

    function E:set_music(m, file)
        local old = m.file
        local me = self
        self.history:run({ name = "Music: " .. file,
            redo = function() m.file = file; me.dirty.script = true end,
            undo = function() m.file = old; me.dirty.script = true end })
        return true
    end

    -- {{{ the script's text
    local function create_call(s)
        local a = {}
        for i, k in ipairs(sounds.KEYS) do a[i] = sounds.jass(s[k]) end
        return "CreateSound(" .. table.concat(a, ",") .. ")"
    end
    sounds.create_call = create_call

    function E:sound_edits()
        local out = {}
        for _, s in ipairs(self.sound_list or {}) do
            local changed = false
            for _, k in ipairs(sounds.KEYS) do if s[k] ~= s.orig[k] then changed = true end end
            local added = {}
            for key, fn in pairs(sounds.SETTERS) do
                if s[key] ~= s.orig[key] then
                    if s.setters[key] then
                        out[#out + 1] = { at = s.setters[key].at, to = s.setters[key].to,
                                          text = fn .. "(" .. s.var .. "," .. sounds.jass(s[key]) .. ")" }
                    elseif s[key] ~= nil then
                        added[#added + 1] = "call " .. fn .. "(" .. s.var .. "," .. sounds.jass(s[key]) .. ")"
                        changed = true
                    end
                end
            end
            if changed then
                table.sort(added)
                local text = create_call(s)
                if #added > 0 then text = text .. "\n" .. table.concat(added, "\n") end
                out[#out + 1] = { at = s.at, to = s.to, text = text }
            end
        end
        for _, m in ipairs(self.music_list or {}) do
            if m.file ~= m.orig then out[#out + 1] = { at = m.at, to = m.to, text = sounds.jass(m.file) } end
        end
        return out
    end

    -- the editor's sounds, for the trigger code (editor/triggers.lua)
    function E:sound_code()
        local list = self.trig.sounds or {}
        if #list == 0 then return nil end
        local g, f = {}, { "function EditorInitSounds takes nothing returns nothing" }
        for _, s in ipairs(list) do
            g[#g + 1] = "sound " .. s.var .. " = null"
            f[#f + 1] = "    set " .. s.var .. " = " .. create_call(s)
            for _, key in ipairs({ "label", "duration", "channel", "volume", "pitch" }) do
                if s[key] ~= nil then
                    f[#f + 1] = "    call " .. sounds.SETTERS[key] .. "(" .. s.var .. ", " .. sounds.jass(s[key]) .. ")"
                end
            end
        end
        f[#f + 1] = "endfunction"
        return { globals = table.concat(g, "\n"), functions = table.concat(f, "\n"), call = "EditorInitSounds" }
    end
    -- }}}

    -- {{{ the files
    function E:sound_file(file)
        if type(file) ~= "string" or file == "" then return nil end
        local path = file:gsub("/", "\\")
        local data = self.import_data and self:import_named(path) and self:import_data(path)
        if data then return data, "map" end
        local a = require("mpq").open(self.path)
        if a then
            local d = a:has(path) and a:extract(path)
            a:close()
            if d then return d, "map" end
        end
        self.sound_assets = self.sound_assets or require("assets").open(self.path, { root = self.opts and self.opts.root })
        local d, where = self.sound_assets:read(path)
        if d then return d, where == "map" and "map" or "install" end
        return nil
    end
    -- }}}
end

return setmetatable(sounds, { __call = function(_, E) return install(E) end })
