#!/usr/bin/env lua

-- HTML Template Engine for Poetry Generation
-- Handles poem page generation with similarity recommendations

local utils = require("libs.utils")
local json = require("libs.json")
local url_manager = require("src.html-generator.url-manager")
local similarity_engine = require("src.html-generator.similarity-engine")
local golden_indicators = require("src.html-generator.golden-poem-indicators")

local M = {}
local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

-- {{{ function M.escape_html
function M.escape_html(text)
    if not text then return "" end
    return tostring(text)
        :gsub("&", "&amp;")
        :gsub("<", "&lt;")
        :gsub(">", "&gt;")
        :gsub('"', "&quot;")
        :gsub("'", "&#39;")
end
-- }}}

-- {{{ function M.generate_breadcrumb
function M.generate_breadcrumb(current_poem, category)
    category = category or url_manager.get_poem_category(current_poem)
    local breadcrumb_data = url_manager.generate_breadcrumb_data(current_poem, category)
    
    local html = ""
    for i, part in ipairs(breadcrumb_data) do
        if part.is_link then
            html = html .. string.format('<a href="%s">%s</a> > ', part.url, M.escape_html(part.title))
        else
            html = html .. '<span>' .. M.escape_html(part.title) .. '</span>'
        end
    end
    
    return html
end
-- }}}

-- NOTE: Golden poem indicator functions moved to golden-poem-indicators.lua module
-- This provides enhanced visual indicators with accessibility features

-- {{{ function M.generate_similarity_section
function M.generate_similarity_section(poem, poems_data, options)
    options = options or {}
    
    -- If we have pre-computed similar poems, use them
    if options.similar_poems and #options.similar_poems > 0 then
        return M.render_similarity_list(options.similar_poems)
    end
    
    -- Otherwise, generate recommendations using similarity engine
    if not poem or not poem.id then
        return '<p>No similarity data available for this poem.</p>'
    end
    
    local recommendations = similarity_engine.get_top_recommendations(
        poem.id, 
        poems_data, 
        {
            count = options.count or 10,
            apply_golden_bonus = true  -- Enable golden poem bonuses by default
        }
    )
    
    if #recommendations == 0 then
        return M.generate_fallback_recommendations(poem, poems_data)
    end
    
    local html = M.render_similarity_list(recommendations)
    
    -- Add exploration features
    html = html .. M.generate_exploration_controls(poem, poems_data)
    
    return html
end
-- }}}

-- {{{ function M.render_similarity_list
function M.render_similarity_list(recommendations)
    if not recommendations or #recommendations == 0 then
        return '<p>No similar poems found.</p>'
    end
    
    local html = '<ol class="similarity-list">\n'
    
    -- Use enhanced golden indicators system
    html = html .. golden_indicators.enhance_similarity_list_with_golden(recommendations)
    
    html = html .. '</ol>\n'
    return html
end
-- }}}

-- {{{ function M.generate_fallback_recommendations  
function M.generate_fallback_recommendations(poem, poems_data)
    -- Generate category-based recommendations if no similarity data
    local category_recs = similarity_engine.get_category_recommendations(
        poem.id, poems_data, poem.category, 5
    )
    
    if #category_recs > 0 then
        local html = '<p><em>Similarity data not yet available. Here are other poems from the same category:</em></p>\n'
        html = html .. M.render_similarity_list(category_recs)
        return html
    end
    
    -- Random recommendations as final fallback
    local random_recs = {}
    for i = 1, 3 do
        local random_rec = similarity_engine.generate_random_recommendation(poem.id, poems_data)
        if random_rec then
            table.insert(random_recs, random_rec)
        end
    end
    
    if #random_recs > 0 then
        local html = '<p><em>Discovering poems for you...</em></p>\n'
        html = html .. M.render_similarity_list(random_recs)
        return html
    end
    
    return '<p>Poem discovery features will be available once similarity processing is complete.</p>'
end
-- }}}

-- {{{ function M.generate_exploration_controls
function M.generate_exploration_controls(poem, poems_data)
    if not poem then return "" end
    
    local html = '<div class="exploration-controls">\n'
    
    -- Random similar poem (if we have similarity data)
    local random_sim = similarity_engine.generate_random_recommendation(poem.id, poems_data, poem.category)
    if random_sim then
        html = html .. string.format(
            '<p><a href="%s" class="explore-link">🎲 Discover Random Poem</a></p>\n',
            random_sim.url
        )
    end
    
    -- Category exploration
    if poem.category then
        local category_index_url = url_manager.generate_category_index_url(poem.category)
        html = html .. string.format(
            '<p><a href="%s" class="explore-link">📁 Browse All %s Poems</a></p>\n',
            category_index_url,
            poem.category:gsub("^%l", string.upper)
        )
    end
    
    -- Golden poems collection
    local golden_index_url = url_manager.generate_category_index_url("golden")
    html = html .. string.format(
        '<p><a href="%s" class="explore-link">✨ Golden Poem Collection</a></p>\n',
        golden_index_url
    )
    
    html = html .. '</div>\n'
    return html
end
-- }}}

