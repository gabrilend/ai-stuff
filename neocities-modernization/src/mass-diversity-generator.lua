-- Mass diversity page generation system for creating thousands of diversity chain pages
-- Generates individual HTML pages for each poem showing its maximum diversity exploration chain

local DIR = DIR or "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

-- Set up path for local development
if not DIR:find("^/") then
    -- Relative path mode
    package.path = './libs/?.lua;' .. package.path
    local utils = require('utils')
else
    -- Absolute path mode
    package.path = DIR .. '/libs/?.lua;' .. package.path
    local utils = require('utils')
end

local utils = require('utils')
local diversity = require('diversity-chaining')

local M = {}

-- {{{ function escape_html
local function escape_html(text)
    if not text then return "" end
    text = tostring(text)
    text = text:gsub("&", "&amp;")
    text = text:gsub("<", "&lt;")
    text = text:gsub(">", "&gt;")
    text = text:gsub('"', "&quot;")
    text = text:gsub("'", "&#39;")
    return text
end
-- }}}

-- {{{ function ensure_directory
local function ensure_directory(path)
    -- Simple shell escaping for paths
    local escaped_path = path:gsub("'", "'\"'\"'")
    local success = os.execute("mkdir -p '" .. escaped_path .. "'")
    return success == 0 or success == true
end
-- }}}

