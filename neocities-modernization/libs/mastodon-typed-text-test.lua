-- mastodon-typed-text-test.lua
-- Unit tests for libs/mastodon-typed-text.lua (issue 4-003, August 2026).
-- Pure string-in/string-out, runs standalone with no project setup:
--   luajit libs/mastodon-typed-text-test.lua
-- The final section is an optional integration pass: if the extracted
-- fediverse poems.json is present, three poems whose golden status was
-- hand-verified during the audit are recounted from their raw HTML.

-- {{{ setup_dir_path()
local function setup_dir_path(provided)
    if provided then return provided end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end
-- }}}

local DIR = setup_dir_path(arg and arg[1])
package.path = DIR .. "/libs/?.lua;" .. package.path
local typed = require("mastodon-typed-text")

local passed, failed = 0, 0

-- {{{ local function check_equal()
local function check_equal(name, got, want)
    if got == want then
        passed = passed + 1
        print("  ok  " .. name)
    else
        failed = failed + 1
        print("FAIL  " .. name)
        print("        want: " .. tostring(want))
        print("        got:  " .. tostring(got))
    end
end
-- }}}

-- Emphasis delimiters come back (the golden poem deficit mechanism)
check_equal("em restores asterisks",
    typed.restore("<p>I'd <em>love</em> to talk</p>"),
    "I'd *love* to talk")
check_equal("strong restores double asterisks",
    typed.restore("<p>a <strong>bold</strong> claim</p>"),
    "a **bold** claim")
check_equal("del restores tildes",
    typed.restore("<p>never <del>always</del> mind</p>"),
    "never ~~always~~ mind")
check_equal("code restores backticks",
    typed.restore("<p>run <code>make</code> twice</p>"),
    "run `make` twice")

-- Tag-name literals must not bleed into longer tags
check_equal("<b> restoration leaves <br /> alone",
    typed.restore("<p>one<br />two <b>loud</b></p>"),
    "one\ntwo **loud**")
check_equal("<s> restoration leaves <span> alone",
    typed.restore('<p><span class="x">kept</span> <s>gone</s></p>'),
    "kept ~~gone~~")

-- Paragraph structure: each break was two typed newlines
check_equal("paragraphs become blank lines",
    typed.restore("<p>first</p><p>second</p>"),
    "first\n\nsecond")

-- Entity decoding: specific entities before &amp;, so typed "&lt;" survives
check_equal("typed &lt; literal survives decoding",
    typed.restore("<p>type &amp;lt; for less-than</p>"),
    "type &lt; for less-than")
check_equal("plain ampersand decodes",
    typed.restore("<p>salt &amp; pepper</p>"),
    "salt & pepper")

-- Typed backslash-escapes are the author's text, not markup damage
check_equal("backslash-quote sequences survive",
    typed.restore("<p>the \\&quot;or\\&quot; operator</p>"),
    "the \\\"or\\\" operator")

-- Compose box length: visible characters, not bytes or UTF-16 units
check_equal("ascii counts one per char", typed.composer_length("abc"), 3)
check_equal("curly quote counts 1 (not 3 bytes)", typed.composer_length("\226\128\153"), 1)
check_equal("astral emoji counts 1", typed.composer_length("\240\159\152\128"), 1)
check_equal("heart plus variation selector counts 1",
    typed.composer_length("\226\157\164\239\184\143"), 1)

-- Mentions charge their visible text; URLs charge a flat 23
check_equal("mention counts as visible @user",
    typed.compose_box_count('<p><span class="h-card"><a href="https://spore.social/@friend" class="u-url mention">@<span>friend</span></a></span> hi</p>', nil),
    #"@friend hi")
check_equal("hashtag counts as visible #tag",
    typed.compose_box_count('<p><a href="https://tech.lgbt/tags/poetry" class="mention hashtag" rel="tag">#<span>poetry</span></a></p>', nil),
    #"#poetry")
check_equal("long URL counts as 23",
    typed.compose_box_count('<p>see <a href="https://example.com/a/very/long/path"><span class="invisible">https://</span><span class="ellipsis">example.com/a/very</span><span class="invisible">/long/path</span></a></p>', nil),
    #"see " + 23)
check_equal("short URL also counts as 23",
    typed.compose_box_count('<p><a href="https://a.io"><span class="invisible">https://</span>a.io</a></p>', nil),
    23)
check_equal("plain-text mention prices at local part",
    typed.compose_box_count("<p>@friend@octodon.social hello</p>", nil),
    #"@friend hello")

-- Content warning text joins the count, delimiters join the count
check_equal("cw text adds to the count",
    typed.compose_box_count("<p>body</p>", "warn"),
    #"body" + #"warn")
check_equal("delimiters join the count",
    typed.compose_box_count("<p>I'd <em>love</em> to</p>", nil),
    #"I'd *love* to")

-- {{{ Optional integration: recount audit-verified poems from the archive
local dkjson_ok, dkjson = pcall(require, "dkjson")
local poems_path = DIR .. "/input/fediverse/files/poems.json"
local pf = io.open(poems_path, "r")
if dkjson_ok and pf then
    local data = dkjson.decode(pf:read("*a"))
    pf:close()
    -- Poems hand-verified during the August 2026 audit. 0100/0145/4129 lost
    -- exactly their markdown delimiters; 2066 has a never-linkified plain-text
    -- mention whose domain rides free; 1673 has a heart emoji with an
    -- invisible variation selector. Typed length was 1024 on the nose for all.
    local verified_golden = {
        ["0100"] = true, ["0145"] = true, ["4129"] = true,
        ["2066"] = true, ["1673"] = true,
    }
    for _, poem in ipairs(data.poems) do
        if poem.category == "fediverse" and verified_golden[poem.id] then
            check_equal("archive poem " .. poem.id .. " recounts to 1024",
                typed.compose_box_count(poem.raw_content, poem.content_warning), 1024)
        end
    end
else
    print("  (skipping archive integration checks: poems.json not present)")
end
-- }}}

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
