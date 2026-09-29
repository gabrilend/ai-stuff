-- 095-mechanism-counts.lua
--
-- How often each mechanism has been seen (docs/069, issue 1002d) — counted,
-- not judged. Takes an array of lesson records (085's own shape) rather
-- than reading `output/story/lessons.md` itself: 1002b (the append-only
-- writer) is not yet built, so this counts what 1002a already produces,
-- and 1002b's reader can hand it real parsed lessons unchanged the day it
-- exists (strategems/build-to-the-shape-not-the-neighbor.md).

local mechanism_counts = {}

-- {{{ function mechanism_counts.from_lessons
-- lessons: array of lesson tables (085-the-lesson.lua's `build` shape).
-- Returns {[mechanism] = how many lessons named it}.
function mechanism_counts.from_lessons(lessons)
    local counts = {}
    for _, one in ipairs(lessons) do
        counts[one.mechanism] = (counts[one.mechanism] or 0) + 1
    end
    return counts
end
-- }}}

return mechanism_counts
