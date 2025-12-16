#!/usr/bin/env lua

-- Golden Poem Collection Page Generator
-- Creates dedicated browsing interfaces for fediverse golden poems

package.path = package.path .. ';./?.lua;./libs/?.lua'

local utils = require("libs.utils")
local template_engine = require("src.html-generator.template-engine")
local similarity_engine = require("src.html-generator.similarity-engine")
local golden_indicators = require("src.html-generator.golden-poem-indicators")
local url_manager = require("src.html-generator.url-manager")

-- Import progress bar system from flat-html-generator
local flat_html_generator = require("src.flat-html-generator")

-- Color configuration for progress bars (copied from flat-html-generator)
local COLOR_CONFIG = {
    red = "#dc3c3c",
    blue = "#3c78dc", 
    green = "#3cb45a",
    purple = "#8c3cc8",
    orange = "#e68c3c",
    yellow = "#c8b428",
    gray = "#787878"
}

local M = {}
local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

-- {{{ function escape_html
local function escape_html(text)
    if not text then return "" end
    return tostring(text):gsub("[<>&\"']", {["<"]="&lt;", [">"]="&gt;", ["&"]="&amp;", ["\""]="&quot;", ["'"]="&#39;"})
end
-- }}}

-- {{{ function parse_date_for_comparison
local function parse_date_for_comparison(date_str)
    if not date_str then return 0 end
    
    -- Handle ISO 8601 format: "2023-04-20T05:22:03" or "2023-04-20T05:22:03Z"
    local year, month, day, hour, min, sec = date_str:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    
    if year and month and day and hour and min and sec then
        -- Convert to timestamp for comparison (rough approximation)
        return tonumber(year) * 10000000000 + tonumber(month) * 100000000 + 
               tonumber(day) * 1000000 + tonumber(hour) * 10000 + 
               tonumber(min) * 100 + tonumber(sec)
    end
    
    -- Fallback: try to extract just year-month-day
    year, month, day = date_str:match("(%d+)-(%d+)-(%d+)")
    if year and month and day then
        return tonumber(year) * 10000 + tonumber(month) * 100 + tonumber(day)
    end
    
    return 0
end
-- }}}

-- {{{ function load_poem_colors
local function load_poem_colors()
    local poem_colors_file = DIR .. "/assets/embeddings/EmbeddingGemma_latest/poem_colors.json"
    local poem_colors_data = utils.read_json_file(poem_colors_file)
    
    if poem_colors_data and poem_colors_data.poem_colors then
        utils.log_info(string.format("Loaded semantic colors for %d poems", poem_colors_data.total_poems))
        return poem_colors_data.poem_colors
    else
        utils.log_warn("Could not load poem colors, using fallback colors")
        -- Fallback color assignment
        return {}
    end
end
-- }}}

-- {{{ function generate_progress_dashes
local function generate_progress_dashes(progress_info, color_name)
    local total_chars = 80
    local progress_chars = math.floor((progress_info.percentage / 100) * total_chars)
    local remaining_chars = total_chars - progress_chars
    
    -- Get color information
    local hex_color = COLOR_CONFIG[color_name] or COLOR_CONFIG["gray"]
    
    -- Create progress visualization using equals/dash distinction for all poems
    local progress_section = string.rep("═", progress_chars)  -- Equals for progress (thick)
    local remaining_section = string.rep("─", remaining_chars)  -- Dashes for remainder (thin)
    
    -- Apply color styling to progress section only
    local colored_progress = string.format(
        '<span style="color: %s; font-weight: bold;">%s</span>%s',
        hex_color, progress_section, remaining_section
    )
    
    -- Screen reader accessible version - brief format for frequent use
    local screen_reader_text = string.format(
        'aria-label="eighty dashes. %s."',
        color_name
    )
    
    return {
        visual = colored_progress,
        accessibility = screen_reader_text,
        percentage = progress_info.percentage
    }
end
-- }}}

-- {{{ function filter_golden_poems
function filter_golden_poems(poems_data)
    local golden_poems = {}
    
    for poem_id, poem in pairs(poems_data.poems) do
        if poem.is_fediverse_golden then
            table.insert(golden_poems, {
                id = poem_id,
                title = poem.title or ("Poem " .. poem_id),
                content = poem.content,
                category = poem.category,
                character_count = poem.character_count,
                creation_date = poem.creation_date or poem.metadata.creation_date,
                url = url_manager.generate_poem_url(poem_id, poem.category),
                similarity_score = poem.similarity_score or 0
            })
        end
    end
    
    -- Sort by similarity score (highest first)
    table.sort(golden_poems, function(a, b)
        return a.similarity_score > b.similarity_score
    end)
    
    return golden_poems
end
-- }}}

