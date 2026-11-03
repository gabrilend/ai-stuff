-- {{{ Sound player
-- Plays an ability cue's sound_effect by name, when a file for it
-- exists: assets/sounds/<name>.ogg, then .wav. No file, no audio module,
-- or a file that won't load: nothing plays and nothing fails. Each name
-- is looked up once.
--
--   SoundPlayer.new(options)   options: audio (love.audio), filesystem
--                              (love.filesystem), folder, extensions,
--                              volume (0-1)
--   player:play(name)          true when a sound started
--   player:available(name)     whether a file was found
local SoundPlayer = {}
SoundPlayer.__index = SoundPlayer

-- {{{ SoundPlayer.new
-- With no audio or filesystem given, LÖVE's are used when they exist.
function SoundPlayer.new(options)
    options = options or {}
    local love_table = rawget(_G, "love")
    local player = {
        audio = options.audio or (love_table and love_table.audio),
        filesystem = options.filesystem or (love_table and love_table.filesystem),
        folder = options.folder or "assets/sounds",
        extensions = options.extensions or {"ogg", "wav"},
        volume = options.volume or 1,
        sources = {},      -- name -> source, or false when there is none
        stats = {played = 0, missing = 0, failed = 0}
    }
    return setmetatable(player, SoundPlayer)
end
-- }}}

-- {{{ SoundPlayer:source
-- The loaded source for a name, or false.
function SoundPlayer:source(name)
    if self.sources[name] ~= nil then
        return self.sources[name]
    end
    local found = false
    if self.audio and self.filesystem and type(name) == "string" and name:match("^[%w_%-]+$") then
        for _, extension in ipairs(self.extensions) do
            local path = self.folder .. "/" .. name .. "." .. extension
            local info = self.filesystem.getInfo and self.filesystem.getInfo(path)
            if info then
                local ok, source = pcall(self.audio.newSource, path, "static")
                if ok and source then
                    pcall(source.setVolume, source, self.volume)
                    found = source
                else
                    self.stats.failed = self.stats.failed + 1
                end
                break
            end
        end
    end
    self.sources[name] = found
    return found
end
-- }}}

-- {{{ SoundPlayer:available
function SoundPlayer:available(name)
    return self:source(name) ~= false
end
-- }}}

-- {{{ SoundPlayer:play
-- Restarts the sound if it is already playing, so rapid hits stay
-- audible without piling up copies.
function SoundPlayer:play(name)
    if not name then
        return false
    end
    local source = self:source(name)
    if not source then
        self.stats.missing = self.stats.missing + 1
        return false
    end
    pcall(source.stop, source)
    local ok = pcall(source.play, source)
    if ok then
        self.stats.played = self.stats.played + 1
    else
        self.stats.failed = self.stats.failed + 1
    end
    return ok
end
-- }}}

return SoundPlayer
-- }}}
