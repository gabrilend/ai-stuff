-- bend-light-hold.lua - does the pipe's bend keep its light in?
-- Written by Claude (Opus 5.5), 2026-10-11, for issue 105 (third round:
-- a 5 mm side-emitting fibre around the head, mirror-coated); format in
-- docs/tolerances.md.
--
-- Light is trapped in a fibre's core by total internal reflection: at the
-- boundary with the lower-index cladding it is turned back completely, as
-- long as it strikes at a glancing angle (the sine of its angle from the
-- wall's perpendicular at least cladding index / core index). Around a
-- bend, a ray travelling along the pipe meets the outer wall more squarely
-- the tighter the bend: one hugging the inner wall (the worst case) meets
-- the outer wall at sine (R - w/2) / (R + w/2), for bend radius R and pipe
-- width w. Where that falls short, the mirror coating has to catch it.
return {
    question = "Around the bend of the band, does total internal reflection alone keep the light in, and how much is left to the mirror coating?",
    inputs = {
        { name = "pipe_width", nominal = 5.0, unit = "mm", minus = 0.1, plus = 0.1, from = "the owner: as wide as a thick glasses arm (5-6 mm)" },
        { name = "bend_radius", nominal = 90, unit = "mm", minus = 10, plus = 10, condition = true, from = "issue 105 model; heads differ (docs/sizes.md: 520-620 mm around)" },
        { name = "core_index", nominal = 1.492, unit = "ratio", minus = 0.001, plus = 0.001, from = "datasheet: PMMA, the usual core of side-emitting fibre" },
        { name = "cladding_index", nominal = 1.40, unit = "ratio", minus = 0.01, plus = 0.01, from = "datasheet: fluorinated polymer cladding of plastic fibre" },
    },
    outputs = {
        -- positive: every ray travelling along the pipe stays trapped
        { name = "trapping_margin", unit = "ratio", at_least = 0 },
        { name = "share_left_to_the_mirror", unit = "percent" },
        { name = "acceptance_half_angle", unit = "deg" },
        { name = "tightest_bend_trapped", unit = "mm" },
    },
    compute = function(v)
        local half = v.pipe_width / 2
        local ratio = v.cladding_index / v.core_index
        local worst = (v.bend_radius - half) / (v.bend_radius + half)
        -- rays entering spread evenly across the width, all along the pipe:
        -- those whose distance from the bend's centre is below
        -- ratio x (R + w/2) meet the outer wall too squarely
        local failing = (ratio * (v.bend_radius + half) - (v.bend_radius - half)) / v.pipe_width
        -- the cone of angles a straight fibre accepts: sine = sqrt(n1^2 - n2^2)
        local acceptance = math.deg(math.asin(math.min(1, math.sqrt(v.core_index ^ 2 - v.cladding_index ^ 2))))
        return {
            trapping_margin = worst - ratio,
            share_left_to_the_mirror = math.max(0, math.min(1, failing)) * 100,
            acceptance_half_angle = acceptance,
            tightest_bend_trapped = half * (1 + ratio) / (1 - ratio),
        }
    end,
}
