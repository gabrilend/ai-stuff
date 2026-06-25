-- Tests for image-render.lua (Issue 9-013 renderer side).
-- Run: luajit src/image-render.test.lua
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

-- Class 2: existing post tagged in place, NOT duplicated.
local p4
for _, p in ipairs(poems.poems) do if p.poem_index == 4 then p4 = p end end
check("class-2 post tagged is_image in place", p4 and p4.is_image == true and p4.image_class == 2)
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
check("title deep-links to the chronological gallery anchor",
    html:find("gallery/chronological%.html#img%-abc123", 1) ~= nil)
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

print(string.format("\nimage-render: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
