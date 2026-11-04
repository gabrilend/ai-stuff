-- 036-lexicon.lua — which words in a person's prose the studio knows
-- (issue 604b).
--
-- What this is, generally: before anything is drawn, every word of the
-- prose is checked. A word is known if the score vocabulary uses it, if
-- it is ordinary English that carries no picture of its own ("the",
-- "after", "left"), or if a word file exists for it. Every other word is
-- unrecognized, and becomes a job for a word session (604c). The list
-- comes back in the order the words first appear, each with the
-- sentence it came from, so the session can read the word in context.
--
-- Data-format notes worth knowing more than once:
--   * words are lower-cased; anything but letters, hyphens and
--     apostrophes splits words; words under three letters are known;
--   * a simple inflection of a known word is known: -s, -es, -ed, -ing,
--     -ly, -er, -est (with a doubled consonant or a dropped e undone),
--     so "spirals" and "spiralling" do not each start their own session.

local lexicon = {}

-- {{{ PLAIN_ENGLISH -- ordinary words that draw nothing by themselves
-- Kept short on purpose: a word missing from here costs one word
-- session, which writes a plain word file for it once, forever after.
local PLAIN_ENGLISH = [[
a about above across after again against all almost along also always am
among an and another any anything are around as at away back be because
been before behind being below beneath beside besides between beyond both
but by can cannot could did do does doing done down during each either
else enough even ever every everything few first for from further get
gets getting give go goes going gone had has have having he her here hers
him his how however i if in inside into is it its itself just keep kind
last later least less let like little lot made make makes making many may
me might more most much must my near nearly never next no none nor not
nothing now of off often on once one only onto or other others our out
outside over own part per perhaps quite rather really right same see seem
seems she should show shows side since so some something sometimes soon
still such than that the their them then there these they thing things
this those though through throughout till to together too toward towards
under until up upon us use used very want was way we well were what when
where whether which while who whole why will with within without would yet
you your
start starts started starting begin begins began beginning end ends ended
ending stop stops finish finishes become becomes turn turns turned turning
go went come comes came appear appears disappear disappears happen happens
move moves moved moving draw draws drawn drawing leave leaves stay stays
first second third fourth fifth half quarter middle center centre top
bottom left right edge edges corner corners each both between
zero one two three four five six seven eight nine ten eleven twelve
twenty thirty hundred
second seconds minute minutes moment moments time times beat beats
fast faster fastest quick quickly slower slowest bit little big small
large tiny long short tall wide narrow thin thick full empty whole
bright dark light dim soft hard brighter darker
red orange yellow green blue purple pink white black grey gray brown
color colour colors colours
like same different again more less much
make let then also while before after once twice
]]
-- }}}

-- {{{ local function vocabulary_words()
-- The words the score itself uses, read from the same tables the wall
-- trusts, so a hue added to the palette is known here the same day.
local function vocabulary_words()
    local known = {}
    local function add(word)
        for part in tostring(word):lower():gmatch("[a-z]+") do known[part] = true end
    end
    for name in pairs(require("002-palette").hues) do add(name) end
    local easing = require("016-easing")
    for name in pairs(easing.EASINGS) do add(name) end
    for name in pairs(easing.ENVELOPES) do add(name) end
    for name in pairs(require("008-emit").DEFAULTS) do add(name) end
    for _, word in ipairs({ "canvas", "stroke", "strokes", "arc", "line",
        "point", "fill", "tip", "pattern", "clockwise", "counterclockwise",
        "clock", "o'clock", "oclock", "hour", "radius", "center", "sweep",
        "downward", "radial", "along", "at-once", "fade", "ease", "emit",
        "glow", "particle", "particles", "gif", "seed", "size", "fps",
        "length", "gravity", "vertex", "vertices", "triangle", "shape" }) do
        add(word)
    end
    return known
end
-- }}}

-- {{{ local function stems()
-- The forms a word might be an inflection of. "spiralling" yields
-- "spirall", "spiral"; "faded" yields "fad", "fade".
local function stems(word)
    local out = {}
    for _, suffix in ipairs({ "ing", "ed", "es", "s", "ly", "est", "er" }) do
        if #word > #suffix + 2 and word:sub(-#suffix) == suffix then
            local base = word:sub(1, -#suffix - 1)
            out[#out + 1] = base
            out[#out + 1] = base .. "e"
            if base:sub(-1) == base:sub(-2, -2) then
                out[#out + 1] = base:sub(1, -2)
            end
            if base:sub(-1) == "i" then
                out[#out + 1] = base:sub(1, -2) .. "y"
            end
        end
    end
    return out
end
-- }}}

-- {{{ function lexicon.known_set()
-- Every known word: vocabulary, plain English, and every word file's
-- word and aliases. `vocabulary` is the table src/034-words.lua loads.
function lexicon.known_set(vocabulary)
    local known = vocabulary_words()
    for word in PLAIN_ENGLISH:gmatch("[a-z']+") do known[word] = true end
    for form in pairs(vocabulary.forms) do known[form] = true end
    return known
end
-- }}}

-- {{{ local function is_known()
local function is_known(word, known)
    if #word < 3 or known[word] then return true end
    for _, stem in ipairs(stems(word)) do
        if known[stem] then return true end
    end
    return false
end
-- }}}

-- {{{ function lexicon.unknown()
-- The unrecognized words in `prose`, in order of first appearance:
-- a list of { word = "spiral", sentence = "..." }.
function lexicon.unknown(prose, vocabulary)
    local known = lexicon.known_set(vocabulary)
    local found, seen = {}, {}
    -- sentences end at . ! ? or a blank line
    local text = prose:gsub("\n%s*\n", ". ")
    for sentence in (text .. "."):gmatch("%s*([^%.!%?]+)[%.!%?]") do
        local clean = sentence:gsub("%s+", " ")
        for raw in clean:lower():gmatch("[a-z][a-z'%-]*") do
            local word = raw:gsub("'s$", ""):gsub("^%-+", ""):gsub("%-+$", "")
            -- an unknown word also claims its stems, so "hands" then
            -- "hand" (or the other way round) start one session, not two
            local already = seen[word]
            for _, stem in ipairs(stems(word)) do
                if seen[stem] then already = true end
            end
            if not already and not is_known(word, known) then
                seen[word] = true
                for _, stem in ipairs(stems(word)) do seen[stem] = true end
                found[#found + 1] = { word = word, sentence = clean }
            end
        end
    end
    return found
end
-- }}}

return lexicon
