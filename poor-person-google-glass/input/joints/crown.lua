-- crown.lua - joint records for the model crown (format: docs/joints.md).
-- Made and refreshed by ./joints find, which never changes what a person wrote:
-- each part's material, and each joint's equation, inputs and note.
-- Write notes in a joint's `note`, not as comments: this file is rewritten.
--
-- To fill a joint: equation = "NAME" (a calculation in input/calculations/),
-- inputs = { INPUT = "structure.MEASURE" or "a.PROPERTY" or "b.PROPERTY" or a number }.
--   structure measures (in mm): gap, reach_a, reach_b, contact_size
--   materials (input/materials.lua): aluminium-6061, borosilicate, index-matching-liquid, n-bk7, nylon-pa12, stainless-304
-- An empty spot is "" (an equation) or "unassigned" (a material) or -1 (millimetres_per_unit).
return {
    contact_distance = 0.0081250000000000003,
    joints = {
        {
            a = "band",
            b = "emitter",
            equation = "",
            found = {
                contact_point = {
                    -9.1027100000000002e-17,
                    -1.0570999999999999e-18,
                    -0.5,
                },
                contact_size = 0.057402500000000002,
                gap = 2.6774799999999999e-18,
                normal = {
                    0,
                    0,
                    -1,
                },
                reach_a = 1,
                reach_b = 0.10000000000000001,
                still_found = true,
            },
            inputs = {},
            note = "",
        },
        {
            a = "band",
            b = "light pipe",
            equation = "",
            found = {
                contact_point = {
                    1.4542699999999999e-17,
                    0.074999999999999997,
                    0.42499999999999999,
                },
                contact_size = 0.90740299999999996,
                gap = 2.2962099999999999e-17,
                normal = {
                    0.065403100000000006,
                    0.99785900000000005,
                    0,
                },
                reach_a = 0.20527200000000001,
                reach_b = 0.099785899999999997,
                still_found = true,
            },
            inputs = {},
            note = "",
        },
        {
            a = "band",
            b = "glasses arm",
            equation = "",
            found = {
                contact_point = {
                    0.5,
                    -1.81837e-17,
                    0,
                },
                contact_size = 0.130526,
                gap = 3.7194699999999999e-19,
                normal = {
                    0.99785900000000005,
                    0.065403100000000006,
                    0,
                },
                reach_a = 0.99785900000000005,
                reach_b = 0.049893,
                still_found = true,
            },
            inputs = {},
            note = "",
        },
        {
            a = "glasses arm",
            b = "panel arm",
            equation = "",
            found = {
                contact_point = {
                    0.549786,
                    -0.0032631499999999998,
                    0.5,
                },
                contact_size = 0.050000000000000003,
                gap = 0,
                normal = {
                    0.99785900000000005,
                    -0.065403100000000006,
                    0,
                },
                reach_a = 0.049893,
                reach_b = 0.049893,
                still_found = true,
            },
            inputs = {},
            note = "",
        },
        {
            a = "panel arm",
            b = "panel",
            equation = "",
            found = {
                contact_point = {
                    0.549786,
                    -0.0032631499999999998,
                    1,
                },
                contact_size = 0.050000000000000003,
                gap = 0,
                normal = {
                    0,
                    0,
                    1,
                },
                reach_a = 0.5,
                reach_b = 0.025000000000000001,
                still_found = true,
            },
            inputs = {},
            note = "",
        },
    },
    materials = {
        band = "unassigned",
        emitter = "unassigned",
        ["glasses arm"] = "unassigned",
        ["light pipe"] = "unassigned",
        panel = "unassigned",
        ["panel arm"] = "unassigned",
    },
    millimetres_per_unit = -1,
    model = "crown",
}
