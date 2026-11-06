-- test-corpus.lua — reading the corpus: splitting on the 80-dash
-- delimiter, classifying each block, and normalizing it (issue 032's
-- structural-line strip included), checked against a small synthetic
-- corpus whose right answers are written out below.  Also checks that the
-- embedding pipeline's copy of the normalizer (themes-v2/
-- load-poem-embeddings.lua) gives byte-identical output to the
-- renderer's, since the embedding cache is keyed on that text.
--
-- Usage: <lua5.2 | luajit | lua5.4> test-corpus.lua [DIR]
--   DIR  the words-pdf project folder (default below)
-- Prints PASS or FAIL per check and "counts <passed> <failed>".

local DIR = arg[1] or "/home/ritz/programming/ai-stuff/words-pdf"
package.path = DIR .. "/tests/?.lua;" .. package.path
local kit = require("kit")

local FIXTURE = DIR .. "/tests/fixtures/corpus.txt"
local DELIMITER = string.rep("-", 80)
kit.load_compiler(DIR, FIXTURE)

-- {{{ function raw_blocks
-- The fixture split by hand on the delimiter, untouched, trailing block
-- included, so checks can feed single blocks to the normalizers.
local function raw_blocks(path)
    local blocks, current = {}, {}
    for line in io.lines(path) do
        if line == DELIMITER then
            table.insert(blocks, current)
            current = {}
        else
            table.insert(current, line)
        end
    end
    table.insert(blocks, current)
    return blocks
end
-- }}}

local blocks = raw_blocks(FIXTURE)

print("detect_poem_type")
-- {{{ classification
kit.check("a fediverse block with a CW line is fediverse_with_cw", function()
    kit.same(detect_poem_type(blocks[1]), "fediverse_with_cw")
end)
kit.check("a fediverse block without a CW line is fediverse_no_cw", function()
    kit.same(detect_poem_type(blocks[2]), "fediverse_no_cw")
end)
kit.check("a block from anywhere else is messages_notes", function()
    kit.same(detect_poem_type(blocks[4]), "messages_notes")
    kit.same(detect_poem_type(blocks[7]), "messages_notes")
end)
kit.check("an empty block is unknown", function()
    kit.same(detect_poem_type({}), "unknown")
end)
-- }}}

print("normalize_poem_spacing")
-- {{{ normalization
kit.check("CW poem: header dropped, CW line, one blank, then the poem", function()
    kit.lines(normalize_poem_spacing(blocks[1]),
        { "CW: weather", "", "the rain kept its own counsel", "and so did i" })
end)
kit.check("fediverse poem: header and leading blanks dropped", function()
    kit.lines(normalize_poem_spacing(blocks[2]), { "a short note about bread" })
end)
kit.check("message: leading blanks dropped, inner blank kept", function()
    kit.lines(normalize_poem_spacing(blocks[4]),
        { "three lines", "of a message", "", "to nobody" })
end)
kit.check("image-only post normalizes to nothing", function()
    kit.lines(normalize_poem_spacing(blocks[3]), {})
end)
kit.check("timestamp-only post normalizes to nothing", function()
    kit.lines(normalize_poem_spacing(blocks[5]), {})
end)
kit.check("an attachment line inside a note is dropped, the note kept", function()
    kit.lines(normalize_poem_spacing(blocks[7]),
        { "notes without a header", "second line, kept" })
end)
kit.check("words that merely look like files stay", function()
    local kept = {
        "see notes.txt for more",       -- has spaces: a sentence
        "version 1.5",                  -- has a space
        "e.g.",                         -- no extension after the last dot
        "readme.md",                    -- .md is not a known media/doc ext
        "20250414",                     -- a bare date, not a full stamp
    }
    kit.lines(normalize_poem_spacing(kept), kept)
end)
kit.check("the header is recognized with any indent and arrow length", function()
    kit.lines(normalize_poem_spacing({ "-> file: a.txt", "   --> file: b.txt", "kept" }), { "kept" })
end)
kit.check("normalizing does not change the input list", function()
    local block = { " -> file: fediverse/1.txt", "", "x" }
    normalize_poem_spacing(block)
    kit.same(#block, 3, "input length")
end)
-- }}}

print("load_file")
-- {{{ loading the whole fixture
local book = load_file({ pages = {}, poems = {} })

kit.check("every delimited block with text becomes one poem, in order", function()
    kit.same(#book.poems, 5, "poem count")
    kit.same(book.poems[1][1], "CW: weather")
    kit.same(book.poems[2][1], "a short note about bread")
    kit.same(book.poems[3][1], "three lines")
    kit.same(book.poems[4][1], "notes without a header")
    kit.same(book.poems[5][1], "CW: long")
end)
kit.check("blocks that normalize to nothing take no place in the book", function()
    for i, poem in ipairs(book.poems) do
        kit.truthy(#poem > 0, "poem " .. i .. " is not empty")
    end
end)
kit.check("no source header reaches the book", function()
    for _, poem in ipairs(book.poems) do
        for _, line in ipairs(poem) do
            kit.truthy(not line:match("file:"), "line '" .. line .. "' has no header")
        end
    end
end)
kit.check("a final block with no delimiter after it is not loaded", function()
    -- Deliberate, and mirrored by themes-v2/load-poem-embeddings.lua's
    -- split_poems: the cleaned corpus always ends with a delimiter.
    for _, poem in ipairs(book.poems) do
        kit.truthy(poem[1] ~= "a trailing block with no delimiter after it", "trailing block skipped")
    end
end)
kit.check("a missing input file is a clear error, not a crash", function()
    FILE = DIR .. "/tests/fixtures/no-such-file.txt"
    local ok, problem = pcall(load_file, { pages = {}, poems = {} })
    FILE = FIXTURE
    kit.truthy(not ok, "load_file refuses")
    kit.truthy(tostring(problem):find("no-such-file.txt", 1, true), "error names the file")
end)
-- }}}

print("the embedding pipeline's copy")
-- {{{ twin equivalence
local EMBED = DIR .. "/themes-v2/load-poem-embeddings.lua"
local twin = kit.sandbox({
    kit.extract_function(EMBED, "detect_poem_type"),
    kit.extract_function(EMBED, "normalize_poem_spacing"),
})

-- {{{ local function same_everywhere
local function same_everywhere(block, label)
    local mine = normalize_poem_spacing(block)
    local theirs = twin.normalize_poem_spacing(block)
    kit.same(table.concat(theirs, "\n"), table.concat(mine, "\n"), label)
    kit.same(twin.detect_poem_type(block), detect_poem_type(block), label .. " type")
end
-- }}}

kit.check("both copies give the same text for every fixture block", function()
    for i, block in ipairs(blocks) do
        same_everywhere(block, "block " .. i)
    end
end)
kit.check("both copies agree on edge cases", function()
    local cases = {
        {},
        { "" },
        { "", "", "" },
        { "CW: only a warning" },
        { " -> file: fediverse/9.txt", "CW: x", "", "", "body" },
        { " -> file: fediverse/9.txt", "body", "CW: late warning", "more" },
        { "IMG_0001.JPEG", "caption under it" },
        { "  clip.mp4  " },
        { "fediverse/ mentioned in passing", "text" },
    }
    for i, block in ipairs(cases) do
        same_everywhere(block, "case " .. i)
    end
end)
-- }}}

kit.finish()
