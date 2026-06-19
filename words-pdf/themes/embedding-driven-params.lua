-- Embedding-driven parameter config for compile-pdf-ai.lua art generators.
--
-- Each entry defines one parameter that a generator drives from the page's
-- embedding rather than from math.random(). At startup, every positive and
-- negative keyword list is embedded; the axis between them becomes a
-- directed direction in embedding space. For each page, the text is
-- embedded, projected onto that axis, and the resulting score is
-- percentile-ranked across the corpus. The percentile (in [0, 1]) maps
-- linearly to the parameter's [low, high] range and reaches the generator.
--
-- Keyword lists are dense and short on purpose — shared filler like "this
-- writing describes" would dilute the discriminating signal, since the
-- model encodes identical strings identically.
--
-- Generators of restrained character (isolation, melancholy) get a single
-- axis on purpose: emptiness and quietness are part of their visual
-- vocabulary. Neutral stays paramless — "intentionally minimal" is the
-- whole point of that theme.

return {
    -- {{{ resistance — explosive radials of revolt
    resistance = {
        {
            name = "ray_count", low = 4, high = 25,
            positive = "uprising, militant, organizing, mobilizing, surging, masses, revolt, swarming, mass-action, collective",
            negative = "solitary, private, internal, quiet, individual, lone, alone, single, hushed, withdrawn",
        },
        {
            name = "ray_length", low = 8, high = 30,
            positive = "reaching, far-reaching, vast, sprawling, overwhelming, sweeping, expansive, dominant, encompassing, total",
            negative = "contained, near, confined, local, modest, restrained, limited, close, immediate, small",
        },
    },
    -- }}}

    -- {{{ technology — green circuit traces of system thinking
    technology = {
        {
            name = "trace_count", low = 4, high = 20,
            positive = "distributed, networked, intricate, dense, complex, layered, elaborate, sophisticated, woven, meshed",
            negative = "simple, monolithic, sparse, plain, atomic, basic, single, minimal, raw, elementary",
        },
        {
            name = "trace_length", low = 6, high = 24,
            positive = "infrastructure, architectural, scaling, sprawling, large-scale, framework, expansive, sweeping, system-wide, foundational",
            negative = "atomic, modular, local, isolated, component, contained, small, brief, discrete, scoped",
        },
    },
    -- }}}

    -- {{{ creativity — brush-stroke flow of making
    creativity = {
        {
            name = "stroke_count", low = 4, high = 18,
            positive = "prolific, abundant, generative, fertile, productive, flowing, copious, expansive, profuse, overflowing",
            negative = "spare, distilled, refined, restrained, deliberate, minimal, considered, careful, sparse, terse",
        },
        {
            name = "stroke_jaggedness", low = 1, high = 6,
            positive = "wild, spontaneous, untamed, frenzied, raw, frantic, expressive, unrestrained, gestural, impulsive",
            negative = "deliberate, composed, smooth, measured, planned, controlled, even, contained, considered, polished",
        },
        {
            name = "color_richness", low = 1, high = 3,
            positive = "vibrant, saturated, kaleidoscopic, prismatic, riotous, exuberant, lush, vivid, rich, jubilant",
            negative = "monochrome, restrained, subdued, single-hued, focused, narrow, austere, spare, quiet, muted",
        },
    },
    -- }}}

    -- {{{ isolation — sparse marks of separation
    -- Only one axis: isolation should always be sparse; we only vary how
    -- present the sparse marks are. Mark count is intentionally not driven.
    isolation = {
        {
            name = "alpha_level", low = 0.3, high = 0.95,
            positive = "present, tangible, immediate, here, real, embodied, palpable, vivid, weighted, anchored",
            negative = "ghostly, faded, distant, removed, intangible, dim, fading, evanescent, vanishing, spectral",
        },
    },
    -- }}}

    -- {{{ identity — prismatic refraction of self
    identity = {
        {
            name = "shape_count", low = 3, high = 12,
            positive = "multifaceted, plural, manifold, layered, complex, kaleidoscopic, varied, many-sided, prismatic, multitudinous",
            negative = "singular, unified, focused, simple, consolidated, integrated, whole, one, distilled, essential",
        },
        {
            name = "offset_magnitude", low = 1, high = 6,
            positive = "fragmented, dispersed, scattered, divided, split, refracted, disjointed, separated, shattered, broken",
            negative = "aligned, centered, coherent, focused, integrated, unified, together, gathered, cohesive, whole",
        },
    },
    -- }}}

    -- {{{ systems — blueprint nodes of structural thought
    systems = {
        {
            name = "node_count", low = 4, high = 16,
            positive = "vast, sprawling, comprehensive, infrastructure, network, large-scale, encompassing, expansive, federated, planetary",
            negative = "small, intimate, local, modest, contained, atomic, simple, minimal, household, neighborhood",
        },
        {
            name = "line_weight", low = 0.3, high = 1.2,
            positive = "infrastructural, monumental, heavy, weighted, established, anchored, substantial, fixed, durable, permanent",
            negative = "diagrammatic, sketched, light, provisional, draft, ephemeral, fluid, tentative, hypothetical, proposed",
        },
    },
    -- }}}

    -- {{{ connection — warm braids of bonding
    connection = {
        {
            name = "curve_count", low = 3, high = 14,
            positive = "many, dense, abundant, numerous, populated, multitude, manifold, crowded, plentiful, woven",
            negative = "few, scarce, sparse, limited, single, rare, isolated, alone, singular, lone",
        },
        {
            name = "sway_magnitude", low = 8, high = 50,
            positive = "dramatic, sweeping, turbulent, intense, wild, sweeping, swirling, churning, passionate, fierce",
            negative = "subtle, gentle, quiet, restrained, steady, calm, still, even, soft, measured",
        },
        {
            name = "alpha_layering", low = 0.3, high = 0.7,
            positive = "interwoven, layered, overlapping, braided, knotted, dense, blended, merged, fused, entangled",
            negative = "separate, parallel, distinct, individual, side-by-side, adjacent, clean, discrete, unblended, apart",
        },
    },
    -- }}}

    -- {{{ chaos — RGB-shifted glitch of breakdown
    chaos = {
        {
            name = "glitch_count", low = 4, high = 20,
            positive = "overwhelming, cascading, prolific, swarming, multiplying, exploding, breaking, fragmenting, surging, drowning",
            negative = "stable, contained, singular, isolated, momentary, brief, occasional, sporadic, fleeting, transient",
        },
        {
            name = "shift_magnitude", low = 1, high = 6,
            positive = "corrupted, broken, malfunctioning, disrupted, scrambled, distorted, garbled, decayed, ruined, shattered",
            negative = "intact, aligned, coherent, registered, clean, sharp, focused, stable, ordered, calibrated",
        },
    },
    -- }}}

    -- {{{ transcendence — mandala geometry of mystical layering
    transcendence = {
        {
            name = "ring_count", low = 2, high = 8,
            positive = "layered, recursive, mystical, manifold, nested, esoteric, deep",
            negative = "singular, direct, plain, immediate, one-pointed, clear, surface",
        },
        {
            name = "radial_count", low = 4, high = 16,
            positive = "ritual, structured, ceremonial, ordered, geometric, formal, repeating",
            negative = "spontaneous, free-form, intuitive, organic, unmeasured, improvised, loose",
        },
        {
            name = "gold_center_size", low = 1, high = 6,
            positive = "revelation, clear, central, illumination, focus, anchor, certainty",
            negative = "diffuse, vague, undefined, peripheral, scattered, unclear, ambient",
        },
    },
    -- }}}

    -- {{{ survival — root systems of resourcefulness
    survival = {
        {
            name = "trunk_count", low = 1, high = 6,
            positive = "abundant, plentiful, fertile, plenty, replete, ample, sustained, supported, surplus, secure",
            negative = "scarce, sparse, lean, depleted, exhausted, barren, threadbare, last-ditch, precarious, hungry",
        },
        {
            name = "branch_count", low = 2, high = 10,
            positive = "branching, ramifying, resourceful, adaptive, networked, distributed, redundant, layered, multiplied, varied",
            negative = "single, direct, lean, austere, simple, basic, raw, unembellished, focused, narrow",
        },
    },
    -- }}}

    -- {{{ nature — branching curves of organic growth
    nature = {
        {
            name = "stem_count", low = 4, high = 18,
            positive = "lush, abundant, dense, thriving, growing, flourishing, verdant, profuse, fecund, jungle",
            negative = "sparse, austere, bare, minimal, restrained, quiet, barren, simple, desert, scarce",
        },
        {
            name = "branch_recursion", low = 2, high = 8,
            positive = "fractal, recursive, branching, manifold, ramifying, growing, layered, deep, complex, generative",
            negative = "simple, direct, straight, unembellished, plain, atomic, single, bare, sapling, sprout",
        },
    },
    -- }}}

    -- {{{ urban — neon rectangles of built density
    urban = {
        {
            name = "block_count", low = 5, high = 30,
            positive = "dense, crowded, packed, busy, populated, thick, congested, swarming, teeming, bustling",
            negative = "sparse, empty, deserted, vacant, quiet, abandoned, hollow, depopulated, ghostly, silent",
        },
        {
            name = "block_scale", low = 10, high = 35,
            positive = "monumental, towering, vast, imposing, grand, massive, sprawling, dominating, megalithic, looming",
            negative = "small, intimate, local, modest, neighborhood, compact, miniature, close, walkable, human-scale",
        },
    },
    -- }}}

    -- {{{ energy — radiating bursts of force
    energy = {
        {
            name = "focal_count", low = 1, high = 4,
            positive = "multiple, dispersed, distributed, several, many, scattered, plural, manifold, diffuse, parallel",
            negative = "single, central, focused, unified, concentrated, one, alone, solo, pointed, singular",
        },
        {
            name = "ray_count", low = 8, high = 35,
            positive = "explosive, intense, overwhelming, dazzling, blazing, radiant, blinding, fierce, incandescent, supernova",
            negative = "subtle, gentle, quiet, mild, faint, dim, restrained, soft, muted, smoldering",
        },
    },
    -- }}}

    -- {{{ love — braided pink curves of bonding
    love = {
        {
            name = "braid_count", low = 2, high = 10,
            positive = "intertwined, woven, bound, joined, embraced, knotted, intimate, bonded, entwined, locked",
            negative = "separate, distant, parallel, apart, distinct, separated, individual, lonesome, solo, untouched",
        },
        {
            name = "sway_intensity", low = 6, high = 24,
            positive = "passionate, fierce, dramatic, intense, sweeping, turbulent, ardent, fervent, consuming, all-encompassing",
            negative = "gentle, tender, soft, quiet, calm, peaceful, steady, mild, easy, comfortable",
        },
    },
    -- }}}

    -- {{{ melancholy — downward strokes of sorrow
    -- Single axis: melancholy is melancholy; we only vary how saturated.
    -- Drop count and length being one parameter (saturation) preserves the
    -- emotional character without giving sorrow knobs that feel mechanical.
    melancholy = {
        {
            name = "saturation", low = 0.2, high = 1.0,
            positive = "overwhelming, drowning, cascading, falling, persistent, ceaseless, weeping, flooding, deluging, engulfing",
            negative = "passing, fleeting, momentary, occasional, distant, faint, brief, slight, wisp, shadow",
        },
    },
    -- }}}

    -- {{{ dream — purple sine waves of reverie
    dream = {
        {
            name = "wave_count", low = 3, high = 14,
            positive = "layered, multiple, manifold, complex, woven, nested, deep, intricate, hypnagogic, recursive",
            negative = "single, clear, focused, simple, direct, plain, atomic, lone, lucid, isolated",
        },
        {
            name = "amplitude", low = 6, high = 30,
            positive = "vivid, immersive, transporting, surreal, profound, fantastical, intense, otherworldly, kaleidoscopic, immersive",
            negative = "subtle, faint, fading, gentle, restrained, quiet, dim, peripheral, fleeting, half-remembered",
        },
    },
    -- }}}

    -- {{{ constellation — gold stars and connecting lines
    constellation = {
        {
            name = "star_count", low = 6, high = 24,
            positive = "many, abundant, scattered, plentiful, populated, multitude, profuse, dense, swarming, infinite",
            negative = "few, sparse, scattered, isolated, single, rare, sparse, alone, solitary, lone",
        },
        {
            name = "star_size", low = 0.5, high = 2.5,
            positive = "luminous, bright, brilliant, dazzling, radiant, blazing, gleaming, shining, beaming, lucent",
            negative = "dim, faint, fading, weak, distant, ghostly, pale, subtle, hushed, withdrawn",
        },
    },
    -- }}}

    -- {{{ spiral — concentric arcs of whirling motion
    spiral = {
        {
            name = "segment_count", low = 10, high = 40,
            positive = "vast, endless, expanding, growing, sprawling, infinite, boundless, unfolding, perpetual, ceaseless",
            negative = "tight, contained, brief, compact, small, modest, bounded, finite, finished, complete",
        },
        {
            name = "growth_rate", low = 0.8, high = 2.5,
            positive = "rapid, accelerating, exponential, opening, expanding, growing, blooming, surging, escalating, ballooning",
            negative = "tight, gradual, slow, contained, measured, controlled, restrained, modest, glacial, stilled",
        },
    },
    -- }}}

    -- {{{ circuit — Manhattan traces of technical structure
    circuit = {
        {
            name = "trace_count", low = 4, high = 20,
            positive = "complex, dense, intricate, distributed, layered, elaborate, sophisticated, networked, byzantine, interwoven",
            negative = "simple, sparse, atomic, basic, minimal, plain, single, contained, primitive, elementary",
        },
        {
            name = "segments_per_trace", low = 2, high = 8,
            positive = "winding, convoluted, complex, indirect, twisting, elaborate, intricate, meandering, labyrinthine, devious",
            negative = "direct, straight, simple, immediate, clear, brief, atomic, plain, terse, blunt",
        },
    },
    -- }}}

    -- {{{ lightning — jagged bolts of sudden force
    lightning = {
        {
            name = "bolt_count", low = 1, high = 5,
            positive = "many, repeated, repeating, multiple, sustained, hammering, ceaseless, frequent, drumming, relentless",
            negative = "single, isolated, lone, one, sudden, brief, momentary, rare, once, singular",
        },
        {
            name = "jaggedness", low = 4, high = 16,
            positive = "erratic, chaotic, wild, unpredictable, jagged, frantic, broken, violent, convulsive, spasmodic",
            negative = "direct, straight, clean, focused, predictable, clear, smooth, controlled, calm, deliberate",
        },
    },
    -- }}}

    -- {{{ crystal — hexagonal facets of structured clarity
    crystal = {
        {
            name = "facet_count", low = 2, high = 10,
            positive = "many, scattered, dense, abundant, populated, crowded, multiple, manifold, profuse, gathered",
            negative = "single, isolated, alone, one, lone, solitary, individual, atomic, sole, lone",
        },
        {
            name = "facet_radius", low = 6, high = 18,
            positive = "monumental, large, dominant, looming, vast, imposing, grand, towering, massive, megalithic",
            negative = "small, delicate, intricate, minute, precious, fine, jewel-like, modest, miniature, dainty",
        },
    },
    -- }}}

    -- neutral: paramless on purpose. "Intentionally minimal" is the theme's
    -- whole point; embedding-driven variation would betray that.
}
