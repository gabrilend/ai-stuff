-- made by src/022-calculate.lua on 2026-10-11 00:18 from input/calculations/bend-light-hold.lua: every answer of the calculation (format: src/021-the-tolerance-report.lua)
return {
    inputs = {
        {
            condition = false,
            from = "the owner: as wide as a thick glasses arm (5-6 mm)",
            minus = 0.10000000000000001,
            name = "pipe_width",
            nominal = 5,
            plus = 0.10000000000000001,
            unit = "mm",
        },
        {
            condition = true,
            from = "issue 105 model; heads differ (docs/sizes.md: 520-620 mm around)",
            minus = 10,
            name = "bend_radius",
            nominal = 90,
            plus = 10,
            unit = "mm",
        },
        {
            condition = false,
            from = "datasheet: PMMA, the usual core of side-emitting fibre",
            minus = 0.001,
            name = "core_index",
            nominal = 1.492,
            plus = 0.001,
            unit = "ratio",
        },
        {
            condition = false,
            from = "datasheet: fluorinated polymer cladding of plastic fibre",
            minus = 0.01,
            name = "cladding_index",
            nominal = 1.3999999999999999,
            plus = 0.01,
            unit = "ratio",
        },
    },
    made = "2026-10-11 00:18",
    name = "bend-light-hold",
    question = "Around the bend of the band, does total internal reflection alone keep the light in, and how much is left to the mirror coating?",
    results = {
        {
            at_least = 0,
            name = "trapping_margin",
            nominal = 0.0076081443373668955,
            shares = {
                {
                    input = "cladding_index",
                    percent = 50.274117477479557,
                },
                {
                    input = "bend_radius",
                    percent = 48.043069617059771,
                },
                {
                    input = "pipe_width",
                    percent = 1.2395664818897769,
                },
                {
                    input = "core_index",
                    percent = 0.44324642357089183,
                },
            },
            spread = {
                centre = 0.0076081443373668955,
                high = 0.017060911247816175,
                low = -0.001844622573082386,
            },
            spread_verdict = "fail",
            unit = "ratio",
            worst = {
                high = 0.02116040464742408,
                low = -0.0074547832116866886,
            },
            worst_verdict = "fail",
        },
        {
            name = "share_left_to_the_mirror",
            nominal = 0,
            shares = {
                {
                    input = "bend_radius",
                    percent = 0,
                },
                {
                    input = "cladding_index",
                    percent = 0,
                },
                {
                    input = "core_index",
                    percent = 0,
                },
                {
                    input = "pipe_width",
                    percent = 0,
                },
            },
            spread = {
                centre = 0,
                high = 0,
                low = 0,
            },
            spread_verdict = "no limit",
            unit = "percent",
            worst = {
                high = 12.066516747543856,
                low = 0,
            },
            worst_verdict = "no limit",
        },
        {
            name = "acceptance_half_angle",
            nominal = 31.051874057810245,
            shares = {
                {
                    input = "cladding_index",
                    percent = 98.920760975089337,
                },
                {
                    input = "core_index",
                    percent = 1.0792390249106649,
                },
                {
                    input = "bend_radius",
                    percent = 0,
                },
                {
                    input = "pipe_width",
                    percent = 0,
                },
            },
            spread = {
                centre = 31.051874057810245,
                high = 32.916734433194307,
                low = 29.187013682426187,
            },
            spread_verdict = "no limit",
            unit = "deg",
            worst = {
                high = 33.019898709267132,
                low = 28.99598881479255,
            },
            worst_verdict = "no limit",
        },
        {
            name = "tightest_bend_trapped",
            nominal = 78.586956521739069,
            shares = {
                {
                    input = "cladding_index",
                    percent = 96.860518443470269,
                },
                {
                    input = "pipe_width",
                    percent = 2.4469969329264307,
                },
                {
                    input = "core_index",
                    percent = 0.69248462360329177,
                },
                {
                    input = "bend_radius",
                    percent = 0,
                },
            },
            spread = {
                centre = 78.586956521739069,
                high = 88.634589278217604,
                low = 68.539323765260534,
            },
            spread_verdict = "no limit",
            unit = "mm",
            worst = {
                high = 91.327777777777527,
                low = 68.576213592232989,
            },
            worst_verdict = "no limit",
        },
    },
}
