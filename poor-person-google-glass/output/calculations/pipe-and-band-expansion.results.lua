-- made by src/022-calculate.lua on 2026-10-10 23:19 from input/calculations/pipe-and-band-expansion.lua: every answer of the calculation (format: src/021-the-tolerance-report.lua)
return {
  inputs = {
    {
      condition = false,
      from = "issue 105 model: 90 mm radius x 2.25 radians",
      minus = 1,
      name = "pipe_length",
      nominal = 200,
      plus = 1,
      unit = "mm",
    },
    {
      condition = false,
      from = "docs/sizes.md: borosilicate",
      minus = 9.9999999999999995e-08,
      name = "glass_expansion",
      nominal = 3.3000000000000002e-06,
      plus = 9.9999999999999995e-08,
      unit = "per-C",
    },
    {
      condition = false,
      from = "docs/sizes.md: nylon PA12",
      minus = 2.0000000000000002e-05,
      name = "band_expansion",
      nominal = 0.0001,
      plus = 2.0000000000000002e-05,
      unit = "per-C",
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
      from = "guess: a room",
      minus = 2,
      name = "assembly_temperature",
      nominal = 20,
      plus = 2,
      unit = "C",
    },
  },
  made = "2026-10-10 23:19",
  name = "pipe-and-band-expansion",
  question = "How much do the glass light pipe and the nylon band holding it change length differently?",
  results = {
    {
      at_least = -0.10000000000000001,
      at_most = 0.10000000000000001,
      name = "length_difference",
      nominal = 0.19340000000000002,
      shares = {
        {
          input = "temperature",
          percent = 96.450503737570671,
        },
        {
          input = "band_expansion",
          percent = 1.8337031255861815,
        },
        {
          input = "assembly_temperature",
          percent = 1.7146756220012576,
        },
        {
          input = "pipe_length",
          percent = 0.0010716722637507752,
        },
        {
          input = "glass_expansion",
          percent = 4.5842578139657139e-05,
        },
      },
      spread = {
        centre = 0.19340000000000002,
        high = 0.48878978907369164,
        low = -0.10198978907369161,
      },
      spread_verdict = "fail",
      unit = "mm",
      worst = {
        high = 0.63387360000000004,
        low = -0.1643376,
      },
      worst_verdict = "fail",
    },
    {
      at_least = -0.00050000000000000001,
      at_most = 0.00050000000000000001,
      name = "strain_if_glued",
      nominal = 0.00096700000000000009,
      shares = {
        {
          input = "temperature",
          percent = 96.45153738194476,
        },
        {
          input = "band_expansion",
          percent = 1.8337227770845765,
        },
        {
          input = "assembly_temperature",
          percent = 1.7146939979012403,
        },
        {
          input = "glass_expansion",
          percent = 4.5843069427116645e-05,
        },
        {
          input = "pipe_length",
          percent = 0,
        },
      },
      spread = {
        centre = 0.00096700000000000009,
        high = 0.0024439410313211564,
        low = -0.00050994103132115615,
      },
      spread_verdict = "fail",
      unit = "ratio",
      worst = {
        high = 0.0031536000000000003,
        low = -0.00081760000000000003,
      },
      worst_verdict = "fail",
    },
  },
}
