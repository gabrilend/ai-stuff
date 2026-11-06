-- Tests for image-render.lua (Issue 9-013 renderer side).
-- Run: luajit src/image-render.test.lua
-- The project folder from --dir PATH, or nil when it was not given (the
-- default below is then used); a stray word on the command line stops the
-- program, named (libs/project-dir.lua, Issue 10-076).
local PROJECT_DIR_ARG = (function()
    local own = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
    local dir = dofile(own .. "../libs/project-dir.lua").read(arg, "")
    if dir == "" then return nil end
    return dir
end)()

package.path = "./src/?.lua;./libs/?.lua;" .. package.path
local R = require("image-render")

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; print("  FAIL: " .. name) end
end

-- A poems_data that already contains a class-2 image-only post (poem_index 4).
local poems = { poems = {
    { poem_index = 1, id = 1, content = "real poem" },
    { poem_index = 4, id = 4, content = "🖼", category = "fediverse",
      attachments = {{ relative_path = "files/1/2/y.png", media_type = "image/png" }} },
}}

local manifest = {
    ["4"] = { class = 2, poem_index = 4, category = "fediverse" },
    ["5"] = { class = 3, poem_index = 5, source_name = "my-art",
              display_title = "my-art: factory-cube.png",
              relative_path = "/p/input/images/my-art/factory-cube.png",
              gallery_anchor = "img-abc123",
              width = 100, height = 80, creation_date = "2024-01-02T00:00:00Z" },
}

R.inject_pseudo_poems(poems, manifest)

-- Class 2: an image-only post stays the ordinary post it is (owner, 2026-10-22),
-- drawn with its text, warning and links, and is not duplicated.
local p4
for _, p in ipairs(poems.poems) do if p.poem_index == 4 then p4 = p end end
check("class-2 post is left an ordinary post", p4 and not p4.is_image and p4.image_class == nil)
check("class-2 keeps its original attachments", p4 and p4.attachments[1].relative_path == "files/1/2/y.png")

