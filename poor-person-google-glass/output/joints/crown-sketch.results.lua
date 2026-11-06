-- made by src/028-joints.lua on 2026-10-10 23:29 from input/joints/crown-sketch.lua: the answers of every filled joint (format: docs/joints.md)
return {
    joints = {
        {
            a = "band",
            b = "light pipes",
            equation = "joint-gap-under-heat",
            inputs = {
                {
                    from = "stand-in; bind to structure.gap. Tolerance a guess: +/-0.02 mm",
                    minus = 0.02,
                    name = "gap",
                    nominal = 0.00065266499999999997,
                    plus = 0.02,
                    unit = "mm",
                },
                {
                    from = "stand-in; bind to structure.reach_a",
                    minus = 0.050000000000000003,
                    name = "reach_a",
                    nominal = 201.339,
                    plus = 0.050000000000000003,
                    unit = "mm",
                },
                {
                    from = "stand-in; bind to structure.reach_b",
                    minus = 0.050000000000000003,
                    name = "reach_b",
                    nominal = 197.62100000000001,
                    plus = 0.050000000000000003,
                    unit = "mm",
                },
                {
                    from = "nylon-pa12.expansion (input/materials.lua): docs/sizes.md",
                    minus = 2.0000000000000002e-05,
                    name = "expansion_a",
                    nominal = 0.0001,
                    plus = 2.0000000000000002e-05,
                    unit = "per-C",
                },
                {
                    from = "borosilicate.expansion (input/materials.lua): docs/sizes.md",
                    minus = 9.9999999999999995e-08,
                    name = "expansion_b",
                    nominal = 3.3000000000000002e-06,
                    plus = 9.9999999999999995e-08,
                    unit = "per-C",
                },
                {
                    from = "docs/sizes.md: wearing temperature 15-45",
                    minus = 15,
                    name = "temperature",
                    nominal = 30,
                    plus = 15,
                    unit = "C",
                },
                {
                    from = "guess: a room",
                    minus = 2,
                    name = "assembly_temperature",
                    nominal = 20,
                    plus = 2,
                    unit = "C",
                },
            },
            question = "Does the gap between these two parts stay open from cold to warm?",
            results = {
                {
                    at_least = 0,
                    name = "gap_when_warm",
                    nominal = -0.10327758150000001,
                    shares = {
                        {
                            input = "temperature",
                            percent = 95.155031727765703,
                        },
                        {
                            input = "assembly_temperature",
                            percent = 1.6916450084936141,
                        },
                        {
                            input = "expansion_a",
                            percent = 1.5871615727787352,
                        },
                        {
                            input = "gap",
                            percent = 1.5661210141183215,
                        },
                        {
                            input = "expansion_b",
                            percent = 3.8227114681503638e-05,
                        },
                        {
                            input = "reach_a",
                            percent = 2.4470640845620538e-06,
                        },
                        {
                            input = "reach_b",
                            percent = 2.6648527881493097e-09,
                        },
                    },
                    spread = {
                        centre = -0.10327758150000001,
                        high = 0.056537344190302111,
                        low = -0.26309250719030214,
                    },
                    spread_verdict = "fail",
                    unit = "mm",
                    worst = {
                        high = 0.10758832990000002,
                        low = -0.35467061390000004,
                    },
                    worst_verdict = "fail",
                },
            },
            signature = "{\
    \"joint-gap-under-heat\",\
    {\
        expansion_a = \"a.expansion\",\
        expansion_b = \"b.expansion\",\
        gap = \"structure.gap\",\
        reach_a = \"structure.reach_a\",\
        reach_b = \"structure.reach_b\",\
    },\
    \"nylon-pa12\",\
    \"borosilicate\",\
    0.00065266499999999997,\
    201.339,\
    197.62100000000001,\
    172.54499999999999,\
    1,\
}",
            verdict = "fail",
        },
        {
            a = "panel arm",
            b = "panel",
            equation = "joint-gap-under-heat",
            inputs = {
                {
                    from = "stand-in; bind to structure.gap. Tolerance a guess: +/-0.02 mm",
                    minus = 0.02,
                    name = "gap",
                    nominal = 0.054559900000000001,
                    plus = 0.02,
                    unit = "mm",
                },
                {
                    from = "stand-in; bind to structure.reach_a",
                    minus = 0.050000000000000003,
                    name = "reach_a",
                    nominal = 48.201500000000003,
                    plus = 0.050000000000000003,
                    unit = "mm",
                },
                {
                    from = "stand-in; bind to structure.reach_b",
                    minus = 0.050000000000000003,
                    name = "reach_b",
                    nominal = 7.3891099999999996,
                    plus = 0.050000000000000003,
                    unit = "mm",
                },
                {
                    from = "aluminium-6061.expansion (input/materials.lua): datasheet",
                    minus = 4.9999999999999998e-07,
                    name = "expansion_a",
                    nominal = 2.3600000000000001e-05,
                    plus = 4.9999999999999998e-07,
                    unit = "per-C",
                },
                {
                    from = "n-bk7.expansion (input/materials.lua): docs/sizes.md",
                    minus = 9.9999999999999995e-08,
                    name = "expansion_b",
                    nominal = 7.0999999999999998e-06,
                    plus = 9.9999999999999995e-08,
                    unit = "per-C",
                },
                {
                    from = "docs/sizes.md: wearing temperature 15-45",
                    minus = 15,
                    name = "temperature",
                    nominal = 30,
                    plus = 15,
                    unit = "C",
                },
                {
                    from = "guess: a room",
                    minus = 2,
                    name = "assembly_temperature",
                    nominal = 20,
                    plus = 2,
                    unit = "C",
                },
            },
            question = "Does the gap between these two parts stay open from cold to warm?",
            results = {
                {
                    at_least = 0,
                    name = "gap_when_warm",
                    nominal = 0.048609809594999998,
                    shares = {
                        {
                            input = "gap",
                            percent = 83.144740032603835,
                        },
                        {
                            input = "temperature",
                            percent = 16.557868734842554,
                        },
                        {
                            input = "assembly_temperature",
                            percent = 0.29436211084164843,
                        },
                        {
                            input = "expansion_a",
                            percent = 0.0030183938867161357,
                        },
                        {
                            input = "reach_a",
                            percent = 7.2356710013450094e-06,
                        },
                        {
                            input = "expansion_b",
                            percent = 2.8372595127881883e-06,
                        },
                        {
                            input = "reach_b",
                            percent = 6.5489474141487775e-07,
                        },
                    },
                    spread = {
                        centre = 0.048609809594999998,
                        high = 0.070543545287067994,
                        low = 0.026676073902932008,
                    },
                    spread_verdict = "pass",
                    unit = "mm",
                    worst = {
                        high = 0.078817379596999998,
                        low = 0.018138192983000005,
                    },
                    worst_verdict = "pass",
                },
            },
            signature = "{\
    \"joint-gap-under-heat\",\
    {\
        expansion_a = \"a.expansion\",\
        expansion_b = \"b.expansion\",\
        gap = \"structure.gap\",\
        reach_a = \"structure.reach_a\",\
        reach_b = \"structure.reach_b\",\
    },\
    \"aluminium-6061\",\
    \"n-bk7\",\
    0.054559900000000001,\
    48.201500000000003,\
    7.3891099999999996,\
    6,\
    1,\
}",
            verdict = "pass",
        },
    },
    made = "2026-10-10 23:29",
    model = "crown-sketch",
}
