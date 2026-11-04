-- eye-position-fit.lua - does one frame size suit most people's eyes?
-- Written by Claude (Opus 5.5), 2026-10-10, for issue 009, for the tiles of
-- issue 304 (each lens split into a grid of tiles).
--
-- A frame is made for one distance between the pupils. On a wearer whose
-- eyes are closer or further apart, each pupil sits off the middle of its
-- lens by half the difference. Measured in tiles: past half a tile, the
-- pupil is no longer behind the tile meant for it.
return {
    question = "On how wide a range of eye spacings does one frame keep each pupil behind its middle tile?",
    inputs = {
        { name = "frame_eye_distance", nominal = 63, unit = "mm", minus = 0.3, plus = 0.3, from = "docs/sizes.md: typical 63; frame made to +/-0.3" },
        { name = "wearer_eye_distance", nominal = 63, unit = "mm", minus = 9, plus = 11, condition = true, from = "docs/sizes.md: adults 54-74" },
        { name = "lens_width", nominal = 52, unit = "mm", minus = 0.2, plus = 0.2, from = "docs/sizes.md: typical lens width" },
        { name = "tiles_across", nominal = 4, unit = "count", minus = 0, plus = 0, from = "issue 304 open question 2: guess 4 by 4" },
    },
    outputs = {
        -- signed: wider-set eyes than the frame are positive
        { name = "offset_per_eye", unit = "mm" },
        { name = "offset_in_tiles", unit = "ratio", at_least = -0.5, at_most = 0.5 },
    },
    compute = function(v)
        local offset = (v.wearer_eye_distance - v.frame_eye_distance) / 2
        return { offset_per_eye = offset, offset_in_tiles = offset / (v.lens_width / v.tiles_across) }
    end,
}
