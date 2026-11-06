-- pipe-and-band-expansion.lua - the glass pipe and its nylon band, warmed.
-- Written by Claude (Opus 5.5), 2026-10-10, for issue 009; the light pipe
-- runs along the band (issue 105's model: about 200 mm of arc).
--
-- Nylon grows about thirty times more than glass when warmed. Along 200 mm
-- the band and the pipe it carries end up different lengths; glued along
-- their whole length, the glass would have to stretch or squeeze by the
-- same amount.
return {
    question = "How much do the glass light pipe and the nylon band holding it change length differently?",
    inputs = {
        { name = "pipe_length", nominal = 200, unit = "mm", minus = 1, plus = 1, from = "issue 105 model: 90 mm radius x 2.25 radians" },
        { name = "glass_expansion", nominal = 3.3e-6, unit = "per-C", minus = 0.1e-6, plus = 0.1e-6, from = "docs/sizes.md: borosilicate" },
        { name = "band_expansion", nominal = 100e-6, unit = "per-C", minus = 20e-6, plus = 20e-6, from = "docs/sizes.md: nylon PA12" },
        { name = "temperature", nominal = 30, unit = "C", minus = 15, plus = 15, condition = true, from = "docs/sizes.md: wearing temperature 15-45" },
        { name = "assembly_temperature", nominal = 20, unit = "C", minus = 2, plus = 2, condition = true, from = "guess: a room" },
    },
    outputs = {
        -- signed: warmer than assembled, the band grows longer (positive)
        { name = "length_difference", unit = "mm", at_least = -0.1, at_most = 0.1 },
        { name = "strain_if_glued", unit = "ratio", at_least = -0.0005, at_most = 0.0005 },
    },
    compute = function(v)
        local warmed = v.temperature - v.assembly_temperature
        local strain = (v.band_expansion - v.glass_expansion) * warmed
        return { length_difference = v.pipe_length * strain, strain_if_glued = strain }
    end,
}
