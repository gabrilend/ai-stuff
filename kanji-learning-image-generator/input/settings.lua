-- input/settings.lua
--
-- Every tunable number in the project. The first thing any program here does is
-- read this file (src/009), so changing a number changes every program at once
-- and no program carries its own copy of one.
--
-- For a general: these are the dials. What each one does is in docs/003 for the
-- field, docs/004 for the scene and docs/005 for the workflow. Every time one is
-- turned, the turn goes in docs/balance-updates.md with the reason -- that file
-- is the history of this one.

return {

  -- {{{ archives -- where the data comes from (101)
  archives = {
    kanjivg = {
      url = "https://github.com/KanjiVG/kanjivg/releases/download/r20250422/kanjivg-20250422.xml.gz",
      file = "kanjivg.xml",
      -- the shape a whole file has: it opens with its root element and closes
      -- with it. not a hash -- upstream publishes new releases and a pinned
      -- hash would break the fetch every time they did.
      --
      -- the closing tag is the half that matters. a download fails by losing
      -- its tail, so a check that only reads the beginning proves the file
      -- started arriving and nothing about whether it finished.
      opens_with = "<kanjivg",
      closes_with = "</kanjivg>",
    },
    kanjidic2 = {
      url = "http://www.edrdg.org/kanjidic/kanjidic2.xml.gz",
      file = "kanjidic2.xml",
      opens_with = "<kanjidic2>",
      closes_with = "</kanjidic2>",
    },
  },
  -- }}}

  -- {{{ field -- the grey image the illusion rides on (docs/003, 202)
  field = {
    resolution   = 768,   -- pixels square; matches the control nets this targets
    margin       = 0.07,  -- fraction of the canvas left blank around the character
    stroke_width = 6.5,   -- at the resolution above
    taper        = 0.18,  -- fraction of each stroke thinned at either end
    order_ramp   = 0.12,  -- how much weaker the last stroke is than the first
    blur_radius  = 9,     -- THE dial. line becomes neighbourhood. docs/003.
    blur_passes  = 3,     -- three box blurs approximate a gaussian
    range_low    = 0.16,  -- the field is compressed into this band rather than
    range_high   = 0.86,  -- running full black to full white. docs/003.
    thumbnail    = 96,    -- the size the illusion is supposed to work at
  },
  -- }}}

  -- {{{ scene -- what the picture is of (docs/004, 204)
  scene = {
    named_strokes = 5,    -- how many strokes get an object named in the prompt
    -- weights for biome scoring. a component is evidence about what a character
    -- is about; a translated keyword is a weaker version of the same evidence.
    weight_primary_meaning = 3.0,
    weight_other_meaning   = 1.0,
    weight_component       = 4.0,
    weight_radical         = 2.0,
  },
  -- }}}

  -- {{{ arrows -- the stroke-order layer (206)
  arrows = {
    head_length  = 13,    -- at field.resolution; must read at thumbnail size
    head_width   = 9,
    shaft_length = 26,
    number_size  = 19,
    line_width   = 3.0,
    outline      = 2.4,   -- extra width of the dark outline under everything
    colour       = { 1.00, 0.92, 0.25 },  -- the arrows themselves
    outline_col  = { 0.06, 0.05, 0.02 },  -- what makes them survive a bright sky
  },
  -- }}}

  -- {{{ workflow -- the ComfyUI graph (docs/005, 302)
  workflow = {
    checkpoint       = "v1-5-pruned-emaonly.safetensors",
    control_net      = "control_v1p_sd15_qrcode_monster.safetensors",
    control_strength = 0.85,
    control_start    = 0.0,   -- composition is decided in the earliest steps
    control_end      = 0.72,  -- released so the model can finish the scene
    steps            = 24,
    cfg              = 6.5,   -- below the usual 7-8; high guidance fights the net
    sampler          = "dpmpp_2m",
    scheduler        = "karras",
    width            = 768,
    height           = 768,
    composite_arrows = true,  -- put the arrow layer in the saved image
  },
  -- }}}

  -- {{{ batch -- generating the whole set (303)
  batch = {
    workers = 0,          -- 0 means ask the machine how many processors it has
    out_dir = "tmp/shared-memory/sets",
  },
  -- }}}
}
