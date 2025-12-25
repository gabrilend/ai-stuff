#!/usr/bin/env luajit

-- {{{ Early argument parsing (before package.path setup)
-- Parse arguments to extract directory path, skipping flags like -I
-- This must happen before utils is loaded since package.path depends on DIR
local function parse_dir_from_args(args)
    if not args then return nil end
    for i = 1, #args do
        local a = args[i]
        -- Skip flags (start with -)
        if a and a:sub(1, 1) ~= "-" then
            return a
        end
        -- Handle --dir=path or --dir path
        if a == "--dir" and args[i + 1] then
            return args[i + 1]
        end
        if a:match("^--dir=") then
            return a:match("^--dir=(.+)")
        end
    end
    return nil
end

local function setup_dir_path(provided_dir)
    if provided_dir then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end
-- }}}

-- Script configuration
local DIR = setup_dir_path(parse_dir_from_args(arg))

-- Load required libraries
-- Include TUI library from shared scripts location (updates propagate automatically)
local TUI_LIBS = "/home/ritz/programming/ai-stuff/scripts/libs"
package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. TUI_LIBS .. "/?.lua;" .. package.path
local utils = require("utils")

-- Initialize asset path configuration (CLI --dir takes precedence over config)
-- This must happen early, before any asset_path() calls
utils.init_assets_root(arg)

-- Load modules properly by temporarily updating package.path
local old_path = package.path
package.path = DIR .. "/src/?.lua;" .. DIR .. "/libs/?.lua;" .. package.path

local poem_extractor = require("poem-extractor")
local poem_validator = require("poem-validator")
local image_manager = require("image-manager")
local flat_html_generator = require("flat-html-generator")
local dkjson = require("dkjson")

-- Restore original path
package.path = old_path

local M = {}

