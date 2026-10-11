-- made by src/022-calculate.lua on 2026-10-10 23:19 from input/calculations/hydraulic-reach-drift.lua: every answer of the calculation (format: src/021-the-tolerance-report.lua)
return {
  inputs = {
    {
      condition = false,
      from = "guess: smallest practical piston",
      minus = 0.01,
      name = "piston_bore",
      nominal = 3,
      plus = 0.01,
      unit = "mm",
    },
    {
      condition = false,
      from = "guess: cylinder and line, 0.2 millilitres",
      minus = 20,
      name = "oil_volume",
      nominal = 200,
      plus = 20,
      unit = "mm3",
    },
    {
      condition = false,
      from = "docs/sizes.md: hydraulic mineral oil (volume)",
      minus = 5.0000000000000002e-05,
      name = "oil_expansion",
      nominal = 0.00069999999999999999,
      plus = 5.0000000000000002e-05,
      unit = "per-C",
    },
    {
      condition = false,
      from = "aluminium: 3 x 23e-6 (volume from length)",
      minus = 5.0000000000000004e-06,
      name = "housing_expansion",
      nominal = 6.8999999999999997e-05,
      plus = 5.0000000000000004e-06,
      unit = "per-C",
    },
    {
      condition = false,
      from = "docs/sizes.md: bulk modulus 1.4-2.0",
      minus = 0.10000000000000001,
      name = "oil_stiffness",
      nominal = 1.5,
      plus = 0.5,
      unit = "GPa",
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
      from = "guess: filled in a room",
      minus = 3,
      name = "filled_at",
      nominal = 22,
      plus = 3,
      unit = "C",
    },
  },
  made = "2026-10-10 23:19",
  name = "hydraulic-reach-drift",
  question = "How far does the hydraulic arm creep, or how hard does it push if locked, as it warms?",
  results = {
    {
      at_least = -0.5,
      at_most = 0.5,
      name = "reach_creep",
      nominal = 0.14282918270718004,
      shares = {
        {
          input = "temperature",
          percent = 95.724827498876266,
        },
        {
          input = "filled_at",
          percent = 3.8289930999550523,
        },
        {
          input = "oil_volume",
          percent = 0.27228395377458159,
        },
        {
          input = "oil_expansion",
          percent = 0.17096347568859249,
        },
        {
          input = "housing_expansion",
          percent = 0.0017096347568859333,
        },
        {
          input = "piston_bore",
          percent = 0.0012223369486307617,
        },
        {
          input = "oil_stiffness",
          percent = 0,
        },
      },
      spread = {
        centre = 0.14282918270718004,
        high = 0.41654880179784121,
        low = -0.13089043638348113,
      },
      spread_verdict = "pass",
      unit = "mm",
      worst = {
        high = 0.55884051793349054,
        low = -0.2149386607436502,
      },
      worst_verdict = "fail",
    },
    {
      at_least = -10,
      at_most = 10,
      name = "pressure_if_locked",
      nominal = 7.572000000000001,
      shares = {
        {
          input = "temperature",
          percent = 95.178089510139699,
        },
        {
          input = "filled_at",
          percent = 3.8071235804055874,
        },
        {
          input = "oil_stiffness",
          percent = 0.84310003164691261,
        },
        {
          input = "oil_expansion",
          percent = 0.16998700773051192,
        },
        {
          input = "housing_expansion",
          percent = 0.001699870077305097,
        },
        {
          input = "oil_volume",
          percent = 0,
        },
        {
          input = "piston_bore",
          percent = 0,
        },
      },
      spread = {
        centre = 8.5815999999999999,
        high = 25.074652756236482,
        low = -7.9114527562364838,
      },
      spread_verdict = "fail",
      unit = "MPa",
      worst = {
        high = 35.671999999999997,
        low = -13.719999999999999,
      },
      worst_verdict = "fail",
    },
  },
}
