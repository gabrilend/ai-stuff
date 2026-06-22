-- themes/generators.lua
-- Issue 030: art generator registry.
--
-- Single source of truth for Tier 1 (page-background art) and Tier 2
-- (per-poem column-pattern) generators. Each generator declares its
-- own draw function, a one-sentence style_description used by the
-- themes-v2 pipeline to match HDBSCAN clusters to this generator
-- (cosine similarity between style_description embedding and cluster
-- centroid), and a parameters table of axes the renderer drives from
-- the corpus.
--
-- A parameter is {name, min, max, low_words, high_words} where the
-- word lists are short keyword strings. themes-rebuild embeds each
-- pair, computes axis = normalize(embed(high_words) - embed(low_words)),
-- and stores the axis vector with the cluster. At render time, the
-- poem's embedding is projected onto each axis, the raw score is
-- percentile-ranked across the corpus, and the percentile (∈ [0, 1])
-- maps linearly to [min, max] to produce the parameter value.
--
-- Tier 3 (per-poem background color) lives in themes/palette.lua as a
-- static lookup and is NOT a generator — there's no parameter to tune
-- in a flat color, so the registry pattern would be empty ceremony.
--
-- Adding a new Tier 1 generator: add an entry to M.tier1 with a
-- distinctive style_description and a sensible set of parameters.
-- themes-rebuild will pick it up automatically the next time clusters
-- are re-mapped to generators.

-- hpdf is only called inside the draw functions, which run on the render
-- path (lua5.2, libharu binding on package.cpath). themes-v2/name-clusters.lua
-- loads this module under luajit purely to read each generator's
-- style_description + parameters and never calls draw — and that luajit has
-- no hpdf binding. Resolving hpdf lazily keeps module load independent of
-- the binding so the taxonomy rebuild works; keys memoize after first use.
-- (Without this, the whole cluster→generator mapping pass dies at require.)
local hpdf = setmetatable({}, {__index = function(t, k)
    local real = require "hpdf"
    local v = real[k]; rawset(t, k, v); return v
end})
local palette = require "themes/palette"
local art = require "libs/art-primitives"

local M = {}