-- {{{ TUI Menu Configuration
-- Try to load TUI menu library (falls back to simple text menu if unavailable)
-- NOTE: The TUI library requires LuaJIT (for the 'bit' module). If running with
-- standard Lua, it will fall back to the simple text menu.
local tui_available, menu = pcall(require, "menu")
local tui_load_error = not tui_available and menu or nil  -- menu contains error message when pcall fails
local tui = tui_available and require("tui") or nil

-- {{{ function M.build_menu_config
-- Builds the unified menu configuration for the TUI library
-- Combines functionality from main.lua and flat-html-generator.lua into one interface
local function build_menu_config()
    return {
        title = "Neocities Poetry Modernization",
        subtitle = "Static HTML poetry recommendation system",
        sections = {
            -- Data Pipeline Section
            {
                id = "pipeline",
                title = "Data Pipeline",
                type = "single",  -- Radio-button style (one action at a time)
                items = {
                    {
                        id = "extract",
                        label = "Extract poems from sources",
                        type = "checkbox",
                        value = "0",
                        description = "Auto-detect JSON extracts or compiled.txt",
                        shortcut = "e"
                    },
                    {
                        id = "validate",
                        label = "Validate extracted poems",
                        type = "checkbox",
                        value = "0",
                        description = "Check data quality and generate validation report",
                        shortcut = "v"
                    },
                    {
                        id = "catalog",
                        label = "Catalog and manage images",
                        type = "checkbox",
                        value = "0",
                        description = "Index media attachments from archives",
                        shortcut = "c"
                    },
                    {
                        id = "dataset",
                        label = "Generate complete dataset",
                        type = "checkbox",
                        value = "0",
                        description = "Run extract + validate + catalog in sequence",
                        shortcut = "d"
                    }
                }
            },
            -- Embedding & Similarity Section
            {
                id = "embedding",
                title = "Embedding & Similarity",
                type = "single",
                items = {
                    {
                        id = "test_ollama",
                        label = "Test Ollama embedding service",
                        type = "checkbox",
                        value = "0",
                        description = "Verify connection to local LLM service",
                        shortcut = "t"
                    },
                    {
                        id = "similarity",
                        label = "Calculate similarity matrix (parallel)",
                        type = "checkbox",
                        value = "0",
                        description = "Generate per-poem similarity files using effil threads",
                        shortcut = "s"
                    }
                }
            },
            -- HTML Generation Section
            {
                id = "html",
                title = "HTML Generation",
                type = "single",
                items = {
                    {
                        id = "chronological",
                        label = "Generate chronological index",
                        type = "checkbox",
                        value = "0",
                        description = "Main entry point listing all poems in order"
                    },
                    {
                        id = "explore",
                        label = "Generate explore.html",
                        type = "checkbox",
                        value = "0",
                        description = "Discovery instructions page"
                    },
                    {
                        id = "similar_pages",
                        label = "Generate similarity pages (parallel)",
                        type = "checkbox",
                        value = "0",
                        description = "Per-poem pages sorted by semantic similarity"
                    },
                    {
                        id = "different_pages",
                        label = "Generate difference pages (parallel)",
                        type = "checkbox",
                        value = "0",
                        description = "Per-poem pages sorted by maximum diversity"
                    },
                    {
                        id = "full_website",
                        label = "Generate complete website",
                        type = "checkbox",
                        value = "0",
                        description = "Run all HTML generation steps",
                        shortcut = "w"
                    }
                }
            },
            -- Testing Section
            {
                id = "testing",
                title = "Testing & Debug",
                type = "single",
                items = {
                    {
                        id = "test_similar",
                        label = "Test single similarity page",
                        type = "checkbox",
                        value = "0",
                        description = "Generate one similarity page for testing"
                    },
                    {
                        id = "test_different",
                        label = "Test single difference page",
                        type = "checkbox",
                        value = "0",
                        description = "Generate one difference page for testing"
                    }
                }
            },
            -- Options Section (with editable fields)
            {
                id = "options",
                title = "Options",
                type = "multi",  -- Allow multiple options to be set
                items = {
                    {
                        id = "test_poem_id",
                        label = "Test poem ID",
                        type = "flag",
                        value = "1:5",  -- value:width format
                        description = "Poem ID for test page generation"
                    },
                    {
                        id = "thread_count",
                        label = "Thread count",
                        type = "flag",
                        value = "8:3",
                        description = "Number of parallel threads for generation"
                    }
                }
            },
            -- Utilities Section
            {
                id = "utilities",
                title = "Utilities",
                type = "single",
                items = {
                    {
                        id = "status",
                        label = "View project status",
                        type = "checkbox",
                        value = "0",
                        description = "Show file status and dataset statistics",
                        shortcut = "i"
                    },
                    {
                        id = "clean",
                        label = "Clean and rebuild assets",
                        type = "checkbox",
                        value = "0",
                        description = "Delete generated assets and regenerate",
                        shortcut = "r"
                    }
                }
            },
            -- Action Section
            {
                id = "action",
                title = "",
                type = "single",
                items = {
                    {
                        id = "run",
                        label = "[Run]",
                        type = "action",
                        value = "",
                        description = "Execute selected operation"
                    }
                }
            }
        }
    }
end
-- }}}

-- {{{ function M.show_tui_menu
-- Runs the TUI menu and returns the selected action and values
function M.show_tui_menu()
    if not tui_available then
        -- Fallback to simple text menu
        return M.show_simple_menu()
    end

    local config = build_menu_config()
    menu.init(config)

    local action, values = menu.run()
    menu.cleanup()

    return action, values
end
-- }}}

-- {{{ function M.show_simple_menu
-- Simple text-based menu fallback when TUI is not available
function M.show_simple_menu()
    -- Show why TUI isn't available (once per session)
    if tui_load_error and not M._tui_warning_shown then
        M._tui_warning_shown = true
        io.stderr:write("\n")
        io.stderr:write("╔══════════════════════════════════════════════════════════════════════╗\n")
        io.stderr:write("║  NOTE: TUI menu not available. Using simple text menu.              ║\n")
        io.stderr:write("║                                                                      ║\n")
        if tui_load_error:match("bit") then
            io.stderr:write("║  Reason: The 'bit' module requires LuaJIT.                         ║\n")
            io.stderr:write("║  Fix: Run with 'luajit src/main.lua -I' instead of 'lua'           ║\n")
            io.stderr:write("║       or use the shebang: './src/main.lua -I'                      ║\n")
        else
            io.stderr:write("║  Reason: " .. tostring(tui_load_error):sub(1, 60) .. "\n")
        end
        io.stderr:write("╚══════════════════════════════════════════════════════════════════════╝\n")
        io.stderr:write("\n")
    end

    local options = {
        "Extract poems (auto-detect JSON/compiled.txt)",
        "Validate extracted poems",
        "Test Ollama embedding service",
        "Generate complete dataset",
        "Catalog and manage images",
        "Generate website HTML",
        "View project status",
        "Clean and rebuild assets",
        "Exit"
    }

    local choice = utils.show_menu("Neocities Poetry Modernization", options)

    -- Map simple menu choice to action/values format
    local action_map = {
        [1] = "extract",
        [2] = "validate",
        [3] = "test_ollama",
        [4] = "dataset",
        [5] = "catalog",
        [6] = "full_website",
        [7] = "status",
        [8] = "clean",
        [9] = nil  -- Exit
    }

    if choice == 9 then
        return "quit", {}
    end

    local values = {}
    local action_id = action_map[choice]
    if action_id then
        values[action_id] = "1"
    end

    return "run", values
end
-- }}}

-- {{{ function M.show_main_menu (legacy wrapper)
-- Legacy wrapper for backwards compatibility
function M.show_main_menu()
    local options = {
        "Extract poems (auto-detect JSON/compiled.txt)",
        "Validate extracted poems",
        "Test Ollama embedding service",
        "Generate complete dataset",
        "Catalog and manage images",
        "Generate website HTML",
        "View project status",
        "Clean and rebuild assets",
        "Exit"
    }

    return utils.show_menu("Neocities Poetry Modernization", options)
end
-- }}}
-- }}}

