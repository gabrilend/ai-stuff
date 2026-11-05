--[[
wc3shim natives for sounds and music (issue W02e, step 2)

Licence: GNU AGPL v3 (server-side/LICENSE).

As the project's own runtime keeps them (src/jass/natives/sound.lua): a
sound made is a handle holding its file, label, flags, duration, channel,
volume and pitch; playing one logs it in S.sounds_played { file, label,
at, sound, x, y } (the last 500) and marks it playing until stopped or its
duration passes; the map's music is S.music.

Where the server forces a difference: the server plays nothing. Sounds
are the client's: opts.on_sound(event) hears each play and each change
of music, for W02g to send to the players (the VM's world.on_sound is the
same hook). StartSoundForPlayerBJ names its player in the event (the VM
plays it only for its local player). Nothing here calls ALE.

Installed by init.lua: require("wc3shim.sounds")(S, N, shim).
]]

return function(S, N)
    S.sounds_played, S.music = {}, nil
    local function hear(ev)
        if S.opts.on_sound then
            local ok, err = pcall(S.opts.on_sound, ev)
            if not ok then S:error("on_sound: " .. tostring(err)) end
        end
    end
    local function is_sound(s) return type(s) == "table" and s.kind == "sound" end

    -- {{{ making sounds
    local function make(file, looping, is3d, stop_out, fade_in, fade_out, eax)
        return S:handle({ kind = "sound", file = file, looping = looping, is3d = is3d, stop_out = stop_out,
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
        N[name] = function(s, v) if is_sound(s) then s[key] = v end end
    end
    setter("SetSoundParamsFromLabel", "label")
    setter("SetSoundDuration", "duration")
    setter("SetSoundChannel", "channel")
    setter("SetSoundVolume", "volume")
    setter("SetSoundPitch", "pitch")
    N.SetSoundVolumeBJ = function(s, percent)
        if is_sound(s) then s.volume = math.floor((percent or 100) * 127 / 100 + 0.5) end
    end
    N.SetSoundPosition = function(s, x, y) if is_sound(s) then s.x, s.y = x, y end end
    N.AttachSoundToUnit = function(s, u) if is_sound(s) then s.unit = u end end
    -- }}}

    -- {{{ playing
    local function play(s, x, y, player)
        if not is_sound(s) then return end
        s.playing, s.started = true, S:now()
        if s.unit then x, y = S.sync(s.unit).x, s.unit.y end
        local ev = { file = s.file, label = s.label, at = s.started, sound = s, x = x or s.x, y = y or s.y,
                     player = player and player.id or nil }
        local list = S.sounds_played
        list[#list + 1] = ev
        if #list > 500 then table.remove(list, 1) end
        hear(ev)
    end
    local function stop(s) if is_sound(s) then s.playing = false end end
    N.StartSound = play
    N.PlaySoundBJ = function(s) play(s) end
    N.PlaySoundAtPointBJ = function(s, vol, loc)
        if loc then play(s, loc.x, loc.y) else play(s) end
    end
    N.PlaySoundOnUnitBJ = function(s, vol, u)
        if is_sound(s) then s.unit = u end
        play(s)
    end
    N.PlaySoundFromOffsetBJ = function(s) play(s) end
    N.StartSoundForPlayerBJ = function(p, s) play(s, nil, nil, p) end
    N.StopSound = function(s) stop(s) end
    N.StopSoundBJ = function(s) stop(s) end
    N.KillSoundWhenDone = function() end
    N.KillSoundWhenDoneBJ = N.KillSoundWhenDone
    N.GetSoundIsPlaying = function(s)
        if not is_sound(s) or not s.playing then return false end
        if not s.looping and (s.duration or 0) > 0 and (S:now() - (s.started or 0)) * 1000 > s.duration then
            s.playing = false
        end
        return s.playing
    end
    N.GetSoundDuration = function(s) return is_sound(s) and s.duration or 0 end
    N.GetSoundFileDuration = function() return 0 end
    N.GetLastPlayedSound = function() return rawget(S.env, "bj_lastPlayedSound") end
    -- }}}

    -- {{{ music
    local function music(file)
        S.music = file
        hear({ music = file, at = S:now() })
    end
    N.SetMapMusic = function(file) S.map_music = file; hear({ music = file, at = S:now(), map = true }) end
    N.PlayMusic = music
    N.PlayMusicEx = music
    N.PlayMusicBJ = music
    N.PlayMusicExBJ = music
    N.PlayThematicMusic = music
    N.PlayThematicMusicBJ = music
    N.StopMusic = function() S.music = nil end
    N.StopMusicBJ = N.StopMusic
    N.ResumeMusic = function() S.music = S.music or S.map_music end
    -- }}}
end
