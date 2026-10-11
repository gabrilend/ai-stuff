-- made by src/022-calculate.lua on 2026-10-10 23:19 from input/calculations/eye-position-fit.lua: every answer of the calculation (format: src/021-the-tolerance-report.lua)
return {
  inputs = {
    {
      condition = false,
      from = "docs/sizes.md: typical 63; frame made to +/-0.3",
      minus = 0.29999999999999999,
      name = "frame_eye_distance",
      nominal = 63,
      plus = 0.29999999999999999,
      unit = "mm",
    },
    {
      condition = true,
      from = "docs/sizes.md: adults 54-74",
      minus = 9,
      name = "wearer_eye_distance",
      nominal = 63,
      plus = 11,
      unit = "mm",
    },
    {
      condition = false,
      from = "docs/sizes.md: typical lens width",
      minus = 0.20000000000000001,
      name = "lens_width",
      nominal = 52,
      plus = 0.20000000000000001,
      unit = "mm",
    },
    {
      condition = false,
      from = "issue 304 open question 2: guess 4 by 4",
      minus = 0,
      name = "tiles_across",
      nominal = 4,
      plus = 0,
      unit = "count",
    },
  },
  made = "2026-10-10 23:19",
  name = "eye-position-fit",
  question = "On how wide a range of eye spacings does one frame keep each pupil behind its middle tile?",
  results = {
    {
      name = "offset_per_eye",
      nominal = 0,
      shares = {
        {
          input = "wearer_eye_distance",
          percent = 99.910080927165552,
        },
        {
          input = "frame_eye_distance",
          percent = 0.089919072834447292,
        },
        {
          input = "lens_width",
          percent = 0,
        },
        {
          input = "tiles_across",
          percent = 0,
        },
      },
      spread = {
        centre = 0.5,
        high = 5.5022494939776845,
        low = -4.5022494939776845,
      },
      spread_verdict = "no limit",
      unit = "mm",
      worst = {
        high = 5.6499999999999986,
        low = -4.6499999999999986,
      },
      worst_verdict = "no limit",
    },
    {
      at_least = -0.5,
      at_most = 0.5,
      name = "offset_in_tiles",
      nominal = 0,
      shares = {
        {
          input = "wearer_eye_distance",
          percent = 99.910066046614006,
        },
        {
          input = "frame_eye_distance",
          percent = 0.089919059441950944,
        },
        {
          input = "lens_width",
          percent = 1.4893944044753364e-05,
        },
        {
          input = "tiles_across",
          percent = 0,
        },
      },
      spread = {
        centre = 0.038461538461538464,
        high = 0.42324998973029582,
        low = -0.34632691280721895,
      },
      spread_verdict = "pass",
      unit = "ratio",
      worst = {
        high = 0.4362934362934362,
        low = -0.35907335907335897,
      },
      worst_verdict = "pass",
    },
  },
}
