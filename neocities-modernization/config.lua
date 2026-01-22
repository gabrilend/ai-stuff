-- {{{ config.lua
-- Issue 10-003: Single authoritative configuration for neocities-modernization
-- All settings are validated against actual script usage as of 2026-01-21.
-- Sections are organized with vimfolds for easy navigation.
--
-- Usage:
--   local config = require("config-loader")
--   local assets_root = config.asset_paths.assets_root
--   local colors = config.semantic_colors
-- }}}

return {
    -- {{{ asset_paths
    -- Root directory for all generated assets: embeddings, caches, indexes.
    -- Scripts use this to locate poem embeddings, similarity matrices, and other
    -- computed data that persists between pipeline runs.
    asset_paths = {
        assets_root = "/mnt/mtwo/programming/ai-stuff/neocities-modernization/assets"
    },
    -- }}}

    -- {{{ layout
    -- Controls the visual appearance of poem boxes in generated HTML.
    -- These values are read by src/flat-html-generator.lua:load_layout_from_config()
    -- Width values are in characters. Junction positions are character offsets.
    layout = {
        regular_poem_width = 83,        -- Width of standard poem boxes
        golden_poem_width = 85,         -- Width of golden poem boxes (1024 chars)
        text_content_width = 80,        -- Inner content area width
        left_box_width = 11,            -- Left navigation box width
        right_box_width = 13,           -- Right navigation box width
        gap_width = 59,                 -- Gap between left and right boxes
        left_junction_pos = 5,          -- Position of left box junction point
        right_junction_pos = 6          -- Position of right box junction point
    },
    -- }}}

    -- {{{ input_sources
    -- Paths to raw input data from various sources. The pipeline reads from these
    -- directories during extraction. Each source type has its own extractor script
    -- that parses the native format (ActivityPub JSON, plain text files, etc).
    input_sources = {
        fediverse_backup_path = "input/fediverse",      -- Mastodon/ActivityPub exports
        messages_backup_path = "input/messages",        -- Private message archives
        words_source_path = "input/words",              -- Raw text collections
        notes_source_path = "input/notes",              -- Personal notes and drafts
        bluesky_backup_path = "input/bluesky"           -- Bluesky/AT Protocol exports
    },
    -- }}}

    -- {{{ extraction
    -- Controls which input sources are processed during extraction.
    -- Disabling a source skips it entirely, useful for testing or partial rebuilds.
    extraction = {
        enable_fediverse = true,
        enable_messages = true,
        enable_notes = true,
        enable_bluesky = true
    },
    -- }}}

    -- {{{ privacy
    -- Anonymization settings for public deployment. In "clean" mode, usernames
    -- are replaced with sequential identifiers (user-1, user-2...) to prevent
    -- identifying who you were talking to. The local_server_domain is your home
    -- instance - local users are anonymized while you remain identifiable.
    -- Available modes: "clean" (anonymize), "raw" (preserve original)
    privacy = {
        mode = "clean",                     -- "clean" or "raw"
        anonymization_prefix = "user-",     -- Prefix for anonymized usernames
        include_boosts = true,              -- Include boosted/reblogged posts
        preserve_original_length = true,    -- Keep length hints for anonymized names
        store_anonymization_map = false,    -- Don't store mapping (privacy)
        local_server_domain = "tech.lgbt"   -- Your home instance domain
    },
    -- }}}

    -- {{{ golden_poems
    -- "Golden poems" are exactly 1024 characters - the perfect length for
    -- fediverse sharing (Mastodon's limit). These get a similarity bonus to
    -- appear more often in recommendations, surfacing your most share-worthy work.
    -- Read by: src/html-generator/golden-poem-bonus.lua
    golden_poems = {
        enable_golden_prioritization = true,
        golden_poem_pair_bonus = 0.05,      -- Bonus when both poems are golden
        golden_poem_single_bonus = 0.02,    -- Bonus when one poem is golden
        golden_bonus_threshold = 0.1,       -- Maximum bonus cap
        min_golden_recommendations = 2,     -- Minimum golden poems per page
        max_golden_recommendations = 5      -- Maximum golden poems per page
    },
    -- }}}

    -- {{{ semantic_colors
    -- Colors for the semantic clustering visualization. Each poem is assigned
    -- a color based on its embedding cluster, creating a visual map of your
    -- collection's thematic regions. Progress bars blend these colors.
    -- Read by: src/semantic-color-calculator.lua
    semantic_colors = {
        red    = { rgb = {220, 60, 60},   hex = "#dc3c3c", name = "red" },
        blue   = { rgb = {60, 120, 220},  hex = "#3c78dc", name = "blue" },
        green  = { rgb = {60, 180, 90},   hex = "#3cb45a", name = "green" },
        purple = { rgb = {140, 60, 200},  hex = "#8c3cc8", name = "purple" },
        orange = { rgb = {230, 140, 60},  hex = "#e68c3c", name = "orange" },
        yellow = { rgb = {200, 180, 40},  hex = "#c8b428", name = "yellow" },
        gray   = { rgb = {120, 120, 120}, hex = "#787878", name = "gray" }
    },
    -- Ordered list for deterministic iteration across pages
    color_names = {"red", "blue", "green", "purple", "orange", "yellow", "gray"},
    -- }}}

    -- {{{ similarity
    -- Algorithm settings for computing poem-to-poem similarity scores.
    -- Read by: src/similarity-calculator.lua
    -- Available algorithms: "cosine", "euclidean", "manhattan", "angular", "pearson_correlation"
    -- CLI override: --model NAME (embedding model, via run.sh)
    similarity = {
        default_algorithm = "cosine"    -- Cosine is standard for text embeddings
    },
    -- }}}

    -- {{{ image_integration
    -- Settings for including media attachments (images, GIFs) alongside poems.
    -- Images from fediverse posts are copied to the output and displayed inline.
    -- Read by: src/image-manager.lua
    image_integration = {
        enabled = true,
        image_directories = {"input/media_attachments"},
        supported_formats = {"png", "jpg", "jpeg", "gif", "webp", "svg"},
        max_file_size_mb = 100,                      -- Skip oversized files
        output_path = "assets/images",              -- Where to copy images
        catalog_file = "assets/image-catalog.json"  -- Index of all images
    },
    -- }}}

    -- {{{ image_sync
    -- Syncs media from external backup locations into the project's input directory.
    -- Run before extraction to ensure all attachments are available locally.
    -- Add multiple sources if your media is spread across backup locations.
    image_sync = {
        enabled = true,
        destination = "input/media_attachments",    -- Where to sync images to
        sources = {
            {
                name = "fediverse_media",
                path = "/home/ritz/backups/words/fediverse/media_attachments",
                description = "Mastodon/ActivityPub media attachments"
            },
            {
                name = "my-art",
                path = "/home/ritz/pictures/my-art",
                description = "my artwork, made in kolourpaint"
            }
        },
        preserve_structure = true,                  -- Keep directory hierarchy
        overwrite_existing = false,                 -- Don't replace existing files
        supported_formats = {"png", "jpg", "jpeg", "gif", "webp", "svg"}
    },
    -- }}}

    -- {{{ pagination
    -- Controls how poems are split across HTML pages. Large collections need
    -- pagination to keep page load times reasonable.
    -- Read by: src/flat-html-generator.lua:load_pagination_config()
    -- CLI overrides: --poems-per-page, --chrono-per-page, --pages (via run.sh)
    pagination = {
        poems_per_page = 100,               -- Poems per similar/different page
                                            -- CLI: --poems-per-page N (run.sh default: 200)
        minimum_pages = 1,                  -- Minimum pages to generate
        max_pages_per_poem = 15,            -- Maximum similar/different pages per poem
                                            -- CLI: --pages N
        page_number_padding = 2,            -- Zero-padding for page numbers (01, 02...)
        generate_txt_exports = true,        -- Generate .txt versions of poems
        generate_html_archives = false,     -- Disabled: redundant with paginated pages
        chronological_paginated = false,    -- Split chronological.html into pages
        chronological_poems_per_page = 500  -- Poems per chronological page (if paginated)
                                            -- CLI: --chrono-per-page N
    },
    -- }}}

    -- {{{ storage
    -- Budget planning for Neocities deployment. These values inform the
    -- pagination system about storage constraints.
    -- Read by: src/flat-html-generator.lua:load_pagination_config()
    storage = {
        limit_gb = 45,                  -- Total available storage (Neocities supporter)
        reserved_for_maze_gb = 0.031,   -- Reserved for HTML Maze feature
        reserved_headroom_gb = 5        -- Safety buffer
    },
    -- }}}

    -- {{{ word_cloud
    -- Word cloud page settings. Extracts vocabulary from all poems, filters
    -- stop words (common words like "the", "and"), and displays the remaining
    -- words sized by frequency. Each word links to poems containing it.
    -- Read by: src/wordcloud-generator.lua
    word_cloud = {
        enabled = true,
        stop_words_file = "stop-words.txt",  -- Editable filter list (project root)
        output_file = "wordcloud.html",
        min_occurrences = 5,        -- Minimum times a word must appear
        max_words = 200,            -- Maximum words to display (0 = unlimited)
        min_word_length = 3,        -- Ignore words shorter than this
        font_size_min = 1,          -- HTML font tag: 1-7 scale
        font_size_max = 7
    },
    -- }}}

    -- {{{ centroids
    -- Mood-based exploration anchors. Each centroid defines a "semantic target"
    -- using keywords and optional source files. The pipeline embeds these targets
    -- and generates similarity pages showing which poems match each mood.
    -- Read by: src/centroid-generator.lua
    --
    -- To add a new mood: copy an existing entry, change the name/slug/keywords.
    -- Keywords can be single words or evocative phrases - the embedding model
    -- will find poems that feel similar to the combined meaning.
    centroids = {
        {
            name = "melancholy",
            description = "Sad, reflective, introspective moods - winter feelings and quiet grief",
            source_files = {},
            keywords = {
                "loneliness",
                "grief",
                "winter",
                "rain on windows",
                "empty rooms",
                "quiet sadness",
                "memory of someone gone",
                "the weight of silence"
            },
            output_slug = "melancholy"
        },
        {
            name = "wonder",
            description = "Awe, curiosity, the vastness of existence",
            source_files = {},
            keywords = {
                "stars",
                "infinity",
                "childhood wonder",
                "discovery",
                "the unknown",
                "first time seeing the ocean",
                "questions without answers",
                "the size of the universe"
            },
            output_slug = "wonder"
        },
        {
            name = "rage",
            description = "Anger, frustration, righteous fury",
            source_files = {},
            keywords = {
                "injustice",
                "betrayal",
                "fire",
                "screaming into the void",
                "broken promises",
                "systemic failure",
                "enough is enough"
            },
            output_slug = "rage"
        },
        {
            name = "tenderness",
            description = "Gentle love, care, softness between beings",
            source_files = {},
            keywords = {
                "holding hands",
                "soft voice",
                "caring for someone sick",
                "pet sleeping on your lap",
                "forgiveness",
                "vulnerability",
                "being seen"
            },
            output_slug = "tenderness"
        },
        {
            name = "absurdity",
            description = "The strange, surreal, and darkly comic",
            source_files = {},
            keywords = {
                "kafka",
                "bureaucracy",
                "meaninglessness that becomes funny",
                "the universe as joke",
                "recursive paradox",
                "waiting for something that never comes"
            },
            output_slug = "absurd"
        },
        {
            name = "hope",
            description = "Uplifting, encouraging, healing - poems for hope cards and difficult times",
            source_files = {},
            keywords = {
                "hope",
                "healing",
                "light at the end of the tunnel",
                "things will get better",
                "resilience after hardship",
                "growth through difficulty",
                "recovery and renewal",
                "new beginnings",
                "gentle encouragement",
                "you are not alone in this",
                "kindness in dark times",
                "compassion for yourself",
                "tomorrow is another day",
                "this too shall pass",
                "the relief after crying",
                "being held when you're scared",
                "winter turning to spring",
                "stars in the darkest night",
                "tired but still here",
                "scared but brave enough",
                "small victories matter",
                "rest is not giving up",
                "you did your best today",
                "permission to be imperfect"
            },
            output_slug = "hope"
        },
        {
            name = "fierce-hope",
            description = "Empowering, activist, revolutionary hope - strength and resistance",
            source_files = {},
            keywords = {
                "revolution",
                "resistance",
                "we will overcome",
                "rising up together",
                "collective power",
                "speaking truth to power",
                "no justice no peace",
                "solidarity",
                "the arc of justice",
                "they tried to bury us they didn't know we were seeds",
                "we are the ones we've been waiting for",
                "never give up never surrender",
                "fierce tenderness",
                "angry and hopeful",
                "burn it down and build anew"
            },
            output_slug = "fierce-hope"
        },
        {
            name = "quiet-comfort",
            description = "Cozy, gentle, safe spaces - poems for rest and sanctuary",
            source_files = {},
            keywords = {
                "rest",
                "safety",
                "warm blanket on cold night",
                "tea and quiet moments",
                "sanctuary from the storm",
                "soft lighting",
                "gentle rain on windows",
                "curled up with a book",
                "permission to do nothing",
                "the luxury of being alone",
                "home as refuge",
                "peace in small things",
                "the comfort of routine",
                "slow mornings",
                "everything can wait",
                "you are safe here"
            },
            output_slug = "comfort"
        }
    },
    -- }}}

    -- {{{ html_theme
    -- Dark mode theme colors applied via HTML body attributes (CSS-free).
    -- Uses true black (#000000) for OLED power savings and maximum contrast.
    -- These colors are applied to <body bgcolor="..." text="..." link="..." vlink="...">
    html_theme = {
        background = "#000000",     -- True black background (OLED-friendly)
        text = "#FFFFFF",           -- White text for readability
        link = "#6699FF",           -- Blue for unvisited links
        vlink = "#9966FF"           -- Purple for visited links
    },
    -- }}}

    -- {{{ Algorithm Reference (documentation only)
    -- These algorithm descriptions are for reference only - not read by scripts.
    -- The actual algorithm is selected via similarity.default_algorithm above.
    --
    -- Available algorithms:
    --   cosine:    Angle between vectors, range [-1, 1], fast, best for text embeddings
    --   euclidean: Distance converted to similarity, range [0, 1], fast
    --   manhattan: L1 distance converted to similarity, range [0, 1], robust to outliers
    --   angular:   Normalized angle, range [0, 1], good for directional data
    --   pearson:   Correlation coefficient, range [0, 1], for statistical analysis
    --
    -- Removed stale options (2026-01-21, Issue 10-003):
    --   output_format: Only JSON is supported, no need for config
    --   preserve_timestamps: Always preserved, not configurable
    --   validation_settings: Over-engineering, not implemented
    -- }}}
}
