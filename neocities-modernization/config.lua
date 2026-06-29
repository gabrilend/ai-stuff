-- {{{ config.lua
-- Issue 10-003: Single authoritative configuration for neocities-modernization
-- All settings are validated against actual script usage as of 2026-01-21.
-- Sections are organized with vimfolds for easy navigation.
--
-- For detailed field documentation, see: docs/config-reference.md (Issue 10-019)
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

    -- NOTE: input_sources section REMOVED (Issue 10-015a)
    -- All source paths are now in the unified 'sources' section below.
    -- Extractors use sources-loader.lua to read paths.

    -- {{{ sources
    -- Unified input source configuration (Issue 10-015, extended 10-026).
    -- Each source type supports multiple named directories.
    -- Pipeline deduplicates by content ID across directories.
    -- All extractors now use sources-loader.lua to read these paths.
    --
    -- Issue 10-026: External sync info is now embedded in each source:
    --   - directories[].external.source = where to rsync from
    --   - archives[] = ZIP files that extract to this source's directory
    -- Use sources-loader.get_all_external_syncs() to collect all sync entries.
    sources = {
        fediverse = {
            enabled = true,
            format = "activitypub",
            directories = {
                {
                    name = "primary",
                    path = "input/fediverse",
                },
            },
            -- Issue 10-026: Archive sources (ZIP files that extract to this source's directory)
            archives = {
                {
                    name = "fediverse-zip",
                    source = "/home/ritz/backups/fediverse/backups/most-recent-29.zip",
                    extract_to = "input",  -- Extracts to input/ root (archive contains fediverse/ dir)
                },
            },
            media = {
                extract_attachments = true,
                output_path = "input/media_attachments/fediverse",
            },
        },
        messages = {
            enabled = true,
            format = "messages_export",
            directories = {
                {
                    name = "primary",
                    path = "input/messages",
                },
            },
            -- Issue 10-026: Archive sources
            archives = {
                {
                    name = "messages-zip",
                    source = "/home/ritz/backups/messages-to-myself/input-zip-file/queen-of-her-castle.zip",
                    extract_to = "input",  -- Extracts to input/ root (archive contains messages/ dir)
                },
            },
        },
        notes = {
            enabled = true,
            format = "plaintext",
            directories = {
                {
                    name = "primary",
                    path = "input/notes",
                    -- Issue 10-026: External source for rsync
                    external = {
                        source = "/home/ritz/notes",
                    },
                },
            },
        },
        bluesky = {
            enabled = true,
            format = "atproto",
            directories = {
                {
                    name = "primary",
                    path = "input/bluesky",
                    -- Issue 10-026: External source for rsync
                    external = {
                        source = "/home/ritz/backups/bluesky/input",
                    },
                },
            },
        },
        images = {
            enabled = true,
            -- include_by_default (per source, default true):
            --   true  -> ship EVERYTHING from this source, minus the entries in
            --            excluded_images that name files in it (a blacklist).
            --   false -> ship NOTHING from this source EXCEPT the entries in
            --            excluded_images that name files in it (a whitelist) --
            --            i.e. the SAME list, but its lines now ADD rather than
            --            remove. Use false when a source is a big directory and
            --            you only want a handful of files out of it.
            -- This keeps excluded_images as one flat list; the flag decides
            -- whether a source's lines subtract from "all" or add to "none".
            directories = {
                {
                    name = "fediverse-media",
                    -- Bugfix: this pointed at input/images/files, which never
                    -- exists, so 546 fediverse post attachments were silently
                    -- skipped and never rendered inline. The ZIP extraction
                    -- (scripts/update -> scripts/zip-extractor.lua) writes the
                    -- deeply-nested Mastodon media to input/media_attachments/
                    -- files/..., so the source points there now.
                    path = "input/media_attachments/files",
                    description = "Mastodon/ActivityPub media attachments (deeply nested)",
                    -- No external: comes from ZIP extraction
                },
                {
                    name = "my-art",
                    include_by_default = true,
                    path = "input/images/my-art",
                    description = "artwork made in kolourpaint",
                    -- Issue 10-026: External source for rsync
                    external = {
                        source = "/home/ritz/pictures/my-art",
                    },
                },
                {
                    name = "things-I-almost-posted",
                    include_by_default = true,
                    path = "input/images/things-i-almost-posted",
                    external = {
                        source = "/home/ritz/pictures/things-i-almost-posted",
                    },
                    randomize_order = false,
                },
                {
                    name = "poem-pictures",
                    include_by_default = true,
                    path = "input/images/poem-pictures",
                    external = {
                        source = "/home/ritz/pictures/poem-pictures",
                    },
                },
                {
                    name = "dnd-pictures-from-the-internet",
                    include_by_default = true,
                    path = "input/images/dnd-pictures",
                    external = {
                        source = "/home/ritz/pictures/dnd-pictures",
                    },
                    -- Issue 10-030: Randomize position of these images in timeline
                    -- (they don't have meaningful dates, scatter throughout)
                    randomize_order = true;

                },
                {
                    -- NOTE: external syncs to fediverse-stars, sources reads from here
                    -- Path updated to match sync destination (was fediverse-backup)
                    name = "fediverse-stars",
                    include_by_default = true,
                    path = "input/images/fediverse-stars",
                    external = {
                        source = "/home/ritz/pictures/fediverse-backup",
                    },
                    -- Issue 10-030: Randomize position of these images in timeline
                    -- (they don't have meaningful dates, scatter throughout)
                    randomize_order = true;
                },
            },
            supported_formats = {"png", "jpg", "jpeg", "gif", "webp", "svg"},
            max_file_size_mb = 200,
            preserve_structure = true,
            overwrite_existing = false,
        },
    },
    -- }}}

    -- {{{ external_files - DEPRECATED (Issue 10-026)
    -- This section has been merged into the 'sources' section above.
    -- External sync info is now stored as 'external' fields in each source's directories,
    -- and as 'archives' arrays for ZIP files.
    --
    -- external-sync.lua now reads from sources-loader.get_all_external_syncs()
    -- which collects external sync info from the unified sources configuration.
    --
    -- This empty array is kept for backward compatibility during the transition.
    -- It can be removed after confirming all scripts use sources-loader.
    external_files = {},
    -- }}}

    -- {{{ extraction
    -- Controls which input sources are processed during extraction.
    -- Disabling a source skips it entirely, useful for testing or partial rebuilds.
    extraction = {
        enable_fediverse = true,
        enable_messages = true,
        enable_notes = true,
        enable_bluesky = true,
        -- Issue 7-003: ZIP files to ignore during archive scanning.
        -- These are ZIPs that appear in input/ but aren't content archives
        -- (e.g., site backups embedded in media_attachments from fediverse export).
        ignored_archives = {
            "neocities-ritz-menardi"  -- Neocities site backup, not content data
        }
    },
    -- }}}

    -- {{{ randomization
    -- Issue 10-058: One master seed governs every randomization site in a build.
    -- Today that is the word-cloud word shuffle (src/wordcloud-generator.lua) and
    -- the image-order randomization for any source that does not pin its own
    -- per-source random_seed (src/image-manager.lua). Reproducibility needs two
    -- things: (a) all randomness flowing from ONE known seed, and (b) that seed
    -- recorded somewhere durable. run.sh resolves the seed -- precedence is the
    -- --seed CLI flag > this config value > an auto-generated seed -- and records
    -- the resolved value to output/generation-metadata.json and the run log, so a
    -- build is always answerable to "which seed produced this?".
    --
    --   seed = nil  => run.sh invents a seed each build and RECORDS it, so even a
    --                  build nobody thought to seed is reproducible after the fact.
    --   seed = N    => a fixed non-negative integer pins the build: the same seed
    --                  over the same inputs yields byte-identical shuffled output.
    --
    -- A `--seed N` on the run.sh command line overrides this value for one run.
    randomization = {
        seed = nil,
    },
    -- }}}

    -- {{{ excluded_poems
    -- Issue 6-031: Poems to exclude from the collection during extraction.
    -- Excluded poems leave gaps in the ID sequence (tombstoning) - they don't
    -- shift other poem IDs down, preserving stable anchor links.
    -- Read by: libs/exclusion-filter.lua
    --
    -- ID Formats by Category:
    --   fediverse: Numeric post ID from ActivityPub (e.g., "113847291038475")
    --   notes:     Filename without extension (e.g., "what-a-lame-movie")
    --   messages:  Numeric message index (e.g., "42")
    --   bluesky:   AT Protocol record key (e.g., "3k...abc")
    --
    -- Finding poem IDs:
    --   Browse chronological.html, search poems.json, or grep generated HTML
    excluded_poems = {
        fediverse = {
            -- Add fediverse post IDs here, e.g.: "113847291038475"
        },
        notes = {
            -- Add note filenames here (without extension), e.g.: "test-post-please-ignore"
            -- 0129.txt is a raw PDF file (its content starts with %PDF-1.5), not text.
            -- Extraction stored the PDF's binary bytes as the poem content, and because
            -- a PDF is maximally dissimilar to every text poem it became a diversity
            -- outlier -- landing on ~7,900 "different" pages and dumping ~14KB of binary
            -- (NUL bytes, PDF stream data) into each one. Excluding it tombstones the
            -- poem so it never enters poems.json, clearing the whole "different" section.
            -- (Takes effect on the next extraction run.)
            "0129",
        },
        messages = {
            -- Add message indices here, e.g.: "42"
        },
        bluesky = {
            -- Add bluesky record keys here
        }
    },
    -- }}}

    -- {{{ excluded_images
    -- Issue 10-053: Images to exclude, named RELATIVE TO input/images/ -- i.e.
    -- "<source>/<path-within-source>", the same shape you'd see under
    -- input/images/. The leading "input/images/" is implied, so it is no longer
    -- repeated on every line (it carried no information and hid the part that
    -- matters: which gallery, which file).
    --
    -- These are STRIPPED from input/ by scripts/strip-excluded after sync, so
    -- they never get cataloged, embedded, flattened into output/media, rendered,
    -- OR uploaded with input/. The originals stay safe in the /home/ritz/... rsync
    -- sources (a later sync re-copies them; the strip removes them again).
    --
    -- VALIDATED at build start: strip-excluded resolves every entry back to its
    -- rsync source and ERRORS if one points at no real file -- a wrong path
    -- (e.g. forgetting a subdirectory like kooky-dookerie/) can no longer fail
    -- silently and let the image ship anyway. Fix the path and re-run the phase.
    --
    -- Finding an image's path: copy it from the gallery/page that shows it, or
    --   ls input/images/<source>/   then drop the "input/images/" prefix.
    excluded_images = {
        -- "my-art/that-one-i-regret.png",
        "poem-pictures/stick-cubes-2.png",
        "my-art/sword-of-damocles-3.png",
        "my-art/help-me-obiwan-kenobi-3.png",
        "my-art/help-me-obiwan-kenobi-2.png",
        "my-art/help-me-obiwan-kenobi-1.png",
        "my-art/legion-td-idea.png",
        "my-art/chat-application-with-arrows.png",
        "my-art/air-defence-drones-1.png",
        "my-art/air-defence-drones-2.png",
        "my-art/air-defence-drones-3.png",

        "my-art/air-defence-drones-5.png",
        "my-art/greed.png",
        "my-art/continual-context.png",
        "my-art/continual-context-part-2.png",
        "my-art/about-face.png",
        "my-art/perspective-of-matter.png",

        -- usa-today is a sliced thread: the 18 numbered pieces (1..9, then
        -- 99..9999999999) are just the cut-up panels of the single stitched
        -- image usa-today.png, which is the only one we want in the gallery.
        -- The slices stay on disk under my-art/usa-today/ (and their .txt
        -- alt-text); only their input/ copies are stripped so they never
        -- catalog, render, or upload. preserve_structure=true keeps the
        -- usa-today/ subdir, so these paths carry it.
        "my-art/usa-today/1.png",
        "my-art/usa-today/2.png",
        "my-art/usa-today/3.png",
        "my-art/usa-today/4.png",
        "my-art/usa-today/5.png",
        "my-art/usa-today/6.png",
        "my-art/usa-today/7.png",
        "my-art/usa-today/8.png",
        "my-art/usa-today/9.png",
        "my-art/usa-today/99.png",
        "my-art/usa-today/999.png",
        "my-art/usa-today/9999.png",
        "my-art/usa-today/99999.png",
        "my-art/usa-today/999999.png",
        "my-art/usa-today/9999999.png",
        "my-art/usa-today/99999999.png",
        "my-art/usa-today/999999999.png",
        "my-art/usa-today/9999999999.png",

        -- 777-1.png lives in the kooky-dookerie/ subdir, NOT the poem-pictures
        -- root -- preserve_structure=true keeps that subdir, so the exclusion
        -- path must carry it. The old root-level path silently matched nothing.
        -- (The former poem-pictures/1-7.png entries were dropped after those
        -- 2560x1440 screenshots were deleted from disk.)
        "poem-pictures/kooky-dookerie/777-1.png",

        "fediverse-stars/ffdsfa90f670235.png",

        "dnd-pictures/flag.png",
        "dnd-pictures/flag6.png",
        "dnd-pictures/flag7.png",
        "dnd-pictures/flag8.png",
        "dnd-pictures/flag9.png",
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
        include_boosts = false,             -- Boosted/reblogged posts OFF by default (the name implies opt-in); pass --include-boosts to add them
        preserve_original_length = true,    -- Keep length hints for anonymized names
        store_anonymization_map = false,    -- Don't store mapping (privacy)
        local_server_domain = "tech.lgbt"   -- Your home instance domain
    },
    -- }}}

    -- Golden-poem PRIORITIZATION was removed in Issue 5-015 (Dec 2025): golden
    -- poems rank on equal footing and are distinguished only visually (the
    -- box-drawing frame). The golden_poems bonus/quota config and its entire dead
    -- template subsystem (golden-poem-bonus, similarity-engine, template-engine,
    -- golden-collection-generator + tests) were deleted on 2026-06-23 -- the live
    -- GPU ranking path never read any of it.

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

    -- {{{ color_associations
    -- Each color's "essence" as a list of associated words -- concrete things AND
    -- abstract feelings/concepts. semantic-color-calculator embeds every word,
    -- mean-combines them into one per-color centroid (the same recombination used
    -- for long-poem chunks, Issue 10-050), and assigns each poem the color whose
    -- centroid it sits most ABOVE-baseline for (z-scored, hubness-corrected).
    --
    -- Why a list of associations instead of the bare color word: the bare word
    -- "red" embeds to a generic point that, by raw nearness, swallowed ~38% of
    -- all poems. A list (fire, blood, passion, rage...) pulls the anchor into the
    -- color's real semantic territory -- a poem about war or embers reads red even
    -- if it never says "red". Keep each list COHERENT (every word genuinely of
    -- that color); a coherent set averages to a clean anchor, an incoherent one
    -- to mush. These are a starting point -- edit freely; re-run stage 6.5 after.
    color_associations = {
        red    = {"fire", "blood", "passion", "anger", "rose", "heat", "danger", "war", "rage", "embers", "desire", "love", "wound"},
        blue   = {"sky", "ocean", "calm", "sadness", "cold", "melancholy", "depth", "distance", "ice", "serenity", "longing", "loneliness", "peace"},
        green  = {"forest", "growth", "nature", "envy", "leaf", "spring", "life", "moss", "renewal", "jealousy", "fertility", "garden", "grass"},
        purple = {"royalty", "mystery", "magic", "twilight", "luxury", "grief", "wisdom", "orchid", "velvet", "dusk", "nobility", "dream", "spirituality"},
        orange = {"autumn", "warmth", "energy", "citrus", "sunset", "harvest", "enthusiasm", "pumpkin", "amber", "glow", "vitality", "spice", "zest"},
        yellow = {"sun", "joy", "warning", "gold", "happiness", "cowardice", "daffodil", "brightness", "caution", "summer", "lemon", "optimism", "light"},
        gray   = {"fog", "ash", "stone", "age", "neutrality", "concrete", "rain", "dullness", "shadow", "winter", "steel", "silence", "gloom"},
    },
    -- }}}
    -- }}}

    -- {{{ similarity
    -- Algorithm settings for computing poem-to-poem similarity scores.
    -- Read by: src/similarity-calculator.lua
    -- Available algorithms: "cosine", "euclidean", "manhattan", "angular", "pearson_correlation"
    similarity = {
        default_algorithm = "cosine"    -- Cosine is standard for text embeddings
    },
    -- }}}

    -- {{{ inference_servers
    -- Issue 10-049: Inference-server configuration for embedding generation.
    -- Originally written for Ollama under 10-017; renamed and re-shaped for
    -- llama.cpp. Define multiple servers (local, remote GPU, etc.) and
    -- switch between them via TUI selection or CLI flags.
    -- Read by: libs/inference-server-config.lua
    -- CLI overrides: --server NAME, --model NAME, --list-servers
    --
    -- Fields per server:
    --   name: Label shown in the TUI and used with the --server flag
    --   description: Human-readable description
    --   host: Server hostname or IP
    --   port: Inference server's HTTP port
    --   model: Identifier sent in the OpenAI request body (informational;
    --          llama-server serves whatever model it has loaded). Convention
    --          is to use the GGUF basename without ".gguf".
    --   model_path: Path to the GGUF model file on disk, relative to the
    --               project DIR. start-llamacpp-server.sh resolves this
    --               into the absolute path it passes to llama-server -m.
    --   available_models: (optional) List of models the host can serve
    --   embedding_prompt_prefix: (optional) Prefix prepended to every input
    --                            (e.g. "clustering: " for nomic-embed-text v1.5)
    inference_servers = {
        {
            name = "gpu-server",
            description = "Remote GPU server (CUDA)",
            host = "192.168.0.115",
            port = 10265,
            model = "nomic-embed-text-v1.5",
            model_path = "assets/models/nomic-embed-text-v1.5.Q8_0.gguf",
            available_models = {
                "nomic-embed-text-v1.5",
                "mxbai-embed-large",
            }
        },
        {
            name = "gpu-server-alt",
            description = "Remote GPU server (alternate port)",
            host = "192.168.0.115",
            port = 11434,
            model = "nomic-embed-text-v1.5",
            model_path = "assets/models/nomic-embed-text-v1.5.Q8_0.gguf",
        },
        {
            name = "local",
            description = "Local llama.cpp instance (CUDA-enabled)",
            host = "192.168.1.100",
            port = 10265,
            -- nomic-embed-text v1.5 produces 768-dimensional vectors and
            -- requires a task-prefix on every input. For diversity ranking
            -- of poetry the right prefix is "clustering: ", which routes
            -- the model through its clustering-oriented internal weights.
            -- Switching models requires regenerating embeddings.json, the
            -- similarity caches, the diversity cache, etc.
            model = "nomic-embed-text-v1.5",
            model_path = "assets/models/nomic-embed-text-v1.5.Q8_0.gguf",
            embedding_prompt_prefix = "clustering: ",
        },
        -- Issue 10-031: two more local models, so the evaluation framework can
        -- compare how each judges poem similarity. Same host/port as "local":
        -- the comparison harness runs ONE server at a time (loads this GGUF,
        -- embeds the sample, stops, next), so they never contend for the port.
        {
            name = "local-mxbai",
            description = "Local llama.cpp -- mxbai-embed-large-v1 (model comparison)",
            host = "192.168.1.100",
            port = 10265,
            model = "mxbai-embed-large-v1",
            model_path = "assets/models/mxbai-embed-large-v1.Q8_0.gguf",
            -- mxbai-embed-large has no task-prompt training. For symmetric
            -- poem-to-poem similarity the convention is to embed plain text; the
            -- "Represent this sentence..." instruction is only for the QUERY side
            -- of asymmetric retrieval, which would skew a similarity comparison.
            embedding_prompt_prefix = nil,
        },
        {
            name = "local-gemma",
            description = "Local llama.cpp -- embeddinggemma-300m (model comparison)",
            host = "192.168.1.100",
            port = 10265,
            model = "embeddinggemma-300m",
            model_path = "assets/models/embeddinggemma-300M-Q8_0.gguf",
            -- EmbeddingGemma is trained WITH task prompts; the clustering task --
            -- which is what grouping poems by likeness wants -- uses this exact
            -- prefix per the model card. It mirrors the intent of nomic's
            -- "clustering: " so all three models are asked the same question.
            embedding_prompt_prefix = "task: clustering | query: ",
        },
    },
    -- Default server name (must match a name above)
    -- If not set, first server in list is used
    default_inference_server = "local",
    -- }}}

    -- {{{ image_integration
    -- Settings for including media attachments (images, GIFs) alongside poems.
    -- Images from fediverse posts are copied to the output and displayed inline.
    -- Read by: src/image-manager.lua (uses sources.images for directories)
    image_integration = {
        enabled = true,
        -- NOTE: image directories now come from sources.images (Issue 10-015a)
        supported_formats = {"png", "jpg", "jpeg", "gif", "webp", "svg"},
        max_file_size_mb = 100,                      -- Skip oversized files
        output_path = "assets/images",              -- Where to copy images
        catalog_file = "assets/image-catalog.json"  -- Index of all images
    },
    -- }}}

    -- {{{ image_sync - DEPRECATED (Issue 10-003b)
    -- This section has been replaced by external_files (see above).
    -- All external file syncing is now handled by libs/external-sync.lua
    -- and scripts/sync-external-files.
    --
    -- To add new image sources, add entries to external_files with:
    --   destination = "media_attachments/your-source-name"
    -- }}}
    -- REMOVED: image_sync section (10-003b)

    -- {{{ pagination
    -- Controls how poems are split across HTML pages. Large collections need
    -- pagination to keep page load times reasonable.
    -- Read by: src/flat-html-generator.lua:load_pagination_config()
    -- CLI overrides: --poems-per-page, --chrono-per-page, --pages (via run.sh)
    pagination = {
        poems_per_page = 200,               -- Poems per similar/different page
                                            -- CLI: --poems-per-page N (run.sh default: 200)
        minimum_pages = 1,                  -- Minimum pages to generate
        -- max_pages_per_poem is intentionally NOT here: the per-poem page ceiling is
        -- COMPUTED each build from the storage quota (storage.limit_gb below) and the
        -- measured size of the last build's pages, by flat-html-generator's
        -- compute_storage_max_pages (Issue 10-057). A frozen 15 was an estimate that
        -- would have shipped ~66GB into a 45GB quota.
        page_number_padding = 2,            -- Zero-padding for page numbers (01, 02...)
        generate_txt_exports = true,        -- Generate .txt versions of poems
        generate_html_archives = false,     -- Disabled: redundant with paginated pages
        chronological_paginated = false,    -- Split chronological.html into pages
        chronological_poems_per_page = 1000 -- Poems per chronological page (if paginated)
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
        output_file = "wordcloud.html",
        min_occurrences = 5,        -- Minimum times a word must appear
        max_words = 200,            -- Maximum words to display (0 = unlimited)
        min_word_length = 3,        -- Ignore words shorter than this
        font_size_min = 1,          -- HTML font tag: 1-7 scale
        font_size_max = 7,

        -- Stop words: common words to exclude from word cloud
        -- Organized by category for easy editing
        stop_words = {
            -- Anonymization artifacts (from privacy processing)
            "user", "users",
            -- Contraction fragments (from apostrophe removal)
            "don", "doesn", "didn", "isn", "aren", "wasn", "weren",
            "wouldn", "couldn", "shouldn", "haven", "hasn", "hadn", "won",
            -- URL/Technical artifacts
            "https", "http", "www", "com", "org", "net",
            -- Articles
            "a", "an", "the",
            -- Pronouns
            "i", "me", "my", "mine", "myself", "you", "your", "yours", "yourself",
            "he", "him", "his", "himself", "she", "her", "hers", "herself",
            "it", "its", "itself", "we", "us", "our", "ours", "ourselves",
            "they", "them", "their", "theirs", "themselves",
            "who", "whom", "whose", "which", "what", "that", "this", "these", "those",
            -- Prepositions
            "in", "on", "at", "to", "for", "of", "with", "by", "from", "up", "down",
            "out", "into", "over", "under", "through", "between", "among",
            "about", "after", "before", "during", "without", "within",
            -- Conjunctions
            "and", "or", "but", "nor", "so", "yet", "because", "although",
            "while", "if", "when", "where", "as", "than",
            -- Auxiliary verbs
            "is", "are", "was", "were", "be", "been", "being", "am",
            "have", "has", "had", "having", "do", "does", "did", "doing",
            "will", "would", "could", "should", "may", "might", "must", "shall", "can",
            -- Common verbs
            "get", "got", "go", "went", "gone", "come", "came", "make", "made",
            "take", "took", "taken", "see", "saw", "seen", "know", "knew", "known",
            "think", "thought", "say", "said", "give", "gave", "given",
            "find", "found", "tell", "told", "feel", "felt", "become", "became",
            "leave", "left", "put", "keep", "kept", "let", "begin", "began", "begun",
            "seem", "seemed", "help", "helped", "show", "showed", "shown",
            "hear", "heard", "turn", "turned", "start", "started", "run", "ran", "move", "moved",
            -- Common adverbs
            "very", "really", "just", "also", "too", "still", "even", "now", "then",
            "here", "there", "always", "never", "often", "sometimes", "already",
            "again", "ever", "soon", "only",
            -- Question words
            "how", "why",
            -- Other common words
            "all", "some", "any", "no", "not", "more", "most", "other", "such",
            "own", "same", "like", "well", "way", "back", "much", "many",
            "new", "good", "first", "last", "long", "great", "little", "old",
            "right", "big", "high", "different", "small", "large", "next", "early",
            "young", "important", "few", "public", "bad", "enough", "able", "sure",
            "thing", "things", "people", "time", "year", "years", "day", "days",
            "world", "life", "man", "woman", "men", "women", "child", "children",
            "something", "nothing", "everything", "someone", "anyone", "everyone"
        }
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
