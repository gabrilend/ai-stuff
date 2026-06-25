#!/usr/bin/env luajit
-- image-render-test.lua
--
-- Regression test for URL-encoding of image filenames in the rendered HTML.
--
-- General description: an artist's PNG can be named anything -- including names
-- with spaces and a literal "?" (e.g. a real file in ~/pictures/my-art that
-- ends in "...TROUBLE-U-?-message-...png"). When such a name was dropped raw
-- into an <img src="..."> the browser cut the path at the first space, or
-- treated everything after the "?" as a query string, and drew a broken-image
-- icon. This test pins the fix: format_image_entry() and text_image_link() must
-- percent-encode the basename so the link reaches the real file on disk.
--
-- Runnable from any directory; it locates the source beside itself.

-- {{{ locate the module beside this test, regardless of caller's cwd
local DIR = arg[0]:match("^(.*)/[^/]+$") or "."
package.path = DIR .. "/?.lua;" .. package.path
local image_render = require("image-render")
-- }}}

local failures = 0

-- {{{ local function check()
local function check(label, condition)
    if condition then
        print("  ok   - " .. label)
    else
        print("  FAIL - " .. label)
        failures = failures + 1
    end
end
-- }}}

-- The actual offending filename pattern from the my-art catalog: spaces AND a
-- question mark. If either survives un-encoded into an attribute the image 404s.
local NASTY = "wawawwawawa ABC JK ? TROUBLE-U-?-message.png"
-- A "looks like junk but is URL-safe" name -- all letters/digits. Must pass
-- through UNCHANGED (we do not want gratuitous encoding of safe characters).
local SAFE_JUNK = "hbidrtszezdsgvfty6.png"

-- {{{ test: format_image_entry encodes the <img src>
do
    local poem = {
        display_title = "test",
        attachments = { { relative_path = NASTY, width = 100, height = 50 } },
    }
    local html = image_render.format_image_entry(poem)
    local src = html:match('<img src="([^"]*)"')
    check("format_image_entry emits an <img src>", src ~= nil)
    check("space is percent-encoded (%20)", src:find("%%20") ~= nil)
    check("question mark is percent-encoded (%3F)", src:find("%%3F") ~= nil)
    check("no raw space survives in src", src:find(" ") == nil)
    check("no raw '?' survives in src", src:find("%?") == nil)
end
-- }}}

-- {{{ test: text_image_link encodes the <a href>
do
    local poem = { attachments = { { relative_path = NASTY } } }
    local link = image_render.text_image_link(poem)
    local href = link:match('<a href="([^"]*)"')
    check("text_image_link emits an <a href>", href ~= nil)
    check("href has no raw space", href:find(" ") == nil)
    check("href has no raw '?'", href:find("%?") == nil)
end
-- }}}

-- {{{ test: URL-safe junk filename is left untouched
do
    local poem = { attachments = { { relative_path = SAFE_JUNK } } }
    local link = image_render.text_image_link(poem)
    check("safe filename passes through unencoded",
        link:find(SAFE_JUNK, 1, true) ~= nil)
end
-- }}}

-- Namespacing (the collision fix): art images keep their source + subdirs so two
-- files sharing a basename map to two different output/media/ paths; Mastodon
-- hashes (not under input/images/) stay flat.
local ROOT = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
local ART_A = ROOT .. "/input/images/my-art/proposed-movement-design.png"
local ART_B = ROOT .. "/input/images/my-art/game-design/proposed-movement-design.png"
local MASTODON = ROOT .. "/input/media_attachments/files/112/500/670/original/ad3a0a69d3dcf172.png"

local function src_of(path)
    local html = image_render.format_image_entry(
        { display_title = "t", attachments = { { relative_path = path, width = 1, height = 1 } } })
    return html:match('<img src="([^"]*)"')
end

-- {{{ test: art keeps source + subdir; same-name files no longer collide
do
    local a, b = src_of(ART_A), src_of(ART_B)
    check("art src keeps source prefix (my-art/)", a:find("my-art/proposed-movement-design.png", 1, true) ~= nil)
    check("art src in subdir keeps the subdir (my-art/game-design/)",
        b:find("my-art/game-design/proposed-movement-design.png", 1, true) ~= nil)
    check("same basename, different subdir -> DIFFERENT src (collision fixed)", a ~= b)
end
-- }}}

-- {{{ test: Mastodon hash stays flat (basename only, no nesting)
do
    local s = src_of(MASTODON)
    check("mastodon src is the bare hash", s:find("ad3a0a69d3dcf172.png", 1, true) ~= nil)
    check("mastodon src has no media_attachments nesting", s:find("media_attachments") == nil)
    check("mastodon src has no files/ nesting", s:find("/files/") == nil)
end
-- }}}

if failures == 0 then
    print("ALL PASS")
    os.exit(0)
else
    print(failures .. " FAILURE(S)")
    os.exit(1)
end