-- {{{ function select_featured_golden_poems
function select_featured_golden_poems(golden_poems, count)
    count = count or 6
    
    local featured = {}
    local used_indices = {}
    
    -- Start with highest similarity score
    if #golden_poems > 0 then
        table.insert(featured, golden_poems[1])
        used_indices[1] = true
    end
    
    -- Select diverse poems using simple distribution
    for i = 2, math.min(count, #golden_poems) do
        local step = math.max(1, math.floor(#golden_poems / count))
        local target_index = i * step
        
        -- Find nearest unused poem
        local best_candidate = nil
        local min_distance = math.huge
        
        for j, candidate in ipairs(golden_poems) do
            if not used_indices[j] then
                local distance = math.abs(j - target_index)
                if distance < min_distance then
                    min_distance = distance
                    best_candidate = j
                end
            end
        end
        
        if best_candidate then
            table.insert(featured, golden_poems[best_candidate])
            used_indices[best_candidate] = true
        end
    end
    
    return featured
end
-- }}}

-- {{{ function generate_static_fediverse_copy_area
function generate_static_fediverse_copy_area(poem)
    return string.format([[
<div class="fediverse-copy-area">
    <h4>🌐 Ready for Fediverse Sharing</h4>
    <p class="copy-instructions">Select and copy the text below (1024 characters):</p>
    <textarea readonly class="poem-copy-text" rows="6" cols="60">%s</textarea>
    <p class="copy-note">
        💡 <strong>How to copy:</strong> Click in the text area above, press Ctrl+A (Cmd+A on Mac) to select all, 
        then Ctrl+C (Cmd+C on Mac) to copy. Paste into your fediverse platform.
    </p>
</div>]], escape_html(poem.content))
end
-- }}}

-- {{{ function generate_featured_section
function generate_featured_section(featured_golden)
    local featured_html = ""
    
    for i, poem in ipairs(featured_golden) do
        local copy_area = generate_static_fediverse_copy_area(poem)
        featured_html = featured_html .. string.format([[
<div class="featured-golden-card">
    <h3><a href="../%s/%s">%s</a> ✨</h3>
    <div class="poem-preview">%s</div>
    <div class="poem-meta">
        <span class="character-count">1024 characters</span>
        <span class="category">%s category</span>
    </div>
    <div class="poem-actions">
        <a href="../%s/%s" class="read-button">Read Full Poem →</a>
        <span class="fediverse-ready">✨ 1024 chars - Perfect for fediverse!</span>
    </div>
    %s
</div>]], 
            poem.category, 
            string.format("poem-%03d.html", poem.id),
            escape_html(poem.title),
            escape_html(string.sub(poem.content, 1, 150)) .. "...",
            poem.category,
            poem.category,
            string.format("poem-%03d.html", poem.id),
            copy_area)
    end
    
    return featured_html
end
-- }}}

-- {{{ function generate_complete_golden_index
function generate_complete_golden_index(golden_poems)
    local index_html = [[<div class="golden-index-grid">]]
    
    for i, poem in ipairs(golden_poems) do
        index_html = index_html .. string.format([[
<div class="golden-index-item">
    <div class="item-number">%d</div>
    <div class="item-content">
        <h4><a href="../%s/%s">%s</a> ✨</h4>
        <p class="item-preview">%s...</p>
        <p class="item-meta">%s category • Perfect fediverse length</p>
    </div>
</div>]], i, poem.category, 
            string.format("poem-%03d.html", poem.id),
            escape_html(poem.title),
            escape_html(string.sub(poem.content, 1, 80)),
            poem.category)
    end
    
    index_html = index_html .. "</div>"
    return index_html
end
-- }}}

-- {{{ function generate_golden_collection_index
function generate_golden_collection_index(poems_data, output_dir)
    local golden_poems = filter_golden_poems(poems_data)
    utils.log_info(string.format("Found %d golden poems for collection", #golden_poems))
    
    if #golden_poems == 0 then
        utils.log_warn("No golden poems found - skipping collection generation")
        return nil
    end
    
    -- Sort golden poems by similarity scores for featured selection
    local featured_golden = select_featured_golden_poems(golden_poems, 6)
    local complete_index = generate_complete_golden_index(golden_poems)
    
    -- Create golden collection template
    local template = [[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="Golden Poem Collection - Poetry perfectly formatted for fediverse sharing at exactly 1024 characters">
    <title>Golden Poem Collection - Perfect Fediverse Poetry</title>
</head>
<body>
    <nav class="breadcrumb">
        <a href="../../index.html">Poetry Collection</a> > 
        <span>Golden Poems</span>
    </nav>
    
    <header class="collection-header">
        <h1>✨ Golden Poem Collection</h1>
        <div class="collection-stats">
            <p><strong>{GOLDEN_COUNT}</strong> poems of exactly <strong>1024 characters</strong></p>
            <p>Perfect for fediverse sharing • Artistic constraint achievements</p>
        </div>
    </header>
    
    <main class="collection-main">
        <section class="featured-golden">
            <h2>Featured Golden Poems</h2>
            {FEATURED_GOLDEN_POEMS}
        </section>
        
        <section class="browse-options">
            <h2>Explore the Collection</h2>
            <div class="browse-grid">
                <div class="browse-card">
                    <h3>📈 Most Similar</h3>
                    <p>Discover golden poems through AI-powered similarity recommendations</p>
                    <a href="by-similarity.html">Browse by Similarity →</a>
                </div>
                
                <div class="browse-card">
                    <h3>📅 Chronological</h3>
                    <p>Explore golden poems in order of creation or discovery</p>
                    <a href="chronological.html">Browse Chronologically →</a>
                </div>
                
                <div class="browse-card">
                    <h3>🎲 Random Discovery</h3>
                    <p>Serendipitous exploration of golden poem achievements</p>
                    <a href="random.html">Random Golden Poem →</a>
                </div>
            </div>
        </section>
        
        <section class="complete-index">
            <h2>Complete Golden Poem Index</h2>
            {COMPLETE_GOLDEN_INDEX}
        </section>
    </main>
</body>
</html>]]
    
    -- Substitute template variables
    template = template:gsub("{GOLDEN_COUNT}", tostring(#golden_poems))
    template = template:gsub("{FEATURED_GOLDEN_POEMS}", generate_featured_section(featured_golden))
    template = template:gsub("{COMPLETE_GOLDEN_INDEX}", complete_index)
    
    -- Ensure golden directory exists
    local golden_dir = output_dir .. "/poems/golden"
    os.execute("mkdir -p " .. golden_dir)
    
    -- Write collection index
    local output_file = golden_dir .. "/index.html"
    local success = utils.write_file(output_file, template)
    
    if success then
        utils.log_info("Generated golden collection index: " .. output_file)
        return {
            file = output_file,
            golden_count = #golden_poems,
            featured_count = #featured_golden
        }
    else
        utils.log_error("Failed to generate golden collection index")
        return nil
    end
end
-- }}}

-- {{{ function generate_golden_similarity_browser
function generate_golden_similarity_browser(golden_poems, similarity_data, output_dir)
    if #golden_poems == 0 then
        utils.log_warn("No golden poems for similarity browser")
        return nil
    end
    
    -- Create similarity clusters for golden poems
    local similarity_clusters = create_golden_similarity_clusters(golden_poems, similarity_data)
    local clusters_html = ""
    
    for cluster_name, cluster_poems in pairs(similarity_clusters) do
        clusters_html = clusters_html .. string.format([[
<div class="similarity-cluster">
    <h3>%s</h3>
    <div class="cluster-poems">
        %s
    </div>
</div>]], escape_html(cluster_name), generate_cluster_poem_list(cluster_poems))
    end
    
    local template = [[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Golden Poems by Similarity</title>
</head>
<body>
    <nav class="breadcrumb">
        <a href="../../index.html">Poetry Collection</a> > 
        <a href="index.html">Golden Poems</a> > 
        <span>By Similarity</span>
    </nav>
    
    <h1>✨ Golden Poems by Similarity</h1>
    <p>Explore golden poems grouped by AI-powered similarity analysis.</p>
    
    {SIMILARITY_CLUSTERS}
</body>
</html>]]
    
    template = template:gsub("{SIMILARITY_CLUSTERS}", clusters_html)
    
    local output_file = output_dir .. "/poems/golden/by-similarity.html"
    local success = utils.write_file(output_file, template)
    
    if success then
        utils.log_info("Generated golden similarity browser: " .. output_file)
        return output_file
    else
        utils.log_error("Failed to generate golden similarity browser")
        return nil
    end
end
-- }}}

-- {{{ function create_golden_similarity_clusters
function create_golden_similarity_clusters(golden_poems, similarity_data)
    local clusters = {
        ["High Similarity (>0.8)"] = {},
        ["Medium Similarity (0.6-0.8)"] = {},
        ["Unique Poems (<0.6)"] = {}
    }
    
    for _, poem in ipairs(golden_poems) do
        local score = poem.similarity_score or 0
        
        if score > 0.8 then
            table.insert(clusters["High Similarity (>0.8)"], poem)
        elseif score >= 0.6 then
            table.insert(clusters["Medium Similarity (0.6-0.8)"], poem)
        else
            table.insert(clusters["Unique Poems (<0.6)"], poem)
        end
    end
    
    return clusters
end
-- }}}

-- {{{ function generate_cluster_poem_list
function generate_cluster_poem_list(cluster_poems)
    local list_html = ""
    
    for _, poem in ipairs(cluster_poems) do
        list_html = list_html .. string.format([[
<div class="cluster-poem-item golden-poem">
    <h4><a href="../%s/%s">%s</a> ✨</h4>
    <p>%s...</p>
    <p class="poem-meta">%s category • 1024 characters</p>
</div>]], poem.category, 
            string.format("poem-%03d.html", poem.id),
            escape_html(poem.title),
            escape_html(string.sub(poem.content, 1, 100)),
            poem.category)
    end
    
    return list_html
end
-- }}}

-- {{{ function generate_golden_chronological_browser
function generate_golden_chronological_browser(golden_poems, output_dir)
    if #golden_poems == 0 then
        return nil
    end
    
    -- Sort golden poems chronologically by actual creation dates
    local sorted_poems = {}
    for _, poem in ipairs(golden_poems) do
        table.insert(sorted_poems, poem)
    end
    
    table.sort(sorted_poems, function(a, b)
        local date_a = parse_date_for_comparison(a.creation_date)
        local date_b = parse_date_for_comparison(b.creation_date)
        
        -- Sort chronologically (earliest first)
        if date_a ~= date_b then
            return date_a < date_b
        end
        
        -- Fallback to ID for consistent sorting if dates are equal
        return a.id < b.id
    end)
    
    -- Load poem colors once for all poems
    local poem_colors = load_poem_colors()
    
    local chronological_html = ""
    
    for i, poem in ipairs(sorted_poems) do
        local creation_date_display = poem.creation_date and 
            poem.creation_date:match("(%d+-%d+-%d+)") or "Unknown date"
        
        local timeline_progress = i / #sorted_poems * 100
        
        local semantic_color = (poem_colors[poem.id] and poem_colors[poem.id].color) or "gray"
        
        -- Generate progress information
        local progress_info = {
            poem_id = poem.id,
            total_poems = #sorted_poems,
            percentage = timeline_progress,
            position = i
        }
        
        -- Generate Unicode progress bar
        local progress_dashes = generate_progress_dashes(progress_info, semantic_color)
        
        chronological_html = chronological_html .. string.format([[
<div class="chronological-entry">
    <div class="entry-number">%d</div>
    <div class="entry-content">
        <h4><a href="../%s/%s">%s</a> ✨</h4>
        <p class="entry-preview">%s...</p>
        <p class="entry-meta">Created: %s • 1024 characters • %s category</p>
        <div %s>%s</div>
        <p style="color: #666; font-size: 0.9rem; margin: 0.25rem 0 0 0;">%.1f%% through timeline</p>
    </div>
</div>]], i, poem.category, 
            string.format("poem-%03d.html", poem.id),
            escape_html(poem.title),
            escape_html(string.sub(poem.content, 1, 100)),
            creation_date_display,
            poem.category,
            progress_dashes.accessibility,
            progress_dashes.visual,
            timeline_progress)
    end
    
    local template = [[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Golden Poems Chronologically</title>
</head>
<body>
    <nav class="breadcrumb">
        <a href="../../index.html">Poetry Collection</a> > 
        <a href="index.html">Golden Poems</a> > 
        <span>Chronological</span>
    </nav>
    
    <h1>✨ Golden Poems Chronologically</h1>
    <p>Explore golden poems in true chronological order by actual creation dates. Each poem shows its timeline position and creation date.</p>
    
    <div class="chronological-list">
        {CHRONOLOGICAL_LIST}
    </div>
</body>
</html>]]
    
    template = template:gsub("{CHRONOLOGICAL_LIST}", chronological_html)
    
    local output_file = output_dir .. "/poems/golden/chronological.html"
    local success = utils.write_file(output_file, template)
    
    if success then
        utils.log_info("Generated golden chronological browser: " .. output_file)
        return output_file
    else
        utils.log_error("Failed to generate golden chronological browser")
        return nil
    end
end
-- }}}

-- {{{ function generate_random_golden_page
function generate_random_golden_page(golden_poems, output_dir)
    if #golden_poems == 0 then
        return nil
    end
    
    -- Create random selections using deterministic approach
    math.randomseed(os.time())
    local random_selections = {}
    local max_selections = math.min(10, #golden_poems)
    
    for i = 1, max_selections do
        local random_index = math.random(1, #golden_poems)
        table.insert(random_selections, golden_poems[random_index])
    end
    
    local random_html = ""
    for i, poem in ipairs(random_selections) do
        local copy_area = generate_static_fediverse_copy_area(poem)
        random_html = random_html .. string.format([[
<div class="random-poem-card">
    <h4><a href="../%s/%s">%s</a> ✨</h4>
    <div class="poem-preview">%s</div>
    <div class="poem-actions">
        <a href="../%s/%s" class="read-button">Read Full Poem →</a>
        <span class="fediverse-ready">✨ 1024 chars - Perfect for fediverse!</span>
    </div>
    %s
</div>]], poem.category, 
            string.format("poem-%03d.html", poem.id),
            escape_html(poem.title),
            escape_html(string.sub(poem.content, 1, 200)) .. "...",
            poem.category,
            string.format("poem-%03d.html", poem.id),
            copy_area)
    end
    
    local template = [[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Random Golden Poems</title>
</head>
<body>
    <nav class="breadcrumb">
        <a href="../../index.html">Poetry Collection</a> > 
        <a href="index.html">Golden Poems</a> > 
        <span>Random</span>
    </nav>
    
    <h1>🎲 Random Golden Poem Discovery</h1>
    <p>Serendipitous exploration of golden poem achievements. Refresh for new selections!</p>
    
    <div class="random-selections">
        {RANDOM_SELECTIONS}
    </div>
</body>
</html>]]
    
    template = template:gsub("{RANDOM_SELECTIONS}", random_html)
    
    local output_file = output_dir .. "/poems/golden/random.html"
    local success = utils.write_file(output_file, template)
    
    if success then
        utils.log_info("Generated golden random discovery: " .. output_file)
        return output_file
    else
        utils.log_error("Failed to generate golden random discovery")
        return nil
    end
end
-- }}}

-- {{{ function M.generate_all_golden_collection_pages
function M.generate_all_golden_collection_pages(poems_data, similarity_data, output_dir)
    utils.log_info("Generating all golden poem collection pages...")
    
    local results = {
        index = nil,
        similarity_browser = nil,
        chronological_browser = nil,
        random_page = nil,
        golden_count = 0
    }
    
    -- Generate main collection index
    local index_result = generate_golden_collection_index(poems_data, output_dir)
    if index_result then
        results.index = index_result.file
        results.golden_count = index_result.golden_count
    end
    
    -- Get golden poems for other pages
    local golden_poems = filter_golden_poems(poems_data)
    
    if #golden_poems > 0 then
        -- Generate similarity browser
        results.similarity_browser = generate_golden_similarity_browser(golden_poems, similarity_data, output_dir)
        
        -- Generate chronological browser  
        results.chronological_browser = generate_golden_chronological_browser(golden_poems, output_dir)
        
        -- Generate random discovery page
        results.random_page = generate_random_golden_page(golden_poems, output_dir)
    end
    
    utils.log_info(string.format("Generated %d golden collection pages for %d golden poems", 
                                4, results.golden_count))
    
    return results
end
-- }}}

-- Export individual functions for testing
M.filter_golden_poems = filter_golden_poems
M.select_featured_golden_poems = select_featured_golden_poems
M.generate_featured_section = generate_featured_section
M.generate_complete_golden_index = generate_complete_golden_index
M.generate_golden_collection_index = generate_golden_collection_index
M.generate_golden_similarity_browser = generate_golden_similarity_browser
M.create_golden_similarity_clusters = create_golden_similarity_clusters
M.generate_cluster_poem_list = generate_cluster_poem_list
M.generate_golden_chronological_browser = generate_golden_chronological_browser
M.generate_random_golden_page = generate_random_golden_page

return M