-- {{{ function M.generate_poem_html
function M.generate_poem_html(poem, poems_data, options)
    options = options or {}
    local template_path = options.template_path or (DIR .. "/templates/poem-page.html")
    
    -- Load template
    if not utils.file_exists(template_path) then
        utils.log_error("Template file not found: " .. template_path)
        return nil
    end
    
    local template = utils.read_file(template_path)
    if not template then
        utils.log_error("Failed to read template: " .. template_path)
        return nil
    end
    
    -- Generate components
    local breadcrumb = M.generate_breadcrumb(poem, poem.category)
    local golden_indicator = golden_indicators.generate_golden_indicator(poem, "full")
    local character_display = golden_indicators.generate_character_count_display(poem)
    local similar_section = M.generate_similarity_section(poem, poems_data, {
        similar_poems = options.similar_poems,
        count = options.similarity_count or 10
    })
    
    -- Substitute template variables (escape % characters for gsub)
    local escaped_title = M.escape_html(poem.title or "Untitled"):gsub("%%", "%%%%")
    local escaped_content = M.escape_html(poem.content or ""):gsub("%%", "%%%%")
    local escaped_breadcrumb = breadcrumb:gsub("%%", "%%%%")
    local escaped_golden = golden_indicator:gsub("%%", "%%%%")
    local escaped_character = character_display:gsub("%%", "%%%%")
    local escaped_similar = similar_section:gsub("%%", "%%%%")
    
    template = template:gsub("{POEM_TITLE}", escaped_title)
    template = template:gsub("{POEM_CONTENT}", escaped_content)
    template = template:gsub("{BREADCRUMB_HTML}", escaped_breadcrumb)
    template = template:gsub("{GOLDEN_POEM_INDICATOR}", escaped_golden)
    template = template:gsub("{CHARACTER_COUNT_DISPLAY}", escaped_character)
    template = template:gsub("{SIMILAR_POEMS_SECTION}", escaped_similar)
    
    return template
end
-- }}}

-- {{{ function M.load_poems_data
function M.load_poems_data(poems_file)
    poems_file = poems_file or (DIR .. "/assets/poems.json")
    
    if not utils.file_exists(poems_file) then
        utils.log_error("Poems data file not found: " .. poems_file)
        return nil
    end
    
    local poems_json = utils.read_file(poems_file)
    local poems_data = json.decode(poems_json)
    
    if not poems_data or not poems_data.poems then
        utils.log_error("Invalid poems data format")
        return nil
    end
    
    utils.log_info(string.format("Loaded %d poems from %s", #poems_data.poems, poems_file))
    return poems_data
end
-- }}}

-- {{{ function M.get_poem_by_id
function M.get_poem_by_id(poems_data, poem_id)
    if not poems_data or not poems_data.poems then
        return nil
    end
    
    for _, poem in ipairs(poems_data.poems) do
        if poem.id == poem_id then
            return poem
        end
    end
    
    return nil
end
-- }}}

-- {{{ function M.validate_html
function M.validate_html(html_content)
    -- Basic HTML validation checks
    local errors = {}
    
    -- Check for basic structure
    if not html_content:match("<!DOCTYPE html>") then
        table.insert(errors, "Missing DOCTYPE declaration")
    end
    
    if not html_content:match("<html[^>]*>") then
        table.insert(errors, "Missing html tag")
    end
    
    if not html_content:match("<head[^>]*>") then
        table.insert(errors, "Missing head tag")
    end
    
    if not html_content:match("<title[^>]*>.*</title>") then
        table.insert(errors, "Missing title tag")
    end
    
    if not html_content:match('<meta charset="UTF%-8"') then
        table.insert(errors, "Missing charset meta tag")
    end
    
    if not html_content:match('<meta name="viewport"') then
        table.insert(errors, "Missing viewport meta tag")
    end
    
    return #errors == 0, errors
end
-- }}}

-- {{{ function M.test_template_system
function M.test_template_system()
    utils.log_info("Testing HTML template system...")
    
    -- Load test data
    local poems_data = M.load_poems_data()
    if not poems_data then
        return false
    end
    
    -- Find a test poem
    local test_poem = nil
    for _, poem in ipairs(poems_data.poems) do
        if poem.id and poem.content and poem.content:len() > 0 then
            test_poem = poem
            break
        end
    end
    
    if not test_poem then
        utils.log_error("No valid test poem found")
        return false
    end
    
    utils.log_info(string.format("Testing with poem ID %s: %s", 
                                test_poem.id or "unknown",
                                test_poem.title or "Untitled"))
    
    -- Generate test HTML
    local mock_similar_poems = {
        {id = 999, title = "Test Similar Poem", url = "poem-999.html", score = 0.85, is_golden = false},
        {id = 1000, title = "Another Similar Poem", url = "poem-1000.html", score = 0.72, is_golden = true}
    }
    
    local html = M.generate_poem_html(test_poem, mock_similar_poems)
    if not html then
        utils.log_error("Failed to generate HTML")
        return false
    end
    
    -- Validate generated HTML
    local valid, errors = M.validate_html(html)
    if not valid then
        utils.log_error("HTML validation failed:")
        for _, error in ipairs(errors) do
            utils.log_error("  - " .. error)
        end
        return false
    end
    
    -- Write test output
    local test_output_file = DIR .. "/test-poem.html"
    local success = utils.write_file(test_output_file, html)
    if success then
        utils.log_info("Test HTML generated successfully: " .. test_output_file)
        utils.log_info("Template system test PASSED")
        return true
    else
        utils.log_error("Failed to write test HTML file")
        return false
    end
end
-- }}}

return M