-- Class 3: appended as a new pseudo-poem with a usable attachment.
local p5
for _, p in ipairs(poems.poems) do if p.poem_index == 5 then p5 = p end end
check("class-3 pseudo-poem appended", p5 and p5.is_image == true and p5.image_class == 3)
-- Class-3 now keeps the FULL relative_path (not just the basename) so the
-- renderer can namespace art by source+subdir -- the bare-filename form was what
-- let same-named art images collide in output/media/.
check("class-3 attachment keeps the full relative_path", p5 and p5.attachments[1].relative_path == "/p/input/images/my-art/factory-cube.png")
check("class-3 attachment media type from ext", p5 and p5.attachments[1].media_type == "image/png")
check("class-3 display title carried", p5 and p5.display_title == "my-art: factory-cube.png")
check("total poems is 3 (1 + tagged 4 + appended 5)", #poems.poems == 3)

-- Idempotency: a second inject must not append again.
R.inject_pseudo_poems(poems, manifest)
check("idempotent: no duplicate append", #poems.poems == 3)

-- Issue 10-062: the gallery is paginated, so a picture's title links to its
-- page. Before the gallery index is loaded, drawing a gallery picture is a
-- wiring mistake and stops the build.
check("drawing a gallery picture before the gallery index is loaded is refused",
    not pcall(R.format_image_entry, p5))

-- A catalog of 25 my-art pictures, one a minute; the one hashed "abc123" is the
-- 13th. Ten pages -> 3 per page -> it is on page floor(12 / 3) + 1 = 5. A
-- fediverse-media picture is not in the gallery and does not shift anything.
local catalog = { images = { { source_name = "fediverse-media", hash = "zzz", modification_time = 0 } } }
for i = 1, 25 do
    catalog.images[#catalog.images + 1] = {
        source_name = "my-art", modification_time = i * 60,
        hash = (i == 13) and "abc123" or string.format("h%02d", i),
        relative_path = string.format("/p/input/images/my-art/%02d.png", i),
    }
end
local read_calls = 0
local function fake_read(path)
    read_calls = read_calls + 1
    return path == "catalog.json" and catalog or nil
end
local index = R.load_gallery_index("catalog.json", fake_read, 10)
check("the gallery index counts only the gallery's pictures", index.total == 25 and index.page_size == 3)
R.load_gallery_index("catalog.json", fake_read, 10)
check("the gallery index is read once per process", read_calls == 1)

-- format_image_entry: self-contained image box built from the injected attachment.
local html = R.format_image_entry(p5)
check("format includes the title", html:find("my%-art: factory%-cube%.png", 1) ~= nil)
-- art src is namespaced by source: output/media/my-art/factory-cube.png, NOT a
-- flat output/media/factory-cube.png (which would collide with any other source's
-- factory-cube.png). Mastodon hashes still flatten (see text_image_link below).
check("format namespaces art src under its source (relative)", html:find("%.%./media/my%-art/factory%-cube%.png", 1) ~= nil)
check("format carries width/height hints", html:find('width="100"') ~= nil and html:find('height="80"') ~= nil)
check("format is css-free (no class= attrs)", html:find('class=') == nil)
check("class-3 pseudo-poem carries gallery_anchor", p5.gallery_anchor == "img-abc123")
check("title deep-links to the picture's page of the chronological gallery",
    html:find('<a href="../gallery/chronological-05.html#img-abc123">', 1, true) ~= nil)
-- A picture the gallery does not show gets no link rather than a dead one.
local html_gone = R.format_image_entry({ display_title = "not in gallery", gallery_anchor = "img-nowhere",
    attachments = {} })
check("a picture the gallery does not show is not linked", html_gone:find("<a ", 1, true) == nil
    and html_gone:find("not in gallery", 1, true) ~= nil)
-- An image-only post (no gallery_anchor) keeps a plain title (no gallery link).
local html2 = R.format_image_entry({ display_title = "image post", attachments = {} })
check("image-only title is not gallery-linked", html2:find("chronological%.html", 1) == nil)

-- text_image_link: "image.png" link for a text+image post; "" for pure text.
do
    local link = R.text_image_link({ attachments = {{ relative_path = "files/9/8/photo.jpg", media_type = "image/jpeg" }} })
    check("text+image link labelled image.png", link:find(">image%.png</a>", 1) ~= nil)
    check("text+image link targets the media file (relative)", link:find("%.%./media/photo%.jpg", 1) ~= nil)
    check("pure-text poem gets no link", R.text_image_link({ content = "just words" }) == "")
end

-- No catalog at all: no gallery, so nothing is linked, and nothing fails.
R.reset_cache()
R.load_gallery_index("missing.json", fake_read, 10)
check("with no catalog, a gallery picture is drawn unlinked",
    R.format_image_entry(p5):find("<a ", 1, true) == nil)
R.reset_cache()
check("a bad page count is refused", not pcall(R.load_gallery_index, "catalog.json", fake_read, 0))

-- What a screen reader hears for a picture in the box: its own description,
-- else the box title (2026-10-22: every picture used to read as the title,
-- "fediverse: image post", though 80 of 85 had a description).
do
    local box = R.format_image_entry({ display_title = "fediverse: image post", attachments = {
        { relative_path = "a/one.png", description = 'a cat saying "hi" <3' },
        { relative_path = "a/two.png", description = "   " },
        { relative_path = "a/three.png" },
    } })
    check("a described picture is read by its description, quotes and < escaped",
        box:find('alt="a cat saying &quot;hi&quot; &lt;3"', 1, true) ~= nil)
    local _, titled = box:gsub('alt="fediverse: image post"', "")
    check("a blank or missing description falls back to the box title (2 of 3)", titled == 2)
    check("the description is also the hover title", box:find('title="a cat saying &quot;hi&quot; &lt;3"', 1, true) ~= nil)
end

print(string.format("\nimage-render: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