-- {{{ M.tier1 — page-background art generators (22 total, migrated from
--     compile-pdf-ai.lua by Issue 030; param declarations originally lived
--     in themes/embedding-driven-params.lua, which is now retired. The
--     draw functions are functionally identical to the pre-migration
--     generators; only their location and metadata changed.)
M.tier1 = {

    -- {{{ resistance
    resistance = {
        style_description = "Explosive radial rays bursting from a center point in red, suggesting uprising, revolt, militant collective action against power structures.",
        parameters = {
            {name = "ray_count",  min = 4, max = 25,
             low_words  = "solitary, private, internal, quiet, individual, lone, alone, single, hushed, withdrawn",
             high_words = "uprising, militant, organizing, mobilizing, surging, masses, revolt, swarming, mass-action, collective"},
            {name = "ray_length", min = 8, max = 30,
             low_words  = "contained, near, confined, local, modest, restrained, limited, close, immediate, small",
             high_words = "reaching, far-reaching, vast, sprawling, overwhelming, sweeping, expansive, dominant, encompassing, total"},
        },
        draw = function(page, space, params)
            params = params or {}
            local ray_count  = math.floor(4 + (params.ray_count  or 0.5) * 21 + 0.5)
            local max_length = math.floor(8 + (params.ray_length or 0.5) * 22 + 0.5)
            local cx = space.x + space.width  / 2
            local cy = space.y + space.height / 2
            hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.resistance_red))
            hpdf.Page_SetLineWidth(page, 1.0)
            for i = 1, ray_count do
                local angle  = (i / ray_count) * math.pi * 2
                local length = max_length * (0.5 + math.random() * 0.5)
                hpdf.Page_MoveTo(page, cx, cy)
                hpdf.Page_LineTo(page, cx + math.cos(angle) * length, cy + math.sin(angle) * length)
                hpdf.Page_Stroke(page)
            end
        end,
    },
    -- }}}

    -- {{{ technology
    technology = {
        style_description = "Green orthogonal circuit traces on a dense rectangular field, suggesting programming, distributed networks, software architecture.",
        parameters = {
            {name = "trace_count",  min = 4, max = 20,
             low_words  = "simple, monolithic, sparse, plain, atomic, basic, single, minimal, raw, elementary",
             high_words = "distributed, networked, intricate, dense, complex, layered, elaborate, sophisticated, woven, meshed"},
            {name = "trace_length", min = 6, max = 24,
             low_words  = "atomic, modular, local, isolated, component, contained, small, brief, discrete, scoped",
             high_words = "infrastructure, architectural, scaling, sprawling, large-scale, framework, expansive, sweeping, system-wide, foundational"},
        },
        draw = function(page, space, params)
            params = params or {}
            local trace_count  = math.floor(4 + (params.trace_count  or 0.5) * 16 + 0.5)
            local trace_length = math.floor(6 + (params.trace_length or 0.5) * 18 + 0.5)
            hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.circuit_green))
            hpdf.Page_SetLineWidth(page, 0.4)
            for i = 1, trace_count do
                local x = space.x + math.random() * space.width
                local y = space.y + math.random() * space.height
                if math.random() > 0.5 then
                    hpdf.Page_MoveTo(page, x, y); hpdf.Page_LineTo(page, x + trace_length, y)
                else
                    hpdf.Page_MoveTo(page, x, y); hpdf.Page_LineTo(page, x, y + trace_length)
                end
                hpdf.Page_Stroke(page)
            end
        end,
    },
    -- }}}

    -- {{{ creativity
    creativity = {
        style_description = "Multi-color flowing brush strokes with jagged path segments, suggesting prolific artistic expression and a kaleidoscopic palette.",
        parameters = {
            {name = "stroke_count",     min = 4, max = 18,
             low_words  = "spare, distilled, refined, restrained, deliberate, minimal, considered, careful, sparse, terse",
             high_words = "prolific, abundant, generative, fertile, productive, flowing, copious, expansive, profuse, overflowing"},
            {name = "stroke_jaggedness", min = 1, max = 6,
             low_words  = "deliberate, composed, smooth, measured, planned, controlled, even, contained, considered, polished",
             high_words = "wild, spontaneous, untamed, frenzied, raw, frantic, expressive, unrestrained, gestural, impulsive"},
            {name = "color_richness",   min = 1, max = 3,
             low_words  = "monochrome, restrained, subdued, single-hued, focused, narrow, austere, spare, quiet, muted",
             high_words = "vibrant, saturated, kaleidoscopic, prismatic, riotous, exuberant, lush, vivid, rich, jubilant"},
        },
        draw = function(page, space, params)
            params = params or {}
            local stroke_count       = math.floor(4 + (params.stroke_count       or 0.5) * 14 + 0.5)
            local segments_per_stroke = math.floor(1 + (params.stroke_jaggedness or 0.5) * 5  + 0.5)
            local color_palette_size = math.floor(1 + (params.color_richness     or 0.5) * 2  + 0.5)
            local colors = {}
            for i = 1, color_palette_size do colors[i] = palette.brush_set[i] end
            for i = 1, stroke_count do
                local color = colors[math.random(#colors)]
                local x = space.x + math.random() * space.width
                local y = space.y + math.random() * space.height
                hpdf.Page_SetRGBStroke(page, color[1], color[2], color[3])
                hpdf.Page_SetLineWidth(page, 0.6)
                hpdf.Page_MoveTo(page, x, y)
                for seg = 1, segments_per_stroke do
                    x = x + math.random(-10, 10)
                    y = y + math.random(-10, 10)
                    hpdf.Page_LineTo(page, x, y)
                end
                hpdf.Page_Stroke(page)
            end
        end,
    },
    -- }}}

    -- {{{ isolation
    isolation = {
        style_description = "Sparse pale-blue marks scattered across vast negative space, suggesting loneliness, disconnection, withdrawal.",
        parameters = {
            {name = "alpha_level", min = 0.3, max = 0.95,
             low_words  = "ghostly, faded, distant, removed, intangible, dim, fading, evanescent, vanishing, spectral",
             high_words = "present, tangible, immediate, here, real, embodied, palpable, vivid, weighted, anchored"},
        },
        draw = function(page, space, params)
            params = params or {}
            local alpha = 0.3 + (params.alpha_level or 0.5) * 0.65
            local count = 6
            hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.lonely_blue))
            hpdf.Page_SetLineWidth(page, 0.4)
            art.with_alpha(page, alpha, function()
                for i = 1, count do
                    local x = space.x + math.random() * space.width
                    local y = space.y + math.random() * space.height
                    hpdf.Page_Circle(page, x, y, 1.5)
                    hpdf.Page_Stroke(page)
                end
            end)
        end,
    },
    -- }}}

    -- {{{ identity
    identity = {
        style_description = "Repeated colored squares with prismatic offset between channels, suggesting multifaceted self, fluid gender, fragmented identity.",
        parameters = {
            {name = "shape_count",      min = 3, max = 12,
             low_words  = "singular, unified, focused, simple, consolidated, integrated, whole, one, distilled, essential",
             high_words = "multifaceted, plural, manifold, layered, complex, kaleidoscopic, varied, many-sided, prismatic, multitudinous"},
            {name = "offset_magnitude", min = 1, max = 6,
             low_words  = "aligned, centered, coherent, focused, integrated, unified, together, gathered, cohesive, whole",
             high_words = "fragmented, dispersed, scattered, divided, split, refracted, disjointed, separated, shattered, broken"},
        },
        draw = function(page, space, params)
            params = params or {}
            local count        = math.floor(3 + (params.shape_count      or 0.5) * 9 + 0.5)
            local offset_scale = 1 + (params.offset_magnitude or 0.5) * 5
            for i = 1, count do
                local cx = space.x + math.random() * space.width
                local cy = space.y + math.random() * space.height
                local size = 6 + math.random(8)
                for ci, color in ipairs(palette.brush_set) do
                    local offset_x = (ci - 2) * offset_scale
                    local offset_y = (ci - 2) * (offset_scale * 0.5)
                    art.with_alpha(page, 0.5, function()
                        hpdf.Page_SetRGBFill(page, color[1], color[2], color[3])
                        hpdf.Page_Rectangle(page, cx + offset_x, cy + offset_y, size, size)
                        hpdf.Page_Fill(page)
                    end)
                end
            end
        end,
    },
    -- }}}

    -- {{{ systems
    systems = {
        style_description = "Blueprint-blue nodes connected by Manhattan right-angle lines, suggesting architectural thinking, federated structure, complex systems.",
        parameters = {
            {name = "node_count",  min = 4,   max = 16,
             low_words  = "small, intimate, local, modest, contained, atomic, simple, minimal, household, neighborhood",
             high_words = "vast, sprawling, comprehensive, infrastructure, network, large-scale, encompassing, expansive, federated, planetary"},
            {name = "line_weight", min = 0.3, max = 1.2,
             low_words  = "diagrammatic, sketched, light, provisional, draft, ephemeral, fluid, tentative, hypothetical, proposed",
             high_words = "infrastructural, monumental, heavy, weighted, established, anchored, substantial, fixed, durable, permanent"},
        },
        draw = function(page, space, params)
            params = params or {}
            local node_count  = math.floor(4 + (params.node_count  or 0.5) * 12 + 0.5)
            local line_weight = 0.3 + (params.line_weight or 0.5) * 0.9
            local nodes = {}
            hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.blueprint_blue))
            hpdf.Page_SetLineWidth(page, line_weight)
            for i = 1, node_count do
                local x = space.x + math.random() * space.width
                local y = space.y + math.random() * space.height
                nodes[i] = { x = x, y = y }
                hpdf.Page_Circle(page, x, y, 1.5)
                hpdf.Page_Stroke(page)
            end
            for i = 2, #nodes do
                local a, b = nodes[i - 1], nodes[i]
                hpdf.Page_MoveTo(page, a.x, a.y)
                hpdf.Page_LineTo(page, b.x, a.y)
                hpdf.Page_LineTo(page, b.x, b.y)
                hpdf.Page_Stroke(page)
            end
        end,
    },
    -- }}}

    -- {{{ connection
    connection = {
        style_description = "Warm amber bezier curves linking distant points with layered translucency, suggesting bonds, weaving, community ties.",
        parameters = {
            {name = "curve_count",    min = 3,   max = 14,
             low_words  = "few, scarce, sparse, limited, single, rare, isolated, alone, singular, lone",
             high_words = "many, dense, abundant, numerous, populated, multitude, manifold, crowded, plentiful, woven"},
            {name = "sway_magnitude", min = 8,   max = 50,
             low_words  = "subtle, gentle, quiet, restrained, steady, calm, still, even, soft, measured",
             high_words = "dramatic, sweeping, turbulent, intense, wild, sweeping, swirling, churning, passionate, fierce"},
            {name = "alpha_layering", min = 0.3, max = 0.7,
             low_words  = "separate, parallel, distinct, individual, side-by-side, adjacent, clean, discrete, unblended, apart",
             high_words = "interwoven, layered, overlapping, braided, knotted, dense, blended, merged, fused, entangled"},
        },
        draw = function(page, space, params)
            params = params or {}
            local curve_count = math.floor(3 + (params.curve_count or 0.5) * 11 + 0.5)
            local max_sway    = 8 + (params.sway_magnitude or 0.5) * 42
            local alpha       = 0.3 + (params.alpha_layering or 0.5) * 0.4
            hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.warm_amber))
            hpdf.Page_SetLineWidth(page, 0.6)
            art.with_alpha(page, alpha, function()
                for i = 1, curve_count do
                    local x1 = space.x + math.random() * space.width
                    local y1 = space.y + math.random() * space.height
                    local x2 = space.x + math.random() * space.width
                    local y2 = space.y + math.random() * space.height
                    local sway = (math.random() - 0.5) * 2 * max_sway
                    art.flowing_curve(page, x1, y1, x2, y2, sway)
                    hpdf.Page_Stroke(page)
                end
            end)
        end,
    },
    -- }}}

    -- {{{ chaos
    chaos = {
        style_description = "RGB-channel-separated overlapping rectangles, suggesting glitch, breakdown, scrambled signal, mental overflow.",
        parameters = {
            {name = "glitch_count",    min = 4, max = 20,
             low_words  = "stable, contained, singular, isolated, momentary, brief, occasional, sporadic, fleeting, transient",
             high_words = "overwhelming, cascading, prolific, swarming, multiplying, exploding, breaking, fragmenting, surging, drowning"},
            {name = "shift_magnitude", min = 1, max = 6,
             low_words  = "intact, aligned, coherent, registered, clean, sharp, focused, stable, ordered, calibrated",
             high_words = "corrupted, broken, malfunctioning, disrupted, scrambled, distorted, garbled, decayed, ruined, shattered"},
        },
        draw = function(page, space, params)
            params = params or {}
            local count       = math.floor(4 + (params.glitch_count    or 0.5) * 16 + 0.5)
            local shift_scale = 1 + (params.shift_magnitude or 0.5) * 5
            local channels = {
                palette.accents.glitch_red,
                palette.accents.glitch_green,
                palette.accents.glitch_blue,
            }
            for i = 1, count do
                local x = space.x + math.random() * space.width
                local y = space.y + math.random() * space.height
                local size = 8 + math.random(10)
                art.with_alpha(page, 0.6, function()
                    for ci, color in ipairs(channels) do
                        local off = (ci - 2) * shift_scale
                        hpdf.Page_SetRGBStroke(page, color[1], color[2], color[3])
                        hpdf.Page_SetLineWidth(page, 0.5)
                        hpdf.Page_Rectangle(page, x + off, y + off, size, size)
                        hpdf.Page_Stroke(page)
                    end
                end)
            end
        end,
    },
    -- }}}

    -- {{{ transcendence
    transcendence = {
        style_description = "Concentric purple mandala arcs with a gold center, suggesting mystical layering, sacred ritual, spiritual depth.",
        parameters = {
            {name = "ring_count",       min = 2, max = 8,
             low_words  = "singular, direct, plain, immediate, one-pointed, clear, surface",
             high_words = "layered, recursive, mystical, manifold, nested, esoteric, deep"},
            {name = "radial_count",     min = 4, max = 16,
             low_words  = "spontaneous, free-form, intuitive, organic, unmeasured, improvised, loose",
             high_words = "ritual, structured, ceremonial, ordered, geometric, formal, repeating"},
            {name = "gold_center_size", min = 1, max = 6,
             low_words  = "diffuse, vague, undefined, peripheral, scattered, unclear, ambient",
             high_words = "revelation, clear, central, illumination, focus, anchor, certainty"},
        },
        draw = function(page, space, params)
            params = params or {}
            local p_rings  = params.ring_count       or 0.5
            local p_radial = params.radial_count     or 0.5
            local p_gold   = params.gold_center_size or 0.5
            local cx = space.x + space.width  / 2
            local cy = space.y + space.height / 2
            local ring_count       = math.floor(2 + p_rings  * 6 + 0.5)
            local radial_count     = math.floor(4 + p_radial * 12 + 0.5)
            local gold_center_size = 1 + p_gold * 5
            hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.sacred_purple))
            hpdf.Page_SetLineWidth(page, 0.5)
            art.with_alpha(page, 0.7, function()
                for r = 1, ring_count do
                    local radius = r * 8
                    for s = 0, radial_count - 1 do
                        local start_deg = s * (360 / radial_count)
                        local end_deg = start_deg + (360 / radial_count) * 0.7
                        art.arc(page, cx, cy, radius, start_deg, end_deg)
                        hpdf.Page_Stroke(page)
                    end
                end
                hpdf.Page_SetRGBFill(page, table.unpack(palette.accents.temple_gold))
                hpdf.Page_Circle(page, cx, cy, gold_center_size)
                hpdf.Page_Fill(page)
            end)
        end,
    },
    -- }}}

    -- {{{ survival
    survival = {
        style_description = "Brown vertical trunks with tan branching root-curves, suggesting resourcefulness, scarcity, basic needs, foraging.",
        parameters = {
            {name = "trunk_count",  min = 1, max = 6,
             low_words  = "scarce, sparse, lean, depleted, exhausted, barren, threadbare, last-ditch, precarious, hungry",
             high_words = "abundant, plentiful, fertile, plenty, replete, ample, sustained, supported, surplus, secure"},
            {name = "branch_count", min = 2, max = 10,
             low_words  = "single, direct, lean, austere, simple, basic, raw, unembellished, focused, narrow",
             high_words = "branching, ramifying, resourceful, adaptive, networked, distributed, redundant, layered, multiplied, varied"},
        },
        draw = function(page, space, params)
            params = params or {}
            local trunk_count        = math.floor(1 + (params.trunk_count  or 0.5) * 5 + 0.5)
            local branches_per_trunk = math.floor(2 + (params.branch_count or 0.5) * 8 + 0.5)
            hpdf.Page_SetLineWidth(page, 0.5)
            for t = 1, trunk_count do
                local x = space.x + math.random() * space.width
                local y_top = space.y + space.height
                local y_bot = space.y
                hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.earth_brown))
                art.flowing_curve(page, x, y_top, x + math.random(-10, 10), y_bot, math.random(-5, 5))
                hpdf.Page_Stroke(page)
                hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.root_tan))
                hpdf.Page_SetLineWidth(page, 0.3)
                for b = 1, branches_per_trunk do
                    local fx = x + math.random(-3, 3)
                    local fy = y_top - math.random() * space.height * 0.7
                    local bx = fx + math.random(-20, 20)
                    local by = fy + math.random(-10, 10)
                    art.flowing_curve(page, fx, fy, bx, by, math.random(-3, 3))
                    hpdf.Page_Stroke(page)
                end
            end
        end,
    },
    -- }}}

    -- {{{ nature
    nature = {
        style_description = "Branching forest-green curves radiating organically from random points, suggesting flora, growth, woodland, organic life.",
        parameters = {
            {name = "stem_count",       min = 4, max = 18,
             low_words  = "sparse, austere, bare, minimal, restrained, quiet, barren, simple, desert, scarce",
             high_words = "lush, abundant, dense, thriving, growing, flourishing, verdant, profuse, fecund, jungle"},
            {name = "branch_recursion", min = 2, max = 8,
             low_words  = "simple, direct, straight, unembellished, plain, atomic, single, bare, sapling, sprout",
             high_words = "fractal, recursive, branching, manifold, ramifying, growing, layered, deep, complex, generative"},
        },
        draw = function(page, space, params)
            params = params or {}
            local stems              = math.floor(4 + (params.stem_count       or 0.5) * 14 + 0.5)
            local branches_per_stem  = math.floor(2 + (params.branch_recursion or 0.5) * 6  + 0.5)
            hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.forest_green))
            hpdf.Page_SetLineWidth(page, 0.3)
            for i = 1, stems do
                local x = space.x + math.random() * space.width
                local y = space.y + math.random() * space.height
                for b = 1, branches_per_stem do
                    local angle = (math.random() - 0.5) * math.pi
                    local length = 15 + math.random(30)
                    local ex = x + math.cos(angle) * length
                    local ey = y + math.sin(angle) * length
                    art.flowing_curve(page, x, y, ex, ey, math.random(-4, 4))
                    hpdf.Page_Stroke(page)
                    x, y = ex, ey
                end
            end
        end,
    },
    -- }}}

    -- {{{ urban
    urban = {
        style_description = "Scattered neon rectangle outlines suggesting buildings, dense city map, urban density.",
        parameters = {
            {name = "block_count", min = 5,  max = 30,
             low_words  = "sparse, empty, deserted, vacant, quiet, abandoned, hollow, depopulated, ghostly, silent",
             high_words = "dense, crowded, packed, busy, populated, thick, congested, swarming, teeming, bustling"},
            {name = "block_scale", min = 10, max = 35,
             low_words  = "small, intimate, local, modest, neighborhood, compact, miniature, close, walkable, human-scale",
             high_words = "monumental, towering, vast, imposing, grand, massive, sprawling, dominating, megalithic, looming"},
        },
        draw = function(page, space, params)
            params = params or {}
            local count    = math.floor(5  + (params.block_count or 0.5) * 25 + 0.5)
            local max_size = math.floor(10 + (params.block_scale or 0.5) * 25 + 0.5)
            local colors = { palette.neon_set[1], palette.neon_set[2], palette.neon_set[3] }
            for i = 1, count do
                local color = colors[math.random(#colors)]
                hpdf.Page_SetRGBStroke(page, color[1], color[2], color[3])
                hpdf.Page_SetLineWidth(page, 0.5 + math.random())
                local x = space.x + math.random() * space.width
                local y = space.y + math.random() * space.height
                local size = max_size * (0.4 + math.random() * 0.6)
                hpdf.Page_Rectangle(page, x, y, size, size)
                hpdf.Page_Stroke(page)
            end
        end,
    },
    -- }}}

    -- {{{ energy
    energy = {
        style_description = "Radiating white-to-orange bursts from one or more focal points, suggesting explosive force, intensity, kinetic power.",
        parameters = {
            {name = "focal_count", min = 1, max = 4,
             low_words  = "single, central, focused, unified, concentrated, one, alone, solo, pointed, singular",
             high_words = "multiple, dispersed, distributed, several, many, scattered, plural, manifold, diffuse, parallel"},
            {name = "ray_count",   min = 8, max = 35,
             low_words  = "subtle, gentle, quiet, mild, faint, dim, restrained, soft, muted, smoldering",
             high_words = "explosive, intense, overwhelming, dazzling, blazing, radiant, blinding, fierce, incandescent, supernova"},
        },
        draw = function(page, space, params)
            params = params or {}
            local focal_count    = math.floor(1 + (params.focal_count or 0.5) * 3  + 0.5)
            local rays_per_focal = math.floor(8 + (params.ray_count   or 0.5) * 27 + 0.5)
            for f = 1, focal_count do
                local cx = space.x + space.width  * (0.2 + math.random() * 0.6)
                local cy = space.y + space.height * (0.2 + math.random() * 0.6)
                for i = 1, rays_per_focal do
                    local angle  = (i / rays_per_focal) * math.pi * 2 + math.random() * 0.2
                    local length = 10 + math.random(25)
                    local mid_x  = cx + math.cos(angle) * length * 0.5
                    local mid_y  = cy + math.sin(angle) * length * 0.5
                    hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.burst_white))
                    hpdf.Page_SetLineWidth(page, 1.2)
                    hpdf.Page_MoveTo(page, cx, cy)
                    hpdf.Page_LineTo(page, mid_x, mid_y)
                    hpdf.Page_Stroke(page)
                    hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.burst_orange))
                    hpdf.Page_SetLineWidth(page, 0.4)
                    hpdf.Page_MoveTo(page, mid_x, mid_y)
                    hpdf.Page_LineTo(page, cx + math.cos(angle) * length, cy + math.sin(angle) * length)
                    hpdf.Page_Stroke(page)
                end
            end
        end,
    },
    -- }}}

    -- {{{ love
    love = {
        style_description = "Paired soft pink curves braiding together at varied sway intensity, suggesting bonds, intimacy, tender embrace.",
        parameters = {
            {name = "braid_count",    min = 2, max = 10,
             low_words  = "separate, distant, parallel, apart, distinct, separated, individual, lonesome, solo, untouched",
             high_words = "intertwined, woven, bound, joined, embraced, knotted, intimate, bonded, entwined, locked"},
            {name = "sway_intensity", min = 6, max = 24,
             low_words  = "gentle, tender, soft, quiet, calm, peaceful, steady, mild, easy, comfortable",
             high_words = "passionate, fierce, dramatic, intense, sweeping, turbulent, ardent, fervent, consuming, all-encompassing"},
        },
        draw = function(page, space, params)
            params = params or {}
            local pair_count = math.floor(2 + (params.braid_count    or 0.5) * 8  + 0.5)
            local max_sway   = 6 + (params.sway_intensity or 0.5) * 18
            hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.soft_pink))
            hpdf.Page_SetLineWidth(page, 0.7)
            art.with_alpha(page, 0.6, function()
                for i = 1, pair_count do
                    local x1 = space.x + math.random() * space.width
                    local y1 = space.y + math.random() * space.height
                    local x2 = space.x + math.random() * space.width
                    local y2 = space.y + math.random() * space.height
                    local sway = max_sway * (0.5 + math.random() * 0.5)
                    art.flowing_curve(page, x1, y1, x2, y2, sway)
                    hpdf.Page_Stroke(page)
                    art.flowing_curve(page, x1 + 3, y1, x2 + 3, y2, -sway)
                    hpdf.Page_Stroke(page)
                end
            end)
        end,
    },
    -- }}}

    -- {{{ melancholy
    melancholy = {
        style_description = "Downward gray-to-blue rain strokes, suggesting sorrow, tears, persistent sadness, quiet grief.",
        parameters = {
            {name = "saturation", min = 0.2, max = 1.0,
             low_words  = "passing, fleeting, momentary, occasional, distant, faint, brief, slight, wisp, shadow",
             high_words = "overwhelming, drowning, cascading, falling, persistent, ceaseless, weeping, flooding, deluging, engulfing"},
        },
        draw = function(page, space, params)
            params = params or {}
            local saturation = 0.2 + (params.saturation or 0.5) * 0.8
            local count    = math.floor(8 + saturation * 32 + 0.5)
            local max_drop = 2 + saturation * 10
            local c1 = palette.accents.tear_blue
            local c2 = palette.accents.rain_gray
            for i = 1, count do
                local x = space.x + math.random() * space.width
                local y = space.y + math.random() * space.height
                local t = (y - space.y) / space.height
                hpdf.Page_SetRGBStroke(page,
                    c1[1] * t + c2[1] * (1 - t),
                    c1[2] * t + c2[2] * (1 - t),
                    c1[3] * t + c2[3] * (1 - t))
                hpdf.Page_SetLineWidth(page, 0.4)
                hpdf.Page_MoveTo(page, x, y)
                hpdf.Page_LineTo(page, x, y - max_drop * (0.4 + math.random() * 0.6))
                hpdf.Page_Stroke(page)
            end
        end,
    },
    -- }}}

    -- {{{ dream
    dream = {
        style_description = "Dreamy purple sine waves at varied amplitudes layered in low alpha, suggesting reverie, surreal vision, dreamy drift.",
        parameters = {
            {name = "wave_count", min = 3, max = 14,
             low_words  = "single, clear, focused, simple, direct, plain, atomic, lone, lucid, isolated",
             high_words = "layered, multiple, manifold, complex, woven, nested, deep, intricate, hypnagogic, recursive"},
            {name = "amplitude",  min = 6, max = 30,
             low_words  = "subtle, faint, fading, gentle, restrained, quiet, dim, peripheral, fleeting, half-remembered",
             high_words = "vivid, immersive, transporting, surreal, profound, fantastical, intense, otherworldly, kaleidoscopic, immersive"},
        },
        draw = function(page, space, params)
            params = params or {}
            local wave_count    = math.floor(3 + (params.wave_count or 0.5) * 11 + 0.5)
            local max_amplitude = 6 + (params.amplitude or 0.5) * 24
            hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.dreamy_purple))
            hpdf.Page_SetLineWidth(page, 0.3)
            art.with_alpha(page, 0.5, function()
                for w = 1, wave_count do
                    local y_base    = space.y + math.random() * space.height
                    local amplitude = max_amplitude * (0.4 + math.random() * 0.6)
                    local segs      = 6
                    local seg_width = space.width / segs
                    hpdf.Page_MoveTo(page, space.x, y_base)
                    for s = 1, segs do
                        local x1 = space.x + s * seg_width
                        local sign = (s % 2 == 0) and 1 or -1
                        local y1 = y_base + sign * amplitude
                        local cx1 = x1 - seg_width * 0.6
                        local cy1 = y_base + sign * -amplitude
                        local cx2 = x1 - seg_width * 0.4
                        local cy2 = y_base + sign * amplitude
                        hpdf.Page_CurveTo(page, cx1, cy1, cx2, cy2, x1, y1)
                    end
                    hpdf.Page_Stroke(page)
                end
            end)
        end,
    },
    -- }}}

    -- {{{ constellation
    constellation = {
        style_description = "Gold star points connected by thin night-blue lines, suggesting cosmic awareness, celestial navigation, stellar patterns.",
        parameters = {
            {name = "star_count", min = 6,   max = 24,
             low_words  = "few, sparse, scattered, isolated, single, rare, sparse, alone, solitary, lone",
             high_words = "many, abundant, scattered, plentiful, populated, multitude, profuse, dense, swarming, infinite"},
            {name = "star_size",  min = 0.5, max = 2.5,
             low_words  = "dim, faint, fading, weak, distant, ghostly, pale, subtle, hushed, withdrawn",
             high_words = "luminous, bright, brilliant, dazzling, radiant, blazing, gleaming, shining, beaming, lucent"},
        },
        draw = function(page, space, params)
            params = params or {}
            local star_count = math.floor(6 + (params.star_count or 0.5) * 18 + 0.5)
            local star_size  = 0.5 + (params.star_size or 0.5) * 2.0
            local stars = {}
            for i = 1, star_count do
                stars[i] = {
                    x = space.x + math.random() * space.width,
                    y = space.y + math.random() * space.height,
                }
            end
            hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.night_blue))
            hpdf.Page_SetLineWidth(page, 0.2)
            art.with_alpha(page, 0.5, function()
                for i = 1, #stars - 1 do
                    hpdf.Page_MoveTo(page, stars[i].x, stars[i].y)
                    hpdf.Page_LineTo(page, stars[i + 1].x, stars[i + 1].y)
                    hpdf.Page_Stroke(page)
                end
            end)
            hpdf.Page_SetRGBFill(page, table.unpack(palette.accents.star_gold))
            for _, s in ipairs(stars) do
                hpdf.Page_Circle(page, s.x, s.y, star_size)
                hpdf.Page_Fill(page)
            end
        end,
    },
    -- }}}

    -- {{{ spiral
    spiral = {
        style_description = "Single growing purple spiral built from arc segments at increasing radii, suggesting whirling motion, mandala, expanding consciousness.",
        parameters = {
            {name = "segment_count", min = 10,  max = 40,
             low_words  = "tight, contained, brief, compact, small, modest, bounded, finite, finished, complete",
             high_words = "vast, endless, expanding, growing, sprawling, infinite, boundless, unfolding, perpetual, ceaseless"},
            {name = "growth_rate",   min = 0.8, max = 2.5,
             low_words  = "tight, gradual, slow, contained, measured, controlled, restrained, modest, glacial, stilled",
             high_words = "rapid, accelerating, exponential, opening, expanding, growing, blooming, surging, escalating, ballooning"},
        },
        draw = function(page, space, params)
            params = params or {}
            local segments    = math.floor(10 + (params.segment_count or 0.5) * 30 + 0.5)
            local growth_rate = 0.8 + (params.growth_rate or 0.5) * 1.7
            local cx = space.x + space.width  / 2
            local cy = space.y + space.height / 2
            hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.sacred_purple))
            hpdf.Page_SetLineWidth(page, 0.4)
            for i = 1, segments do
                local radius = i * growth_rate
                local start_deg = i * 25
                local end_deg   = start_deg + 30
                art.arc(page, cx, cy, radius, start_deg, end_deg)
                hpdf.Page_Stroke(page)
            end
        end,
    },
    -- }}}

    -- {{{ circuit
    circuit = {
        style_description = "Manhattan-geometry green circuit traces with junction nodes at each turn, suggesting processor layout, technical pathways, digital structure.",
        parameters = {
            {name = "trace_count",        min = 4, max = 20,
             low_words  = "simple, sparse, atomic, basic, minimal, plain, single, contained, primitive, elementary",
             high_words = "complex, dense, intricate, distributed, layered, elaborate, sophisticated, networked, byzantine, interwoven"},
            {name = "segments_per_trace", min = 2, max = 8,
             low_words  = "direct, straight, simple, immediate, clear, brief, atomic, plain, terse, blunt",
             high_words = "winding, convoluted, complex, indirect, twisting, elaborate, intricate, meandering, labyrinthine, devious"},
        },
        draw = function(page, space, params)
            params = params or {}
            local trace_count   = math.floor(4 + (params.trace_count        or 0.5) * 16 + 0.5)
            local segs_per_trace = math.floor(2 + (params.segments_per_trace or 0.5) * 6  + 0.5)
            hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.circuit_green))
            hpdf.Page_SetLineWidth(page, 0.5)
            for i = 1, trace_count do
                local x = space.x + math.random() * space.width
                local y = space.y + math.random() * space.height
                for s = 1, segs_per_trace do
                    local len = 6 + math.random(10)
                    local nx, ny = x, y
                    if math.random() > 0.5 then
                        nx = x + (math.random() > 0.5 and len or -len)
                    else
                        ny = y + (math.random() > 0.5 and len or -len)
                    end
                    hpdf.Page_MoveTo(page, x, y)
                    hpdf.Page_LineTo(page, nx, ny)
                    hpdf.Page_Stroke(page)
                    hpdf.Page_Circle(page, nx, ny, 0.8)
                    hpdf.Page_Stroke(page)
                    x, y = nx, ny
                end
            end
        end,
    },
    -- }}}

    -- {{{ lightning
    lightning = {
        style_description = "Jagged blue-glow bolts with thin white cores from top to bottom, suggesting sudden force, electrical discharge, dramatic strike.",
        parameters = {
            {name = "bolt_count", min = 1, max = 5,
             low_words  = "single, isolated, lone, one, sudden, brief, momentary, rare, once, singular",
             high_words = "many, repeated, repeating, multiple, sustained, hammering, ceaseless, frequent, drumming, relentless"},
            {name = "jaggedness", min = 4, max = 16,
             low_words  = "direct, straight, clean, focused, predictable, clear, smooth, controlled, calm, deliberate",
             high_words = "erratic, chaotic, wild, unpredictable, jagged, frantic, broken, violent, convulsive, spasmodic"},
        },
        draw = function(page, space, params)
            params = params or {}
            local bolt_count = math.floor(1 + (params.bolt_count or 0.5) * 4 + 0.5)
            local jag_max    = 4 + (params.jaggedness or 0.5) * 12
            for b = 1, bolt_count do
                local x = space.x + math.random() * space.width
                local y = space.y + space.height
                local path_x, path_y = { x }, { y }
                while y > space.y do
                    y = y - 6 - math.random() * 8
                    x = x + (math.random() - 0.5) * jag_max
                    table.insert(path_x, x)
                    table.insert(path_y, y)
                end
                hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.bolt_blue))
                hpdf.Page_SetLineWidth(page, 1.5)
                hpdf.Page_MoveTo(page, path_x[1], path_y[1])
                for j = 2, #path_x do hpdf.Page_LineTo(page, path_x[j], path_y[j]) end
                hpdf.Page_Stroke(page)
                hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.bolt_white))
                hpdf.Page_SetLineWidth(page, 0.4)
                hpdf.Page_MoveTo(page, path_x[1], path_y[1])
                for j = 2, #path_x do hpdf.Page_LineTo(page, path_x[j], path_y[j]) end
                hpdf.Page_Stroke(page)
            end
        end,
    },
    -- }}}

    -- {{{ crystal
    crystal = {
        style_description = "Cyan hexagonal facets with internal subdivision lines, suggesting crystalline structure, geometric clarity, faceted refraction.",
        parameters = {
            {name = "facet_count",  min = 2, max = 10,
             low_words  = "single, isolated, alone, one, lone, solitary, individual, atomic, sole, lone",
             high_words = "many, scattered, dense, abundant, populated, crowded, multiple, manifold, profuse, gathered"},
            {name = "facet_radius", min = 6, max = 18,
             low_words  = "small, delicate, intricate, minute, precious, fine, jewel-like, modest, miniature, dainty",
             high_words = "monumental, large, dominant, looming, vast, imposing, grand, towering, massive, megalithic"},
        },
        draw = function(page, space, params)
            params = params or {}
            local count      = math.floor(2 + (params.facet_count  or 0.5) * 8  + 0.5)
            local max_radius = 6 + (params.facet_radius or 0.5) * 12
            hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.crystal_cyan))
            hpdf.Page_SetLineWidth(page, 0.4)
            for i = 1, count do
                local cx = space.x + math.random() * space.width
                local cy = space.y + math.random() * space.height
                local radius = max_radius * (0.5 + math.random() * 0.5)
                local first_x, first_y = cx + radius, cy
                hpdf.Page_MoveTo(page, first_x, first_y)
                for s = 1, 5 do
                    local angle = s * math.pi / 3
                    hpdf.Page_LineTo(page, cx + math.cos(angle) * radius, cy + math.sin(angle) * radius)
                end
                hpdf.Page_LineTo(page, first_x, first_y)
                hpdf.Page_Stroke(page)
                for s = 0, 5 do
                    local angle = s * math.pi / 3
                    hpdf.Page_MoveTo(page, cx, cy)
                    hpdf.Page_LineTo(page, cx + math.cos(angle) * radius, cy + math.sin(angle) * radius)
                    hpdf.Page_Stroke(page)
                end
            end
        end,
    },
    -- }}}

    -- {{{ neutral
    -- Paramless on purpose. "Intentionally minimal" is the theme's whole
    -- point; embedding-driven variation would betray that. This generator
    -- is also the fallback when cluster→generator matching fails to find
    -- any candidate above the similarity threshold.
    neutral = {
        style_description = "A single faint horizontal line in pale gray. Intentionally minimal; the visual default when nothing else fits.",
        parameters = {},
        draw = function(page, space, params)
            hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.pale_gray))
            hpdf.Page_SetLineWidth(page, 0.3)
            art.with_alpha(page, 0.4, function()
                local y = space.y + space.height * 0.5
                hpdf.Page_MoveTo(page, space.x + 10, y)
                hpdf.Page_LineTo(page, space.x + space.width - 10, y)
                hpdf.Page_Stroke(page)
            end)
        end,
    },
    -- }}}
}
-- }}}

