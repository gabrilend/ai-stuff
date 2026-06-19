-- Central color palette for compile-pdf-ai.lua
-- All RGB triples used by the art system live here so they can be audited
-- and rebalanced in one place. Generators import this module and reference
-- colors by name rather than embedding raw {r, g, b} triples inline.

local M = {}

-- {{{ mask_color: light purple, drawn behind poem boxes to set them apart
-- from page background art. The poem text is rendered on top of this.
M.mask_color = {0.9, 0.7, 1.0}
-- }}}

-- {{{ text_color: black, used for all body text and the column divider
M.text_color = {0.0, 0.0, 0.0}
-- }}}

-- {{{ accents: named singletons used by individual generators
-- Each entry should evoke what it's *for*, not what color it *is*, so a
-- future rebalancing can change the RGB without renaming everything.
M.accents = {
    -- Original accents (used by pre-existing generators)
    ocean_blue        = {0.3, 0.6, 0.8},  -- fish-particle stroke
    hot_pink          = {1.0, 0.4, 0.8},  -- vaporwave grid lines
    forest_green      = {0.2, 0.5, 0.3},  -- nature branches
    dreamy_purple     = {0.7, 0.3, 0.9},  -- dream sine waves
    resistance_red    = {1.0, 0.2, 0.2},  -- explosive radials
    circuit_green     = {0.2, 0.8, 0.3},  -- technology traces
    code_green        = {0.3, 0.7, 0.3},  -- programming_philosophy dashes
    default_gray      = {0.6, 0.6, 0.6},  -- placeholder dot pattern
    fallback_lavender = {0.5, 0.5, 0.7},  -- tier2 default circle
    encrypted_red     = {0.8, 0.2, 0.2},  -- digital_resistance rectangles

    -- New accents for Tier 1 generators (Issue 019)
    lonely_blue       = {0.55, 0.62, 0.70}, -- isolation, sparse marks
    blueprint_blue    = {0.20, 0.40, 0.65}, -- systems, network nodes
    warm_amber        = {0.95, 0.65, 0.20}, -- connection, woven curves
    sacred_purple     = {0.40, 0.18, 0.55}, -- transcendence, mandala
    temple_gold       = {0.85, 0.70, 0.30}, -- transcendence accents
    earth_brown       = {0.45, 0.30, 0.18}, -- survival, root systems
    root_tan          = {0.65, 0.50, 0.35}, -- survival secondary
    leaf_green        = {0.30, 0.55, 0.25}, -- nature secondary
    burst_white       = {0.95, 0.95, 0.85}, -- energy core
    burst_orange      = {1.00, 0.55, 0.15}, -- energy outer
    soft_pink         = {0.95, 0.65, 0.75}, -- love braid
    rain_gray         = {0.55, 0.60, 0.68}, -- melancholy drift
    tear_blue         = {0.40, 0.50, 0.65}, -- melancholy upper
    star_gold         = {1.00, 0.90, 0.50}, -- constellation marks
    night_blue        = {0.10, 0.15, 0.30}, -- constellation lines (subtle)
    bolt_white        = {0.95, 0.97, 1.00}, -- lightning core
    bolt_blue         = {0.55, 0.75, 1.00}, -- lightning outer
    crystal_cyan      = {0.50, 0.85, 0.90}, -- crystal faceting
    pale_gray         = {0.82, 0.82, 0.82}, -- neutral subtle mark
    glitch_red        = {1.00, 0.00, 0.20}, -- chaos RGB-shift red channel
    glitch_green      = {0.00, 1.00, 0.30}, -- chaos RGB-shift green channel
    glitch_blue       = {0.10, 0.20, 1.00}, -- chaos RGB-shift blue channel
}
-- }}}

-- {{{ neon_set: bright cycle used by vaporwave and urban full-page art
M.neon_set = {
    {1.0, 0.0, 1.0},  -- magenta
    {0.0, 1.0, 1.0},  -- cyan
    {1.0, 1.0, 0.0},  -- yellow
    {1.0, 0.3, 0.0},  -- orange
}
-- }}}

