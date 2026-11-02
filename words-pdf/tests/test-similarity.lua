-- test-similarity.lua — the vector arithmetic that picks each page's
-- theme (libs/fuzzy-computing.lua): cosine_similarity,
-- find_most_similar_theme, and the frequency-weighted chooser that keeps
-- one theme from taking over the book.  Vectors are small and written by
-- hand; nothing here talks to the embedding server.
--
-- Usage: <lua5.2 | luajit | lua5.4> test-similarity.lua [DIR]
--   DIR  the words-pdf project folder (default below)
-- Prints PASS or FAIL per check and "counts <passed> <failed>".

local DIR = arg[1] or "/home/ritz/programming/ai-stuff/words-pdf"
package.path = DIR .. "/tests/?.lua;" .. DIR .. "/?.lua;" .. package.path
local kit = require("kit")
local fuzz = require("libs/fuzzy-computing")

-- {{{ cosine_similarity
kit.check("identical vectors score 1", function()
    kit.near(fuzz.cosine_similarity({ 0.2, -0.4, 0.9 }, { 0.2, -0.4, 0.9 }), 1)
end)

kit.check("length does not matter, only direction", function()
    kit.near(fuzz.cosine_similarity({ 1, 2, 3 }, { 2, 4, 6 }), 1)
end)

kit.check("orthogonal vectors score 0", function()
    kit.near(fuzz.cosine_similarity({ 1, 0 }, { 0, 1 }), 0)
end)

kit.check("opposite vectors score -1", function()
    kit.near(fuzz.cosine_similarity({ 1, -2 }, { -1, 2 }), -1)
end)

kit.check("a known angle: 45 degrees scores sqrt(2)/2", function()
    kit.near(fuzz.cosine_similarity({ 1, 0 }, { 1, 1 }), math.sqrt(2) / 2)
end)

kit.check("vectors of different lengths score 0", function()
    kit.same(fuzz.cosine_similarity({ 1, 2, 3 }, { 1, 2 }), 0)
end)

kit.check("a missing vector scores 0", function()
    kit.same(fuzz.cosine_similarity(nil, { 1 }), 0)
    kit.same(fuzz.cosine_similarity({ 1 }, nil), 0)
end)

kit.check("a zero vector scores 0 instead of dividing by zero", function()
    kit.same(fuzz.cosine_similarity({ 0, 0 }, { 1, 1 }), 0)
end)
-- }}}

-- Three themes around the unit circle; the text points 10 degrees off
-- "sea", 50 off "forest" and 170 off "city".
local function at(degrees)
    local r = math.rad(degrees)
    return { math.cos(r), math.sin(r) }
end
local themes = { sea = at(0), forest = at(60), city = at(180) }
local text = at(10)

-- {{{ find_most_similar_theme
kit.check("the closest theme wins, with its similarity", function()
    local theme, similarity = fuzz.find_most_similar_theme(text, themes)
    kit.same(theme, "sea", "theme")
    kit.near(similarity, math.cos(math.rad(10)), "similarity")
end)

kit.check("no themes at all falls back to neutral", function()
    local theme, similarity = fuzz.find_most_similar_theme(text, {})
    kit.same(theme, "neutral", "theme")
    kit.same(similarity, -1, "similarity")
end)
-- }}}

-- {{{ find_most_similar_theme_weighted
kit.check("with no picks yet, weighting changes nothing", function()
    local theme, raw, weighted = fuzz.find_most_similar_theme_weighted(text, themes, {})
    kit.same(theme, "sea", "theme")
    kit.near(raw, math.cos(math.rad(10)), "raw similarity")
    kit.near(weighted, raw, "weighted score")
end)

kit.check("a heavily picked theme gives way to a nearly as close fresh one", function()
    -- sea: cos 10 = 0.985 x 1/(1+3) = 0.246; forest: cos 50 = 0.643 x 1.
    local theme, raw = fuzz.find_most_similar_theme_weighted(text, themes, { sea = 30 })
    kit.same(theme, "forest", "theme")
    kit.near(raw, math.cos(math.rad(50)), "raw similarity reported, not weighted")
end)

kit.check("a few picks do not outweigh a clear lead (soft decay)", function()
    -- sea: 0.985 x 1/(1+0.5) = 0.657 still beats forest's 0.643.
    local theme = fuzz.find_most_similar_theme_weighted(text, themes, { sea = 5 })
    kit.same(theme, "sea", "theme")
end)

kit.check("the boost follows 1/(1 + picks/10)", function()
    for _, picks in ipairs({ 0, 1, 10, 20, 100 }) do
        local _, raw, weighted = fuzz.find_most_similar_theme_weighted(
            text, { sea = themes.sea }, { sea = picks })
        kit.near(weighted, raw / (1 + picks / 10), picks .. " picks")
    end
end)

-- Issue 034: a text that points away from every theme.  It sits at -10
-- degrees, so a theme at angle t scores cos(t + 10), below zero here.
local back = at(-10)
local away = { sea = at(120), forest = at(170) }   -- cos 130 = -0.643, cos 180 = -1

kit.check("all scores negative: a heavily picked theme does not win (issue 034)", function()
    -- forest: cos 110 = -0.342, picked 100 times; sea: cos 120 = -0.5, fresh.
    -- Multiplying by forest's boost (1/11) gave -0.031 and forest won.
    local close = { sea = at(110), forest = at(100) }
    local theme, raw = fuzz.find_most_similar_theme_weighted(back, close, { forest = 100 })
    kit.same(theme, "sea", "theme")
    kit.near(raw, math.cos(math.rad(120)), "raw similarity reported, not weighted")
end)

kit.check("the issue's example: -0.9 picked 100 times loses to -0.5 never picked", function()
    -- A text at angle 0 scores cos t against a theme at angle t.
    local themes_neg = { used = at(math.deg(math.acos(-0.9))), fresh = at(math.deg(math.acos(-0.5))) }
    local theme, raw, weighted = fuzz.find_most_similar_theme_weighted(at(0), themes_neg, { used = 100 })
    kit.same(theme, "fresh", "theme")
    kit.near(raw, -0.5, "raw")
    kit.near(weighted, -0.5, "weighted (no picks, unchanged)")
end)

kit.check("every pick makes a negative score worse, never better", function()
    local last = math.huge
    for _, picks in ipairs({ 0, 1, 10, 20, 100 }) do
        local _, raw, weighted = fuzz.find_most_similar_theme_weighted(
            back, { sea = away.sea }, { sea = picks })
        kit.near(weighted, raw * (1 + picks / 10), picks .. " picks")
        kit.truthy(weighted < last, picks .. " picks scores below fewer picks")
        last = weighted
    end
end)

kit.check("with no picks, negative scores keep their order", function()
    local theme, raw = fuzz.find_most_similar_theme_weighted(back, away, {})
    kit.same(theme, "sea", "theme")
    kit.near(raw, math.cos(math.rad(130)), "raw")
end)

kit.check("a positive score still beats any negative one, however picked", function()
    -- up: cos 10, picked 1000 times; down: cos 190 = -0.985, fresh.
    local theme = fuzz.find_most_similar_theme_weighted(back, { up = at(0), down = at(180) }, { up = 1000 })
    kit.same(theme, "up", "theme")
end)
-- }}}

kit.finish()
