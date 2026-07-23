-- 08-media-dispatch.lua — "what kind is this, and who opens it?"
--
-- General description: two lookup tables. One turns a file's extension into a
-- kind (video, audio, image, doc, text). The other turns a kind into the
-- program that should open it (mpv, feh, zathura, neovim). Adding support for a
-- new format is adding a row to a table, never editing a branch of if/else --
-- because looking a thing up by index is cheaper and clearer than walking a
-- ladder of conditionals. An unknown kind has no row on purpose, so the caller
-- takes the flagged fallback path (xdg-open, with a warning) rather than
-- guessing silently.

local DIR = DIR or "/home/ritz/programming/ai-stuff/filesystem-tapestry"
package.path = DIR .. "/libs/?.lua;" .. package.path
local utils = require("01-utils")

local M = {}

-- {{{ EXT_TO_KIND
-- Extension (lower-case, no dot) -> kind. The scanner stamps every record with
-- the kind it finds here; anything not listed becomes "other".
local EXT_TO_KIND = {
    -- moving pictures
    mkv = "video", mp4 = "video", webm = "video", avi = "video",
    mov = "video", m4v = "video", flv = "video", wmv = "video", mpg = "video",
    -- sound
    mp3 = "audio", flac = "audio", opus = "audio", wav = "audio",
    ogg = "audio", m4a = "audio", aac = "audio",
    -- still pictures
    png = "image", jpg = "image", jpeg = "image", gif = "image",
    webp = "image", bmp = "image", tiff = "image", svg = "image",
    -- documents that are not plain text
    pdf = "doc", epub = "doc", djvu = "doc",
    -- text and code (neovim opens all of these)
    txt = "text", md = "text", lua = "text", sh = "text", c = "text",
    h = "text", cpp = "text", hpp = "text", py = "text", js = "text",
    json = "text", html = "text", css = "text", conf = "text", ini = "text",
    log = "text", csv = "text", org = "text", rst = "text", toml = "text",
    yaml = "text", yml = "text",
}
-- }}}

-- {{{ KIND_TO_VIEWER
-- Kind -> { program, args, terminal }. "other" is intentionally ABSENT so
-- viewer_for returns nil and the navigator takes the announced xdg-open
-- fallback. `terminal` distinguishes a program that must OWN the terminal
-- (neovim -- run it in the foreground and wait) from a windowed program that
-- should open detached so the navigator prompt stays live. All programs here
-- were confirmed present on this machine.
local KIND_TO_VIEWER = {
    video = { program = "mpv",     args = {}, terminal = false },
    audio = { program = "mpv",     args = {}, terminal = false },
    image = { program = "feh",     args = {}, terminal = false },
    doc   = { program = "zathura", args = {}, terminal = false },
    text  = { program = "nvim",    args = {}, terminal = true  },
}
-- }}}

-- {{{ M.apply_overrides
-- Let config.lua re-point a kind (e.g. images to sxiv) without touching this
-- file. Called once at startup by main.
function M.apply_overrides(overrides)
    for kind, viewer in pairs(overrides or {}) do
        KIND_TO_VIEWER[kind] = viewer
    end
end
-- }}}

-- {{{ M.kind_of
function M.kind_of(path)
    return EXT_TO_KIND[utils.extension(path)] or "other"
end
-- }}}

-- {{{ M.viewer_for
-- Returns { program, args } or nil. nil is the signal to fall back — and the
-- navigator prints a warning when it does, because a fallback is never silent.
function M.viewer_for(kind)
    return KIND_TO_VIEWER[kind]
end
-- }}}

return M
