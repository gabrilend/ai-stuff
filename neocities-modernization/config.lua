-- {{{ config.lua
-- Issue 10-003: Single authoritative configuration for neocities-modernization
-- To list settings that no program reads, run scripts/audit-config-keys.
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
        -- The widest a poem's line may be. Every frame is drawn from it
        -- (src/poem-bars.lua): a wall, a space, the text, a space, a wall --
        -- text_content_width + 4 columns (owner, 2026-10-25). The checker
        -- (scripts/validate-output) holds every page to the same width.
        text_content_width = 80,
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
                    -- Issue 10-068: subdirectories of the source that are
                    -- machinery, not writing. Never synced into input/, never
                    -- extracted. "rmail" is the phone-to-notes mailbox: its
                    -- config, contacts (shared secrets), hooks and state would
                    -- otherwise be published as poems. Each name must exist in
                    -- the source; a stale entry stops the sync.
                    excluded_subdirectories = { "rmail" },
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
            -- gallery (per source): { slug, title } puts the source on the
            -- gallery pages, as gallery/<slug>.html under that title, in the
            -- order listed here; a source without it is not in the gallery.
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
                    gallery = { slug = "my-art", title = "My Art" },
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
                    gallery = { slug = "things-i-almost-posted", title = "Things I Almost Posted" },
                    include_by_default = true,
                    path = "input/images/things-i-almost-posted",
                    external = {
                        source = "/home/ritz/pictures/things-i-almost-posted",
                    },
                    randomize_order = false,
                },
                {
                    name = "poem-pictures",
                    gallery = { slug = "poem-pictures", title = "Poem Pictures" },
                    include_by_default = true,
                    path = "input/images/poem-pictures",
                    external = {
                        source = "/home/ritz/pictures/poem-pictures",
                    },
                },
                {
                    name = "dnd-pictures-from-the-internet",
                    -- the full name as the title, so it is clear these were
                    -- found, not made
                    gallery = { slug = "dnd-pictures", title = "dnd-pictures-from-the-internet" },
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
                    gallery = { slug = "fediverse-stars", title = "Fediverse Stars" },
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
            -- the gallery pages' grid: columns, each picture's width, and the
            -- gaps between columns and between stacked pictures (px)
            gallery_layout = { columns = 4, thumbnail_width = 200, column_gap = 16, picture_gap = 8 },
            supported_formats = {"png", "jpg", "jpeg", "gif", "webp", "svg"},
            max_file_size_mb = 200,
            preserve_structure = true,
            overwrite_existing = false,
        },
    },
    -- }}}

    -- External syncs are described on the sources themselves: an `external`
    -- field on a directory entry (rsync from there) or an `archives` list (ZIP
    -- files that extract there). An empty `external_files` list used to sit
    -- here for the move to that layout (Issue 10-026); the move is done, so it
    -- was removed (2026-10-04).

    -- {{{ extraction
    -- Settings for the archive-scanning step of extraction.
    -- Read by: scripts/zip-extractor.lua
    --
    -- To switch a source off, set `enabled = false` on its entry under `sources`
    -- above. Four per-source switches used to sit here (enable_fediverse,
    -- enable_messages, enable_notes, enable_bluesky); nothing read them, so
    -- they were removed (scripts/audit-config-keys found them, 2026-10-04).
    extraction = {
        -- Issue 7-003: ZIP files to ignore during archive scanning.
        -- These are ZIPs that appear in input/ but aren't content archives
        -- (e.g., site backups embedded in media_attachments from fediverse export).
        ignored_archives = {
            "neocities-ritz-menardi"  -- Neocities site backup, not content data
        }
    },
    -- }}}

    -- The build's random seed is not set in this file. It is given on the
    -- command line as `run.sh --seed N`; with no --seed, run.sh picks one. Either
    -- way it is recorded in output/generation-metadata.json and stamped into the
    -- word-cloud page (Issues 10-058, 10-065). A `randomization.seed` setting
    -- used to sit here; run.sh stopped reading it, so it was removed.
    -- A source can still pin its own image order with `random_seed` on its
    -- entry under `sources`.

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
            -- Another raw PDF (input/notes/reddit-comments/, content starts
            -- %PDF-1.5): its binary bytes printed into chronological page 3 and
            -- several "different" pages as over-wide garbage lines. Excluded by
            -- hand, one by one, rather than by a "refuse PDFs" rule (owner,
            -- 2026-10-07).
            "tips for enlightenment that I've discovered that improved my life awakened",
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
        "my-art/help-me-obiwan-kenobi.png",
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
        include_boosts = false,             -- Boosts/reblogs. run.sh ignores this and requires --boosts yes|no; read only when scripts/extract-fediverse.lua or src/main.lua runs on its own without a boosts flag
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
    --   available_models: the models this server can serve. There is no
    --                     default: every run names its model with --model
    --                     (owner, 2026-10-21: "we should not have a default
    --                     model. It should be manually specified"). Each entry:
    --     model: Identifier sent in the OpenAI request body (llama-server
    --            serves whatever it has loaded). Convention is the GGUF
    --            basename without ".gguf". Also the name of the model's cache
    --            folder under assets/embeddings/.
    --     model_path: (local models) the GGUF file, relative to the project
    --                 DIR; start-llamacpp-server.sh passes it to llama-server -m.
    --     embedding_prompt_prefix: (optional) prepended to every input
    --                              (e.g. "clustering: " for nomic-embed-text v1.5).
    --     A model this server does not list is refused when its prefix or
    --     file is needed, rather than embedded without its prefix.
    --   launch_flags: (optional) Extra llama-server flags for THIS machine's
    --                 GPU, as a list of separate words ({ "--flash-attn", "off" }).
    --                 start-llamacpp-server.sh appends them after its own
    --                 flags. Only used by servers this project launches itself.
    --                 Put a GPU's limits here so they are stated choices, not
    --                 something llama.cpp quietly decides at load time.
    inference_servers = {
        {
            name = "gpu-server",
            description = "Remote GPU server (CUDA)",
            host = "192.168.0.115",
            port = 10265,
            available_models = {
                {
                    model = "nomic-embed-text-v1.5",
                    model_path = "assets/models/nomic-embed-text-v1.5.Q8_0.gguf",
                },
                { model = "mxbai-embed-large" },
            }
        },
        {
            name = "local",
            description = "Local llama.cpp instance (CUDA-enabled)",
            -- Loopback only. This was the machine's LAN address (192.168.1.100),
            -- and llama-server listens on whatever host it is told, so the
            -- unauthenticated server (no API key, any web origin allowed, plus a
            -- chat web page) was reachable by every device on the network.
            -- Nothing off this machine uses it, so it now listens only here.
            host = "127.0.0.1",
            port = 10265,
            -- This machine is a GTX 1080 Ti (Pascal, compute 6.1). llama.cpp's
            -- Flash Attention has no kernel for it: left on "auto", it found
            -- that out at load time and switched itself off with a warning --
            -- a silent fallback. Saying "off" here makes it a decision.
            launch_flags = { "--flash-attn", "off" },
            -- This one machine can serve several local GGUFs (one at a time:
            -- start-llamacpp-server.sh --server=local --model=NAME loads the
            -- chosen file). Each entry brings its own GGUF and the prompt
            -- phrasing its makers intend for clustering/similarity, so each
            -- model is asked the same question the right way. Switching the
            -- served model needs a server restart (and regenerating the caches
            -- that depend on the embedding space: embeddings.json, the
            -- similarity and diversity caches).
            available_models = {
                {
                    -- nomic-embed-text v1.5: 768-dimensional, and requires a
                    -- task prefix on every input. For diversity ranking of
                    -- poetry the right prefix is "clustering: ", which routes
                    -- the model through its clustering-oriented weights.
                    model = "nomic-embed-text-v1.5",
                    model_path = "assets/models/nomic-embed-text-v1.5.Q8_0.gguf",
                    embedding_prompt_prefix = "clustering: ",
                },
                {
                    model = "mxbai-embed-large-v1",
                    model_path = "assets/models/mxbai-embed-large-v1.Q8_0.gguf",
                    -- No task-prompt training; embed plain text for symmetric
                    -- poem-to-poem similarity (the "Represent this sentence..."
                    -- instruction is only for the query side of retrieval).
                    embedding_prompt_prefix = nil,
                },
                {
                    model = "embeddinggemma-300m",
                    model_path = "assets/models/embeddinggemma-300M-Q8_0.gguf",
                    -- Trained WITH task prompts; the clustering task uses this
                    -- exact prefix per the model card, mirroring nomic's intent.
                    embedding_prompt_prefix = "task: clustering | query: ",
                },
                {
                    -- Issue 1-010: EmbeddingGemma 2 (740M total, of which the
                    -- 270M text model is all this file holds; 8K-token context).
                    -- Needs llama.cpp b11454 or later. The model card keeps the
                    -- same symmetric clustering prompt as version 1.
                    model = "embeddinggemma-2",
                    model_path = "assets/models/embeddinggemma-2-Q8_0.gguf",
                    embedding_prompt_prefix = "task: clustering | query: ",
                    -- Issue 9-013: the vision projector that lets this model
                    -- embed pictures into the same space as text. A model
                    -- without one cannot place pictures, and the build stops.
                    vision_projector = "assets/models/mmproj-embeddinggemma-2-Q8_0.gguf",
                },
            },
        },
    },
    -- Default server name (must match a name above)
    -- If not set, first server in list is used
    default_inference_server = "local",
    -- }}}

    -- {{{ libraries
    -- Libraries built or kept outside this project, by where this machine
    -- keeps them. Another machine edits these two lines.
    libraries = {
        -- the terminal menu library (shared scripts); read by src/main.lua
        tui_lua_dir = "/home/ritz/programming/ai-stuff/scripts/libs",
        -- the LuaJIT build of the effil threading library, as a package.cpath
        -- entry ("?" is the module name); read by libs/effil-loader.lua
        effil_cpath = "/home/ritz/programming/ai-stuff/libs/lua/effil-jit/build/?.so",
    },
    -- }}}

    -- {{{ gpu
    -- Tuning for the graphics card, measured on a GTX 1080 Ti; another card
    -- wants its own numbers. Read by: scripts/precompute-diversity-sequences-gpu
    -- (Stage 8), which hands them to libs/vulkan-compute/lua/vk_compute.lua.
    gpu = {
        diversity = {
            batch_size = 3584,            -- walks run at once: one per CUDA core of a 1080 Ti (lowered to fit free memory)
            probe_steps = 10,             -- steps in the timing run each batch starts with
            chunk_seconds = 1.5,          -- GPU work per dispatch; the display watchdog kills one that runs ~2 s
            safety_factor = 0.6,          -- aim this far below chunk_seconds, so jitter stays under the watchdog
            l2_cache_bytes = 5767168,     -- the card's L2 cache, 5.5 MiB on a 1080 Ti: one tile of poems is sized to fit
            cache_share = 0.85,           -- of that cache, the part a tile may fill (the rest holds the centre, the mask, the code)
        },
    },
    -- }}}

    -- {{{ deploy
    -- How scripts/deploy-to-neocities paces its requests to Neocities
    -- (libs/neocities-sync.lua). Each batch carries up to "budget" worth of
    -- work; after grow_after batches in a row succeed the budget grows by
    -- "grow" (up to max_budget); a batch the site refuses as too large halves
    -- it (never below floor). A refusal for going too fast waits and retries,
    -- up to max_retries times. pause_seconds is a courtesy wait between calls.
    -- Read by: scripts/deploy-to-neocities
    deploy = {
        uploads = {                       -- budget in bytes of file data per request
            budget = 8 * 1024 * 1024,
            max_count = 60,               -- files per request, at most
            floor = 1,
            grow = 1.5,
            grow_after = 3,
            max_budget = 64 * 1024 * 1024,
            pause_seconds = 0.2,
            max_retries = 8,
        },
        deletions = {                     -- budget in files per request
            budget = 50,
            max_count = 50,
            floor = 1,
            grow = 1.5,
            grow_after = 3,
            max_budget = 64 * 1024 * 1024,
            pause_seconds = 0.2,
            max_retries = 8,
        },
    },
    -- }}}

    -- {{{ picture_embeddings
    -- How pictures get their place among the poems (Issue 9-013): the vision
    -- model embeds each picture itself.
    -- Read by: src/picture-embeddings.lua, src/augment-embeddings-with-images.lua
    picture_embeddings = {
        long_side = 1800,     -- pixels; a picture is shrunk to this before it is sent (handwriting read better at 1800 than 900)
        text_share = 0.5,     -- a text + picture post: this much its text, the rest its pictures
        request_seconds = 300, -- how long one picture may take before the server is called stuck
    },
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
        chronological_poems_per_page = 1000, -- Poems per chronological page (if paginated)
                                            -- CLI: --chrono-per-page N
        -- Issue 10-062: the chronological IMAGE gallery (gallery/chronological-NN.html,
        -- and chronological-reverse-NN.html newest first) is split into this many
        -- pages per direction; page size = ceil(images / this). Read by
        -- src/gallery-pages.lua through generate-gallery-pages.lua (the pages) and
        -- flat-html-generator.lua (the poem pages' links into them).
        gallery_chronological_pages = 10
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
    --
    -- Whether the word cloud is built is chosen by selecting its stage (stage
    -- 10) on the run.sh command line or menu. An `enabled` switch used to sit
    -- here; nothing read it, so it was removed (2026-10-04).
    word_cloud = {
        output_file = "wordcloud.html",
        min_occurrences = 5,        -- Minimum times a word must appear
        max_words = 200,            -- Words in the cloud and on word pages; the default offered when --words is not given (no limit: --all, or answer "all")
        poems_per_page = 50,        -- Poems on each word page; the default offered when --poems-per-page is not given (Issue 10-065a: this 50 used to be written in src/generate-word-pages.lua and applied silently)
        min_word_length = 3,        -- Ignore words shorter than this
        font_size_min = 1,          -- HTML font tag: 1-7 scale
        font_size_max = 7,
        -- The words' colours are semantic_colors above, the same ones the
        -- progress bars use: a word's colour means what a bar's colour means.

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
    -- The site's colours, in one place (owner, 2026-10-25): every page's
    -- <body bgcolor="..." text="..." link="..." vlink="..."> and the source
    -- browser's backgrounds come from here, through src/page-theme.lua.
    -- Pure black (#000000) background: on an OLED screen a black pixel is an
    -- unlit one (Issue 11-009).
    -- Read by: src/page-theme.lua
    html_theme = {
        background = "#000000",     -- True black background (OLED-friendly)
        text = "#E0E0E0",           -- Soft white: gentler than pure #FFFFFF on pure black in a dark room (owner, 2026-10-25)
        link = "#6699FF",           -- Blue for unvisited links
        vlink = "#9966FF"           -- Purple for visited links
    },
    -- }}}

    -- {{{ testing
    -- The embedding model and server the tests, the sample renderer's checks
    -- and the demos draw from. A build names its own (--model, --server);
    -- this is only the one the checks use, so they agree with each other.
    testing = { model = "embeddinggemma-2", server = "local" },
    -- }}}
}
