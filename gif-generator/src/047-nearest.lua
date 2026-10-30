-- 047-nearest.lua — the nearest legal word to a miss, shared by both
-- walls.
--
-- What this is, generally: when a name misses its vocabulary, the wall
-- quotes back the closest legal word, measured by edit distance. The 2D
-- score's wall (024-compile.lua) and the 3D scene's wall
-- (049-shape-wall.lua) both teach this way, so they share this one
-- measure rather than each keeping a copy.

local nearest = {}

-- {{{ function nearest.edit_distance()
-- Levenshtein, the plain dynamic program — small words, small cost.
function nearest.edit_distance(a, b)
    local la, lb = #a, #b
    local row = {}
    for j = 0, lb do row[j] = j end
    for i = 1, la do
        local prev = row[0]
        row[0] = i
        for j = 1, lb do
            local cur = row[j]
            local cost = (a:byte(i) == b:byte(j)) and 0 or 1
            local best = math.min(row[j] + 1, row[j - 1] + 1,
                                  prev + cost)
            row[j] = best
            prev = cur
        end
    end
    return row[lb]
end
-- }}}

-- {{{ function nearest.word()
-- The closest legal word to a miss — the wall's teaching voice,
-- quoted back to humans and to the porch's models alike. Ties go to
-- the word met first, so a sorted list gives a steady answer.
function nearest.word(word, candidates)
    local best, best_d = nil, math.huge
    for _, c in ipairs(candidates) do
        local d = nearest.edit_distance(tostring(word), c)
        if d < best_d then best, best_d = c, d end
    end
    return best
end
-- }}}

return nearest
