-- 012-the-shape-words.lua - every word a description may use, and what it
-- means.
--
-- In plain terms: the describing language is closed. These tables are the
-- whole of it; the reader (013) refuses any word not here, and suggests the
-- nearest one that is. docs/shape-words.md says the same thing for people,
-- and a test (017) checks the two agree, word for word: the document is the
-- contract, and this file must never know a word the document does not.
--
-- Why closed: a reader that guesses at unknown words draws something
-- plausible and wrong. A short list has nowhere to guess.
--
-- Every part has an axis (its own up, "upright" unless told otherwise) and
-- three extents: ALONG the axis, ACROSS it, and DEEP (the second direction
-- across). Round kinds keep across and deep equal; cubes and spheres keep
-- all three equal.

local M = {}

-- {{{ KINDS
-- Each kind of solid: the solid the builder makes (015), its default
-- extents (proportions, in units of the first part), which extents are tied
-- together, and which extent "thick" and "thin" mean for it (its smallest).
--   links: "round" (across = deep) or "all" (along = across = deep) or nil
M.KINDS = {
    box      = { solid = "box",      along = 1,    across = 1,   deep = 1,   thin = "along" },
    plate    = { solid = "box",      along = 0.1,  across = 1,   deep = 1,   thin = "along" },
    cube     = { solid = "box",      along = 1,    across = 1,   deep = 1,   thin = "along", links = "all" },
    cylinder = { solid = "cylinder", along = 1,    across = 1,   deep = 1,   thin = "along", links = "round" },
    disc     = { solid = "cylinder", along = 0.2,  across = 1,   deep = 1,   thin = "along", links = "round" },
    rod      = { solid = "cylinder", along = 1,    across = 0.15, deep = 0.15, thin = "across", links = "round" },
    cone     = { solid = "cone",     along = 1,    across = 1,   deep = 1,   thin = "along", links = "round" },
    sphere   = { solid = "sphere",   along = 1,    across = 1,   deep = 1,   thin = "along", links = "all" },
    ring     = { solid = "ring",     along = 0.15, across = 1,   deep = 1,   thin = "along", links = "round" },
}
-- other words for the same kinds
M.KIND_ALIASES = { block = "box", slab = "plate", disk = "disc", ball = "sphere", torus = "ring", pole = "rod" }
-- }}}

-- {{{ COLOURS
-- Each colour word to { r, g, b }. Parts with no colour word take the
-- next of DEFAULT_COLOURS in the order they were named.
M.COLOURS = {
    red = { 0.80, 0.20, 0.17 }, orange = { 0.90, 0.50, 0.15 }, yellow = { 0.92, 0.80, 0.25 },
    green = { 0.30, 0.65, 0.30 }, teal = { 0.25, 0.65, 0.62 }, blue = { 0.25, 0.42, 0.80 },
    purple = { 0.55, 0.35, 0.70 }, pink = { 0.90, 0.55, 0.65 }, brown = { 0.42, 0.28, 0.17 },
    black = { 0.10, 0.10, 0.11 }, grey = { 0.55, 0.56, 0.58 }, gray = { 0.55, 0.56, 0.58 },
    white = { 0.92, 0.92, 0.90 }, silver = { 0.75, 0.77, 0.80 }, gold = { 0.83, 0.68, 0.30 },
    metallic = { 0.70, 0.72, 0.76 },
}
M.DEFAULT_COLOURS = { "grey", "teal", "orange", "purple", "yellow", "green", "pink", "blue" }
-- }}}

-- {{{ EXTENT_WORDS
-- Size adjectives and nouns, each to the extent it measures. "thin"
-- (thick, thickness) means the kind's own thinnest extent; "all" means the
-- part as a whole (its largest extent, proportions kept).
M.EXTENT_WORDS = {
    tall = "along", high = "along", height = "along", long = "along", length = "along",
    wide = "across", width = "across", diameter = "across",
    deep = "deep", depth = "deep",
    thick = "thin", thickness = "thin",
    large = "all", big = "all", size = "all",
}
-- }}}

-- {{{ COMPARATIVES
-- "X is wider than Y": the extent, and whether X is more (1) or less (-1).
M.COMPARATIVES = {
    taller = { "along", 1 }, longer = { "along", 1 }, higher = { "along", 1 }, shorter = { "along", -1 },
    wider = { "across", 1 }, narrower = { "across", -1 },
    deeper = { "deep", 1 }, shallower = { "deep", -1 },
    thicker = { "thin", 1 }, thinner = { "thin", -1 },
    larger = { "all", 1 }, bigger = { "all", 1 }, smaller = { "all", -1 },
}
-- How much more a comparative means, by the word before it. With no word
-- before it, "wider than" means half as much again.
M.DEGREES = { none = 1.5, slightly = 1.25, a_little = 1.25, much = 3, far = 4 }
-- }}}

-- {{{ RATIOS
-- Ratio words before "as ... as" or "the size of". Digits are allowed in
-- "N times" (a ratio, not a measurement): "3 times as long as".
M.RATIOS = {
    half = 0.5, a_third = 1 / 3, a_quarter = 0.25, a_tenth = 0.1,
    twice = 2, one_and_a_half_times = 1.5, three_times = 3, four_times = 4, five_times = 5,
    six_times = 6, seven_times = 7, eight_times = 8, nine_times = 9, ten_times = 10,
}
-- }}}

