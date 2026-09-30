--[[
JASS natives: sounds and music, kept (Issue 907)

There is no audio yet, but the script's sounds are real things: a sound
made (CreateSound and friends) is a handle holding its file, flags,
fades, label, duration, channel, volume and pitch; playing one
(StartSound, PlaySoundBJ, PlaySoundAtPointBJ, PlaySoundOnUnitBJ ...)
logs it in V.sounds_played { file, at (game time), sound, x, y } and
marks it playing until stopped or its duration passes; the map's music
(SetMapMusic, PlayMusic, PlayMusicBJ ...) is V.music. A world with an
on_sound(event) function hears each (the window's audio, later).

Loaded after the other native modules, so these replace their no-ops.
]]

return function(V, N, T)
    V.sounds_played, V.music = {}, nil
    local function real(name) V.noop[name] = nil end
    local function hear(ev)
        if V.world and V.world.on_sound then pcall(V.world.on_sound, ev) end
    end

    -- {{{ making sounds
    local function make(file, looping, is3d, stop_out, fade_in, fade_out, eax)
        return V:handle({ kind = "sound", file = file, looping = looping, is3d = is3d, stop_out = stop_out,
                          fade_in = fade_in, fade_out = fade_out, eax = eax, volume = 127, pitch = 1, duration = 0 })
    end
    N.CreateSound = make
    N.CreateSoundFilenameWithLabel = function(file, looping, is3d, stop_out, fade_in, fade_out, label)
        local s = make(file, looping, is3d, stop_out, fade_in, fade_out)
        s.label = label
        return s
    end
    N.CreateSoundFromLabel = function(label, looping, is3d, stop_out, fade_in, fade_out)
        local s = make(nil, looping, is3d, stop_out, fade_in, fade_out)
        s.label = label
        return s
    end
    N.CreateMIDISound = function(label, fade_in, fade_out)
        local s = make(nil, false, false, false, fade_in, fade_out)
        s.label = label
        return s
    end
    local function setter(name, key)
        real(name)
        N[name] = function(s, v) if type(s) == "table" and s.kind == "sound" then s[key] = v end end
    end
    setter("SetSoundParamsFromLabel", "label")
    setter("SetSoundDuration", "duration")
    setter("SetSoundChannel", "channel")
    setter("SetSoundVolume", "volume")
    setter("SetSoundPitch", "pitch")
    N.SetSoundVolumeBJ = function(s, percent)
        if type(s) == "table" then s.volume = math.floor((percent or 100) * 127 / 100 + 0.5) end
    end
    N.SetSoundPosition = function(s, x, y) if type(s) == "table" then s.x, s.y = x, y end end
    N.AttachSoundToUnit = function(s, u) if type(s) == "table" then s.unit = u end end
    for _, n in ipairs({ "CreateSound", "CreateSoundFilenameWithLabel", "CreateSoundFromLabel", "CreateMIDISound",
                         "SetSoundVolumeBJ", "SetSoundPosition", "AttachSoundToUnit" }) do real(n) end
    -- }}}

    -- {{{ playing
    local function play(s, x, y)
        if type(s) ~= "table" or s.kind ~= "sound" then return end
        s.playing, s.started = true, V.time
        if s.unit then x, y = s.unit.x, s.unit.y end
        local ev = { file = s.file, label = s.label, at = V.time, sound = s, x = x or s.x, y = y or s.y }
        local list = V.sounds_played
        list[#list + 1] = ev
        if #list > 500 then table.remove(list, 1) end
        hear(ev)
    end
    local function stop(s) if type(s) == "table" then s.playing = false end end
    N.StartSound = play
    N.PlaySoundBJ = function(s) play(s) end
    N.PlaySoundAtPointBJ = function(s, vol, loc)
        if loc then play(s, N.GetLocationX(loc), N.GetLocationY(loc)) else play(s) end
    end
    N.PlaySoundOnUnitBJ = function(s, vol, u)
        if type(s) == "table" then s.unit = u end
        play(s)
    end
    N.PlaySoundFromOffsetBJ = function(s) play(s) end
    N.StartSoundForPlayerBJ = function(p, s) if p == nil or p.id == V.local_id then play(s) end end
    N.StopSound = function(s) stop(s) end
    N.StopSoundBJ = function(s) stop(s) end
    N.KillSoundWhenDone = function() end
    N.KillSoundWhenDoneBJ = N.KillSoundWhenDone
    N.GetSoundIsPlaying = function(s)
        if type(s) ~= "table" or not s.playing then return false end
        if not s.looping and (s.duration or 0) > 0 and (V.time - (s.started or 0)) * 1000 > s.duration then
            s.playing = false
        end
        return s.playing
    end
    N.GetSoundDuration = function(s) return type(s) == "table" and s.duration or 0 end
    N.GetSoundFileDuration = function() return 0 end
    for _, n in ipairs({ "StartSound", "PlaySoundBJ", "PlaySoundAtPointBJ", "PlaySoundOnUnitBJ", "PlaySoundFromOffsetBJ",
                         "StartSoundForPlayerBJ", "StopSound", "StopSoundBJ", "KillSoundWhenDone",
                         "KillSoundWhenDoneBJ" }) do real(n) end
    T.GetSoundIsPlaying = "boolean"
    -- }}}

    -- {{{ music
    local function music(file)
        V.music = file
        hear({ music = file, at = V.time })
    end
    N.SetMapMusic = function(file) V.map_music = file end
    N.PlayMusic = music
    N.PlayMusicEx = music
    N.PlayMusicBJ = music
    N.PlayMusicExBJ = music
    N.PlayThematicMusic = music
    N.PlayThematicMusicBJ = music
    N.StopMusic = function() V.music = nil end
    N.StopMusicBJ = N.StopMusic
    N.ResumeMusic = function() V.music = V.music or V.map_music end
    for _, n in ipairs({ "SetMapMusic", "PlayMusic", "PlayMusicEx", "PlayMusicBJ", "PlayMusicExBJ", "PlayThematicMusic",
                         "PlayThematicMusicBJ", "StopMusic", "StopMusicBJ", "ResumeMusic" }) do real(n) end
    -- }}}
end