-- {{{ function M.is_data_fresh
function M.is_data_fresh()
    -- Check if assets/poems.json exists and is newer than source files
    local output_file = utils.asset_path("poems.json")
    if not utils.file_exists(output_file) then
        return false
    end

    -- Get output file modification time
    local output_mtime = utils.get_file_mtime(output_file)
    if not output_mtime then
        return false
    end

    -- Check source JSON files
    local source_files = {
        DIR .. "/input/fediverse/files/poems.json",
        DIR .. "/input/messages/files/poems.json",
        DIR .. "/input/notes/files/poems.json"
    }

    for _, source_file in ipairs(source_files) do
        if utils.file_exists(source_file) then
            local source_mtime = utils.get_file_mtime(source_file)
            if source_mtime and source_mtime > output_mtime then
                return false -- Source is newer, need to regenerate
            end
        end
    end

    return true -- Output exists and is up to date
end
-- }}}

-- {{{ function M.extract_poems
function M.extract_poems(force)
    -- Skip if data is fresh (unless forced)
    if not force and M.is_data_fresh() then
        utils.log_info("Poem data is up to date, skipping extraction")
        return true
    end

    utils.log_info("Starting poem extraction with auto-detection...")
    local output_file = utils.asset_path("poems.json")

    -- Use auto-detection to handle both JSON extracts and compiled.txt
    local success, result = pcall(function()
        return poem_extractor.extract_poems_auto(DIR, output_file)
    end)

    if success then
        local mode = result.metadata.source_mode
        utils.log_info("Poem extraction completed using " .. mode .. " mode")
        utils.log_info("Found " .. result.metadata.total_poems .. " poems")
        return true
    else
        utils.log_error("Poem extraction failed: " .. tostring(result))
        return false
    end
end
-- }}}