-- {{{ PLACES
-- Where a part goes, relative to another. Faces touch: "on top of" puts the
-- part's bottom on the other's top, centred above it.
--   top, bottom      above / below
--   left, right      to the side, along the left-right direction
--   front, back      toward / away from the viewer
--   centre           same middle (inside, in the middle of)
--   around, through  same middle and the same axis (a ring around a rod,
--                    an axle through a wheel)
--   end, other_end   beyond the far / near end of the other part's axis
M.PLACES = {
    on_top_of = "top", on = "top", above = "top",
    under = "bottom", below = "bottom", beneath = "bottom", underneath = "bottom",
    to_left_of = "left", left_of = "left",
    to_right_of = "right", right_of = "right", beside = "right", next_to = "right",
    in_front_of = "front", behind = "back",
    inside = "centre", in_middle_of = "centre", at_centre_of = "centre", at_center_of = "centre",
    around = "around",
    through = "through", passes_through = "through", goes_through = "through", runs_through = "through",
    at_end_of = "end", at_far_end_of = "end", at_other_end_of = "other_end", at_near_end_of = "other_end",
}
-- }}}

-- {{{ DIRECTIONS
-- Which way a part's own axis runs. "upright" is the default.
M.DIRECTIONS = {
    stands_upright = "y", is_upright = "y", upright = "y",
    lies_left_to_right = "x", lies_sideways = "x",
    lies_front_to_back = "z", points_forward = "z",
    -- for flat things (plates, discs, rings) the axis is the way they face
    faces_forward = "z", faces_up = "y", faces_sideways = "x",
}
-- }}}

-- {{{ ALIGNING
-- "Aligned with the axis of": the same axis direction, and the middle moved
-- onto the other part's axis line (keeping its place along it).
M.ALIGNING = {
    aligned_with_rotational_axis_of = true, aligned_with_axis_of = true,
    aligned_with = true, shares_axis_with = true,
}
-- }}}

-- {{{ PROPORTIONS
-- shaped_like: the other part's proportions (and its size, unless a size
-- sentence changes it). scaled_to: own proportions, overall size matched
-- (largest extent equal to the other part's largest).
M.PROPORTIONS = {
    shaped_like = "shaped_like", proportionally_scaled_to = "scaled_to", scaled_to = "scaled_to",
    same_size_as = "same_size",
}
-- }}}

-- {{{ JOINING_WORDS
-- Verbs joining a part to what is said about it; all mean the same.
M.JOINING_WORDS = { is = true, sits = true, rests = true, stands = true, hangs = true, lies = true, are = true }
-- }}}

-- {{{ GRAMMAR_WORDS
-- Small words sentence shapes use, with no meaning on their own.
M.GRAMMAR_WORDS = { as = true, than = true, of = true, there = true, called = true, shaped = true, thing = true,
    -- "it": the sentence's own part, in "half as deep as it is wide"
    it = true }
-- dropped before reading: the articles
M.DROPPED_WORDS = { a = true, an = true, the = true }
-- }}}

-- {{{ PHRASES
-- Multi-word phrases joined into one word before reading, longest first.
-- Two lists, because some phrases need their article ("a third") and are
-- joined before articles are dropped; the rest are written without them.
M.PHRASES_WITH_ARTICLES = {
    "one and a half times", "a third", "a quarter", "a tenth", "a little",
}
M.PHRASES = {
    "aligned with rotational axis of", "aligned with axis of", "shares axis with", "aligned with",
    "proportionally scaled to", "scaled to", "shaped like", "same size as",
    "on top of", "to left of", "to right of", "left of", "right of", "next to", "in front of",
    "in middle of", "at centre of", "at center of", "at far end of", "at other end of", "at near end of", "at end of",
    "passes through", "goes through", "runs through",
    "stands upright", "is upright", "lies left to right", "lies sideways", "lies front to back", "points forward",
    "faces forward", "faces up", "faces sideways",
    "three times", "four times", "five times", "six times", "seven times", "eight times", "nine times", "ten times",
}
-- }}}

-- {{{ function M.all_words()
-- Every legal single word (after phrase joining), for suggestions and for
-- the agreement test with the document.
function M.all_words()
    local words = {}
    local function add(list) for word in pairs(list) do words[word] = true end end
    add(M.KINDS) add(M.KIND_ALIASES) add(M.COLOURS) add(M.EXTENT_WORDS) add(M.COMPARATIVES)
    add(M.RATIOS) add(M.PLACES) add(M.DIRECTIONS) add(M.ALIGNING) add(M.PROPORTIONS)
    add(M.JOINING_WORDS) add(M.GRAMMAR_WORDS)
    for word in pairs(M.DEGREES) do if word ~= "none" then words[word] = true end end
    return words
end
-- }}}

-- {{{ function M.kind_of()
-- A kind word (or alias) to its kind name, or nil.
function M.kind_of(word)
    if M.KINDS[word] then return word end
    return M.KIND_ALIASES[word]
end
-- }}}

return M
