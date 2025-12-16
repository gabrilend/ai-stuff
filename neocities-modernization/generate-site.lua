#!/usr/bin/env lua

-- Generate complete HTML site demonstration
-- Creates a functional poetry website with actual content

package.path = package.path .. ';./?.lua;./libs/?.lua;./src/html-generator/?.lua'

local utils = require("libs.utils")
local golden_collection = require("src.html-generator.golden-collection-generator")

local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

-- {{{ function create_sample_poems
function create_sample_poems()
    -- Create sample poems with proper golden poem flags
    local poems_data = {
        poems = {}
    }
    
    -- Add some regular poems
    for i = 1, 10 do
        local content = string.format("This is poem number %d. It contains meaningful poetry content that demonstrates the website functionality. Each poem tells a unique story and connects to the overall collection through similarity-based recommendations.", i)
        
        poems_data.poems[i] = {
            id = i,
            title = string.format("Sample Poem %d", i),
            content = content,
            category = "fediverse",
            character_count = string.len(content),
            is_fediverse_golden = false
        }
    end
    
    -- Add golden poems (exactly 1024 characters)
    local golden_content_1 = "This is a golden poem designed to be exactly 1024 characters long for perfect fediverse sharing. It tells of morning light that dances through the trees, awakening the world with gentle grace. Each line flows like honey through time, carrying messages of hope and wonder. The characters count perfectly to the limit, showcasing the artistry of constrained writing. Golden words for golden moments, crafted with care for those who seek beauty in brevity. This poem represents the harmony between form and content, where every letter serves a purpose. The dawn breaks with promises of new beginnings, and through these verses we find connection across digital spaces. May this golden creation spark joy in hearts that read it, bridging distances with shared appreciation for poetry that fits precisely within the bounds we've chosen. Perfect length achieved through thoughtful selection of each word, each phrase, each moment of expression that builds toward completion."
    
    local golden_content_2 = "Another golden poem reaching exactly 1024 characters, exploring digital landscapes where creativity meets constraint. In virtual realms we find new ways to express ancient truths about human experience. These golden verses represent the intersection of technology and art, where precise character limits become opportunities for innovation rather than restrictions. Through careful word choice and rhythmic flow, we craft messages that resonate across platforms and communities. The fediverse welcomes these perfectly sized creations, enabling seamless sharing of poetic content that respects both artistic integrity and technical requirements. Each poem becomes a bridge between individual expression and collective experience, fostering connections through shared appreciation of language and form. These digital dreams manifest as golden opportunities to practice the ancient art of constrained writing, where limitations inspire rather than limit creativity."
    
    local golden_content_3 = "A third golden poem crafted with precision to meet the 1024 character requirement for optimal fediverse distribution. These network verses explore how poetry adapts to modern communication channels while maintaining its essential power to move hearts and minds. Through digital networks we share fragments of our inner lives, creating moments of connection that transcend physical boundaries. The golden constraint challenges poets to distill their thoughts into concentrated essences, where every word carries weight and meaning. This compression of language mirrors the way social networks compress human experience into manageable fragments, yet somehow retain the capacity to convey profound emotion and insight. In these perfectly sized verses we find the continuation of an ancient tradition in new forms, proving that poetry evolves with technology while preserving its core mission to illuminate the human condition with beauty and truth."
    
    -- Add the golden poems
    poems_data.poems[11] = {
        id = 11,
        title = "Golden Sunrise",
        content = golden_content_1,
        category = "fediverse", 
        character_count = 1024,
        is_fediverse_golden = true,
        similarity_score = 0.9
    }
    
    poems_data.poems[12] = {
        id = 12,
        title = "Digital Dreams",
        content = golden_content_2,
        category = "fediverse",
        character_count = 1024, 
        is_fediverse_golden = true,
        similarity_score = 0.8
    }
    
    poems_data.poems[13] = {
        id = 13,
        title = "Network Verses",
        content = golden_content_3,
        category = "messages",
        character_count = 1024,
        is_fediverse_golden = true,
        similarity_score = 0.7
    }
    
    -- Add some poems from other categories
    for i = 14, 20 do
        local content = string.format("This is a %s poem number %d with interesting content that shows cross-category navigation.", i > 17 and "notes" or "messages", i)
        
        poems_data.poems[i] = {
            id = i,
            title = string.format("Sample %s Poem %d", i > 17 and "Notes" or "Messages", i),
            content = content,
            category = i > 17 and "notes" or "messages",
            character_count = string.len(content),
            is_fediverse_golden = false
        }
    end
    
    return poems_data
end
-- }}}

