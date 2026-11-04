-- crown-sketch.lua - joint records for the model crown-sketch (format: docs/joints.md).
-- Made and refreshed by ./joints find, which never changes what a person wrote:
-- each part's material, and each joint's equation, inputs and note.
-- Write notes in a joint's `note`, not as comments: this file is rewritten.
--
-- To fill a joint: equation = "NAME" (a calculation in input/calculations/),
-- inputs = { INPUT = "structure.MEASURE" or "a.PROPERTY" or "b.PROPERTY" or a number }.
--   structure measures (in mm): gap, reach_a, reach_b, contact_size
--   materials (input/materials.lua): (see input/materials.lua)
-- An empty spot is "" (an equation) or "unassigned" (a material) or -1 (millimetres_per_unit).
return {
    contact_distance = 1.5,
    joints = {
        {
            a = "band",
            b = "emitters",
            equation = "",
            found = {
                contact_point = {
                    -69.285499999999999,
                    1,
                    62.6297,
                },
                contact_size = 126.309,
                gap = 0.023863800000000001,
                normal = {
                    -0.60330600000000001,
                    0,
                    0.79751000000000005,
                },
                reach_a = 183.47200000000001,
                reach_b = 109.426,
                still_found = true,
            },
            inputs = {},
            note = "",
        },
        {
            a = "band",
            b = "light pipes",
            equation = "joint-gap-under-heat",
            found = {
                contact_point = {
                    96.091099999999997,
                    9,
                    32.129800000000003,
                },
                contact_size = 172.54499999999999,
                gap = 0.00065266499999999997,
                normal = {
                    0.90641899999999997,
                    0,
                    0.422379,
                },
                reach_a = 201.339,
                reach_b = 197.62100000000001,
                still_found = true,
            },
            inputs = {
                expansion_a = "a.expansion",
                expansion_b = "b.expansion",
                gap = "structure.gap",
                reach_a = "structure.reach_a",
                reach_b = "structure.reach_b",
            },
            note = "example filled by Claude, 2026-10-10: the general gap calculation, bound to the joint's measures and materials",
        },
        {
            a = "band",
            b = "dials",
            equation = "",
            found = {
                contact_point = {
                    46.107700000000001,
                    12,
                    73.169300000000007,
                },
                contact_size = 159.96899999999999,
                gap = 0,
                normal = {
                    0,
                    -1,
                    0,
                },
                reach_a = 12,
                reach_b = 28,
                still_found = true,
            },
            inputs = {},
            note = "",
        },
        {
            a = "band",
            b = "panel arm",
            equation = "",
            found = {
                contact_point = {
                    104,
                    0,
                    0,
                },
                contact_size = 6,
                gap = 0,
                normal = {
                    1,
                    0,
                    0,
                },
                reach_a = 208,
                reach_b = 48,
                still_found = true,
            },
            inputs = {},
            note = "",
        },
        {
            a = "emitters",
            b = "light pipes",
            equation = "",
            found = {
                contact_point = {
                    -69.292699999999996,
                    3,
                    62.639200000000002,
                },
                contact_size = 131.244,
                gap = 0,
                normal = {
                    0.61087999999999998,
                    0,
                    -0.79172399999999998,
                },
                reach_a = 108.63200000000001,
                reach_b = 191.852,
                still_found = true,
            },
            inputs = {},
            note = "",
        },
        {
            a = "light pipes",
            b = "dials",
            equation = "",
            found = {
                contact_point = {
                    52.010100000000001,
                    8.9682499999999994,
                    72.75,
                },
                contact_size = 168.489,
                gap = 0.13986699999999999,
                normal = {
                    -0.75382099999999996,
                    -0.45399099999999998,
                    0.47502100000000003,
                },
                reach_a = 179.62299999999999,
                reach_b = 144.928,
                still_found = true,
            },
            inputs = {},
            note = "",
        },
        {
            a = "panel arm",
            b = "panel",
            equation = "joint-gap-under-heat",
            found = {
                contact_point = {
                    151.97300000000001,
                    -58,
                    2.99891,
                },
                contact_size = 6,
                gap = 0.054559900000000001,
                normal = {
                    -0.99919999999999998,
                    0,
                    -0.039987099999999998,
                },
                reach_a = 48.201500000000003,
                reach_b = 7.3891099999999996,
                still_found = true,
            },
            inputs = {
                expansion_a = "a.expansion",
                expansion_b = "b.expansion",
                gap = "structure.gap",
                reach_a = "structure.reach_a",
                reach_b = "structure.reach_b",
            },
            note = "example filled by Claude, 2026-10-10: the general gap calculation, bound to the joint's measures and materials",
        },
    },
    materials = {
        band = "nylon-pa12",
        dials = "aluminium-6061",
        emitters = "aluminium-6061",
        ["light pipes"] = "borosilicate",
        panel = "n-bk7",
        ["panel arm"] = "aluminium-6061",
    },
    millimetres_per_unit = 1,
    model = "crown-sketch",
}