-- {{{ function M.generate_diversity_chain_page
function M.generate_diversity_chain_page(starting_poem_id, starting_poem, chain_result, output_dir, poems_data)
    local template = [[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Diversity Chain: {STARTING_TITLE}</title>
    <style>
        /* Base styles */
        body {
            font-family: Georgia, serif;
            line-height: 1.6;
            margin: 0;
            padding: 1rem;
            max-width: 1000px;
            margin: 0 auto;
            background: #fafafa;
        }
        
        .breadcrumb {
            font-size: 0.9rem;
            margin-bottom: 1rem;
            color: #666;
        }
        
        .breadcrumb a {
            color: #8b4513;
            text-decoration: none;
        }
        
        .breadcrumb a:hover {
            text-decoration: underline;
        }
        
        h1 {
            color: #8b4513;
            border-bottom: 2px solid #8b4513;
            padding-bottom: 0.5rem;
        }
        
        .chain-description {
            background: #f0f8ff;
            padding: 1rem;
            border-left: 4px solid #4682b4;
            margin: 1rem 0;
            font-style: italic;
        }
        
        .chain-stats {
            display: flex;
            gap: 2rem;
            margin: 1rem 0;
            font-size: 0.9rem;
            color: #666;
        }
        
        .diversity-chain {
            margin: 2rem 0;
        }
        
        .chain-poem {
            border-left: 3px solid #8b4513;
            margin: 1rem 0;
            padding: 1rem;
            background: #ffffff;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
            transition: all 0.3s ease;
        }
        
        .chain-poem:hover {
            background: #f9f9f9;
            box-shadow: 0 2px 6px rgba(0,0,0,0.15);
        }
        
        .poem-number {
            font-weight: bold;
            color: #8b4513;
            font-size: 0.9rem;
            margin-bottom: 0.5rem;
        }
        
        .poem-title {
            color: #2c5530;
            margin: 0.5rem 0;
        }
        
        .poem-title a {
            color: inherit;
            text-decoration: none;
        }
        
        .poem-title a:hover {
            text-decoration: underline;
        }
        
        .poem-excerpt {
            color: #444;
            margin: 0.5rem 0;
            font-style: italic;
        }
        
        .diversity-score {
            color: #666;
            font-size: 0.8rem;
            margin-top: 0.5rem;
            padding: 0.25rem 0.5rem;
            background: #f5f5f5;
            border-radius: 3px;
            display: inline-block;
        }
        
        .chain-actions {
            margin: 2rem 0;
            padding: 1rem;
            background: #f8f8f8;
            border-radius: 5px;
        }
        
        .chain-actions a {
            display: inline-block;
            margin-right: 1rem;
            padding: 0.5rem 1rem;
            background: #8b4513;
            color: white;
            text-decoration: none;
            border-radius: 3px;
            font-size: 0.9rem;
        }
        
        .chain-actions a:hover {
            background: #5d2e0a;
        }
        
        @media (max-width: 600px) {
            body {
                padding: 0.5rem;
            }
            
            .chain-stats {
                flex-direction: column;
                gap: 0.5rem;
            }
            
            .chain-actions a {
                display: block;
                margin: 0.5rem 0;
                text-align: center;
            }
        }
    </style>
</head>
<body>
    <nav class="breadcrumb">
        <a href="../../../index.html">Poetry Collection</a> → 
        <a href="../../index.html">Poems</a> → 
        <a href="../index.html">Diversity Chains</a> → 
        <span>{STARTING_TITLE}</span>
    </nav>
    
    <h1>🎭 Diversity Chain: {STARTING_TITLE}</h1>
    
    <div class="chain-description">
        A maximum diversity exploration starting from "{STARTING_TITLE}" – 
        each step leads to the <strong>least similar</strong> poem, creating unexpected literary connections 
        and challenging transitions that reveal hidden relationships across different themes and styles.
    </div>
    
    <div class="chain-stats">
        <div><strong>Chain Length:</strong> {CHAIN_LENGTH} poems</div>
        <div><strong>Average Diversity:</strong> {AVERAGE_DIVERSITY}</div>
        <div><strong>Category:</strong> {CATEGORY}</div>
        <div><strong>Generated:</strong> {GENERATION_DATE}</div>
    </div>
    
    <div class="diversity-chain">
        {CHAIN_POEMS}
    </div>
    
    <div class="chain-actions">
        <a href="../by-category/{CATEGORY}/">More {CATEGORY} chains</a>
        <a href="../random-start/">Random diversity chain</a>
        <a href="../browse/">Browse all chains</a>
    </div>
</body>
</html>]]

    local chain = chain_result.chain or {}
    local metadata = chain_result.metadata or {}
    
    -- Build chain poems HTML
    local chain_html = ""
    for i, poem_id in ipairs(chain) do
        local poem = poems_data.poems and poems_data.poems[poem_id]
        if poem then
            local diversity_score = ""
            if i > 1 and metadata.diversities and metadata.diversities[i-1] then
                diversity_score = string.format('<div class="diversity-score">Diversity: %.2f</div>', 
                                              metadata.diversities[i-1])
            end
            
            chain_html = chain_html .. string.format([[
<div class="chain-poem">
    <div class="poem-number">Step %d</div>
    <h3 class="poem-title"><a href="../../%s/poem-%03d.html">%s</a></h3>
    <div class="poem-excerpt">%s</div>
    %s
</div>]], 
                i, 
                poem.category or "fediverse", 
                poem_id,
                escape_html(poem.title or ("Poem " .. poem_id)),
                escape_html(string.sub(poem.content or poem.text or "", 1, 120) .. (string.len(poem.content or poem.text or "") > 120 and "..." or "")),
                diversity_score
            )
        end
    end
    
    -- Calculate average diversity display
    local avg_diversity = metadata.average_diversity or 0
    local avg_diversity_display = string.format("%.2f", avg_diversity)
    
    -- Substitute template variables
    local starting_title = escape_html(starting_poem.title or ("Poem " .. starting_poem_id))
    local category = starting_poem.category or "fediverse"
    
    template = template:gsub("{STARTING_TITLE}", starting_title)
    template = template:gsub("{CATEGORY}", category)
    template = template:gsub("{CHAIN_LENGTH}", tostring(#chain))
    template = template:gsub("{AVERAGE_DIVERSITY}", avg_diversity_display)
    template = template:gsub("{GENERATION_DATE}", os.date("%Y-%m-%d"))
    template = template:gsub("{CHAIN_POEMS}", chain_html)
    
    -- Ensure output directory exists
    local category_dir = string.format("%s/poems/diversity/by-category/%s", 
                                     output_dir, category)
    if not ensure_directory(category_dir) then
        utils.log_error("Failed to create directory: " .. category_dir)
        return nil
    end
    
    -- Write page
    local output_file = string.format("%s/poem-%03d.html", category_dir, starting_poem_id)
    local success = utils.write_file(output_file, template)
    
    if success then
        return {
            file = output_file,
            starting_poem = starting_poem_id,
            chain_length = #chain,
            category = category,
            average_diversity = avg_diversity
        }
    else
        utils.log_error("Failed to write diversity page: " .. output_file)
        return nil
    end
end
-- }}}

-- {{{ function M.generate_diversity_batch
function M.generate_diversity_batch(poems_batch, similarity_data, output_dir, poems_data, config)
    local results = {}
    local failed_count = 0
    
    for _, poem_entry in ipairs(poems_batch) do
        local poem_id = poem_entry.id
        local poem_data = poem_entry.data
        
        -- Generate diversity chain
        local diversity_chain_result = diversity.generate_maximum_diversity_chain(
            poem_id, 
            poems_data.poems,  -- Pass the poems table, not the full poems_data object
            similarity_data, 
            config
        )
        
        if diversity_chain_result and diversity_chain_result.chain and #diversity_chain_result.chain >= 1 then
            -- Generate HTML page
            local page_result = M.generate_diversity_chain_page(
                poem_id, 
                poem_data, 
                diversity_chain_result, 
                output_dir,
                poems_data
            )
            
            if page_result then
                table.insert(results, page_result)
            else
                failed_count = failed_count + 1
                utils.log_warn(string.format("Failed to generate HTML page for poem %s", poem_id))
            end
        else
            failed_count = failed_count + 1
            utils.log_warn(string.format("Failed to generate diversity chain for poem %s", poem_id))
        end
    end
    
    if failed_count > 0 then
        utils.log_warn(string.format("Batch completed with %d failures out of %d poems", 
                                    failed_count, #poems_batch))
    end
    
    return results
end
-- }}}

-- {{{ function M.generate_all_diversity_chain_pages
function M.generate_all_diversity_chain_pages(poems_data, similarity_data, output_dir, config)
    config = config or diversity.DiversityConfig:new({
        chain_length = 15,
        debug_logging = false
    })
    
    local batch_size = 50  -- Manageable batch size for memory efficiency
    
    -- Count total poems
    local total_poems = 0
    local poem_list = {}
    for poem_id, poem_data in pairs(poems_data.poems or {}) do
        total_poems = total_poems + 1
        table.insert(poem_list, {id = tonumber(poem_id), data = poem_data})
    end
    
    -- Sort by ID for consistent processing
    table.sort(poem_list, function(a, b) return a.id < b.id end)
    
    utils.log_info(string.format("🏭 Generating diversity pages for %d poems...", total_poems))
    utils.log_info(string.format("📊 Target chain length: %d, Batch size: %d", 
                                config.chain_length, batch_size))
    
    local generated_pages = {}
    local batch_count = 0
    local current_batch = {}
    local start_time = os.clock()
    
    for _, poem_entry in ipairs(poem_list) do
        table.insert(current_batch, poem_entry)
        
        if #current_batch >= batch_size then
            local batch_results = M.generate_diversity_batch(
                current_batch, similarity_data, output_dir, poems_data, config
            )
            
            for _, result in ipairs(batch_results) do
                table.insert(generated_pages, result)
            end
            
            batch_count = batch_count + 1
            current_batch = {}
            
            local elapsed = os.clock() - start_time
            local rate = #generated_pages / elapsed
            local eta = (total_poems - #generated_pages) / rate
            
            utils.log_info(string.format("📈 Batch %d complete: %d/%d pages (%.1f%%, %.1f pages/sec, ETA: %.0f min)", 
                                       batch_count, #generated_pages, total_poems,
                                       (#generated_pages / total_poems) * 100,
                                       rate, eta / 60))
            
            -- Memory cleanup hint
            collectgarbage()
        end
    end
    
    -- Process final batch
    if #current_batch > 0 then
        local batch_results = M.generate_diversity_batch(
            current_batch, similarity_data, output_dir, poems_data, config
        )
        for _, result in ipairs(batch_results) do
            table.insert(generated_pages, result)
        end
        batch_count = batch_count + 1
    end
    
    local total_time = os.clock() - start_time
    
    utils.log_info(string.format("✅ Mass generation complete: %d pages in %.1f seconds (%.1f pages/sec)", 
                                #generated_pages, total_time, #generated_pages / total_time))
    
    return {
        total_pages = #generated_pages,
        requested_pages = total_poems,
        success_rate = #generated_pages / total_poems,
        output_directory = output_dir .. "/poems/diversity",
        generation_time_seconds = total_time,
        generation_rate = #generated_pages / total_time,
        pages = generated_pages,
        batch_count = batch_count,
        config = config
    }
end
-- }}}

-- {{{ function M.generate_index_pages
function M.generate_index_pages(generation_result, output_dir)
    -- Create main diversity index page
    local diversity_dir = output_dir .. "/poems/diversity"
    ensure_directory(diversity_dir)
    
    local index_template = [[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Diversity Chain Explorer</title>
    <style>
        body {
            font-family: Georgia, serif;
            line-height: 1.6;
            margin: 0;
            padding: 1rem;
            max-width: 1000px;
            margin: 0 auto;
            background: #fafafa;
        }
        
        h1 {
            color: #8b4513;
            border-bottom: 2px solid #8b4513;
            padding-bottom: 0.5rem;
        }
        
        .description {
            background: #f0f8ff;
            padding: 1rem;
            border-left: 4px solid #4682b4;
            margin: 1rem 0;
        }
        
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
            margin: 2rem 0;
        }
        
        .stat-card {
            background: white;
            padding: 1rem;
            border-radius: 5px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        
        .stat-number {
            font-size: 1.5rem;
            font-weight: bold;
            color: #8b4513;
        }
        
        .navigation {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1rem;
            margin: 2rem 0;
        }
        
        .nav-card {
            background: white;
            padding: 1.5rem;
            border-radius: 5px;
            box-shadow: 0 2px 6px rgba(0,0,0,0.1);
            text-align: center;
            border: 2px solid transparent;
            transition: all 0.3s ease;
        }
        
        .nav-card:hover {
            border-color: #8b4513;
            transform: translateY(-2px);
        }
        
        .nav-card h3 {
            color: #8b4513;
            margin-top: 0;
        }
        
        .nav-card a {
            text-decoration: none;
            color: inherit;
        }
    </style>
</head>
<body>
    <h1>🎭 Diversity Chain Explorer</h1>
    
    <div class="description">
        <p><strong>Diversity chains</strong> create unexpected literary journeys by connecting poems through 
        <em>maximum dissimilarity</em>. Each step leads to the least similar poem, creating surprising 
        transitions and revealing hidden connections across different themes, styles, and emotions.</p>
    </div>
    
    <div class="stats">
        <div class="stat-card">
            <div class="stat-number">{TOTAL_PAGES}</div>
            <div>Diversity Chains</div>
        </div>
        <div class="stat-card">
            <div class="stat-number">{SUCCESS_RATE}%</div>
            <div>Generation Success</div>
        </div>
        <div class="stat-card">
            <div class="stat-number">{GENERATION_TIME}s</div>
            <div>Generation Time</div>
        </div>
        <div class="stat-card">
            <div class="stat-number">{GENERATION_RATE}</div>
            <div>Pages/Second</div>
        </div>
    </div>
    
    <div class="navigation">
        <div class="nav-card">
            <a href="by-category/">
                <h3>📚 Browse by Category</h3>
                <p>Explore diversity chains organized by poem categories like fediverse, messages, and notes.</p>
            </a>
        </div>
        
        <div class="nav-card">
            <a href="random-start/">
                <h3>🎲 Random Start</h3>
                <p>Begin a diversity journey from a randomly selected poem for serendipitous discovery.</p>
            </a>
        </div>
        
        <div class="nav-card">
            <a href="browse/">
                <h3>🗂️ Browse All</h3>
                <p>View complete alphabetical listing of all available diversity chain starting points.</p>
            </a>
        </div>
    </div>
</body>
</html>]]
    
    -- Substitute stats
    index_template = index_template:gsub("{TOTAL_PAGES}", tostring(generation_result.total_pages))
    index_template = index_template:gsub("{SUCCESS_RATE}", string.format("%.1f", generation_result.success_rate * 100))
    index_template = index_template:gsub("{GENERATION_TIME}", string.format("%.1f", generation_result.generation_time_seconds))
    index_template = index_template:gsub("{GENERATION_RATE}", string.format("%.1f", generation_result.generation_rate))
    
    -- Write index page
    local index_file = diversity_dir .. "/index.html"
    utils.write_file(index_file, index_template)
    
    utils.log_info("📄 Created diversity index page: " .. index_file)
    
    return {
        index_page = index_file
    }
end
-- }}}

-- {{{ function M.test_mass_generation
function M.test_mass_generation(similarity_file, poems_file, output_dir, test_count)
    test_count = test_count or 10
    
    utils.log_info("🧪 Testing mass diversity generation with " .. test_count .. " poems")
    
    -- Load data
    local similarity_data = diversity.load_similarity_data(similarity_file)
    if not similarity_data then return false end
    
    local poems_data = utils.read_json_file(poems_file)
    if not poems_data or not poems_data.poems then
        utils.log_error("Failed to load poems data")
        return false
    end
    
    -- Create limited dataset for testing
    local test_poems = {poems = {}}
    local count = 0
    for poem_id, poem_data in pairs(poems_data.poems) do
        if count >= test_count then break end
        test_poems.poems[poem_id] = poem_data
        count = count + 1
    end
    
    utils.log_info(string.format("Test dataset created with %d poems", count))
    
    -- Configure test
    local config = diversity.DiversityConfig:new({
        chain_length = 5,  -- Shorter chains for testing
        debug_logging = false
    })
    
    -- Generate test pages
    local result = M.generate_all_diversity_chain_pages(test_poems, similarity_data, output_dir, config)
    
    if result then
        utils.log_info(string.format("✅ Test successful: %d/%d pages generated (%.1f%% success rate)", 
                                    result.total_pages, result.requested_pages, result.success_rate * 100))
        
        -- Generate index pages
        M.generate_index_pages(result, output_dir)
        
        return result
    else
        utils.log_error("❌ Test failed")
        return false
    end
end
-- }}}

return M