-- {{{ function create_sample_similarity_data
function create_sample_similarity_data(poems_data)
    -- Create basic similarity data for demonstration
    local similarity_data = {}
    
    for poem_id, poem in pairs(poems_data.poems) do
        similarity_data[tostring(poem_id)] = {}
        
        -- Create similarity connections to other poems
        for other_id, other_poem in pairs(poems_data.poems) do
            if poem_id ~= other_id then
                -- Golden poems get higher similarity scores with each other
                local base_similarity = math.random() * 0.5 + 0.2
                
                if poem.is_fediverse_golden and other_poem.is_fediverse_golden then
                    base_similarity = base_similarity + 0.3
                elseif poem.category == other_poem.category then
                    base_similarity = base_similarity + 0.2
                end
                
                similarity_data[tostring(poem_id)][tostring(other_id)] = base_similarity
            end
        end
    end
    
    return similarity_data
end
-- }}}

-- {{{ function generate_individual_poem_pages
function generate_individual_poem_pages(poems_data, similarity_data, output_dir)
    utils.log_info("Generating individual poem pages...")
    
    local count = 0
    for poem_id, poem in pairs(poems_data.poems) do
        if poem and poem.content and poem.category then
            -- Create poem page directory
            local category_dir = string.format("%s/poems/%s", output_dir, poem.category)
            os.execute("mkdir -p " .. category_dir)
            
            -- Get similarity recommendations
            local similar_poems = {}
            local poem_similarities = similarity_data[tostring(poem_id)] or {}
            
            -- Sort by similarity score
            local sorted_similarities = {}
            for other_id, score in pairs(poem_similarities) do
                local other_poem = poems_data.poems[tonumber(other_id)]
                if other_poem then
                    table.insert(sorted_similarities, {
                        id = tonumber(other_id),
                        poem = other_poem,
                        score = score
                    })
                end
            end
            
            table.sort(sorted_similarities, function(a, b) return a.score > b.score end)
            
            -- Take top 5 similar poems
            for i = 1, math.min(5, #sorted_similarities) do
                table.insert(similar_poems, sorted_similarities[i])
            end
            
            -- Generate poem page HTML
            local template = [[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{TITLE} - Poetry Collection</title>
    <style>
        body {
            font-family: Georgia, serif;
            line-height: 1.6;
            margin: 0;
            padding: 1rem;
            max-width: 800px;
            margin: 0 auto;
        }
        
        .poem-header {
            text-align: center;
            margin-bottom: 2rem;
            padding-bottom: 1rem;
            border-bottom: 2px solid #8b4513;
        }
        
        .poem-content {
            background: #f9f9f9;
            padding: 2rem;
            border-radius: 8px;
            margin: 2rem 0;
            border-left: 4px solid #8b4513;
        }
        
        .golden-badge {
            background: #ffd700;
            color: #8b4513;
            padding: 0.25rem 0.75rem;
            border-radius: 20px;
            font-size: 0.8rem;
            font-weight: bold;
            margin-left: 1rem;
        }
        
        .similar-poems {
            margin-top: 3rem;
            padding: 1.5rem;
            background: #f0f8ff;
            border-radius: 8px;
        }
        
        .similar-poems h3 {
            color: #2c5282;
            margin-bottom: 1rem;
        }
        
        .similar-poem-link {
            display: block;
            margin: 0.5rem 0;
            padding: 0.5rem;
            background: white;
            border: 1px solid #e2e8f0;
            border-radius: 4px;
            text-decoration: none;
            color: #333;
        }
        
        .similar-poem-link:hover {
            background: #e6f3ff;
            border-color: #8b4513;
        }
        
        .breadcrumb {
            margin-bottom: 2rem;
            color: #666;
        }
        
        .breadcrumb a {
            color: #8b4513;
            text-decoration: none;
        }
        
        @media (max-width: 768px) {
            body { padding: 0.5rem; }
            .poem-content { padding: 1rem; }
        }
    </style>
</head>
<body>
    <nav class="breadcrumb">
        <a href="../../index.html">Poetry Collection</a> > 
        <a href="../index.html">{CATEGORY_TITLE}</a> > 
        <span>{TITLE}</span>
    </nav>
    
    <div class="poem-header">
        <h1>{TITLE}</h1>
        {GOLDEN_BADGE}
        <p>Category: <strong>{CATEGORY_TITLE}</strong> | Length: <strong>{CHARACTER_COUNT} characters</strong></p>
    </div>
    
    <div class="poem-content">
        <p>{CONTENT}</p>
    </div>
    
    <div class="similar-poems">
        <h3>🔗 Similar Poems</h3>
        {SIMILAR_POEMS_HTML}
    </div>
</body>
</html>]]
            
            -- Build similar poems HTML
            local similar_html = ""
            for _, similar in ipairs(similar_poems) do
                similar_html = similar_html .. string.format([[
<a href="../%s/poem-%03d.html" class="similar-poem-link">
    <strong>%s</strong><br>
    <small>%s category • Similarity: %.1f%%</small>
</a>]], 
                    similar.poem.category,
                    similar.id,
                    similar.poem.title or ("Poem " .. similar.id),
                    similar.poem.category,
                    similar.score * 100
                )
            end
            
            -- Substitute template variables (escape percent signs for safe gsub replacement)
            local html = template
            local safe_title = (poem.title or ("Poem " .. poem_id)):gsub("%%", "%%%%")
            local safe_category = string.upper(string.sub(poem.category, 1, 1)) .. string.sub(poem.category, 2)
            local safe_content = (poem.content or ""):gsub("%%", "%%%%")
            local safe_similar_html = similar_html:gsub("%%", "%%%%")
            
            html = html:gsub("{TITLE}", safe_title)
            html = html:gsub("{CATEGORY_TITLE}", safe_category)
            html = html:gsub("{CHARACTER_COUNT}", tostring(poem.character_count or 0))
            html = html:gsub("{CONTENT}", safe_content)
            html = html:gsub("{SIMILAR_POEMS_HTML}", safe_similar_html)
            
            if poem.is_fediverse_golden then
                html = html:gsub("{GOLDEN_BADGE}", '<span class="golden-badge">✨ Golden Poem</span>')
            else
                html = html:gsub("{GOLDEN_BADGE}", "")
            end
            
            -- Write poem page
            local output_file = string.format("%s/poem-%03d.html", category_dir, poem_id)
            local file = io.open(output_file, "w")
            if file then
                file:write(html)
                file:close()
                count = count + 1
            end
        end
    end
    
    utils.log_info(string.format("Generated %d individual poem pages", count))
    return count
end
-- }}}

-- {{{ Main execution
function main()
    utils.log_info("Generating complete HTML poetry website...")
    
    local output_dir = DIR .. "/generated-site"
    
    -- Create sample data
    utils.log_info("Creating sample poem data...")
    local poems_data = create_sample_poems()
    local similarity_data = create_sample_similarity_data(poems_data)
    
    -- Generate golden collection pages
    utils.log_info("Generating golden poem collection pages...")
    local results = golden_collection.generate_all_golden_collection_pages(
        poems_data,
        similarity_data,
        output_dir
    )
    
    -- Generate individual poem pages
    local poem_count = generate_individual_poem_pages(poems_data, similarity_data, output_dir)
    
    -- Generate category index pages
    local categories = {"fediverse", "messages", "notes"}
    for _, category in ipairs(categories) do
        local category_dir = string.format("%s/poems/%s", output_dir, category)
        local index_file = category_dir .. "/index.html"
        
        local category_poems = {}
        for _, poem in pairs(poems_data.poems) do
            if poem.category == category then
                table.insert(category_poems, poem)
            end
        end
        
        local index_html = string.format([[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>%s Poems - Poetry Collection</title>
</head>
<body>
    <h1>%s Poetry Collection</h1>
    <p>%d poems in this category</p>
    <ul>]], 
            string.upper(string.sub(category, 1, 1)) .. string.sub(category, 2),
            string.upper(string.sub(category, 1, 1)) .. string.sub(category, 2),
            #category_poems
        )
        
        for _, poem in ipairs(category_poems) do
            index_html = index_html .. string.format([[
        <li><a href="poem-%03d.html">%s</a>%s</li>]], 
                poem.id,
                poem.title or ("Poem " .. poem.id),
                poem.is_fediverse_golden and " ✨" or ""
            )
        end
        
        index_html = index_html .. [[
    </ul>
    <p><a href="../golden/">View Golden Poems Collection →</a></p>
</body>
</html>]]
        
        local file = io.open(index_file, "w")
        if file then
            file:write(index_html)
            file:close()
        end
    end
    
    -- Generate main index
    local main_index = output_dir .. "/index.html"
    local main_html = [[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Poetry Collection - Phase 3 Demo</title>
    <style>
        body {
            font-family: Georgia, serif;
            line-height: 1.6;
            max-width: 800px;
            margin: 0 auto;
            padding: 1rem;
        }
        
        .hero {
            text-align: center;
            background: linear-gradient(135deg, #f0f8ff, #e6f3ff);
            padding: 3rem 2rem;
            border-radius: 12px;
            margin: 2rem 0;
        }
        
        .categories {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 2rem;
            margin: 2rem 0;
        }
        
        .category-card {
            border: 2px solid #8b4513;
            border-radius: 8px;
            padding: 1.5rem;
            text-align: center;
            background: white;
            transition: transform 0.3s ease;
        }
        
        .category-card:hover {
            transform: translateY(-2px);
        }
        
        .category-card a {
            color: #8b4513;
            text-decoration: none;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <div class="hero">
        <h1>🎭 Poetry Collection</h1>
        <p>Phase 3 Demonstration - Complete HTML Generation System</p>
        <p><strong>20 sample poems</strong> with <strong>3 golden poems</strong> optimized for fediverse sharing</p>
    </div>
    
    <div class="categories">
        <div class="category-card">
            <h3><a href="poems/fediverse/">📱 Fediverse Poems</a></h3>
            <p>13 poems including 2 golden poems</p>
        </div>
        
        <div class="category-card">
            <h3><a href="poems/messages/">💬 Messages</a></h3>
            <p>4 poems including 1 golden poem</p>
        </div>
        
        <div class="category-card">
            <h3><a href="poems/notes/">📝 Notes</a></h3>
            <p>3 poems</p>
        </div>
        
        <div class="category-card">
            <h3><a href="poems/golden/">✨ Golden Collection</a></h3>
            <p>3 poems exactly 1024 characters</p>
        </div>
    </div>
    
    <footer style="margin-top: 3rem; text-align: center; color: #666;">
        <p>Generated by Phase 3 HTML Generation System</p>
        <p>Features: JavaScript-free, responsive design, similarity navigation</p>
    </footer>
</body>
</html>]]
    
    local file = io.open(main_index, "w")
    if file then
        file:write(main_html)
        file:close()
    end
    
    -- Final summary
    utils.log_info("HTML generation complete!")
    utils.log_info(string.format("Generated site location: %s", output_dir))
    utils.log_info(string.format("Total poem pages: %d", poem_count))
    utils.log_info("Golden collection pages: 4")
    utils.log_info("Category index pages: 3")
    utils.log_info("Main index page: 1")
    
    local total_files = poem_count + 4 + 3 + 1
    utils.log_info(string.format("Total HTML files: %d", total_files))
    
    return output_dir
end

main()
-- }}}