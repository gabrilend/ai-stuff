#!/usr/bin/env lua

-- {{{ local function setup_dir_path
local function setup_dir_path(provided_dir)
    if provided_dir then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end
-- }}}

-- Script configuration
local DIR = setup_dir_path(arg and arg[1])

-- Load required libraries
package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. package.path
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

-- {{{ function M.show_main_menu
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
    local similarity_file = utils.embeddings_dir("EmbeddingGemma_latest") .. "/similarity_matrix.json"
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

    local embeddings_file = utils.embeddings_dir("EmbeddingGemma_latest") .. "/embeddings.json"
    if not utils.file_exists(embeddings_file) then
        utils.log_error("Embeddings file not found. Run generate-embeddings.sh first.")
        return false
    end

    local similarity_file = utils.embeddings_dir("EmbeddingGemma_latest") .. "/similarity_matrix.json"
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

-- {{{ function M.main
function M.main(interactive_mode)
    if interactive_mode then
        print("Neocities Poetry Modernization - Main Interface")
        print("Project Directory: " .. utils.relative_path(DIR, DIR))

        while true do
            local choice = M.show_main_menu()

            if choice == 1 then
                M.extract_poems()
            elseif choice == 2 then
                M.validate_poems()
            elseif choice == 3 then
                M.test_embedding_service()
            elseif choice == 4 then
                M.generate_complete_dataset()
            elseif choice == 5 then
                M.catalog_images()
            elseif choice == 6 then
                M.generate_website_html(true)  -- force=true in interactive mode
            elseif choice == 7 then
                M.show_project_status()
            elseif choice == 8 then
                M.clean_and_rebuild()
            elseif choice == 9 then
                print("Goodbye!")
                break
            else
                print("Invalid choice. Please try again.")
            end

            if choice and choice ~= 7 then  -- Don't pause after status display
                print("\nPress Enter to continue...")
                io.read()
            end
        end
    else
        -- Non-interactive mode - generate dataset and website HTML
        utils.log_info("Running in non-interactive mode")
        M.show_project_status()
        M.generate_complete_dataset()
        M.generate_website_html()
    end
end
-- }}}

-- Command line execution
if arg then
    local interactive, dir_override = utils.parse_interactive_args(arg)
    if dir_override then
        DIR = dir_override
        package.path = DIR .. "/libs/?.lua;" .. package.path
    end
    
    M.main(interactive)
end

return M