-- {{{ function M.validate_poems
function M.validate_poems()
    utils.log_info("Starting poem validation...")
    local input_file = utils.asset_path("poems.json")
    local output_file = utils.asset_path("validation-report.json")
    
    if not utils.file_exists(input_file) then
        utils.log_error("Poems file not found. Run extraction first.")
        return false
    end
    
    poem_validator.validate_poems(input_file, output_file)
    utils.log_info("Poem validation completed")
    return true
end
-- }}}

-- {{{ function M.test_embedding_service
function M.test_embedding_service()
    utils.log_info("Testing Ollama embedding service...")
    
    -- Try to load ollama manager
    local ollama_manager = require("ollama-manager")
    if ollama_manager then
        local endpoint = ollama_manager.ensure_ollama_ready()
        if endpoint then
            ollama_manager.test_embedding(endpoint, "embeddinggemma:latest")
            return true
        end
    end
    
    utils.log_error("Embedding service test failed")
    return false
end
-- }}}

-- {{{ function M.catalog_images
function M.catalog_images()
    utils.log_info("Starting image cataloging...")
    
    local success, result = pcall(function()
        return image_manager.main()
    end)
    
    if success and result then
        utils.log_info("Image cataloging completed successfully")
        return true
    else
        utils.log_error("Image cataloging failed: " .. tostring(result))
        return false
    end
end
-- }}}

-- {{{ function M.is_html_fresh
function M.is_html_fresh()
    -- Check if output HTML files exist and are newer than source data
    -- We check chronological.html as the main indicator
    local output_file = DIR .. "/output/chronological.html"
    if not utils.file_exists(output_file) then
        return false
    end

    local output_mtime = utils.get_file_mtime(output_file)
    if not output_mtime then
        return false
    end

    -- Check against poems.json (the primary source data)
    local poems_file = utils.asset_path("poems.json")
    if utils.file_exists(poems_file) then
        local poems_mtime = utils.get_file_mtime(poems_file)
        if poems_mtime and poems_mtime > output_mtime then
            return false
        end
    end

    -- Check against similarity matrix (affects similarity/different pages)
    local similarity_file = utils.embeddings_dir("embeddinggemma_latest") .. "/similarity_matrix.json"
    if utils.file_exists(similarity_file) then
        local similarity_mtime = utils.get_file_mtime(similarity_file)
        if similarity_mtime and similarity_mtime > output_mtime then
            return false
        end
    end

    return true
end
-- }}}

-- {{{ function M.generate_website_html
function M.generate_website_html(force)
    -- Skip if HTML is fresh (unless forced)
    if not force and M.is_html_fresh() then
        utils.log_info("Website HTML is up to date, skipping generation")
        return true
    end

    utils.log_info("Starting website HTML generation...")

    -- Check dependencies
    local poems_file = utils.asset_path("poems.json")
    if not utils.file_exists(poems_file) then
        utils.log_error("Poems file not found. Run extraction first.")
        return false
    end

    local embeddings_file = utils.embeddings_dir("embeddinggemma_latest") .. "/embeddings.json"
    if not utils.file_exists(embeddings_file) then
        utils.log_error("Embeddings file not found. Run generate-embeddings.sh first.")
        return false
    end

    local similarity_file = utils.embeddings_dir("embeddinggemma_latest") .. "/similarity_matrix.json"
    if not utils.file_exists(similarity_file) then
        utils.log_error("Similarity matrix not found. Run generate-embeddings.sh first.")
        return false
    end

    -- Load required data
    utils.log_info("Loading poems data...")
    local poems_data = utils.read_json_file(poems_file)
    if not poems_data then
        utils.log_error("Failed to load poems data")
        return false
    end

    utils.log_info("Loading embeddings...")
    local embeddings_data = utils.read_json_file(embeddings_file)
    if not embeddings_data then
        utils.log_error("Failed to load embeddings")
        return false
    end

    utils.log_info("Loading similarity matrix...")
    local similarity_data = utils.read_json_file(similarity_file)
    if not similarity_data then
        utils.log_error("Failed to load similarity matrix")
        return false
    end

    local output_dir = DIR .. "/output"

    -- Generate chronological index (main entry point)
    utils.log_info("Generating chronological index...")
    local success = flat_html_generator.generate_chronological_index_with_navigation(poems_data, output_dir)
    if not success then
        utils.log_error("Failed to generate chronological index")
        return false
    end

    -- Generate explore.html (discovery instructions)
    utils.log_info("Generating explore.html...")
    flat_html_generator.generate_simple_discovery_instructions(output_dir)

    -- Generate all similarity and diversity pages
    -- Note: This is the long operation - generates ~12,000+ files
    utils.log_info("Generating similarity and diversity pages (this may take a while)...")
    local gen_success = flat_html_generator.generate_complete_flat_html_collection(
        poems_data, similarity_data, embeddings_data, output_dir
    )

    if gen_success then
        utils.log_info("Website HTML generation completed successfully")
        return true
    else
        utils.log_error("Website HTML generation failed")
        return false
    end
end
-- }}}

