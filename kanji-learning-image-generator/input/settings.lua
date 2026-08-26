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
    -- The blur cannot be one number for every character. A stroke has to become
    -- a neighbourhood without merging into its neighbours, and a character with
    -- thirty strokes has its strokes much closer together than one with six.
    -- The radius above is the one for a character of `blur_reference` strokes,
    -- and it shrinks from there. See docs/003 and docs/balance-updates.md.
    blur_reference = 8,
    blur_falloff = 0.38,  -- 0 turns the scaling off entirely
    blur_minimum = 3,
    range_low    = 0.16,  -- the field is compressed into this band rather than
    range_high   = 0.86,  -- running full black to full white. docs/003.
    thumbnail    = 96,    -- the size the illusion is supposed to work at
  },
  -- }}}

  -- {{{ scene -- what the picture is of (docs/004, 204)
  scene = {
    -- How a picture reads. "mnemonic" makes every piece of a character a named
    -- thing, including the half chosen for its sound -- which is how the
    -- mnemonic tradition works and why it works. "semantic" demotes that half
    -- to background, which makes a picture that is about what the word means.
    -- Neither is wrong; see notes/041 and src/024.
    reading = "mnemonic",
    named_strokes = 5,    -- how many strokes get an object named in the prompt
    named_subjects = 3,   -- how many pieces of the character get named. a
                          -- character can have six, and naming all of them
                          -- spends the whole sentence before the world is
                          -- mentioned.
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
    head_length  = 27,    -- at field.resolution; must read at thumbnail size
    head_width   = 21,
    shaft_length = 34,
    number_size  = 36,
    line_width   = 5.0,
    outline      = 3.4,   -- extra width of the dark outline under everything
    -- How far apart two arrows have to be before neither is in the other's way.
    -- Must cover the arrow *and* its number: sized to the arrow alone, adjacent
    -- strokes produced two labels printed on top of each other, and the
    -- placement reported that it had found room for both.
    clearance    = 66,
    nudges       = 16,    -- how many sideways attempts before giving up
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
    workers = 0,          -- 0 means work it out from the processor count below
    -- What share of the machine a run is allowed to take. Measured rather
    -- than guessed: at every core this processor reaches the top of its
    -- thermal range within seconds, and the last few cores are the ones that
    -- cost the most heat for the least speed.
    share = 0.45,
    reserve = 1,          -- and at least this many cores left alone regardless
    max_workers = 6,      -- an outright ceiling, whatever the machine has
    nice = 10,            -- how far down the queue the workers wait
    out_dir = "tmp/shared-memory/sets",
  },
  -- }}}

  -- {{{ pool -- every picture ever made, kept (405)
  pool = {
    dir = "tmp/shared-memory/pool",
    -- What a machine has to score before a rendering counts as each tier. The
    -- machine's opinion is a correlation between the finished picture and the
    -- grey field that produced it -- how much the illusion actually took. These
    -- cuts are a starting position and should be set from a real distribution;
    -- src/046 --calibrate is the thing that measures it.
    cuts = { 0.86, 0.72, 0.55, 0.34 },   -- at or above -> tier 5, 4, 3, 2
    -- The share of renderings that must carry a person's rating before the
    -- apparatus is still anchored to anybody's taste. Below this, the machine's
    -- ratings are training the machine.
    human_floor = 0.05,
  },
  -- }}}

  -- {{{ animation -- what a higher tier buys (408)
  animation = {
    floor = 4,            -- at this tier or better, a picture earns an animation
    -- How long each frame is held, in hundredths of a second, because that is
    -- what the format honestly represents. Anything finer is drift dressed as
    -- precision.
    hundredths = 45,
  },
  -- }}}

  -- {{{ heat -- resting when the processor is climbing (307)
  --
  -- Degrees. A duty cycle is the one thing that lowers sustained temperature
  -- rather than moving it around: a busy core is a busy core, but brief regular
  -- idleness lets a chip shed what it has built up.
  heat = {
    warm = 58,            -- above this the run starts pausing between characters
    hot = 72,             -- by here the pauses are as long as they get
    rest_warm = 0.06,     -- seconds of rest at the warm mark
    rest_hot = 0.55,      -- and at the hot one; in between, proportional
    ceiling = 2.5,        -- how far past the hot rest it may go if still climbing
    check_every = 1,      -- characters between readings
  },
  -- }}}
}
