-- made by src/022-calculate.lua on 2026-10-10 23:19 from input/calculations/index-match-drift.lua: every answer of the calculation (format: src/021-the-tolerance-report.lua)
return {
  inputs = {
    {
      condition = false,
      from = "docs/sizes.md: N-BK7 at 587.6 nm; catalogue tolerance",
      minus = 0.00050000000000000001,
      name = "glass_index",
      nominal = 1.5167999999999999,
      plus = 0.00050000000000000001,
      unit = "ratio",
    },
    {
      condition = false,
      from = "guess: matching liquid's labelled tolerance",
      minus = 0.00020000000000000001,
      name = "liquid_index",
      nominal = 1.5167999999999999,
      plus = 0.00020000000000000001,
      unit = "ratio",
    },
    {
      condition = false,
      from = "docs/sizes.md: matching liquids",
      minus = 3.0000000000000001e-05,
      name = "liquid_index_per_C",
      nominal = -0.00036999999999999999,
      plus = 3.0000000000000001e-05,
      unit = "per-C",
    },
    {
      condition = false,
      from = "docs/sizes.md: N-BK7",
      minus = 9.9999999999999995e-07,
      name = "glass_index_per_C",
      nominal = 1.9999999999999999e-06,
      plus = 9.9999999999999995e-07,
      unit = "per-C",
    },
    {
      condition = false,
      from = "guess: liquid and glass disperse differently at red and green",
      minus = 0.00050000000000000001,
      name = "colour_mismatch",
      nominal = 0.00050000000000000001,
      plus = 0.00050000000000000001,
      unit = "ratio",
    },
    {
      condition = true,
      from = "docs/sizes.md: wearing temperature 15-45",
      minus = 15,
      name = "temperature",
      nominal = 30,
      plus = 15,
      unit = "C",
    },
    {
      condition = true,
      from = "datasheets quote indices at 25 C",
      minus = 0,
      name = "matched_at",
      nominal = 25,
      plus = 0,
      unit = "C",
    },
    {
      condition = false,
      from = "issue 105 model: 6 tabs, 2 faces each",
      minus = 0,
      name = "boundaries",
      nominal = 12,
      plus = 0,
      unit = "count",
    },
    {
      condition = false,
      from = "issue 105 model: tabs swing 0-80 degrees",
      minus = 40,
      name = "tab_face_angle",
      nominal = 40,
      plus = 40,
      unit = "deg",
    },
    {
      condition = false,
      from = "as in tab-channel-clearance",
      minus = 0.014999999999999999,
      name = "tab_thickness",
      nominal = 0.29999999999999999,
      plus = 0.014999999999999999,
      unit = "mm",
    },
  },
  made = "2026-10-10 23:19",
  name = "index-match-drift",
  question = "How much light is lost and how far is the picture shifted as the filling's index drifts with temperature?",
  results = {
    {
      name = "index_difference",
      nominal = -0.0013599999999999728,
      shares = {
        {
          input = "temperature",
          percent = 98.225413006908155,
        },
        {
          input = "colour_mismatch",
          percent = 0.78867027825072256,
        },
        {
          input = "glass_index",
          percent = 0.78867027825054892,
        },
        {
          input = "liquid_index",
          percent = 0.12618724452008784,
        },
        {
          input = "liquid_index_per_C",
          percent = 0.070980325042654474,
        },
        {
          input = "glass_index_per_C",
          percent = 7.8867027826105612e-05,
        },
        {
          input = "boundaries",
          percent = 0,
        },
        {
          input = "matched_at",
          percent = 0,
        },
        {
          input = "tab_face_angle",
          percent = 0,
        },
        {
          input = "tab_thickness",
          percent = 0,
        },
      },
      spread = {
        centre = -0.0013599999999999728,
        high = 0.0042701798372700179,
        low = -0.0069901798372699626,
      },
      spread_verdict = "no limit",
      unit = "ratio",
      worst = {
        high = 0.005729999999999901,
        low = -0.008759999999999879,
      },
      worst_verdict = "no limit",
    },
    {
      at_most = 1,
      name = "light_lost",
      nominal = 0.00024118036685560895,
      shares = {
        {
          input = "temperature",
          percent = 99.734607456009357,
        },
        {
          input = "colour_mismatch",
          percent = 0.12053030573143167,
        },
        {
          input = "glass_index",
          percent = 0.12035965581042936,
        },
        {
          input = "liquid_index",
          percent = 0.015876249149437107,
        },
        {
          input = "liquid_index_per_C",
          percent = 0.0086177011625002634,
        },
        {
          input = "glass_index_per_C",
          percent = 8.6321368445388097e-06,
        },
        {
          input = "boundaries",
          percent = 0,
        },
        {
          input = "matched_at",
          percent = 0,
        },
        {
          input = "tab_face_angle",
          percent = 0,
        },
        {
          input = "tab_thickness",
          percent = 0,
        },
      },
      spread = {
        centre = 0.00024118036685560895,
        high = 0.0062881944984906173,
        low = -0.0058058337647793994,
      },
      spread_verdict = "pass",
      unit = "percent",
      worst = {
        high = 0.010003846536232874,
        low = 0.00024118036685560895,
      },
      worst_verdict = "pass",
    },
    {
      at_least = -0.050000000000000003,
      at_most = 0.050000000000000003,
      name = "shift_through_a_tab",
      nominal = -0.00029463979707677272,
      shares = {
        {
          input = "tab_face_angle",
          percent = 97.9775234284931,
        },
        {
          input = "temperature",
          percent = 1.9863025220356996,
        },
        {
          input = "colour_mismatch",
          percent = 0.01594839578464112,
        },
        {
          input = "glass_index",
          percent = 0.015939353104921804,
        },
        {
          input = "liquid_index",
          percent = 0.0025543685930167702,
        },
        {
          input = "liquid_index_per_C",
          percent = 0.0014353556206195112,
        },
        {
          input = "tab_thickness",
          percent = 0.00029498152843271223,
        },
        {
          input = "glass_index_per_C",
          percent = 1.5948395784852416e-06,
        },
        {
          input = "boundaries",
          percent = 0,
        },
        {
          input = "matched_at",
          percent = 0,
        },
      },
      spread = {
        centre = -0.00029463979707677272,
        high = 0.0082829248574611686,
        low = -0.0088722044516147125,
      },
      spread_verdict = "pass",
      unit = "mm",
      worst = {
        high = 0.038867875707071627,
        low = -0.05940929416549387,
      },
      worst_verdict = "fail",
    },
  },
}