-- {{{ function M.generate_complete_dataset
function M.generate_complete_dataset()
    utils.log_info("Generating complete dataset...")

    if not M.extract_poems() then
        return false
    end

    if not M.validate_poems() then
        return false
    end

    if not M.catalog_images() then
        return false
    end

    utils.log_info("Complete dataset generation finished")
    return true
end
-- }}}

-- {{{ function M.show_project_status
function M.show_project_status()
    print("\n=== PROJECT STATUS ===")

    local paths = utils.get_project_paths(DIR)
    local assets_root = utils.get_assets_root()

    -- Check key files (input files use paths.root, generated assets use assets_root)
    local status_items = {
        {"Legacy Source", paths.root .. "/compiled.txt"},
        {"JSON Extracts (Fed)", paths.root .. "/input/fediverse/files/poems.json"},
        {"JSON Extracts (Msg)", paths.root .. "/input/messages/files/poems.json"},
        {"JSON Extracts (Notes)", paths.root .. "/input/notes/files/poems.json"},
        {"Processed Poems", utils.asset_path("poems.json")},
        {"Validation Report", utils.asset_path("validation-report.json")},
        {"Image Catalog", utils.asset_path("image-catalog.json")},
        {"Poem Extractor", paths.src .. "/poem-extractor.lua"},
        {"Poem Validator", paths.src .. "/poem-validator.lua"},
        {"Image Manager", paths.src .. "/image-manager.lua"},
        {"Ollama Manager", paths.src .. "/ollama-manager.lua"}
    }

    -- Show assets location
    print(string.format("%-20s: %s", "Assets Location", assets_root))

    for _, item in ipairs(status_items) do
        local name, filepath = item[1], item[2]
        local status = utils.file_exists(filepath) and "✅ Found" or "❌ Missing"
        print(string.format("%-20s: %s", name, status))
    end

    -- Show poem count if available
    local poems_file = utils.asset_path("poems.json")
    if utils.file_exists(poems_file) then
        local content = utils.read_file(poems_file)
        if content then
            local poem_count = select(2, content:gsub('"id":', '"id":'))
            print(string.format("%-20s: %d poems", "Dataset Size", poem_count))
        end
    end

    print("")
end
-- }}}

-- {{{ function M.clean_and_rebuild
function M.clean_and_rebuild()
    utils.log_info("Cleaning and rebuilding assets...")

    if utils.confirm_action("This will delete existing assets. Continue?") then
        -- Remove old generated assets (from configured assets location)
        os.execute("rm -f " .. utils.asset_path("poems.json"))
        os.execute("rm -f " .. utils.asset_path("validation-report.json"))

        -- Regenerate
        return M.generate_complete_dataset()
    else
        utils.log_info("Operation cancelled")
        return false
    end
end
-- }}}

