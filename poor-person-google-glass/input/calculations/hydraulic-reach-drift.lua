-- hydraulic-reach-drift.lua - does the panel arm creep as it warms?
-- Written by Claude (Opus 5.5), 2026-10-10, for issue 009; the panel arm of
-- issue 302 (hydraulic pistons push it forward and back).
--
-- The arm's oil is sealed in. Warmed, oil grows about ten times more than
-- its aluminium housing, so a free piston is pushed out (the arm reaches
-- further); a locked piston cannot move and the pressure rises instead.
return {
    question = "How far does the hydraulic arm creep, or how hard does it push if locked, as it warms?",
    inputs = {
        { name = "piston_bore", nominal = 3.0, unit = "mm", minus = 0.01, plus = 0.01, from = "guess: smallest practical piston" },
        { name = "oil_volume", nominal = 200, unit = "mm3", minus = 20, plus = 20, from = "guess: cylinder and line, 0.2 millilitres" },
        { name = "oil_expansion", nominal = 7e-4, unit = "per-C", minus = 0.5e-4, plus = 0.5e-4, from = "docs/sizes.md: hydraulic mineral oil (volume)" },
        { name = "housing_expansion", nominal = 69e-6, unit = "per-C", minus = 5e-6, plus = 5e-6, from = "aluminium: 3 x 23e-6 (volume from length)" },
        { name = "oil_stiffness", nominal = 1.5, unit = "GPa", minus = 0.1, plus = 0.5, from = "docs/sizes.md: bulk modulus 1.4-2.0" },
        { name = "temperature", nominal = 30, unit = "C", minus = 15, plus = 15, condition = true, from = "docs/sizes.md: wearing temperature 15-45" },
        { name = "filled_at", nominal = 22, unit = "C", minus = 3, plus = 3, condition = true, from = "guess: filled in a room" },
    },
    outputs = {
        -- signed: warmer than filled pushes out (positive), colder pulls in
        { name = "reach_creep", unit = "mm", at_least = -0.5, at_most = 0.5 },
        { name = "pressure_if_locked", unit = "MPa", at_least = -10, at_most = 10 },
    },
    compute = function(v)
        local warmed = v.temperature - v.filled_at
        local grown = v.oil_volume * (v.oil_expansion - v.housing_expansion) * warmed     -- mm3
        local area = math.pi * v.piston_bore ^ 2 / 4                                        -- mm2
        -- locked: pressure = stiffness x squeezed share of volume; GPa to MPa
        local pressure = v.oil_stiffness * 1000 * (v.oil_expansion - v.housing_expansion) * warmed
        return { reach_creep = grown / area, pressure_if_locked = pressure }
    end,
}
