-- index-match-drift.lua - what the liquid does to light as it warms.
-- Written by Claude (Opus 5.5), 2026-10-10, for issue 009; format in
-- docs/tolerances.md.
--
-- The filling is chosen to bend light exactly as the glass does (the same
-- refractive index), so its boundaries vanish. But liquids change index
-- about 200 times faster with temperature than glass, so away from the
-- matching temperature each boundary reflects a little and bends a little.
-- Light crossing a tab (a thin plate of liquid-glass-liquid) leaves parallel
-- to how it came, shifted sideways; the shift and the reflections are what
-- matter. Both depend on the size of the index difference, which can cross
-- zero inside the ranges: the worst cases (largest) are at the corners, the
-- smallest is not, and the limits here are all "at most".
return {
    question = "How much light is lost and how far is the picture shifted as the filling's index drifts with temperature?",
    inputs = {
        { name = "glass_index", nominal = 1.5168, unit = "ratio", minus = 0.0005, plus = 0.0005, from = "docs/sizes.md: N-BK7 at 587.6 nm; catalogue tolerance" },
        { name = "liquid_index", nominal = 1.5168, unit = "ratio", minus = 0.0002, plus = 0.0002, from = "guess: matching liquid's labelled tolerance" },
        { name = "liquid_index_per_C", nominal = -3.7e-4, unit = "per-C", minus = 0.3e-4, plus = 0.3e-4, from = "docs/sizes.md: matching liquids" },
        { name = "glass_index_per_C", nominal = 2e-6, unit = "per-C", minus = 1e-6, plus = 1e-6, from = "docs/sizes.md: N-BK7" },
        { name = "colour_mismatch", nominal = 0.0005, unit = "ratio", minus = 0.0005, plus = 0.0005, from = "guess: liquid and glass disperse differently at red and green" },
        { name = "temperature", nominal = 30, unit = "C", minus = 15, plus = 15, condition = true, from = "docs/sizes.md: wearing temperature 15-45" },
        { name = "matched_at", nominal = 25, unit = "C", minus = 0, plus = 0, condition = true, from = "datasheets quote indices at 25 C" },
        { name = "boundaries", nominal = 12, unit = "count", minus = 0, plus = 0, from = "issue 105 model: 6 tabs, 2 faces each" },
        { name = "tab_face_angle", nominal = 40, unit = "deg", minus = 40, plus = 40, from = "issue 105 model: tabs swing 0-80 degrees" },
        { name = "tab_thickness", nominal = 0.30, unit = "mm", minus = 0.015, plus = 0.015, from = "as in tab-channel-clearance" },
    },
    outputs = {
        { name = "index_difference", unit = "ratio" },
        { name = "light_lost", unit = "percent", at_most = 1 },
        -- signed with the index difference; limited either way
        { name = "shift_through_a_tab", unit = "mm", at_least = -0.05, at_most = 0.05 },
    },
    compute = function(v)
        local warmed = v.temperature - v.matched_at
        local difference = (v.liquid_index + v.liquid_index_per_C * warmed) - (v.glass_index + v.glass_index_per_C * warmed) + v.colour_mismatch
        local n = (v.liquid_index + v.glass_index) / 2
        -- reflected share at one boundary, light arriving square to it
        -- (Fresnel): ((n1 - n2) / (n1 + n2))^2
        local reflected = (difference / (2 * n)) ^ 2
        local lost = 1 - (1 - reflected) ^ v.boundaries
        -- inside the tab the ray turns by about (difference / n) * tan(angle)
        -- (from Snell's law, small difference), over a path thickness /
        -- cos(angle): the sideways shift on leaving
        local a = math.rad(v.tab_face_angle)
        local shift = v.tab_thickness * difference / n * math.tan(a) / math.cos(a)
        return { index_difference = difference, light_lost = lost * 100, shift_through_a_tab = shift }
    end,
}
