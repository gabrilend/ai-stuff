-- materials.lua - each material's fundamentals, for joint records (issue
-- 010; format in docs/joints.md). Written by Claude (Opus 5.5), 2026-10-10,
-- from docs/sizes.md. Every value is { value, minus, plus, unit, from },
-- the same shape as a calculation's inputs, so a material's tolerance
-- travels with it into the calculations.
local function value(v, minus, plus, unit, from) return { value = v, minus = minus, plus = plus, unit = unit, from = from } end
return {
    ["borosilicate"] = {
        expansion = value(3.3e-6, 0.1e-6, 0.1e-6, "per-C", "docs/sizes.md"),
        density = value(2.23, 0.02, 0.02, "g-per-cm3", "datasheet"),
        stiffness = value(64, 2, 2, "GPa", "datasheet: Young's modulus"),
        index = value(1.473, 0.001, 0.001, "ratio", "datasheet at 587.6 nm"),
    },
    ["n-bk7"] = {
        expansion = value(7.1e-6, 0.1e-6, 0.1e-6, "per-C", "docs/sizes.md"),
        density = value(2.51, 0.01, 0.01, "g-per-cm3", "datasheet"),
        stiffness = value(82, 1, 1, "GPa", "datasheet: Young's modulus"),
        index = value(1.5168, 0.0005, 0.0005, "ratio", "docs/sizes.md"),
    },
    ["stainless-304"] = {
        expansion = value(17.3e-6, 0.5e-6, 0.5e-6, "per-C", "docs/sizes.md"),
        density = value(8.0, 0.05, 0.05, "g-per-cm3", "datasheet"),
        stiffness = value(193, 5, 5, "GPa", "datasheet: Young's modulus"),
    },
    ["aluminium-6061"] = {
        expansion = value(23.6e-6, 0.5e-6, 0.5e-6, "per-C", "datasheet"),
        density = value(2.70, 0.01, 0.01, "g-per-cm3", "datasheet"),
        stiffness = value(69, 2, 2, "GPa", "datasheet: Young's modulus"),
    },
    ["nylon-pa12"] = {
        expansion = value(100e-6, 20e-6, 20e-6, "per-C", "docs/sizes.md"),
        density = value(1.01, 0.02, 0.02, "g-per-cm3", "datasheet"),
        stiffness = value(1.5, 0.3, 0.3, "GPa", "datasheet: Young's modulus, varies with moisture"),
    },
    ["index-matching-liquid"] = {
        expansion = value(7e-4, 1e-4, 1e-4, "per-C", "guess: volume expansion, like other oils"),
        density = value(1.2, 0.2, 0.2, "g-per-cm3", "guess"),
        index = value(1.5168, 0.0002, 0.0002, "ratio", "matched to n-bk7; makers' tolerance"),
    },
}
