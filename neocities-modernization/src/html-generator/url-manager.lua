#!/usr/bin/env lua

-- URL Structure Manager for Poetry Website Generation
-- Handles clean URL generation, directory creation, and navigation paths

local utils = require("libs.utils")

local M = {}
local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

-- Default configuration
M.config = {
    base_output_dir = DIR .. "/generated-site",
    poetry_section = "words-pdf-sorted",
    main_categories = {"fediverse", "messages", "notes"},
    special_categories = {"golden"},
    browse_sections = {"by-similarity", "recent", "random"}
}

-- {{{ function M.set_config
function M.set_config(new_config)
    for key, value in pairs(new_config) do
        M.config[key] = value
    end
end
-- }}}

-- {{{ function M.generate_poem_url
function M.generate_poem_url(poem_id, category, options)
    options = options or {}
    category = category or "poems"
    local use_golden = options.use_golden_category or false
    
    -- Handle golden poem categorization
    if use_golden and options.is_golden then
        category = "golden"
    end
    
    return string.format("poems/%s/poem-%03d.html", category, tonumber(poem_id))
end
-- }}}

-- {{{ function M.generate_category_index_url
function M.generate_category_index_url(category)
    return string.format("poems/%s/index.html", category)
end
-- }}}

-- {{{ function M.generate_browse_url
function M.generate_browse_url(browse_type)
    return string.format("browse/%s.html", browse_type)
end
-- }}}

-- {{{ function M.generate_absolute_path
function M.generate_absolute_path(relative_url, base_dir)
    base_dir = base_dir or M.config.base_output_dir
    return string.format("%s/%s", base_dir, relative_url)
end
-- }}}

-- {{{ function M.generate_relative_navigation_path
function M.generate_relative_navigation_path(from_path, to_path)
    -- Calculate relative path from one location to another
    local from_parts = {}
    local to_parts = {}
    
    for part in string.gmatch(from_path, "[^/]+") do
        table.insert(from_parts, part)
    end
    
    for part in string.gmatch(to_path, "[^/]+") do
        table.insert(to_parts, part)
    end
    
    -- Remove filename from from_path
    if #from_parts > 0 and string.match(from_parts[#from_parts], "%.html$") then
        table.remove(from_parts)
    end
    
    -- Calculate how many directories to go up
    local levels_up = #from_parts
    local relative_path = ""
    
    for i = 1, levels_up do
        relative_path = relative_path .. "../"
    end
    
    relative_path = relative_path .. to_path
    
    return relative_path
end
-- }}}

-- {{{ function M.create_directory_structure
function M.create_directory_structure(base_output_dir)
    base_output_dir = base_output_dir or M.config.base_output_dir
    
    local directories = {
        base_output_dir,
        base_output_dir .. "/poems",
        base_output_dir .. "/browse"
    }
    
    -- Add main category directories
    for _, category in ipairs(M.config.main_categories) do
        table.insert(directories, base_output_dir .. "/poems/" .. category)
    end
    
    -- Add special category directories
    for _, category in ipairs(M.config.special_categories) do
        table.insert(directories, base_output_dir .. "/poems/" .. category)
    end
    
    utils.log_info("Creating directory structure at: " .. base_output_dir)
    
    for _, dir in ipairs(directories) do
        local success = os.execute("mkdir -p \"" .. dir .. "\"")
        if not success then
            utils.log_error("Failed to create directory: " .. dir)
            return false
        end
        utils.log_info("Created directory: " .. dir)
    end
    
    utils.log_info("Directory structure created successfully")
    return true
end
-- }}}

-- {{{ function M.get_poem_category
function M.get_poem_category(poem)
    if not poem then return "poems" end
    
    -- Check if it's a golden poem and should go in golden category
    if poem.is_fediverse_golden then
        return "golden"
    end
    
    -- Use the poem's existing category
    if poem.category then
        return poem.category
    end
    
    -- Default fallback
    return "poems"
end
-- }}}

-- {{{ function M.generate_breadcrumb_data
function M.generate_breadcrumb_data(current_poem, category)
    category = category or M.get_poem_category(current_poem)
    
    local breadcrumb_data = {
        {
            title = "Poetry Collection",
            url = M.generate_relative_navigation_path(
                M.generate_poem_url(current_poem.id or 1, category),
                "index.html"
            ),
            is_link = true
        },
        {
            title = string.format("%s Poems", category:gsub("^%l", string.upper)),
            url = M.generate_relative_navigation_path(
                M.generate_poem_url(current_poem.id or 1, category),
                M.generate_category_index_url(category)
            ),
            is_link = true
        },
        {
            title = current_poem.title or "Current Poem",
            url = "",
            is_link = false
        }
    }
    
    return breadcrumb_data
end
-- }}}

