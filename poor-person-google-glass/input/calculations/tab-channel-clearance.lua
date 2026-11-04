-- tab-channel-clearance.lua - does a tab still swing freely in its channel?
-- Written by Claude (Opus 5.5), 2026-10-10, for issue 009; format in
-- docs/tolerances.md. All sizes are guesses until the tabs are designed.
--
-- A stainless tab, coated on both faces, swings in a narrow channel cut in
-- the glass. The gap left on each side must stay open at every wearing
-- temperature: steel grows over five times faster than glass when warmed.
return {
    question = "Does a tab still swing freely in its channel, from cold to warm?",
    inputs = {
        { name = "channel_width", nominal = 0.40, unit = "mm", minus = 0.02, plus = 0.02, from = "guess: channel etched in glass, +/-5%" },
        { name = "tab_thickness", nominal = 0.30, unit = "mm", minus = 0.015, plus = 0.015, from = "guess: photo-etched stainless sheet, +/-5%" },
        { name = "coating_per_face", nominal = 0.005, unit = "mm", minus = 0.002, plus = 0.003, from = "guess: dark absorbing coat on each face" },
        { name = "hinge_play", nominal = 0.02, unit = "mm", minus = 0.01, plus = 0.01, from = "guess: side-to-side wobble at the hinge" },
        { name = "temperature", nominal = 30, unit = "C", minus = 15, plus = 15, condition = true, from = "docs/sizes.md: wearing temperature 15-45" },
        { name = "assembly_temperature", nominal = 20, unit = "C", minus = 2, plus = 2, condition = true, from = "guess: a room" },
        { name = "tab_expansion", nominal = 17.3e-6, unit = "per-C", minus = 0.5e-6, plus = 0.5e-6, from = "docs/sizes.md: stainless 304" },
        { name = "glass_expansion", nominal = 3.3e-6, unit = "per-C", minus = 0.1e-6, plus = 0.1e-6, from = "docs/sizes.md: borosilicate" },
    },
    outputs = {
        { name = "clearance_per_side", unit = "mm", at_least = 0.01 },
    },
    compute = function(v)
        local warmed = v.temperature - v.assembly_temperature
        local channel = v.channel_width * (1 + v.glass_expansion * warmed)
        local tab = v.tab_thickness * (1 + v.tab_expansion * warmed) + 2 * v.coating_per_face
        return { clearance_per_side = (channel - tab - v.hinge_play) / 2 }
    end,
}