-- {{{ function M.handle_tui_action
-- Handles actions from the TUI menu based on which items are selected
-- values is a table mapping item_id -> "1" for selected items
function M.handle_tui_action(values)
    local executed = false

    -- Data Pipeline actions
    if values.extract == "1" then
        M.extract_poems(true)  -- force=true in interactive mode
        executed = true
    end
    if values.validate == "1" then
        M.validate_poems()
        executed = true
    end
    if values.catalog == "1" then
        M.catalog_images()
        executed = true
    end
    if values.dataset == "1" then
        M.generate_complete_dataset()
        executed = true
    end

    -- Embedding & Similarity actions
    if values.test_ollama == "1" then
        M.test_embedding_service()
        executed = true
    end
    if values.similarity == "1" then
        -- Run parallel similarity calculation
        utils.log_info("Running parallel similarity calculation...")
        local sim_engine = require("similarity-engine-parallel")
        local thread_count = tonumber(values.thread_count) or 8
        local embeddings_file = utils.embeddings_dir("embeddinggemma_latest") .. "/embeddings.json"
        sim_engine.calculate_similarity_matrix_parallel(embeddings_file, "embeddinggemma:latest", 0.2, false, thread_count)
        executed = true
    end

    -- HTML Generation actions
    if values.chronological == "1" then
        local poems_file = utils.asset_path("poems.json")
        local poems_data = utils.read_json_file(poems_file)
        if poems_data then
            flat_html_generator.generate_chronological_index_with_navigation(poems_data, DIR .. "/output")
            utils.log_info("Generated chronological.html")
        end
        executed = true
    end
    if values.explore == "1" then
        flat_html_generator.generate_simple_discovery_instructions(DIR .. "/output")
        utils.log_info("Generated explore.html")
        executed = true
    end
    if values.similar_pages == "1" then
        utils.log_info("Generating similarity pages (use scripts/generate-html-parallel --similar-only)...")
        os.execute("luajit " .. DIR .. "/scripts/generate-html-parallel --similar-only")
        executed = true
    end
    if values.different_pages == "1" then
        utils.log_info("Generating difference pages (use scripts/generate-html-parallel --different-only)...")
        os.execute("luajit " .. DIR .. "/scripts/generate-html-parallel --different-only")
        executed = true
    end
    if values.full_website == "1" then
        M.generate_website_html(true)
        executed = true
    end

    -- Testing actions
    if values.test_similar == "1" then
        local poem_id = tonumber(values.test_poem_id) or 1
        M.test_single_similarity_page(poem_id)
        executed = true
    end
    if values.test_different == "1" then
        local poem_id = tonumber(values.test_poem_id) or 1
        M.test_single_difference_page(poem_id)
        executed = true
    end

    -- Utility actions
    if values.status == "1" then
        M.show_project_status()
        executed = true
    end
    if values.clean == "1" then
        M.clean_and_rebuild()
        executed = true
    end

    return executed
end
-- }}}

-- {{{ function M.test_single_similarity_page
-- Test generating a single similarity page for debugging
function M.test_single_similarity_page(poem_id)
    utils.log_info("Testing similarity page for poem " .. poem_id .. "...")
    local poems_file = utils.asset_path("poems.json")
    local similarity_file = utils.embeddings_dir("embeddinggemma_latest") .. "/similarity_matrix.json"
    local output_dir = DIR .. "/output"

    local poems_data = utils.read_json_file(poems_file)
    local similarity_data = utils.read_json_file(similarity_file)

    if poems_data and similarity_data then
        local poem_data = nil
        for _, poem in ipairs(poems_data.poems) do
            if poem.id == poem_id then
                poem_data = poem
                break
            end
        end

        if poem_data then
            local ranking = flat_html_generator.generate_similarity_ranked_list(poem_id, poems_data, similarity_data.similarities or similarity_data)
            local html = flat_html_generator.generate_flat_poem_list_html(poem_data, ranking, "similar", poem_id)
            local test_file = string.format("%s/test_similar_%03d.html", output_dir, poem_id)
            os.execute("mkdir -p " .. output_dir)
            utils.write_file(test_file, html)
            utils.log_info("Test file written: " .. test_file)
        else
            utils.log_error("Poem ID " .. poem_id .. " not found")
        end
    else
        utils.log_error("Failed to load required data files")
    end
end
-- }}}

