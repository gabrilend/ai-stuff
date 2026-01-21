-- {{{ config/main.lua
-- Issue 10-003: Single authoritative configuration for neocities-modernization
-- All other config files are deprecated in favor of this one.
-- Sections are organized with vimfolds for easy navigation.
--
-- Usage:
--   local config = require("config-loader")
--   local assets_root = config.asset_paths.assets_root
--   local colors = config.semantic_colors
-- }}}

return {
    -- {{{ asset_paths
    -- Generated asset storage locations
    -- Previously: config/asset-paths.lua
    asset_paths = {
        assets_root = "/mnt/mtwo/programming/ai-stuff/neocities-modernization/assets"
    },
    -- }}}

    -- {{{ layout
    -- Output layout configuration
    -- Previously: config/input-sources.json -> layout
    layout = {
        output_width = 80,          -- Width of poem boxes in characters
        margin_left = 4,            -- Left margin for poem text
        margin_right = 4,           -- Right margin for poem text
        box_style = "single",       -- Box drawing style: "single", "double", "ascii"
        line_separator = "─"        -- Character for horizontal rules
    },
    -- }}}

    -- {{{ input_sources
    -- Input sources and paths
    -- Previously: config/input-sources.json -> input_sources
    input_sources = {
        fediverse_backup_path = "input/fediverse",
        messages_backup_path = "input/messages",
        words_source_path = "input/words",
        notes_source_path = "input/notes",
        bluesky_backup_path = "input/bluesky"
    },
    -- }}}

    -- {{{ project_structure
    -- Generated directory structure
    -- Previously: config/input-sources.json -> project_structure
    project_structure = {
        output_dir = "output",
        assets_dir = "assets",
        embeddings_dir = "assets/embeddings",
        cache_dir = "tmp"
    },
    -- }}}

    -- {{{ extraction
    -- Extraction behavior settings
    -- Previously: config/input-sources.json -> extraction
    extraction = {
        enable_fediverse = true,
        enable_messages = true,
        enable_notes = true,
        enable_bluesky = true,
        output_format = "json",
        preserve_timestamps = true
    },
    -- }}}

    -- {{{ privacy
    -- Privacy and anonymization settings
    -- Previously: config/input-sources.json -> privacy
    privacy = {
        mode = "clean",                     -- "clean" = anonymize, "raw" = preserve
        anonymization_prefix = "user-",     -- Prefix for anonymized usernames
        include_boosts = true,              -- Include boosted/reblogged posts
        preserve_original_length = true,    -- Keep length hints for anonymized names
        store_anonymization_map = false,    -- Don't store mapping (privacy)
        local_server_domain = "tech.lgbt"   -- Domain for local users (not anonymized)
    },
    -- }}}

    -- {{{ golden_poems
    -- Golden poem prioritization settings
    -- Previously: config/golden-poem-settings.json
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
    -- Semantic color definitions for clustering visualization
    -- Previously: config/semantic-colors.json
    semantic_colors = {
        red    = { rgb = {220, 60, 60},   hex = "#dc3c3c", name = "red" },
        blue   = { rgb = {60, 120, 220},  hex = "#3c78dc", name = "blue" },
        green  = { rgb = {60, 180, 90},   hex = "#3cb45a", name = "green" },
        purple = { rgb = {140, 60, 200},  hex = "#8c3cc8", name = "purple" },
        orange = { rgb = {230, 140, 60},  hex = "#e68c3c", name = "orange" },
        yellow = { rgb = {200, 180, 40},  hex = "#c8b428", name = "yellow" },
        gray   = { rgb = {120, 120, 120}, hex = "#787878", name = "gray" }
    },
    -- Ordered list for iteration
    color_names = {"red", "blue", "green", "purple", "orange", "yellow", "gray"},
    -- }}}

    -- {{{ similarity
    -- Similarity calculation algorithm settings
    -- Previously: config/similarity-calculator-settings.json
    similarity = {
        default_algorithm = "cosine",
        algorithms = {
            cosine = {
                description = "Cosine similarity - measures angle between vectors, standard for text embeddings",
                recommended_for = {"text_embeddings", "high_dimensional_vectors"},
                performance = "fast",
                range = "[-1, 1]"
            },
            euclidean = {
                description = "Euclidean distance converted to similarity - measures straight-line distance",
                recommended_for = {"spatial_data", "dense_vectors"},
                performance = "fast",
                range = "[0, 1]"
            },
            manhattan = {
                description = "Manhattan distance converted to similarity - measures city-block distance",
                recommended_for = {"sparse_vectors", "robust_to_outliers"},
                performance = "fast",
                range = "[0, 1]"
            },
            angular = {
                description = "Angular similarity - normalized angle between vectors",
                recommended_for = {"directional_data", "normalized_vectors"},
                performance = "medium",
                range = "[0, 1]"
            },
            pearson_correlation = {
                description = "Pearson correlation coefficient - measures linear correlation",
                recommended_for = {"statistical_analysis", "linear_relationships"},
                performance = "medium",
                range = "[0, 1]"
            }
        },
        validation_settings = {
            enable_validation = true,
            tolerance_identical = 0.001,
            tolerance_orthogonal = 0.6,
            tolerance_opposite = 1.2
        }
    },
    -- }}}

    -- {{{ image_integration
    -- Image integration settings
    -- Previously: config/input-sources.json -> image_integration
    image_integration = {
        enabled = true,
        image_directories = {"input/media_attachments"},
        supported_formats = {"png", "jpg", "jpeg", "gif", "webp", "svg"},
        max_file_size_mb = 10,
        output_path = "assets/images",
        catalog_file = "assets/image-catalog.json"
    },
    -- }}}

    -- {{{ image_sync
    -- Issue 8-042: Configurable image source directories for syncing
    -- Previously: config/input-sources.json -> image_sync
    image_sync = {
        enabled = true,
        destination = "input/media_attachments",
        sources = {
            {
                name = "fediverse_media",
                path = "/home/ritz/backups/words/fediverse/media_attachments",
                description = "Mastodon/ActivityPub media attachments"
            }
        },
        preserve_structure = true,
        overwrite_existing = false,
        supported_formats = {"png", "jpg", "jpeg", "gif", "webp", "svg"}
    },
    -- }}}

    -- {{{ pagination
    -- Pagination settings for HTML output
    -- Previously: config/input-sources.json -> pagination
    pagination = {
        poems_per_page = 100,           -- Poems per chronological page
        similar_per_page = 50,          -- Poems per similar/different page
        max_similar_pages = 15,         -- Maximum pages for similar rankings
        max_different_pages = 15        -- Maximum pages for different rankings
    },
    -- }}}

    -- {{{ storage
    -- Storage budget for Neocities deployment
    -- Previously: config/input-sources.json -> storage
    storage = {
        neocities_quota_gb = 45,
        reserved_for_images_gb = 10,
        estimated_html_size_mb = 500
    },
    -- }}}

    -- {{{ word_cloud
    -- Issue 8-043: Word cloud generation settings
    -- Previously: config/input-sources.json -> word_cloud
    word_cloud = {
        enabled = true,
        stop_words_file = "config/stop-words.txt",  -- External file for easy editing
        output_file = "wordcloud.html",
        min_occurrences = 5,        -- Minimum times a word must appear
        max_words = 200,            -- Maximum words to display (0 = unlimited)
        min_word_length = 3,        -- Ignore words shorter than this
        font_size_min = 1,          -- HTML font tag: 1-7
        font_size_max = 7
    },
    -- }}}

    -- {{{ centroids
    -- Mood-based centroids for custom exploration pages
    -- Previously: assets/centroids.json
    -- Each centroid defines a semantic anchor that generates similarity/diversity pages
    -- NOTE: This section is user-editable - add your own moods and keywords
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
    -- Issue 8-047: HTML theme colors (CSS-free dark mode)
    -- Previously: hardcoded in various HTML generators
    html_theme = {
        background = "#000000",     -- True black background
        text = "#FFFFFF",           -- White text
        link = "#6699FF",           -- Blue links
        vlink = "#9966FF"           -- Purple visited links
    }
    -- }}}
}
