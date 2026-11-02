--[[
Player Data: Where the Player's Own Files Live (Issue 604, answering 601's open question)

The owner, 2026-09-26: player data lives in the project directory, "though
they can config file it somewhere else". So:

  default   <root>/player-data/              (git ignores it)
  moved     <root>/config/player-data.lua    returns { folder = "PATH" }
            (git ignores it too: the path is the player's own machine's)

A relative PATH is read from <root>; a leading "~/" is $HOME.

    local player_data = require("assets.player_data")
    local folder, from = player_data.folder(ROOT)   -- "/.../player-data", "default"
    player_data.blobs(ROOT)                          -- folder .. "/blobs" (issue 604)
]]

local player_data = {}

player_data.DEFAULT_NAME = "player-data"
player_data.CONFIG_FILE = "config/player-data.lua"

-- {{{ local function resolve
local function resolve(root, path)
    if path:sub(1, 2) == "~/" then
        local home = os.getenv("HOME")
        if not home then
            error("player data: the config file's folder starts with ~/, but $HOME is not set")
        end
        return home .. path:sub(2)
    end
    if path:sub(1, 1) == "/" then
        return path
    end
    return root .. "/" .. path
end
-- }}}

-- {{{ function player_data.folder
-- The player data folder, and where that answer came from ("default" or the
-- config file's path). A config file that is present but broken is an error,
-- not a quiet fall back to the default: the player meant to move it.
function player_data.folder(root)
    root = root or "."
    local config = root .. "/" .. player_data.CONFIG_FILE
    local f = io.open(config, "rb")
    if not f then
        return root .. "/" .. player_data.DEFAULT_NAME, "default"
    end
    f:close()
    local chunk, load_err = loadfile(config)
    if not chunk then
        error("player data: " .. config .. " does not load: " .. load_err)
    end
    local ok, settings = pcall(chunk)
    if not ok then
        error("player data: " .. config .. " raised an error: " .. tostring(settings))
    end
    if type(settings) ~= "table" or type(settings.folder) ~= "string" or settings.folder == "" then
        error("player data: " .. config .. " must return { folder = \"PATH\" }")
    end
    return (resolve(root, settings.folder):gsub("/+$", "")), config
end
-- }}}

-- {{{ function player_data.blobs
-- The content-addressed store's folder (issue 604).
function player_data.blobs(root)
    return player_data.folder(root) .. "/blobs"
end
-- }}}

return player_data