-- {{{ function M.test_single_difference_page
-- Test generating a single difference page for debugging
function M.test_single_difference_page(poem_id)
    utils.log_info("Testing difference page for poem " .. poem_id .. "...")
    local poems_file = utils.asset_path("poems.json")
    local embeddings_file = utils.embeddings_dir("embeddinggemma_latest") .. "/embeddings.json"
    local output_dir = DIR .. "/output"

    local poems_data = utils.read_json_file(poems_file)
    local embeddings_data = utils.read_json_file(embeddings_file)

    if poems_data and embeddings_data then
        local poem_data = nil
        for _, poem in ipairs(poems_data.poems) do
            if poem.id == poem_id then
                poem_data = poem
                break
            end
        end

        if poem_data then
            local diversity_chaining = require("diversity-chaining")
            local ranking = diversity_chaining.generate_diversity_chain(poem_id, poems_data, embeddings_data)
            local html = flat_html_generator.generate_flat_poem_list_html(poem_data, ranking, "different", poem_id)
            local test_file = string.format("%s/test_different_%03d.html", output_dir, poem_id)
            os.execute("mkdir -p " .. output_dir)
            utils.write_file(test_file, html)
            utils.log_info("Test file written: " .. test_file)
        else
            utils.log_error("Poem ID " .. poem_id .. " not found")
        end
    else
        utils.log_error("Failed to load required data files")
    end
end
-- }}}

-- {{{ function M.main
-- Main entry point with support for selective stage execution via CLI flags
-- Options table can include: interactive, parse_only, validate_only, catalog_only, html_only, force, threads
function M.main(options)
    options = options or {}

    if options.interactive then
        -- Use TUI menu if available, otherwise fall back to simple menu
        while true do
            local action, values = M.show_tui_menu()

            if action == "quit" then
                print("Goodbye!")
                break
            elseif action == "run" then
                local executed = M.handle_tui_action(values)

                if executed then
                    -- Don't pause after status display
                    if values.status ~= "1" then
                        print("\nPress Enter to continue...")
                        io.read()
                    end
                else
                    print("No action selected. Use space to toggle options, then press Enter or select [Run].")
                    print("\nPress Enter to continue...")
                    io.read()
                end
            end
        end
    elseif options.parse_only then
        -- Run only poem parsing/extraction
        utils.log_info("Running poem extraction only")
        M.extract_poems(options.force)
    elseif options.validate_only then
        -- Run only validation
        utils.log_info("Running poem validation only")
        M.validate_poems()
    elseif options.catalog_only then
        -- Run only image cataloging
        utils.log_info("Running image cataloging only")
        M.catalog_images()
    elseif options.html_only then
        -- Run only HTML generation
        utils.log_info("Running HTML generation only")
        M.generate_website_html(options.force)
    else
        -- Non-interactive mode - generate dataset and website HTML (full pipeline)
        utils.log_info("Running in non-interactive mode (full pipeline)")
        M.show_project_status()
        M.generate_complete_dataset()
        M.generate_website_html(options.force)
    end
end
-- }}}

-- Command line execution
if arg then
    local options = utils.parse_cli_args(arg)
    if options.dir_override then
        DIR = options.dir_override
        package.path = DIR .. "/libs/?.lua;" .. package.path
    end

    M.main(options)
end

return M