-- {{{ M.tier2 — per-poem column-pattern generators (21 total, carved out
--     of the monolithic draw_tier2_column_patterns in compile-pdf-ai.lua by
--     Issue 031, slice A). Each entry has the same shape Tier 1 generators
--     use: {style_description, parameters, draw}. The draw bodies are the
--     pre-migration branch bodies verbatim, with two mechanical changes:
--     the legacy `cb` rectangle is now the `space` argument, and the old
--     `math.floor(N * intensity)` count (intensity was a fixed 0.8 baked at
--     the caller) is replaced by a percentile-driven parameter so each poem
--     tunes its own motif density from where it projects onto the axis.
--     themes-rebuild matches each cluster centroid to one of these by
--     cosine similarity against style_description, exactly as for Tier 1.
M.tier2 = {

    -- {{{ digital_resistance — lock symbols (encryption, privacy, surveillance resistance)
    digital_resistance = {
        style_description = "Small green padlock symbols suggesting encryption, privacy, technical activism, surveillance resistance, cryptography.",
        parameters = {
            {name = "lock_count", min = 2, max = 24,
             low_words  = "single, isolated, intimate, private, quiet, personal, lone, hidden",
             high_words = "many, ubiquitous, surveillance, swarmed, pervasive, watched, monitored, tracked"},
        },
        draw = function(page, space, params)
            params = params or {}
            local lock_count = math.floor(2 + (params.lock_count or 0.5) * 22 + 0.5)
            hpdf.Page_SetRGBStroke(page, 0.0, 0.8, 0.4)
            hpdf.Page_SetLineWidth(page, 0.5)
            for n = 1, lock_count do
                local x = space.x + math.random() * (space.width - 4)
                local y = space.y + math.random() * (space.height - 6)
                hpdf.Page_Rectangle(page, x, y, 4, 3)
                hpdf.Page_MoveTo(page, x+1, y+3)
                hpdf.Page_LineTo(page, x+1, y+5)
                hpdf.Page_LineTo(page, x+3, y+5)
                hpdf.Page_LineTo(page, x+3, y+3)
                hpdf.Page_Stroke(page)
            end
        end,
    },
    -- }}}

    -- {{{ neurodivergence — branching neural pathways
    neurodivergence = {
        style_description = "Purple branching neural pathways radiating from cluster centers, suggesting neurodivergence, atypical cognition, branching thought.",
        parameters = {
            {name = "cluster_count", min = 1, max = 6,
             low_words  = "focused, singular, calm, ordered, settled, steady, contained, quiet",
             high_words = "scattered, manifold, branching, overwhelming, racing, divergent, sprawling, restless"},
        },
        draw = function(page, space, params)
            params = params or {}
            local cluster_count = math.floor(1 + (params.cluster_count or 0.5) * 5 + 0.5)
            hpdf.Page_SetRGBStroke(page, 0.7, 0.3, 0.9)
            hpdf.Page_SetLineWidth(page, 0.3)
            for cluster = 1, cluster_count do
                local cx = space.x + math.random() * space.width
                local cy = space.y + math.random() * space.height
                for pathway = 1, 6 do
                    local angle = (pathway / 6) * 2 * math.pi
                    local length = 8 + math.random(15)
                    for segment = 1, 3 do
                        local sx = cx + (segment/3) * math.cos(angle) * length
                        local sy = cy + (segment/3) * math.sin(angle) * length
                        local br_angle = angle + (math.random() - 0.5) * 0.8
                        local br_len = 3 + math.random(8)
                        hpdf.Page_MoveTo(page, sx, sy)
                        hpdf.Page_LineTo(page, sx + math.cos(br_angle) * br_len,
                                              sy + math.sin(br_angle) * br_len)
                    end
                    hpdf.Page_Stroke(page)
                end
            end
        end,
    },
    -- }}}

    -- {{{ gender_fluidity — sinusoidal flow lines in pastel triad
    gender_fluidity = {
        style_description = "Pastel sinusoidal flow lines in pink, blue and green, suggesting fluid gender, shifting identity, gentle transformation.",
        parameters = {
            {name = "flow_count", min = 2, max = 16,
             low_words  = "rigid, fixed, binary, static, settled, singular, defined, stable",
             high_words = "fluid, shifting, flowing, manifold, changing, blurred, spectrum, evolving"},
        },
        draw = function(page, space, params)
            params = params or {}
            local flow_count = math.floor(2 + (params.flow_count or 0.5) * 14 + 0.5)
            local fluid_colors = {{0.9, 0.5, 0.8}, {0.5, 0.8, 0.9}, {0.8, 0.9, 0.5}}
            for flow = 1, flow_count do
                local color = fluid_colors[math.random(#fluid_colors)]
                hpdf.Page_SetRGBStroke(page, color[1], color[2], color[3])
                hpdf.Page_SetLineWidth(page, 0.8)
                local sx, sy = space.x, space.y + math.random() * space.height
                hpdf.Page_MoveTo(page, sx, sy)
                for x = sx, sx + space.width, 2 do
                    local wave_y = sy + math.sin((x - sx) * 0.1) * 8
                    hpdf.Page_LineTo(page, x, wave_y)
                end
                hpdf.Page_Stroke(page)
            end
        end,
    },
    -- }}}

    -- {{{ digital_loneliness — isolated nodes, broken connections
    digital_loneliness = {
        style_description = "Sparse grey-blue isolated nodes with broken dashed connections, suggesting digital loneliness, disconnection, distance between people.",
        parameters = {
            {name = "node_count", min = 2, max = 16,
             low_words  = "connected, together, bonded, present, close, near, held, accompanied",
             high_words = "isolated, scattered, alone, disconnected, distant, severed, adrift, abandoned"},
        },
        draw = function(page, space, params)
            params = params or {}
            local node_count = math.floor(2 + (params.node_count or 0.5) * 14 + 0.5)
            hpdf.Page_SetRGBStroke(page, 0.4, 0.4, 0.6)
            hpdf.Page_SetLineWidth(page, 0.4)
            for n = 1, node_count do
                local x = space.x + math.random() * space.width
                local y = space.y + math.random() * space.height
                hpdf.Page_Rectangle(page, x-1, y-1, 2, 2)
                hpdf.Page_Stroke(page)
                if math.random() > 0.5 then
                    local tx = x + (math.random() - 0.5) * 20
                    local ty = y + (math.random() - 0.5) * 20
                    for dash = 0, 1, 0.3 do
                        local d1x = x + dash * (tx - x); local d1y = y + dash * (ty - y)
                        local d2x = x + (dash + 0.15) * (tx - x); local d2y = y + (dash + 0.15) * (ty - y)
                        hpdf.Page_MoveTo(page, d1x, d1y)
                        hpdf.Page_LineTo(page, d2x, d2y)
                        hpdf.Page_Stroke(page)
                    end
                end
            end
        end,
    },
    -- }}}

    -- {{{ mutual_aid — interconnected community nodes
    mutual_aid = {
        style_description = "Green interconnected community nodes linked by a dense web of lines, suggesting mutual aid, solidarity, collective support networks.",
        parameters = {
            {name = "node_count", min = 3, max = 16,
             low_words  = "individual, solitary, self-reliant, alone, single, isolated, separate, lone",
             high_words = "collective, networked, communal, interdependent, cooperative, shared, woven, mutual"},
        },
        draw = function(page, space, params)
            params = params or {}
            local node_count = math.floor(3 + (params.node_count or 0.5) * 13 + 0.5)
            hpdf.Page_SetRGBStroke(page, 0.2, 0.8, 0.4)
            hpdf.Page_SetLineWidth(page, 0.6)
            local nodes = {}
            for n = 1, node_count do
                table.insert(nodes, {
                    x = space.x + math.random() * space.width,
                    y = space.y + math.random() * space.height,
                })
            end
            for a, n1 in ipairs(nodes) do
                for b, n2 in ipairs(nodes) do
                    if a < b and math.random() > 0.55 then
                        hpdf.Page_MoveTo(page, n1.x, n1.y)
                        hpdf.Page_LineTo(page, n2.x, n2.y)
                        hpdf.Page_Stroke(page)
                    end
                end
            end
            for _, n in ipairs(nodes) do
                hpdf.Page_Circle(page, n.x, n.y, 2)
                hpdf.Page_Stroke(page)
            end
        end,
    },
    -- }}}

    -- {{{ economic_anxiety — jagged stress lines
    economic_anxiety = {
        style_description = "Jagged red-orange stress lines jittering erratically, suggesting economic anxiety, precarity, financial volatility, instability.",
        parameters = {
            {name = "stress_count", min = 3, max = 20,
             low_words  = "secure, stable, calm, comfortable, settled, safe, assured, steady",
             high_words = "precarious, anxious, volatile, desperate, unstable, frantic, threatened, panicked"},
        },
        draw = function(page, space, params)
            params = params or {}
            local stress_count = math.floor(3 + (params.stress_count or 0.5) * 17 + 0.5)
            hpdf.Page_SetRGBStroke(page, 0.8, 0.3, 0.1)
            hpdf.Page_SetLineWidth(page, 0.4)
            for n = 1, stress_count do
                local x = space.x + math.random() * space.width
                local y = space.y + math.random() * space.height
                hpdf.Page_MoveTo(page, x, y)
                for segment = 1, 4 do
                    local nx = x + (math.random() - 0.5) * 15
                    local ny = y + (math.random() - 0.5) * 8
                    hpdf.Page_LineTo(page, nx, ny)
                    x, y = nx, ny
                end
                hpdf.Page_Stroke(page)
            end
        end,
    },
    -- }}}

    -- {{{ technomysticism — circuit mandalas
    technomysticism = {
        style_description = "Purple radial circuit mandalas with spokes ending in nodes, suggesting technomysticism, sacred technology, digital ritual, esoteric machines.",
        parameters = {
            {name = "mandala_count", min = 2, max = 12,
             low_words  = "plain, mundane, secular, literal, ordinary, grounded, prosaic, earthly",
             high_words = "sacred, mystical, esoteric, ritual, transcendent, occult, hallowed, numinous"},
        },
        draw = function(page, space, params)
            params = params or {}
            local mandala_count = math.floor(2 + (params.mandala_count or 0.5) * 10 + 0.5)
            hpdf.Page_SetRGBStroke(page, 0.6, 0.1, 0.8)
            hpdf.Page_SetLineWidth(page, 0.3)
            for n = 1, mandala_count do
                local cx = space.x + math.random() * space.width
                local cy = space.y + math.random() * space.height
                local radius = 3 + math.random(8)
                for spoke = 1, 8 do
                    local angle = (spoke / 8) * 2 * math.pi
                    local x1 = cx + math.cos(angle) * radius * 0.3
                    local y1 = cy + math.sin(angle) * radius * 0.3
                    local x2 = cx + math.cos(angle) * radius
                    local y2 = cy + math.sin(angle) * radius
                    hpdf.Page_MoveTo(page, x1, y1)
                    hpdf.Page_LineTo(page, x2, y2)
                    hpdf.Page_Stroke(page)
                    hpdf.Page_Rectangle(page, x2-1, y2-1, 2, 2)
                    hpdf.Page_Stroke(page)
                end
            end
        end,
    },
    -- }}}

    -- {{{ fragmented_consciousness — scattered broken arcs in three colors
    fragmented_consciousness = {
        style_description = "Scattered broken arc fragments in pink, blue and green, suggesting fragmented consciousness, dissociation, a shattered sense of self.",
        parameters = {
            {name = "fragment_count", min = 2, max = 16,
             low_words  = "whole, integrated, coherent, unified, intact, continuous, grounded, centered",
             high_words = "fragmented, scattered, shattered, dissociated, splintered, broken, disjointed, fractured"},
        },
        draw = function(page, space, params)
            params = params or {}
            local fragment_count = math.floor(2 + (params.fragment_count or 0.5) * 14 + 0.5)
            local frag_colors = {{0.8, 0.2, 0.6}, {0.2, 0.6, 0.8}, {0.6, 0.8, 0.2}}
            for fragment = 1, fragment_count do
                local color = frag_colors[math.random(#frag_colors)]
                hpdf.Page_SetRGBStroke(page, color[1], color[2], color[3])
                hpdf.Page_SetLineWidth(page, 0.5)
                local x = space.x + math.random() * space.width
                local y = space.y + math.random() * space.height
                local size = 4 + math.random(8)
                for arc = 1, 3 do
                    local start_angle = math.random() * math.pi * 2
                    local arc_length = math.pi * 0.3 + math.random() * math.pi * 0.4
                    for step = 0, 4 do
                        local a1 = start_angle + (step / 5) * arc_length
                        local a2 = start_angle + ((step + 1) / 5) * arc_length
                        hpdf.Page_MoveTo(page, x + math.cos(a1) * size, y + math.sin(a1) * size)
                        hpdf.Page_LineTo(page, x + math.cos(a2) * size, y + math.sin(a2) * size)
                        hpdf.Page_Stroke(page)
                    end
                end
            end
        end,
    },
    -- }}}

    -- {{{ gaming_culture — 8-bit pixel shapes (cubes / plus / diamond)
    gaming_culture = {
        style_description = "Green 8-bit pixel shapes — power-up cubes, plus signs and diamonds, suggesting gaming culture, retro arcades, playful digital nostalgia.",
        parameters = {
            {name = "pixel_count", min = 3, max = 20,
             low_words  = "sparse, quiet, analog, restrained, minimal, plain, empty, still",
             high_words = "dense, playful, pixelated, abundant, busy, arcade, frenetic, crowded"},
        },
        draw = function(page, space, params)
            params = params or {}
            local pixel_count = math.floor(3 + (params.pixel_count or 0.5) * 17 + 0.5)
            hpdf.Page_SetRGBStroke(page, 0.1, 0.8, 0.2)
            hpdf.Page_SetLineWidth(page, 0.6)
            for n = 1, pixel_count do
                local x = space.x + math.random() * (space.width - 8)
                local y = space.y + math.random() * (space.height - 8)
                local pattern = math.random(3)
                if pattern == 1 then
                    -- power-up cube
                    hpdf.Page_Rectangle(page, x, y, 6, 6)
                    hpdf.Page_Rectangle(page, x+2, y+2, 2, 2)
                elseif pattern == 2 then
                    -- plus
                    hpdf.Page_Rectangle(page, x+2, y, 2, 6)
                    hpdf.Page_Rectangle(page, x, y+2, 6, 2)
                else
                    -- diamond
                    hpdf.Page_MoveTo(page, x+3, y)
                    hpdf.Page_LineTo(page, x+6, y+3)
                    hpdf.Page_LineTo(page, x+3, y+6)
                    hpdf.Page_LineTo(page, x, y+3)
                    hpdf.Page_LineTo(page, x+3, y)
                end
                hpdf.Page_Stroke(page)
            end
        end,
    },
    -- }}}

    -- {{{ environmental_awareness — stems with paired leaves
    environmental_awareness = {
        style_description = "Green plant stems with paired leaves growing at random angles, suggesting environmental awareness, ecology, flora, the living world.",
        parameters = {
            {name = "stem_count", min = 2, max = 14,
             low_words  = "barren, sparse, depleted, dormant, bare, withered, scarce, dry",
             high_words = "lush, growing, verdant, thriving, abundant, flourishing, green, fertile"},
        },
        draw = function(page, space, params)
            params = params or {}
            local stem_count = math.floor(2 + (params.stem_count or 0.5) * 12 + 0.5)
            hpdf.Page_SetRGBStroke(page, 0.2, 0.7, 0.3)
            hpdf.Page_SetLineWidth(page, 0.4)
            for n = 1, stem_count do
                local sx = space.x + math.random() * space.width
                local sy = space.y + math.random() * space.height
                local angle = math.random() * math.pi * 2
                local length = 8 + math.random(15)
                local ex = sx + math.cos(angle) * length
                local ey = sy + math.sin(angle) * length
                hpdf.Page_MoveTo(page, sx, sy)
                hpdf.Page_LineTo(page, ex, ey)
                hpdf.Page_Stroke(page)
                for leaf = 1, 2 do
                    local leaf_angle = angle + (leaf == 1 and 0.5 or -0.5)
                    local leaf_length = 4 + math.random(6)
                    local lx = ex + math.cos(leaf_angle) * leaf_length
                    local ly = ey + math.sin(leaf_angle) * leaf_length
                    hpdf.Page_MoveTo(page, ex, ey)
                    hpdf.Page_LineTo(page, lx, ly)
                    hpdf.Page_LineTo(page,
                        ex + math.cos(leaf_angle + 0.3) * leaf_length * 0.7,
                        ey + math.sin(leaf_angle + 0.3) * leaf_length * 0.7)
                    hpdf.Page_Stroke(page)
                end
            end
        end,
    },
    -- }}}

    -- {{{ programming_philosophy — code-like dashes
    programming_philosophy = {
        style_description = "Short green horizontal code-like dashes scattered as terminal text, suggesting programming philosophy, software craft, the poetry of code.",
        parameters = {
            {name = "token_count", min = 2, max = 16,
             low_words  = "terse, minimal, sparse, atomic, brief, concise, plain, spare",
             high_words = "verbose, dense, elaborate, layered, intricate, complex, prolific, woven"},
        },
        draw = function(page, space, params)
            params = params or {}
            local token_count = math.floor(2 + (params.token_count or 0.5) * 14 + 0.5)
            hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.code_green))
            hpdf.Page_SetLineWidth(page, 0.4)
            for n = 1, token_count do
                local x = space.x + math.random() * (space.width - 8)
                local y = space.y + math.random() * space.height
                hpdf.Page_MoveTo(page, x, y)
                hpdf.Page_LineTo(page, x + 6, y)
                hpdf.Page_Stroke(page)
            end
        end,
    },
    -- }}}

    -- {{{ anarchist_theory — horizontal-only bars (no verticals = no hierarchy)
    -- The absence of vertical structure is the point: every bar floats at
    -- its own random height, none above or below another in any tree sense.
    -- Charcoal because the classic anarchist palette would be black-and-red,
    -- and red is reserved across this project.
    anarchist_theory = {
        style_description = "Floating charcoal horizontal bars at random heights with no vertical connections, suggesting anarchist theory, horizontalism, the refusal of hierarchy.",
        parameters = {
            {name = "bar_count", min = 4, max = 28,
             low_words  = "singular, quiet, sparse, restrained, lone, minimal, hushed, few",
             high_words = "many, proliferating, horizontal, distributed, leaderless, dispersed, collective, multiplying"},
        },
        draw = function(page, space, params)
            params = params or {}
            local bar_count = math.floor(4 + (params.bar_count or 0.5) * 24 + 0.5)
            hpdf.Page_SetRGBStroke(page, 0.15, 0.15, 0.15)
            hpdf.Page_SetLineWidth(page, 0.6)
            for n = 1, bar_count do
                local y = space.y + math.random() * space.height
                local x1 = space.x + math.random() * space.width
                local x2 = x1 + 4 + math.random() * 16
                if x2 > space.x + space.width then x2 = space.x + space.width end
                hpdf.Page_MoveTo(page, x1, y)
                hpdf.Page_LineTo(page, x2, y)
                hpdf.Page_Stroke(page)
            end
        end,
    },
    -- }}}

    -- {{{ ai_consciousness — layered neural-net diagram with sparse edges
    -- Three vertical columns of small circles ("neurons"), with thin
    -- connections drawn between adjacent layers at random — the topology
    -- everyone draws when they're trying to picture what a model "is."
    -- Different from technomysticism (radial mandalas) and neurodivergence
    -- (single-center branching) because this is explicitly LAYERED.
    ai_consciousness = {
        style_description = "Light-blue layered neural network diagrams with columns of neurons and sparse edges between layers, suggesting artificial intelligence, machine minds, model cognition.",
        parameters = {
            {name = "network_count", min = 1, max = 4,
             low_words  = "simple, singular, shallow, sparse, small, plain, lone, minimal",
             high_words = "layered, manifold, deep, networked, complex, dense, multiple, intricate"},
        },
        draw = function(page, space, params)
            params = params or {}
            local network_count = math.floor(1 + (params.network_count or 0.5) * 3 + 0.5)
            hpdf.Page_SetRGBStroke(page, 0.4, 0.7, 0.95)
            hpdf.Page_SetLineWidth(page, 0.3)
            for net = 1, network_count do
                local cx = space.x + 15 + math.random() * (space.width - 30)
                local cy = space.y + 15 + math.random() * (space.height - 30)
                local net_w, net_h = 28, 24
                local n_layers, nodes_per_layer = 3, 3
                local prev = nil
                for layer = 1, n_layers do
                    local lx = cx - net_w/2 + ((layer-1)/(n_layers-1)) * net_w
                    local current = {}
                    for node = 1, nodes_per_layer do
                        local ny = cy - net_h/2 + ((node-1)/(nodes_per_layer-1)) * net_h
                        table.insert(current, {x = lx, y = ny})
                        hpdf.Page_Circle(page, lx, ny, 0.9)
                        hpdf.Page_Stroke(page)
                    end
                    if prev then
                        for _, p in ipairs(prev) do
                            for _, c in ipairs(current) do
                                if math.random() > 0.5 then
                                    hpdf.Page_MoveTo(page, p.x, p.y)
                                    hpdf.Page_LineTo(page, c.x, c.y)
                                    hpdf.Page_Stroke(page)
                                end
                            end
                        end
                    end
                    prev = current
                end
            end
        end,
    },
    -- }}}

    -- {{{ local_organizing — tight ring of people, adjacent ones in conversation
    -- A meeting: 5-8 attendees arranged on a circle, lines only between
    -- spatial neighbors (you talk to whoever is next to you). Visually
    -- compact, deliberately not a mesh — distinct from mutual_aid's
    -- dispersed help-network and online_communities' federated clusters.
    local_organizing = {
        style_description = "Orange tight rings of people connected to their neighbors, suggesting local organizing, community meetings, face-to-face assembly.",
        parameters = {
            {name = "meeting_count", min = 1, max = 4,
             low_words  = "solitary, individual, dispersed, quiet, alone, scattered, private, lone",
             high_words = "gathered, collective, organized, convened, assembled, united, communal, mobilized"},
        },
        draw = function(page, space, params)
            params = params or {}
            local meeting_count = math.floor(1 + (params.meeting_count or 0.5) * 3 + 0.5)
            hpdf.Page_SetRGBStroke(page, 0.9, 0.55, 0.2)
            hpdf.Page_SetLineWidth(page, 0.5)
            for meeting = 1, meeting_count do
                local cx = space.x + 14 + math.random() * (space.width - 28)
                local cy = space.y + 14 + math.random() * (space.height - 28)
                local people = 5 + math.random(3)
                local radius = 10
                local positions = {}
                for p = 1, people do
                    local angle = (p - 1) * 2 * math.pi / people + math.random() * 0.2
                    local px = cx + math.cos(angle) * radius
                    local py = cy + math.sin(angle) * radius
                    table.insert(positions, {x = px, y = py})
                    hpdf.Page_Circle(page, px, py, 1.4)
                    hpdf.Page_Stroke(page)
                end
                for p = 1, people do
                    local q = (p % people) + 1
                    hpdf.Page_MoveTo(page, positions[p].x, positions[p].y)
                    hpdf.Page_LineTo(page, positions[q].x, positions[q].y)
                    hpdf.Page_Stroke(page)
                end
            end
        end,
    },
    -- }}}

    -- {{{ intimate_relationships — paired circles bridged by a curved arc
    -- Two beings, one bond. The bridge is a sampled half-sine (an upward
    -- bow) rather than a straight line so each pair feels held rather than
    -- merely connected. Single-pair structure, never networks — the
    -- "love is two people facing each other" framing.
    intimate_relationships = {
        style_description = "Warm coral paired circles bridged by a gentle curved arc, suggesting intimate relationships, two people facing each other, tender one-to-one bonds.",
        parameters = {
            {name = "pair_count", min = 2, max = 16,
             low_words  = "solitary, distant, separate, alone, single, apart, unattached, withdrawn",
             high_words = "intimate, paired, bonded, entwined, close, coupled, tender, embracing"},
        },
        draw = function(page, space, params)
            params = params or {}
            local pair_count = math.floor(2 + (params.pair_count or 0.5) * 14 + 0.5)
            hpdf.Page_SetRGBStroke(page, 1.0, 0.65, 0.55)
            hpdf.Page_SetLineWidth(page, 0.45)
            for pair = 1, pair_count do
                local x = space.x + math.random() * (space.width - 18)
                local y = space.y + 4 + math.random() * (space.height - 8)
                local sep = 8 + math.random() * 6
                hpdf.Page_Circle(page, x, y, 1.8)
                hpdf.Page_Stroke(page)
                hpdf.Page_Circle(page, x + sep, y, 1.8)
                hpdf.Page_Stroke(page)
                hpdf.Page_MoveTo(page, x, y)
                local steps = 8
                for s = 1, steps do
                    local t = s / steps
                    local bx = x + t * sep
                    local by = y + math.sin(t * math.pi) * 2.8
                    hpdf.Page_LineTo(page, bx, by)
                end
                hpdf.Page_Stroke(page)
            end
        end,
    },
    -- }}}

    -- {{{ mental_overflow — dense tangle clusters with stack-overflow spillover
    -- The keyword list literally includes "stack-overflow" and "cascade", so
    -- the visual is a clutch of tangled short segments around a center plus
    -- the occasional segment whose second endpoint blows past the cluster
    -- radius — overflow. Magenta because the affect is "wired", not calm.
    mental_overflow = {
        style_description = "Magenta dense tangled segment clusters with occasional spillover past the cluster radius, suggesting mental overflow, racing thoughts, cascade, overwhelm.",
        parameters = {
            {name = "cluster_count", min = 1, max = 4,
             low_words  = "calm, clear, ordered, spacious, settled, quiet, composed, serene",
             high_words = "overwhelmed, racing, cascading, flooded, frantic, tangled, spiraling, swamped"},
        },
        draw = function(page, space, params)
            params = params or {}
            local cluster_count = math.floor(1 + (params.cluster_count or 0.5) * 3 + 0.5)
            hpdf.Page_SetRGBStroke(page, 0.95, 0.4, 0.85)
            hpdf.Page_SetLineWidth(page, 0.35)
            for cluster = 1, cluster_count do
                local cx = space.x + 10 + math.random() * (space.width - 20)
                local cy = space.y + 10 + math.random() * (space.height - 20)
                local segs = 14 + math.random(8)
                for s = 1, segs do
                    local a1 = math.random() * 2 * math.pi
                    local a2 = math.random() * 2 * math.pi
                    local r1 = math.random() * 8
                    local r2 = math.random() * 8
                    if math.random() > 0.85 then  -- 15% spill outside cluster radius
                        r2 = r2 + 8 + math.random() * 8
                    end
                    hpdf.Page_MoveTo(page, cx + math.cos(a1) * r1, cy + math.sin(a1) * r1)
                    hpdf.Page_LineTo(page, cx + math.cos(a2) * r2, cy + math.sin(a2) * r2)
                    hpdf.Page_Stroke(page)
                end
            end
        end,
    },
    -- }}}

    -- {{{ plural_systems — corner-bracketed region with distinct-colored alters
    -- The boundary is two L-shaped corner brackets (top-left + bottom-right)
    -- rather than a full rectangle, so it reads as "frame" rather than
    -- "second poem box". Inside, 2-4 dot clusters in different colors — each
    -- one an alter. Distinct from fragmented_consciousness's broken arcs
    -- because here the parts are intact, organized, and bounded.
    plural_systems = {
        style_description = "Corner-bracketed frames holding several distinct-colored dot clusters, suggesting plural systems, multiplicity, alters sharing one bounded inner world.",
        parameters = {
            {name = "system_count", min = 1, max = 4,
             low_words  = "singular, unified, solitary, one, single, alone, whole, individual",
             high_words = "plural, multiple, many, collective, several, manifold, shared, populated"},
        },
        draw = function(page, space, params)
            params = params or {}
            local system_count = math.floor(1 + (params.system_count or 0.5) * 3 + 0.5)
            local alter_colors = {
                {0.85, 0.45, 0.45}, {0.45, 0.7, 0.85},
                {0.55, 0.8, 0.55}, {0.85, 0.75, 0.4},
            }
            for system = 1, system_count do
                local sx = space.x + 6 + math.random() * math.max(1, (space.width - 32))
                local sy = space.y + 6 + math.random() * math.max(1, (space.height - 26))
                local sw, sh, bracket = 26, 20, 3
                hpdf.Page_SetRGBStroke(page, 0.5, 0.5, 0.5)
                hpdf.Page_SetLineWidth(page, 0.4)
                -- top-left bracket
                hpdf.Page_MoveTo(page, sx, sy + sh - bracket)
                hpdf.Page_LineTo(page, sx, sy + sh)
                hpdf.Page_LineTo(page, sx + bracket, sy + sh)
                hpdf.Page_Stroke(page)
                -- bottom-right bracket
                hpdf.Page_MoveTo(page, sx + sw - bracket, sy)
                hpdf.Page_LineTo(page, sx + sw, sy)
                hpdf.Page_LineTo(page, sx + sw, sy + bracket)
                hpdf.Page_Stroke(page)
                local n_alters = 2 + math.random(2)
                for alter = 1, n_alters do
                    local color = alter_colors[((alter - 1) % #alter_colors) + 1]
                    hpdf.Page_SetRGBStroke(page, color[1], color[2], color[3])
                    hpdf.Page_SetLineWidth(page, 0.4)
                    local ax = sx + ((alter - 0.5) / n_alters) * sw
                    local ay = sy + 3 + math.random() * (sh - 6)
                    for d = 1, 4 + math.random(3) do
                        local dx = ax + (math.random() - 0.5) * 4
                        local dy = ay + (math.random() - 0.5) * 4
                        hpdf.Page_Circle(page, dx, dy, 0.7)
                        hpdf.Page_Stroke(page)
                    end
                end
            end
        end,
    },
    -- }}}

    -- {{{ economic_systems — rectangle pairs joined by directional arrows
    -- Capital and labor flowing between entities. Two rectangles (firms,
    -- households, nations) with an arrow from one to the other. Distinct
    -- from economic_anxiety's emotional jagged stress lines — this is the
    -- analytical-diagram view, not the felt one. Steel grey because finance.
    economic_systems = {
        style_description = "Steel-grey rectangle pairs joined by directional arrows, suggesting economic systems, flows of capital and labor between firms, the analytical view of money.",
        parameters = {
            {name = "flow_count", min = 2, max = 10,
             low_words  = "isolated, static, simple, local, single, closed, small, contained",
             high_words = "systemic, flowing, networked, global, interconnected, circulating, vast, structural"},
        },
        draw = function(page, space, params)
            params = params or {}
            local flow_count = math.floor(2 + (params.flow_count or 0.5) * 8 + 0.5)
            hpdf.Page_SetRGBStroke(page, 0.45, 0.55, 0.6)
            hpdf.Page_SetLineWidth(page, 0.45)
            for n = 1, flow_count do
                local x1 = space.x + math.random() * math.max(1, (space.width - 28))
                local y1 = space.y + math.random() * math.max(1, (space.height - 10))
                hpdf.Page_Rectangle(page, x1, y1, 6, 4)
                hpdf.Page_Stroke(page)
                local x2 = x1 + 12 + math.random() * 8
                local y2 = y1 + (math.random() - 0.5) * 6
                hpdf.Page_Rectangle(page, x2, y2, 6, 4)
                hpdf.Page_Stroke(page)
                -- Arrow from right side of source to left side of target
                local fx, fy = x1 + 6, y1 + 2
                local tx, ty = x2, y2 + 2
                hpdf.Page_MoveTo(page, fx, fy)
                hpdf.Page_LineTo(page, tx, ty)
                hpdf.Page_Stroke(page)
                -- Arrowhead: unit vector + perpendicular, no atan2 (lua 5.2)
                local dx, dy = tx - fx, ty - fy
                local len = math.sqrt(dx*dx + dy*dy)
                if len > 0 then
                    local ux, uy = dx/len, dy/len
                    local px, py = -uy, ux  -- perpendicular
                    local h_len, h_wid = 2, 1.5
                    hpdf.Page_MoveTo(page, tx, ty)
                    hpdf.Page_LineTo(page,
                        tx - h_len*ux + h_wid*px, ty - h_len*uy + h_wid*py)
                    hpdf.Page_MoveTo(page, tx, ty)
                    hpdf.Page_LineTo(page,
                        tx - h_len*ux - h_wid*px, ty - h_len*uy - h_wid*py)
                    hpdf.Page_Stroke(page)
                end
            end
        end,
    },
    -- }}}

    -- {{{ online_communities — federated clusters: dense inside, sparse between
    -- 2-4 small node-clusters per box, each cluster heavily interconnected
    -- internally, with maybe one thin bridge between any two clusters. The
    -- fediverse topology made explicit: a Mastodon instance is internally
    -- chatty; the federation between instances is the thin layer on top.
    online_communities = {
        style_description = "Teal federated clusters, each densely interconnected inside with thin bridges between them, suggesting online communities, the fediverse, networked instances.",
        parameters = {
            {name = "federation_count", min = 1, max = 3,
             low_words  = "isolated, single, local, closed, lone, walled, separate, private",
             high_words = "federated, networked, distributed, interconnected, sprawling, linked, bridged, manifold"},
        },
        draw = function(page, space, params)
            params = params or {}
            local federation_count = math.floor(1 + (params.federation_count or 0.5) * 2 + 0.5)
            hpdf.Page_SetRGBStroke(page, 0.0, 0.65, 0.75)
            hpdf.Page_SetLineWidth(page, 0.4)
            for fed = 1, federation_count do
                local n_instances = 2 + math.random(2)
                local instances = {}
                for inst = 1, n_instances do
                    local cx = space.x + 8 + math.random() * math.max(1, space.width - 16)
                    local cy = space.y + 8 + math.random() * math.max(1, space.height - 16)
                    local members = {}
                    for m = 1, 4 + math.random(3) do
                        local mx = cx + (math.random() - 0.5) * 8
                        local my = cy + (math.random() - 0.5) * 8
                        table.insert(members, {x = mx, y = my})
                        hpdf.Page_Circle(page, mx, my, 0.8)
                        hpdf.Page_Stroke(page)
                    end
                    for a, m1 in ipairs(members) do
                        for b, m2 in ipairs(members) do
                            if a < b and math.random() > 0.45 then
                                hpdf.Page_MoveTo(page, m1.x, m1.y)
                                hpdf.Page_LineTo(page, m2.x, m2.y)
                                hpdf.Page_Stroke(page)
                            end
                        end
                    end
                    table.insert(instances, {x = cx, y = cy})
                end
                -- thin bridges between instances
                for a, i1 in ipairs(instances) do
                    for b, i2 in ipairs(instances) do
                        if a < b and math.random() > 0.5 then
                            hpdf.Page_MoveTo(page, i1.x, i1.y)
                            hpdf.Page_LineTo(page, i2.x, i2.y)
                            hpdf.Page_Stroke(page)
                        end
                    end
                end
            end
        end,
    },
    -- }}}

    -- {{{ social_media_fatigue — parallel scroll-lines fading from top to bottom
    -- The infinite feed: dense bands at the top where attention is fresh,
    -- thinning out as you scroll, with the occasional empty post-card
    -- rectangle interrupting the rhythm. Washed-out cool tone — the color
    -- of staring at a phone too long.
    social_media_fatigue = {
        style_description = "Washed-out cool parallel scroll lines thinning from top to bottom with occasional empty post-card rectangles, suggesting social media fatigue, the infinite feed, doomscrolling.",
        parameters = {
            {name = "feed_density", min = 8, max = 30,
             low_words  = "calm, brief, restful, sparse, quiet, finite, light, occasional",
             high_words = "endless, overwhelming, scrolling, saturated, relentless, infinite, dense, numbing"},
        },
        draw = function(page, space, params)
            params = params or {}
            local line_count = math.floor(8 + (params.feed_density or 0.5) * 22 + 0.5)
            hpdf.Page_SetRGBStroke(page, 0.45, 0.6, 0.65)
            hpdf.Page_SetLineWidth(page, 0.25)
            for n = 1, line_count do
                local progress = n / line_count
                -- skip probability grows with depth → density fades downward
                if math.random() > progress * 0.7 then
                    local y = space.y + (1 - progress) * space.height
                    local x1 = space.x + math.random() * 6
                    local x2 = x1 + 10 + math.random() * math.max(1, (space.width - 12))
                    if x2 > space.x + space.width then x2 = space.x + space.width end
                    hpdf.Page_MoveTo(page, x1, y)
                    hpdf.Page_LineTo(page, x2, y)
                    hpdf.Page_Stroke(page)
                    if math.random() > 0.88 then  -- rare post-card box
                        local px = space.x + math.random() * math.max(1, (space.width - 8))
                        hpdf.Page_Rectangle(page, px, y - 2, 6, 4)
                        hpdf.Page_Stroke(page)
                    end
                end
            end
        end,
    },
    -- }}}

    -- {{{ default — small decorative dashes for any poem without a matched motif
    -- Paramless on purpose, mirroring tier1.neutral: this is the visual
    -- default when cluster→generator matching falls below threshold. It is
    -- the migrated old fallback (the four faint lavender marks), and per
    -- Issue 031 it is the ONLY fallback once the legacy monolith is gone.
    default = {
        style_description = "A few small scattered decorative dashes in pale lavender. Intentionally minimal; the per-poem visual default when no Tier 2 motif fits.",
        parameters = {},
        draw = function(page, space, params)
            hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.fallback_lavender))
            hpdf.Page_SetLineWidth(page, 0.3)
            for n = 1, 5 do
                local x = space.x + math.random() * (space.width - 4)
                local y = space.y + math.random() * space.height
                local size = 2 + math.random(4)
                hpdf.Page_Rectangle(page, x, y, size, 1)
                hpdf.Page_Stroke(page)
            end
        end,
    },
    -- }}}
}
-- }}}

return M
