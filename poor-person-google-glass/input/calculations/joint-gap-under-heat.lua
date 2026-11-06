-- joint-gap-under-heat.lua - how a gap between two parts changes as they
-- warm. Written by Claude (Opus 5.5), 2026-10-10, for issue 010: a general
-- calculation for joint records, its gap, reaches and expansions meant to
-- be bound to the joint's structure and its parts' materials (docs/joints.md).
-- The nominal values below are stand-ins, replaced when bound.
--
-- Each part grows by its reach across the joint x its expansion x the
-- warming; held at its middle, half of that growth is toward the joint. So
-- the gap shrinks by half of each part's growth. Touching parts (gap 0)
-- press on each other when warmed: the answer goes negative, and the limit
-- of zero fails, which is the joint telling you so.
return {
    question = "Does the gap between these two parts stay open from cold to warm?",
    inputs = {
        { name = "gap", nominal = 0.1, unit = "mm", minus = 0.02, plus = 0.02, from = "stand-in; bind to structure.gap. Tolerance a guess: +/-0.02 mm" },
        { name = "reach_a", nominal = 10, unit = "mm", minus = 0.05, plus = 0.05, from = "stand-in; bind to structure.reach_a" },
        { name = "reach_b", nominal = 10, unit = "mm", minus = 0.05, plus = 0.05, from = "stand-in; bind to structure.reach_b" },
        { name = "expansion_a", nominal = 10e-6, unit = "per-C", minus = 0, plus = 0, from = "stand-in; bind to a.expansion" },
        { name = "expansion_b", nominal = 10e-6, unit = "per-C", minus = 0, plus = 0, from = "stand-in; bind to b.expansion" },
        { name = "temperature", nominal = 30, unit = "C", minus = 15, plus = 15, condition = true, from = "docs/sizes.md: wearing temperature 15-45" },
        { name = "assembly_temperature", nominal = 20, unit = "C", minus = 2, plus = 2, condition = true, from = "guess: a room" },
    },
    outputs = {
        { name = "gap_when_warm", unit = "mm", at_least = 0 },
    },
    compute = function(v)
        local warmed = v.temperature - v.assembly_temperature
        return { gap_when_warm = v.gap - (v.reach_a * v.expansion_a + v.reach_b * v.expansion_b) / 2 * warmed }
    end,
}