-- {{{ function M.get_directory_stats
function M.get_directory_stats(base_dir)
    base_dir = base_dir or M.config.base_output_dir
    
    local stats = {
        total_dirs = 0,
        category_dirs = 0,
        exists = false
    }
    
    -- Check if base directory exists
    if utils.file_exists(base_dir) then
        stats.exists = true
        
        -- Count directories
        local categories = {}
        table.insert(categories, M.config.main_categories)
        table.insert(categories, M.config.special_categories)
        
        for _, category_list in ipairs(categories) do
            for _, category in ipairs(category_list) do
                local category_path = base_dir .. "/poems/" .. category
                if utils.file_exists(category_path) then
                    stats.category_dirs = stats.category_dirs + 1
                end
            end
        end
        
        stats.total_dirs = stats.category_dirs + 2 -- poems + browse dirs
    end
    
    return stats
end
-- }}}

-- {{{ function M.validate_url_structure
function M.validate_url_structure(base_dir)
    base_dir = base_dir or M.config.base_output_dir
    
    local validation_results = {
        valid = true,
        errors = {},
        warnings = {}
    }
    
    -- Check base directory
    if not utils.file_exists(base_dir) then
        table.insert(validation_results.errors, "Base directory does not exist: " .. base_dir)
        validation_results.valid = false
        return validation_results
    end
    
    -- Check required subdirectories
    local required_dirs = {
        base_dir .. "/poems",
        base_dir .. "/browse"
    }
    
    for _, category in ipairs(M.config.main_categories) do
        table.insert(required_dirs, base_dir .. "/poems/" .. category)
    end
    
    for _, category in ipairs(M.config.special_categories) do
        table.insert(required_dirs, base_dir .. "/poems/" .. category)
    end
    
    for _, dir in ipairs(required_dirs) do
        if not utils.file_exists(dir) then
            table.insert(validation_results.errors, "Required directory missing: " .. dir)
            validation_results.valid = false
        end
    end
    
    return validation_results
end
-- }}}

-- {{{ function M.test_url_generation
function M.test_url_generation()
    utils.log_info("Testing URL generation system...")
    
    local tests = {
        {
            name = "Basic poem URL generation",
            test = function()
                local url = M.generate_poem_url(42, "fediverse")
                return url == "poems/fediverse/poem-042.html"
            end
        },
        {
            name = "Golden poem URL generation",
            test = function()
                local url = M.generate_poem_url(123, "fediverse", {use_golden_category = true, is_golden = true})
                return url == "poems/golden/poem-123.html"
            end
        },
        {
            name = "Category index URL generation",
            test = function()
                local url = M.generate_category_index_url("messages")
                return url == "poems/messages/index.html"
            end
        },
        {
            name = "Browse URL generation",
            test = function()
                local url = M.generate_browse_url("by-similarity")
                return url == "browse/by-similarity.html"
            end
        },
        {
            name = "Absolute path generation",
            test = function()
                local url = M.generate_absolute_path("poems/test/poem-001.html", "/test/base")
                return url == "/test/base/poems/test/poem-001.html"
            end
        },
        {
            name = "Relative navigation calculation",
            test = function()
                local rel_path = M.generate_relative_navigation_path("poems/fediverse/poem-001.html", "index.html")
                return rel_path == "../../index.html"
            end
        }
    }
    
    local passed = 0
    local total = #tests
    
    for _, test in ipairs(tests) do
        local success = test.test()
        if success then
            utils.log_info("✅ " .. test.name .. " - PASSED")
            passed = passed + 1
        else
            utils.log_error("❌ " .. test.name .. " - FAILED")
        end
    end
    
    utils.log_info(string.format("URL generation tests: %d/%d passed", passed, total))
    return passed == total
end
-- }}}

-- {{{ function M.test_directory_creation
function M.test_directory_creation()
    utils.log_info("Testing directory structure creation...")
    
    local test_dir = DIR .. "/test-generated-site"
    
    -- Clean up any existing test directory
    os.execute("rm -rf \"" .. test_dir .. "\"")
    
    -- Test directory creation
    local success = M.create_directory_structure(test_dir)
    if not success then
        utils.log_error("Directory creation failed")
        return false
    end
    
    -- Validate created structure
    local validation = M.validate_url_structure(test_dir)
    if not validation.valid then
        utils.log_error("Directory structure validation failed:")
        for _, error in ipairs(validation.errors) do
            utils.log_error("  - " .. error)
        end
        return false
    end
    
    -- Get statistics
    local stats = M.get_directory_stats(test_dir)
    utils.log_info(string.format("Created %d directories (%d category dirs)", stats.total_dirs, stats.category_dirs))
    
    -- Clean up test directory
    os.execute("rm -rf \"" .. test_dir .. "\"")
    
    utils.log_info("Directory creation test PASSED")
    return true
end
-- }}}

-- {{{ function M.run_all_tests
function M.run_all_tests()
    utils.log_info("Running URL manager test suite...")
    
    local url_test_passed = M.test_url_generation()
    local dir_test_passed = M.test_directory_creation()
    
    local all_passed = url_test_passed and dir_test_passed
    
    if all_passed then
        utils.log_info("🎉 All URL manager tests PASSED")
    else
        utils.log_error("❌ Some URL manager tests FAILED")
    end
    
    return all_passed
end
-- }}}

return M