-- {{{ brush_set: three colors cycled by the creativity generator's strokes
M.brush_set = {
    {1.0, 0.2, 0.4},  -- warm pink
    {0.2, 0.8, 1.0},  -- sky blue
    {0.8, 1.0, 0.2},  -- lime
}
-- }}}

-- {{{ tier3_backgrounds: pale fill colors for individual poem boxes,
-- keyed by Tier 3 theme name. Each color is washed-out so dark text
-- stays readable on top.
M.tier3_backgrounds = {
    -- Resistance family
    direct_action            = {0.95, 0.85, 0.85},  -- light red/pink
    electoral_critique       = {0.90, 0.85, 0.90},  -- light purple-gray
    anarchist_theory         = {0.98, 0.85, 0.85},  -- light anarchist red

    -- Technology family
    programming_philosophy   = {0.85, 0.95, 0.90},  -- light mint
    ai_consciousness         = {0.85, 0.90, 0.95},  -- light blue
    infrastructure_critique  = {0.88, 0.88, 0.90},  -- light gray-blue

    -- Isolation family
    social_media_fatigue     = {0.90, 0.88, 0.93},  -- light purple-gray
    geographic_isolation     = {0.85, 0.90, 0.88},  -- light blue-gray
    emotional_walls          = {0.88, 0.85, 0.90},  -- light gray-purple

    -- Identity family
    autistic_masking         = {0.90, 0.95, 0.85},  -- light lime
    trans_experience         = {0.95, 0.90, 0.95},  -- light pink
    witch_identity           = {0.90, 0.85, 0.98},  -- light purple
    plural_systems           = {0.95, 0.88, 0.92},  -- light rose

    -- Systems family
    economic_systems         = {0.88, 0.90, 0.88},  -- light olive
    social_organization      = {0.90, 0.88, 0.85},  -- light tan
    technical_architecture   = {0.85, 0.88, 0.95},  -- light steel blue

    -- Connection family
    online_communities       = {0.88, 0.95, 0.90},  -- light green
    local_organizing         = {0.90, 0.93, 0.85},  -- light yellow-green
    intimate_relationships   = {0.98, 0.90, 0.88},  -- light peach

    -- Chaos family
    mental_overflow          = {0.95, 0.88, 0.85},  -- light coral
    system_glitches          = {0.90, 0.85, 0.85},  -- light red-gray
    digital_chaos            = {0.88, 0.85, 0.95},  -- light blue-purple

    -- Transcendence family
    spiritual_technology     = {0.92, 0.88, 0.98},  -- light lavender
    cosmic_consciousness     = {0.85, 0.88, 0.98},  -- light cosmic blue
    mystical_practice        = {0.95, 0.85, 0.95},  -- light magenta

    -- Survival family
    resource_scarcity        = {0.88, 0.85, 0.80},  -- light brown
    mutual_aid_practice      = {0.85, 0.90, 0.85},  -- light green
    survival_preparation     = {0.90, 0.88, 0.80},  -- light tan-brown

    -- Creativity family
    creative_process         = {0.98, 0.95, 0.85},  -- light cream
    generative_art           = {0.95, 0.88, 0.95},  -- light pink-purple
    artistic_expression      = {0.98, 0.90, 0.85},  -- light peach-yellow
    technical_creativity     = {0.85, 0.95, 0.88},  -- light mint-green
    collaborative_creation   = {0.90, 0.95, 0.88},  -- light sage
    digital_art              = {0.88, 0.90, 0.98},  -- light sky blue
    music_creation           = {0.95, 0.85, 0.90},  -- light rose-red
    writing_craft            = {0.88, 0.98, 0.88},  -- light mint
    design_thinking          = {0.90, 0.88, 0.98},  -- light periwinkle
    maker_culture            = {0.85, 0.88, 0.85},  -- light sage-gray
    creative_tools           = {0.88, 0.95, 0.85},  -- light lime-green
    aesthetic_philosophy     = {0.98, 0.88, 0.90},  -- light blush

    -- Default
    neutral                  = {0.93, 0.93, 0.93},  -- light gray
}
-- }}}

return M
