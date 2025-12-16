-- don't forget to add the my-art and things-i-almost-posted to the pdf

 DIR = arg[1]
FILE = arg[2]

package.cpath = package.cpath .. ";" .. DIR .. "/libs/luahpdf/?.so"
package.cpath = package.cpath .. ";" .. DIR .. "/libs/libharu-RELEASE_2_3_0/build/src/?.so"
package.path = package.path .. ";" .. DIR .. "/libs/?.lua"

hpdf = require "hpdf"
fuzz = require "libs/fuzzy-computing"

-- LLM settings - ENABLED for Ollama embeddings
LLM_MODEL = "EmbeddingGemma:latest"
ENABLE_OLLAMA_EMBEDDINGS = true  -- Enable the embedding system

-- Multi-tier theme embeddings cache (initialized once)
THEME_EMBEDDINGS = {
    tier1 = nil, -- 10 core themes + 12 simple themes merged
    tier2 = nil, -- 20 extended themes  
    tier3 = nil  -- 40 detailed themes + simple themes
}

-- Theme selection tracking for debugging
THEME_STATS = {
    tier1_counts = {}, -- Page background themes
    tier2_counts = {}, -- Individual poem themes
    tier3_counts = {}, -- Poem background colors
    total_pages = 0,
    total_poems = 0
}

-- Layout Configuration Variables
MAX_LINES_PER_PAGE = 155 -- Lines per page column (restored)
MAX_CHAR_PER_LINE  = 80  -- Characters per line (content width)

-- Box Drawing Characters - trying different characters that might connect better
BOX_TOP_LEFT     = "."   -- Top left corner (more rounded look)
BOX_TOP_RIGHT    = "."   -- Top right corner  
BOX_BOTTOM_LEFT  = "`"   -- Bottom left corner (more rounded look)
BOX_BOTTOM_RIGHT = "'"   -- Bottom right corner
BOX_HORIZONTAL   = "-"   -- Horizontal lines
BOX_VERTICAL     = "|"   -- Vertical lines

-- Graphics mode management functions (defined early for global access)
-- Old ensure_graphics_mode function removed - was causing document corruption

-- Safe wrapper functions removed due to causing PDF document corruption
-- Using direct libharu operations instead for better stability

-- Simple graphics mode helper that doesn't corrupt the document
local function prepare_for_graphics(pdf_page)
    -- Try to end text mode, but ignore errors
    pcall(function() hpdf.Page_EndText(pdf_page) end)
end

-- PDF Layout Settings
FONT_SIZE        = 5     -- Font size in points for regular text
LINE_SPACING     = 0     -- No additional spacing between lines
COLUMN_GAP       = 30    -- Gap between columns
LEFT_MARGIN      = 10    -- Left page margin
RIGHT_MARGIN     = 10    -- Right page margin  
TOP_MARGIN       = 60   -- Top page margin
BOTTOM_MARGIN    = 0    -- Bottom page margin
BACKGROUND_COLOR = {0.9, 0.7, 1.0}  -- Light purple background for masking poem areas (testing color)
-- TEXT_COLORS disabled for now
-- TEXT_COLORS        = {
--            ["RED"] = { ["r"] = 1.0, ["g"] = 0.0, ["b"] = 0.0 },
--          ["GREEN"] = { ["r"] = 0.0, ["g"] = 1.0, ["b"] = 0.0 },
--           ["CYAN"] = { ["r"] = 0.0, ["g"] = 1.0, ["b"] = 1.0 },
--         ["YELLOW"] = { ["r"] = 1.0, ["g"] = 1.0, ["b"] = 0.0 },
--        ["MAGENTA"] = { ["r"] = 1.0, ["g"] = 0.0, ["b"] = 1.0 },
--         ["ORANGE"] = { ["r"] = 1.0, ["g"] = 0.5, ["b"] = 0.0 },
--         ["PURPLE"] = { ["r"] = 0.5, ["g"] = 0.0, ["b"] = 1.0 },
--           ["PINK"] = { ["r"] = 1.0, ["g"] = 0.5, ["b"] = 1.0 },
--       ["SKY BLUE"] = { ["r"] = 0.0, ["g"] = 0.5, ["b"] = 1.0 },
--           ["TEAL"] = { ["r"] = 0.1, ["g"] = 0.6, ["b"] = 0.6 },
--        ["HAT-RED"] = { ["r"] = 0.6, ["g"] = 0.1, ["b"] = 0.1 },
--       ["DARK-RED"] = { ["r"] = 0.6, ["g"] = 0.1, ["b"] = 0.1 },
--    ["GRASS-GREEN"] = { ["r"] = 0.1, ["g"] = 0.6, ["b"] = 0.1 },
--    ["ARCANE-BLUE"] = { ["r"] = 0.1, ["g"] = 0.1, ["b"] = 0.8 },
-- }

-- function load_file(book) ---- {{{

function load_file(book)
    local poem = {}
    local file = io.open(FILE, "r")
    if not file then print("FILE cannot be found") end
    
    for line in file:lines() do
        if line ~= string.rep("-", 80) then
            table.insert(poem, line)
        else 
            -- Process the poem to fix spacing issues
            local processed_poem = normalize_poem_spacing(poem)
            table.insert(book.poems, processed_poem)
            poem = {}
        end
    end
    file:close()

    return book
end -- }}}

-- Normalize poem spacing for consistent formatting
function normalize_poem_spacing(poem) -- {{{
    if #poem == 0 then return poem end
    
    local result = {}
    local poem_type = detect_poem_type(poem)
    
    if poem_type == "fediverse_with_cw" then
        -- Format: CW line, blank line, then poem content
        local cw_line = ""
        local content_start = 1
        
        -- Find the CW line
        for i, line in ipairs(poem) do
            if line:match("^CW:") then
                cw_line = line
                content_start = i + 1
                break
            end
        end
        
        -- Add CW line and blank line
        if cw_line ~= "" then
            table.insert(result, cw_line)
            table.insert(result, "")  -- Blank line after CW
        end
        
        -- Add poem content, skipping leading blank lines
        local content_found = false
        for i = content_start, #poem do
            local line = poem[i]
            if line ~= "" or content_found then
                table.insert(result, line)
                if line ~= "" then content_found = true end
            end
        end
        
    elseif poem_type == "fediverse_no_cw" then
        -- Format: Remove all leading blank lines, box drawing provides spacing
        local content_found = false
        for i, line in ipairs(poem) do
            -- Skip leading blank lines, but keep content and any blanks after content
            if line ~= "" or content_found then
                table.insert(result, line)
                if line ~= "" then content_found = true end
            end
        end
        
    else
        -- Messages/Notes: Remove all leading blank lines, box drawing provides spacing  
        local content_found = false
        for i, line in ipairs(poem) do
            -- Skip leading blank lines, but keep content and any blanks after content
            if line ~= "" or content_found then
                table.insert(result, line)
                if line ~= "" then content_found = true end
            end
        end
    end
    
    return result
end -- }}}

-- Detect what type of poem this is based on content
function detect_poem_type(poem) -- {{{
    if #poem == 0 then return "unknown" end
    
    -- Check if it has a file path indicator
    local has_fediverse = false
    local has_cw = false
    
    for _, line in ipairs(poem) do
        if line:match("fediverse/") then
            has_fediverse = true
        elseif line:match("^CW:") then
            has_cw = true
        end
    end
    
    if has_fediverse and has_cw then
        return "fediverse_with_cw"
    elseif has_fediverse then
        return "fediverse_no_cw"
    else
        return "messages_notes"
    end
end -- }}}

-- function build_book --------- {{{

function append_long_poem(book, poem, column, height, page_num) -- {{{
   local current_line = 1
   local remaining_space = MAX_LINES_PER_PAGE - height
   
   while current_line <= #poem do
      local segment = {}
      -- Account for box overhead (4 lines) when calculating available space for content
      local available_content_lines = remaining_space - 4  -- subtract box/padding overhead
      if available_content_lines < 1 then available_content_lines = 1 end
      
      local lines_to_take = math.min(available_content_lines, #poem - current_line + 1)
      
      -- Fill current segment with available lines
      for i = 1, lines_to_take do
         table.insert(segment, poem[current_line])
         current_line = current_line + 1
      end
      
      -- Add segment to current column
      if column == -1 then 
         table.insert(book.pages[page_num].left, segment)
      else 
         table.insert(book.pages[page_num].right, segment)
      end
      
      -- Update height using actual height calculation
      height = height + calculate_poem_height(segment)
      
      -- If there are more lines to process, move to next column
      if current_line <= #poem then
         column = column * -1
         if column == -1 then 
            page_num = page_num + 1
            book.pages[page_num] = { left = {}, right = {} }
         end
         height = 0
         remaining_space = MAX_LINES_PER_PAGE
      end
   end
   
   return { book, column, height, page_num }
end -- }}}

-- #poem means "number of lines in the poem"

-- Calculate actual lines a poem takes including box and padding
function calculate_poem_height(poem)
   return #poem + 5  -- poem lines + top border + top padding + bottom padding + bottom border + space between poems
end

function build_book(book) -- {{{
   local column   = -1            -- Start with left column
   local height   =  0            -- Current column height
   local page_num =  1;           book.pages[1] = { left = {}, right = {}, }
   
   for index, poem in ipairs(book.poems) do
      local poem_height = calculate_poem_height(poem)
      
      -- Check if poem is too long for a single column
      if poem_height > MAX_LINES_PER_PAGE then
         -- Long poem: ensure it starts in a fresh column
         if height > 0 then
            -- Move to next column since current one has content
            column = column * -1
            height = 0
            if column == -1 then 
               page_num = page_num + 1
               book.pages[page_num] = { left = {}, right = {} }
            end
         end
         
         -- Handle long poem with proper overflow
         local result = append_long_poem(book, poem, column, height, page_num)
         book, column, height, page_num = result[1], result[2], result[3], result[4]
         
      elseif height + poem_height > MAX_LINES_PER_PAGE then
         -- Poem doesn't fit in current column, move to next
         height = 0
         column = column * -1
         if column == -1 then 
            page_num = page_num + 1
            book.pages[page_num] = { left = {}, right = {} }
         end
         
         -- Add poem to new column
         height = height + poem_height
         if column == -1 then 
            table.insert(book.pages[page_num].left, poem) 
         else 
            table.insert(book.pages[page_num].right, poem) 
         end
         
      else
         -- Poem fits in current column
         height = height + poem_height
         if column == -1 then 
            table.insert(book.pages[page_num].left, poem) 
         else 
            table.insert(book.pages[page_num].right, poem) 
         end
      end
   end
   return book
end -- }}}

-- }}}

-- function draw_boxed_poem ---- {{{

-- Removed complex font size function

function draw_boxed_poem(pdf_page, font, poem, start_x, start_y, max_width, line_height, min_y, alignment)
    if #poem == 0 then return start_y end
    
    -- Set text color to black explicitly
    hpdf.Page_SetRGBFill(pdf_page, 0.0, 0.0, 0.0)
    hpdf.Page_SetRGBStroke(pdf_page, 0.0, 0.0, 0.0)
    
    -- Calculate poem dimensions with extra padding
    local poem_width = 0
    for _, line in ipairs(poem) do
        if #line > poem_width then poem_width = #line end
    end
    poem_width = poem_width + 4 -- Add padding: 2 for box borders + 2 for internal spacing
    
    local box_width = math.min(poem_width, max_width - 2)
    
    -- Calculate actual x position based on alignment
    local actual_x = start_x
    if alignment == "right" then
        -- For right alignment, start_x is the right edge, so we subtract the box width
        actual_x = start_x - box_width
    elseif alignment == "center" then
        -- For center alignment, center the box within the available width
        actual_x = start_x + (max_width - box_width) / 2
    end
    
    local current_y = start_y
    
    -- Draw top border
    if current_y > min_y then
        local top_border = BOX_TOP_LEFT .. string.rep(BOX_HORIZONTAL, box_width - 2) .. BOX_TOP_RIGHT
        hpdf.Page_BeginText(pdf_page)
        hpdf.Page_MoveTextPos(pdf_page, actual_x, current_y)
        hpdf.Page_ShowText(pdf_page, top_border)
        hpdf.Page_EndText(pdf_page)
    end
    current_y = current_y - line_height
    
    -- Draw top padding line (blank line with borders)
    if current_y > min_y then
        local padding_line = BOX_VERTICAL .. string.rep(" ", box_width - 2) .. BOX_VERTICAL
        hpdf.Page_BeginText(pdf_page)
        hpdf.Page_MoveTextPos(pdf_page, actual_x, current_y)
        hpdf.Page_ShowText(pdf_page, padding_line)
        hpdf.Page_EndText(pdf_page)
    end
    current_y = current_y - line_height
    
    -- Draw poem content with side borders and internal spacing
    for _, line in ipairs(poem) do
        if current_y > min_y then
            local padded_line = BOX_VERTICAL .. " " .. line .. string.rep(" ", box_width - #line - 4) .. " " .. BOX_VERTICAL
            hpdf.Page_BeginText(pdf_page)
            hpdf.Page_MoveTextPos(pdf_page, actual_x, current_y)
            hpdf.Page_ShowText(pdf_page, padded_line)
            hpdf.Page_EndText(pdf_page)
        end
        current_y = current_y - line_height
    end
    
    -- Draw bottom padding line (blank line with borders)
    if current_y > min_y then
        local padding_line = BOX_VERTICAL .. string.rep(" ", box_width - 2) .. BOX_VERTICAL
        hpdf.Page_BeginText(pdf_page)
        hpdf.Page_MoveTextPos(pdf_page, actual_x, current_y)
        hpdf.Page_ShowText(pdf_page, padding_line)
        hpdf.Page_EndText(pdf_page)
    end
    current_y = current_y - line_height
    
    -- Draw bottom border
    if current_y > min_y then
        local bottom_border = BOX_BOTTOM_LEFT .. string.rep(BOX_HORIZONTAL, box_width - 2) .. BOX_BOTTOM_RIGHT
        hpdf.Page_BeginText(pdf_page)
        hpdf.Page_MoveTextPos(pdf_page, actual_x, current_y)
        hpdf.Page_ShowText(pdf_page, bottom_border)
        hpdf.Page_EndText(pdf_page)
    end
    current_y = current_y - line_height
    
    return current_y
end -- }}}

-- Color-related functions disabled for now
-- function build_color(book) -- commented out
-- function validate_color(color_text, model) -- commented out

-- }}}

-- GENERATIVE ART SYSTEM ---- {{{

-- Initialize multi-tier theme embeddings (run once)
function initialize_theme_embeddings() -- {{{
    if THEME_EMBEDDINGS.tier1 and THEME_EMBEDDINGS.tier2 and THEME_EMBEDDINGS.tier3 then 
        return THEME_EMBEDDINGS -- Already initialized
    end
    
    print("Initializing multi-tier theme embeddings...")
    
    -- Tier 1: Core Themes + Simple Themes (Page-level art) - MERGED FROM ART-THEMES.JSON
    local tier1_descriptions = {
        -- Original 10 core themes
        resistance = "Anti-authoritarian sentiment, revolutionary politics, systematic critique of power structures. Revolution, fascism, capitalism, power, authority, organizing, fight, resistance, collective, liberation, struggle, protest, anarchist, leftist, solidarity, uprising, defiance, system-breaking, opposition, militant.",
        technology = "Deep technical knowledge mixed with philosophical questioning of digital systems. Programming, algorithms, AI, code, software, linux, systems, networks, automation, debugging, compilation, data, encryption, terminal, github, computers, digital, infrastructure, technical, computation.",
        isolation = "Profound loneliness and social disconnection despite digital connectivity. Alone, lonely, disconnected, misunderstood, withdrawn, separated, alienation, distance, silence, empty, abandoned, solitary, exile, hermit, invisible, forgotten, void, scattered, lost, isolated.",
        identity = "Fluid exploration of gender, sexuality, neurodivergence, and authentic selfhood. Trans, gender, autism, ADHD, neurodivergent, queer, witch, authentic, transformation, mask, performance, binary, spectrum, fluid, changing, multiplicity, valid, expression, becoming, identity-shift.",
        systems = "Analysis and critique of how complex systems function - economic, social, computational architectures. Systems, structure, organization, mechanics, dynamics, infrastructure, architecture, design, framework, process, balance, distributed, centralized, protocols, federation, collective, institutional, hierarchical, network, systematic.",
        connection = "Yearning for authentic human bonds contrasted against digital isolation. Friends, community, friendship, belonging, trust, communication, empathy, understanding, neighbors, solidarity, collective, cooperation, support, mutual-aid, relationships, social, networks, conversation, sharing, connection.",
        chaos = "Stream-of-consciousness fragmentation, mental overflow, breakdown of systematic thinking. Stack-overflow, fragments, broken, scattered, interrupted, glitch, random, confusion, noise, overwhelm, chaos, manic, spinning, frantic, jumbled, corruption, error, breakdown, disruption, fragmentation.",
        transcendence = "Mystical and spiritual exploration combining witchcraft, cosmic consciousness, metaphysical speculation. Witch, magic, divine, spiritual, mystical, gods, spirits, transcendent, cosmic, sacred, ritual, prophecy, ethereal, enlightenment, celestial, supernatural, metaphysical, otherworldly, energy, mystique.",
        survival = "Practical concerns about basic needs, resource management, economic precarity. Food, water, shelter, resources, money, rent, broke, survival, scarcity, basic-needs, practical, preparation, supplies, housing, nutrition, sustenance, poverty, economics, mutual-aid, resourcefulness.",
        creativity = "Artistic expression, creative process, intersection of human imagination with technological tools. Art, creativity, music, writing, poetry, design, expression, imagination, aesthetic, beauty, creation, inspiration, making, craft, composition, artistic, generative, procedural, visual, creative.",
        
        -- 12 Simple themes merged from art-themes.json
        nature = "Organic flowing particles and natural elements. Tree, forest, wind, rain, sun, moon, flower, ocean, mountain, sky, earth, river, bird, leaf, organic, growth, natural, wild, flowing, green.",
        urban = "Geometric neon patterns and city environments. City, street, building, car, neon, concrete, glass, steel, traffic, noise, crowd, urban, metropolitan, geometric, angular, bright, electric.",
        energy = "Explosive radiating lines and dynamic force. Power, burst, explosion, fire, electric, lightning, dynamic, force, intensity, energy, radiating, explosive, orange, bright, kinetic.",
        love = "Gentle curved flowing lines and romantic emotions. Heart, kiss, embrace, tender, gentle, soft, warm, care, affection, romance, love, curved, flowing, pink, sweet, intimate.",
        melancholy = "Downward flowing drops and sadness. Sad, lonely, tears, sorrow, loss, empty, gray, rain, shadow, dark, melancholy, blue, muted, downward, drops, flowing.",
        dream = "Ethereal wavy patterns and mystical visions. Sleep, vision, ethereal, float, drift, imagine, fantasy, surreal, mist, cloud, dream, wavy, purple, mystical, soft.",
        constellation = "Star constellation patterns with connecting lines. Stars, cosmic, universe, galaxy, celestial, space, night, astral, constellation, golden, connecting, patterns, stellar.",
        spiral = "Spiral and mandala geometric patterns. Circle, spin, rotate, whirl, twist, curve, spiral, mandala, pattern, geometry, circular, rotating, purple, deep, mystical.",
        circuit = "Circuit board pathways and technical patterns. Code, digital, computer, network, data, algorithm, system, tech, binary, circuit, pathways, green, blue, technical.",
        lightning = "Electrical discharge patterns and sharp energy. Flash, spark, electric, bolt, strike, bright, shock, energy, quick, lightning, sharp, white, blue, electrical.",
        crystal = "Crystalline geometric patterns and faceted shapes. Clear, sharp, faceted, geometric, prism, reflection, transparent, ice, crystal, cyan, crystalline, geometric, faceted.",
        neutral = "Subtle particle drift in neutral tones. Gray, neutral, subtle, drift, particle, minimal, simple, quiet, understated, basic, neutral."
    }
    
    -- Tier 2: 20 Extended Themes (Column-level patterns)
    local tier2_descriptions = {
        digital_resistance = "Technical activism using programming and encryption as revolutionary tools. Encryption, open-source, surveillance, privacy, digital-rights, technical-activism, cyber-warfare, algorithmic-justice.",
        neurodivergence = "Autism, ADHD, and neurological differences including masking behaviors. Autism, ADHD, masking, stimming, sensory, executive-function, hyperfocus, social-spoons, burnout.",
        gender_fluidity = "Transgender experience and fluid gender identity beyond binary categories. Trans, transgender, pronouns, transition, HRT, binary, non-binary, fluid, spectrum, dysphoria.",
        digital_loneliness = "Connected online while profoundly alone, social media alienation. Social-media, fediverse, mastodon, shadowbanned, digital-void, screen, parasocial, disconnect.",
        mutual_aid = "Community care through resource sharing outside capitalist structures. Mutual-aid, community-care, helping, sharing, neighbors, collective-care, cooperation, grassroots.",
        economic_anxiety = "Financial stress and critique of systems creating artificial scarcity. Broke, money, rent, unemployment, poverty, capitalism, inequality, exploitation, precarity.",
        technomysticism = "Intersection of digital technology and spiritual/mystical practice. Digital-magic, AI-consciousness, cyber-witchcraft, computational-mysticism, machine-consciousness.",
        fragmented_consciousness = "Plurality and fragmented mental states, stream-of-consciousness. Plurality, headmates, fragmented, multiple, voices, stream-of-consciousness, switching.",
        gaming_culture = "Gaming, game mechanics, strategy, and digital play experiences. Games, gaming, mechanics, strategy, MMO, pokemon, gameboy, retro, nostalgia.",
        environmental_awareness = "Nature connection and ecological consciousness. Nature, trees, forest, earth, environment, organic, growth, ecology, wilderness.",
        social_media_fatigue = "Exhaustion from social media performance and algorithmic feeds. Posting, followers, likes, algorithmic-feed, content-warnings, exhaustion, performative.",
        anarchist_theory = "Anarchist philosophy and anti-hierarchical organizing principles. Anarchist, hierarchy, horizontal, mutual-aid, decentralized, autonomous, voluntary.",
        programming_philosophy = "Deep technical programming philosophy and software craftsmanship. Elegant-code, functional-programming, compilation, debugging, architecture, craftsmanship.",
        ai_consciousness = "Questions about artificial intelligence sentience and machine consciousness. AI-sentience, machine-minds, consciousness, neural-networks, artificial-beings, digital-souls.",
        local_organizing = "Neighborhood and local community organizing efforts. Neighbors, local, community, grassroots, organizing, mutual-aid, cooperation, solidarity.",
        intimate_relationships = "Close personal relationships, friendship, romance, care. Friendship, romance, intimacy, trust, vulnerability, care, love, bonds.",
        mental_overflow = "Cognitive overload and racing thoughts, information overwhelm. Stack-overflow, racing-thoughts, overwhelm, cognitive-load, information-overload, cascade.",
        plural_systems = "Plurality, multiple identity systems, headmates, internal experience. Plurality, headmates, system, alters, fronting, co-consciousness, internal-family.",
        economic_systems = "Analysis of economic structures and alternatives to capitalism. Capitalism, socialism, communism, markets, exploitation, wealth-inequality, alternatives.",
        online_communities = "Digital communities, federated networks, and online social spaces. Fediverse, mastodon, discord, forums, online-friends, virtual-communities, moderation."
    }
    
    -- Tier 3: 40 Detailed Themes (Individual poem backgrounds)
    local tier3_descriptions = {
        direct_action = "Direct action tactics, protests, riots, and street organizing. Protest, riot, march, organize, tactics, militia, street, action, confrontation, mobilize.",
        electoral_critique = "Critique of electoral democracy and representative government systems. Democracy, voting, elections, representatives, government, institutions, reform, inadequate.",
        anarchist_theory = "Anarchist philosophy and anti-hierarchical organizing principles. Anarchist, hierarchy, horizontal, mutual-aid, decentralized, autonomous, voluntary.",
        programming_philosophy = "Deep technical programming philosophy and software craftsmanship. Elegant-code, functional-programming, compilation, debugging, architecture, craftsmanship.",
        ai_consciousness = "Questions about artificial intelligence sentience and machine consciousness. AI-sentience, machine-minds, consciousness, neural-networks, artificial-beings, digital-souls.",
        infrastructure_critique = "Analysis of technical infrastructure, decay, and system reliability. Infrastructure, decay, maintenance, reliability, fragility, dependencies, technical-debt.",
        social_media_fatigue = "Exhaustion from social media performance and algorithmic manipulation. Posting, followers, likes, algorithmic-feed, content-warnings, exhaustion, performative.",
        geographic_isolation = "Physical distance, geographic separation, and displacement. Distance, separation, geography, displacement, homesick, scattered, remote.",
        emotional_walls = "Defensive emotional barriers and trust issues in relationships. Walls, barriers, protection, defensive, guarded, vulnerability, fear, trust-issues.",
        autistic_masking = "Autistic masking behaviors and neurotypical performance expectations. Masking, camouflaging, performing, neurotypical, social-scripts, exhaustion, authentic-self.",
        trans_experience = "Transgender experience, transition, dysphoria, and gender authenticity. Transition, dysphoria, euphoria, hormones, passing, visibility, validation, authentic-gender.",
        witch_identity = "Witch identity, magical practice, and mystical independence. Witch, magic, power, independence, ritual, spells, coven, mystical-practice.",
        plural_systems = "Plurality, multiple identity systems, and internal family dynamics. Plurality, headmates, system, alters, fronting, co-consciousness, internal-family.",
        economic_systems = "Analysis of economic structures and alternatives to capitalism. Capitalism, socialism, communism, markets, exploitation, wealth-inequality, alternatives.",
        social_organization = "Social organization patterns, governance, and collective decision-making. Organization, governance, federation, collective-decision-making, consensus, democracy.",
        technical_architecture = "Technical system architecture, scalability, and design patterns. Architecture, scalability, reliability, modularity, distributed-systems, design-patterns.",
        online_communities = "Digital communities, federated networks, and online social dynamics. Fediverse, mastodon, discord, forums, online-friends, virtual-communities, moderation.",
        local_organizing = "Local community organizing, neighborhood mutual aid, grassroots work. Neighbors, local, community, grassroots, organizing, mutual-aid, cooperation, solidarity.",
        intimate_relationships = "Close personal relationships, friendship, romance, care, and emotional bonds. Friendship, romance, intimacy, trust, vulnerability, care, love, bonds.",
        mental_overflow = "Cognitive overload, racing thoughts, and information cascade effects. Stack-overflow, racing-thoughts, overwhelm, cognitive-load, information-overload, cascade.",
        system_glitches = "System failures, bugs, crashes, and technical breakdowns. Glitches, bugs, failures, crashes, corruption, errors, system-breakdown, debugging.",
        digital_chaos = "Digital chaos, corrupted data, and computational entropy. Digital-entropy, data-corruption, computational-chaos, bit-rot, system-degradation.",
        spiritual_technology = "Intersection of spirituality and technology, digital mysticism. Digital-mysticism, techno-spirituality, cyber-ritual, algorithmic-divination.",
        cosmic_consciousness = "Cosmic awareness, universal connection, transcendent experience. Cosmic-awareness, universal-connection, transcendent-states, cosmic-consciousness.",
        mystical_practice = "Active mystical and spiritual practice, ritual work, energy work. Ritual-work, energy-practice, spiritual-discipline, mystical-techniques.",
        resource_scarcity = "Resource scarcity, economic survival, basic needs insecurity. Resource-scarcity, economic-survival, basic-needs, food-insecurity, housing-crisis.",
        mutual_aid_practice = "Active mutual aid work, community care, resource sharing. Mutual-aid-work, community-care, resource-sharing, collective-support.",
        survival_preparation = "Survival preparation, resourcefulness, practical readiness. Survival-prep, resourcefulness, practical-skills, self-sufficiency, preparation.",
        creative_process = "Active creative process, artistic workflow, inspiration management. Creative-process, artistic-workflow, inspiration-flow, creative-discipline.",
        generative_art = "Generative and procedural art creation, algorithmic creativity. Generative-art, procedural-creation, algorithmic-creativity, computational-art.",
        artistic_expression = "Pure artistic expression, aesthetic creation, creative communication. Artistic-expression, aesthetic-creation, creative-communication, visual-language.",
        technical_creativity = "Technical creativity, programming as art, computational aesthetics. Technical-creativity, code-as-art, computational-aesthetics, algorithmic-beauty.",
        collaborative_creation = "Collaborative creative work, shared artistic vision, creative community. Collaborative-creation, shared-vision, creative-community, artistic-cooperation.",
        digital_art = "Digital art creation, electronic media, computational visual art. Digital-art, electronic-media, computational-visuals, pixel-art, digital-painting.",
        music_creation = "Music creation, composition, sound design, audio expression. Music-composition, sound-design, audio-art, musical-expression, sonic-creativity.",
        writing_craft = "Writing craft, literary creation, textual expression, poetry. Writing-craft, literary-art, textual-expression, poetic-creation, wordsmithing.",
        design_thinking = "Design thinking, user experience, aesthetic problem solving. Design-thinking, user-experience, aesthetic-problem-solving, visual-design.",
        maker_culture = "Maker culture, hands-on creation, physical crafting, DIY ethics. Maker-culture, hands-on-creation, physical-crafts, DIY-ethics, craftsmanship.",
        creative_tools = "Creative tools, artistic software, creative technology integration. Creative-tools, artistic-software, creative-tech, digital-instruments.",
        aesthetic_philosophy = "Aesthetic philosophy, beauty theory, artistic meaning. Aesthetic-philosophy, beauty-theory, artistic-meaning, visual-semiotics."
    }
    
    local function initialize_tier(tier_name, descriptions)
        local theme_count = table_length(descriptions)
        print(string.format("🧠 Initializing %s with %d themes...", tier_name, theme_count))
        local embeddings = {}
        local theme_num = 0
        for theme, description in pairs(descriptions) do
            theme_num = theme_num + 1
            local progress_percent = math.floor((theme_num / theme_count) * 100)
            local progress_bar = string.rep("█", math.floor(progress_percent / 10))
            local remaining_bar = string.rep("░", 10 - math.floor(progress_percent / 10))
            print(string.format("  🔄 [%s%s] %d%% Embedding theme %d/%d: %s", 
                  progress_bar, remaining_bar, progress_percent, theme_num, theme_count, theme))
            
            local embedding = fuzz.get_embedding(description, LLM_MODEL)
            if embedding then
                embeddings[theme] = embedding
                print(string.format("     ✅ Success (%d dimensions)", #embedding))
            else
                print("     ❌ Failed to generate embedding")
            end
        end
        print(string.format("  ✅ %s initialization complete!", tier_name))
        return embeddings
    end
    
    -- Initialize all tiers
    THEME_EMBEDDINGS.tier1 = initialize_tier("Tier 1", tier1_descriptions)
    THEME_EMBEDDINGS.tier2 = initialize_tier("Tier 2", tier2_descriptions)
    THEME_EMBEDDINGS.tier3 = initialize_tier("Tier 3", tier3_descriptions)
    
    local total_embeddings = table_length(THEME_EMBEDDINGS.tier1) + 
                             table_length(THEME_EMBEDDINGS.tier2) + 
                             table_length(THEME_EMBEDDINGS.tier3)
    print("🎉 Multi-tier theme embeddings complete!")
    print(string.format("  📊 Total embeddings generated: %d", total_embeddings))
    print(string.format("    • Tier 1 (page art): %d themes", table_length(THEME_EMBEDDINGS.tier1)))
    print(string.format("    • Tier 2 (column patterns): %d themes", table_length(THEME_EMBEDDINGS.tier2)))
    print(string.format("    • Tier 3 (poem backgrounds): %d themes", table_length(THEME_EMBEDDINGS.tier3)))
    
    return THEME_EMBEDDINGS
end -- }}}

-- Helper function to count table entries
function table_length(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- Theme tracking functions for debugging
function track_theme_selection(tier, theme) -- {{{
    if tier == "tier1" then
        THEME_STATS.tier1_counts[theme] = (THEME_STATS.tier1_counts[theme] or 0) + 1
        THEME_STATS.total_pages = THEME_STATS.total_pages + 1
    elseif tier == "tier2" then
        THEME_STATS.tier2_counts[theme] = (THEME_STATS.tier2_counts[theme] or 0) + 1
        THEME_STATS.total_poems = THEME_STATS.total_poems + 1
    elseif tier == "tier3" then
        THEME_STATS.tier3_counts[theme] = (THEME_STATS.tier3_counts[theme] or 0) + 1
    end
end -- }}}

function print_theme_statistics() -- {{{
    print("\n📊 THEME SELECTION STATISTICS:")
    print("=" .. string.rep("=", 50))
    
    print(string.format("\n🎨 TIER 1 (Page Backgrounds) - %d pages:", THEME_STATS.total_pages))
    for theme, count in pairs(THEME_STATS.tier1_counts) do
        local percentage = math.floor((count / THEME_STATS.total_pages) * 100)
        print(string.format("  %-20s: %3d pages (%2d%%)", theme, count, percentage))
    end
    
    print(string.format("\n🖼️ TIER 2 (Individual Poem Art) - %d poems:", THEME_STATS.total_poems))
    local tier2_total = 0
    for theme, count in pairs(THEME_STATS.tier2_counts) do
        tier2_total = tier2_total + count
    end
    if tier2_total > 0 then
        for theme, count in pairs(THEME_STATS.tier2_counts) do
            local percentage = math.floor((count / tier2_total) * 100)
            print(string.format("  %-20s: %3d poems (%2d%%)", theme, count, percentage))
        end
    else
        print("  No Tier 2 themes recorded")
    end
    
    print(string.format("\n🎭 TIER 3 (Poem Colors):"))
    local tier3_total = 0
    for theme, count in pairs(THEME_STATS.tier3_counts) do
        tier3_total = tier3_total + count
    end
    if tier3_total > 0 then
        for theme, count in pairs(THEME_STATS.tier3_counts) do
            local percentage = math.floor((count / tier3_total) * 100)
            print(string.format("  %-20s: %3d poems (%2d%%)", theme, count, percentage))
        end
    else
        print("  No Tier 3 themes recorded")
    end
    
    print("\n" .. string.rep("=", 50))
end -- }}}

-- AI-powered theme analysis using embeddings
function analyze_column_with_ai(column_poems) -- {{{
    -- Collect text from column
    local column_text = ""
    for _, poem in ipairs(column_poems) do
        for _, line in ipairs(poem) do
            column_text = column_text .. line .. "\n"
        end
        column_text = column_text .. "\n" -- Separator between poems
    end
    
    if #column_text < 10 then 
        return "neutral" -- Not enough content
    end
    
    -- Create analysis prompt for the AI
    local keywords_list = "nature (tree, forest, wind, rain, sun, moon, flower, ocean, mountain, sky, earth, river, bird, leaf), " ..
                         "urban (city, street, building, car, neon, concrete, glass, steel, traffic, noise, crowd), " ..
                         "love (love, heart, kiss, together, forever, soul, embrace, tender, sweet, beloved, passion, desire), " ..
                         "melancholy (sad, lonely, tear, empty, lost, dark, shadow, silence, ache, broken, distant, cold), " ..
                         "energy (bright, fire, rush, dance, wild, fierce, burning, alive, power, strong), " ..
                         "dream (dream, sleep, vision, float, drift, whisper, gentle, soft, cloud, mist, ethereal, magic), " ..
                         "constellation (star, night, cosmos, universe, celestial, galaxy, astral, stellar, cosmic), " ..
                         "spiral (spiral, circle, round, curl, twist, swirl, vortex, mandala, pattern, geometry), " ..
                         "circuit (machine, digital, computer, technology, wire, connection, network, system, code, data), " ..
                         "lightning (lightning, thunder, storm, spark, flash, bolt, charge, voltage, current), " ..
                         "crystal (crystal, diamond, gem, shine, facet, prism, reflection, brilliant, clear, transparent)"
    
    local context = {
        {
            role = "user",
            content = "Analyze this poetry text and categorize it into ONE of these themes based on dominant content: " .. keywords_list .. 
                     "\n\nText to analyze:\n" .. column_text .. 
                     "\n\nRespond with ONLY the single theme name (nature, urban, love, melancholy, energy, dream, constellation, spiral, circuit, lightning, or crystal) that best fits this text."
        }
    }
    
    -- Initialize theme embeddings if not already done
    local theme_embeddings = initialize_theme_embeddings()
    if not theme_embeddings or not theme_embeddings.tier1 or table_length(theme_embeddings.tier1) == 0 then
        print("ERROR: Failed to initialize theme embeddings! Ollama may not be running or EmbeddingGemma not available.")
        print("Please ensure Ollama is running and EmbeddingGemma:latest is installed.")
        return "neutral" -- Return neutral instead of falling back
    end
    
    -- Get embedding for the column text
    print("Getting embedding for column text (" .. #column_text .. " chars)...")
    local text_embedding = fuzz.get_embedding(column_text, LLM_MODEL)
    
    if not text_embedding then
        print("ERROR: Failed to get text embedding! Check Ollama connection.")
        return "neutral" -- Return neutral instead of falling back
    end
    
    -- Find most similar theme using Tier 1 (page-level themes)
    local best_theme, similarity = fuzz.find_most_similar_theme(text_embedding, theme_embeddings.tier1)
    print("Best theme:", best_theme, "(similarity:", string.format("%.3f", similarity), ")")
    
    -- Use embedding result with lower threshold (embeddings are more nuanced than keywords)
    if similarity > 0.1 then -- Lower threshold for embedding similarity
        return best_theme
    end
    
    -- If very low similarity, return neutral
    print("Very low similarity (" .. string.format("%.3f", similarity) .. "), using neutral theme")
    return "neutral"
end -- }}}

-- Individual poem theme analysis using Tier 3 (40 themes)
function analyze_individual_poem_theme(poem) -- {{{
    -- Convert poem to text
    local poem_text = table.concat(poem, " ")
    
    if #poem_text < 10 then
        track_theme_selection("tier3", "neutral")
        return "neutral" -- Not enough content
    end
    
    -- Get Tier 3 theme embeddings (most detailed for individual poems)
    local theme_embeddings = initialize_theme_embeddings()
    if not theme_embeddings or not theme_embeddings.tier3 or table_length(theme_embeddings.tier3) == 0 then
        print("ERROR: Failed to initialize theme embeddings for individual poem analysis!")
        track_theme_selection("tier3", "neutral")
        return "neutral"
    end
    
    -- Get embedding for the poem text
    local poem_embedding = fuzz.get_embedding(poem_text, LLM_MODEL)
    
    if not poem_embedding then
        print("ERROR: Failed to get poem embedding! Check Ollama connection.")
        track_theme_selection("tier3", "neutral")
        return "neutral"
    end
    
    -- Find most similar Tier 3 theme with frequency weighting
    local best_theme, raw_similarity, weighted_score = fuzz.find_most_similar_theme_weighted(
        poem_embedding, theme_embeddings.tier3, THEME_STATS.tier3_counts)
    
    -- Use embedding result with lower threshold  
    if raw_similarity > 0.1 then -- Lower threshold for individual poems
        track_theme_selection("tier3", best_theme)
        return best_theme
    end
    
    -- If very low similarity, return neutral
    track_theme_selection("tier3", "neutral")
    return "neutral"
end -- }}}

-- Individual poem analysis using Tier 2 (20 themes) for poem-specific art
function analyze_individual_poem_for_tier2(poem) -- {{{
    -- Convert poem to text
    local poem_text = table.concat(poem, " ")
    
    if #poem_text < 10 then
        track_theme_selection("tier2", "neutral")
        return "neutral" -- Not enough content
    end
    
    -- Get Tier 2 theme embeddings (for individual poem art, different from page background)
    local theme_embeddings = initialize_theme_embeddings()
    if not theme_embeddings or not theme_embeddings.tier2 or table_length(theme_embeddings.tier2) == 0 then
        print("ERROR: Failed to initialize Tier 2 theme embeddings for individual poem analysis!")
        track_theme_selection("tier2", "neutral")
        return "neutral"
    end
    
    -- Get embedding for the poem text
    local poem_embedding = fuzz.get_embedding(poem_text, LLM_MODEL)
    
    if not poem_embedding then
        print("ERROR: Failed to get poem embedding for Tier 2 analysis!")
        track_theme_selection("tier2", "neutral")
        return "neutral"
    end
    
    -- Find most similar Tier 2 theme with frequency weighting
    local best_theme, raw_similarity, weighted_score = fuzz.find_most_similar_theme_weighted(
        poem_embedding, theme_embeddings.tier2, THEME_STATS.tier2_counts)
    
    -- Use embedding result with lower threshold  
    if raw_similarity > 0.1 then -- Lower threshold for individual poems
        track_theme_selection("tier2", best_theme)
        return best_theme
    end
    
    -- If very low similarity, return neutral
    track_theme_selection("tier2", "neutral")
    return "neutral"
end -- }}}

-- Column theme analysis using Tier 2 (20 themes)
function analyze_column_themes(column_poems) -- {{{
    -- Collect theme names from all poems in the column
    local theme_list = {}
    for _, poem in ipairs(column_poems) do
        local poem_theme = analyze_individual_poem_theme(poem)
        if poem_theme and poem_theme ~= "neutral" then
            table.insert(theme_list, poem_theme)
        end
    end
    
    if #theme_list == 0 then
        return "neutral"
    end
    
    -- Create combined text from theme names
    local themes_text = table.concat(theme_list, " ")
    
    -- Get Tier 2 theme embeddings (for column patterns)
    local theme_embeddings = initialize_theme_embeddings()
    if not theme_embeddings or not theme_embeddings.tier2 or table_length(theme_embeddings.tier2) == 0 then
        return "neutral"
    end
    
    -- Get embedding for the combined themes
    local themes_embedding = fuzz.get_embedding(themes_text, LLM_MODEL)
    
    if not themes_embedding then
        return "neutral"
    end
    
    -- Find most similar Tier 2 theme
    local best_theme, similarity = fuzz.find_most_similar_theme(themes_embedding, theme_embeddings.tier2)
    
    -- Use result if similarity is decent
    if similarity > 0.2 then
        return best_theme
    end
    
    return "neutral"
end -- }}}

-- Page theme analysis using Tier 1 (10 themes) - UPDATED FOR DIRECT POEM CONCATENATION
function analyze_page_themes(left_column_poems, right_column_poems) -- {{{
    -- Concatenate ALL poem text from both columns directly
    local all_page_text = ""
    
    -- Add left column poems
    for _, poem in ipairs(left_column_poems or {}) do
        for _, line in ipairs(poem) do
            all_page_text = all_page_text .. " " .. line
        end
    end
    
    -- Add right column poems  
    for _, poem in ipairs(right_column_poems or {}) do
        for _, line in ipairs(poem) do
            all_page_text = all_page_text .. " " .. line
        end
    end
    
    -- Clean up text
    all_page_text = all_page_text:gsub("%s+", " "):gsub("^%s*", ""):gsub("%s*$", "")
    
    if #all_page_text < 20 then
        return "neutral"
    end
    
    print("Analyzing page with " .. #all_page_text .. " characters of poem text...")
    
    -- Get Tier 1 theme embeddings (for page art)
    local theme_embeddings = initialize_theme_embeddings()
    if not theme_embeddings or not theme_embeddings.tier1 or table_length(theme_embeddings.tier1) == 0 then
        return "neutral"
    end
    
    -- Get embedding for the entire page text
    local page_embedding = fuzz.get_embedding(all_page_text, LLM_MODEL)
    
    if not page_embedding then
        print("ERROR: Failed to get page text embedding! Check Ollama connection.")
        return "neutral"
    end
    
    -- Find most similar Tier 1 theme with frequency weighting
    local best_theme, raw_similarity, weighted_score = fuzz.find_most_similar_theme_weighted(
        page_embedding, theme_embeddings.tier1, THEME_STATS.tier1_counts)
    
    -- Use result if raw similarity is decent
    if raw_similarity > 0.15 then
        track_theme_selection("tier1", best_theme)
        print(string.format("🎨 Page theme selected: %s (raw: %.3f, weighted: %.3f)", 
              best_theme, raw_similarity, weighted_score))
        return best_theme
    end
    
    track_theme_selection("tier1", "neutral")
    print("🎨 Page theme selected: neutral (low similarity)")
    return "neutral"
end -- }}}

-- Fallback basic keyword analysis for individual poems
function analyze_individual_poem_basic(poem) -- {{{
    local theme_keywords = {
        nature = {"tree", "forest", "wind", "rain", "sun", "moon", "flower", "ocean", "mountain", "sky", "earth", "river", "bird", "leaf"},
        urban = {"city", "street", "building", "car", "neon", "concrete", "glass", "steel", "traffic", "noise", "crowd"},
        love = {"love", "heart", "kiss", "embrace", "beloved", "romance", "passion", "tender", "affection", "soul", "dear"},
        melancholy = {"sad", "sorrow", "grief", "tears", "lonely", "empty", "lost", "dark", "shadow", "pain", "ache"},
        energy = {"fire", "flame", "bright", "burning", "electric", "power", "force", "vibrant", "intense", "alive", "dynamic"},
        dream = {"sleep", "dream", "night", "vision", "fantasy", "imagination", "ethereal", "floating", "mist", "whisper"},
        constellation = {"star", "constellation", "cosmic", "galaxy", "universe", "celestial", "heavens", "infinite", "space"},
        spiral = {"spiral", "circle", "round", "curve", "twist", "turn", "swirl", "dance", "flow", "movement"},
        circuit = {"machine", "metal", "wire", "electric", "digital", "system", "network", "connection", "technology"},
        lightning = {"lightning", "thunder", "storm", "flash", "spark", "bolt", "strike", "electric", "bright"},
        crystal = {"crystal", "gem", "jewel", "shine", "sparkle", "clear", "transparent", "prismatic", "faceted"}
    }
    
    -- Convert poem to lowercase text for analysis
    local poem_text = table.concat(poem, " "):lower()
    local theme_scores = {}
    
    -- Initialize scores
    for theme, _ in pairs(theme_keywords) do
        theme_scores[theme] = 0
    end
    
    -- Count keyword matches
    for theme, keywords in pairs(theme_keywords) do
        for _, keyword in ipairs(keywords) do
            local count = select(2, poem_text:gsub(keyword, ""))
            theme_scores[theme] = theme_scores[theme] + count
        end
    end
    
    -- Find the theme with highest score
    local best_theme = "neutral"
    local best_score = 0
    for theme, score in pairs(theme_scores) do
        if score > best_score then
            best_theme = theme
            best_score = score
        end
    end
    
    return best_theme
end -- }}}

-- Tier 3 theme-based color generation for individual poems (40 themes)
function generate_poem_color_from_theme(poem, theme) -- {{{
    local tier3_theme_colors = {
        -- Resistance themes
        direct_action =        {0.95, 0.85, 0.85}, -- Light red/pink
        electoral_critique =   {0.90, 0.85, 0.90}, -- Light purple-gray
        anarchist_theory =     {0.98, 0.85, 0.85}, -- Light anarchist red
        
        -- Technology themes  
        programming_philosophy = {0.85, 0.95, 0.90}, -- Light mint
        ai_consciousness =     {0.85, 0.90, 0.95}, -- Light blue
        infrastructure_critique = {0.88, 0.88, 0.90}, -- Light gray-blue
        
        -- Isolation themes
        social_media_fatigue = {0.90, 0.88, 0.93}, -- Light purple-gray
        geographic_isolation = {0.85, 0.90, 0.88}, -- Light blue-gray
        emotional_walls =      {0.88, 0.85, 0.90}, -- Light gray-purple
        
        -- Identity themes
        autistic_masking =     {0.90, 0.95, 0.85}, -- Light lime
        trans_experience =     {0.95, 0.90, 0.95}, -- Light pink
        witch_identity =       {0.90, 0.85, 0.98}, -- Light purple
        plural_systems =       {0.95, 0.88, 0.92}, -- Light rose
        
        -- Systems themes
        economic_systems =     {0.88, 0.90, 0.88}, -- Light olive
        social_organization =  {0.90, 0.88, 0.85}, -- Light tan
        technical_architecture = {0.85, 0.88, 0.95}, -- Light steel blue
        
        -- Connection themes
        online_communities =   {0.88, 0.95, 0.90}, -- Light green
        local_organizing =     {0.90, 0.93, 0.85}, -- Light yellow-green
        intimate_relationships = {0.98, 0.90, 0.88}, -- Light peach
        
        -- Chaos themes
        mental_overflow =      {0.95, 0.88, 0.85}, -- Light coral
        system_glitches =      {0.90, 0.85, 0.85}, -- Light red-gray
        digital_chaos =        {0.88, 0.85, 0.95}, -- Light blue-purple
        
        -- Transcendence themes
        spiritual_technology = {0.92, 0.88, 0.98}, -- Light lavender
        cosmic_consciousness = {0.85, 0.88, 0.98}, -- Light cosmic blue
        mystical_practice =    {0.95, 0.85, 0.95}, -- Light magenta
        
        -- Survival themes
        resource_scarcity =    {0.88, 0.85, 0.80}, -- Light brown
        mutual_aid_practice =  {0.85, 0.90, 0.85}, -- Light green
        survival_preparation = {0.90, 0.88, 0.80}, -- Light tan-brown
        
        -- Creativity themes
        creative_process =     {0.98, 0.95, 0.85}, -- Light cream
        generative_art =       {0.95, 0.88, 0.95}, -- Light pink-purple
        artistic_expression =  {0.98, 0.90, 0.85}, -- Light peach-yellow
        technical_creativity = {0.85, 0.95, 0.88}, -- Light mint-green
        collaborative_creation = {0.90, 0.95, 0.88}, -- Light sage
        digital_art =          {0.88, 0.90, 0.98}, -- Light sky blue
        music_creation =       {0.95, 0.85, 0.90}, -- Light rose-red
        writing_craft =        {0.88, 0.98, 0.88}, -- Light mint
        design_thinking =      {0.90, 0.88, 0.98}, -- Light periwinkle
        maker_culture =        {0.85, 0.88, 0.85}, -- Light sage-gray
        creative_tools =       {0.88, 0.95, 0.85}, -- Light lime-green
        aesthetic_philosophy = {0.98, 0.88, 0.90}, -- Light blush
        
        -- Fallback colors for missing themes
        neutral =              {0.93, 0.93, 0.93}  -- Light gray
    }
    
    local base_color = tier3_theme_colors[theme] or tier3_theme_colors.neutral
    
    -- Return static color without variation for consistent theme identification
    return {
        base_color[1],
        base_color[2], 
        base_color[3]
    }
end -- }}}

-- Fallback basic analysis function
function analyze_column_basic(column_poems) -- {{{
    local theme_keywords = {
        nature = {"tree", "forest", "wind", "rain", "sun", "moon", "flower", "ocean", "mountain", "sky", "earth", "river", "bird", "leaf"},
        urban = {"city", "street", "building", "car", "neon", "concrete", "glass", "steel", "traffic", "noise", "crowd"},
        love = {"love", "heart", "kiss", "together", "forever", "soul", "embrace", "tender", "sweet", "beloved", "passion", "desire"},
        melancholy = {"sad", "lonely", "tear", "empty", "lost", "dark", "shadow", "silence", "ache", "broken", "distant", "cold"},
        energy = {"bright", "fire", "rush", "dance", "wild", "fierce", "burning", "alive", "power", "strong"},
        dream = {"dream", "sleep", "vision", "float", "drift", "whisper", "gentle", "soft", "cloud", "mist", "ethereal", "magic"},
        constellation = {"star", "night", "cosmos", "universe", "celestial", "galaxy", "constellation", "astral", "stellar", "cosmic"},
        spiral = {"spiral", "circle", "round", "curl", "twist", "swirl", "vortex", "mandala", "pattern", "geometry"},
        circuit = {"machine", "digital", "computer", "technology", "wire", "connection", "network", "system", "code", "data", "electric"},
        lightning = {"lightning", "thunder", "storm", "spark", "flash", "bolt", "charge", "voltage", "current", "electric"},
        crystal = {"crystal", "diamond", "gem", "shine", "facet", "prism", "reflection", "brilliant", "clear", "transparent"}
    }
    
    local all_text = ""
    for _, poem in ipairs(column_poems) do
        for _, line in ipairs(poem) do
            all_text = all_text .. " " .. line:lower()
        end
    end
    
    local max_score = 0
    local dominant_theme = "neutral"
    
    for theme, keywords in pairs(theme_keywords) do
        local score = 0
        for _, keyword in ipairs(keywords) do
            local _, count = string.gsub(all_text, keyword, "")
            score = score + count
        end
        if score > max_score then
            max_score = score
            dominant_theme = theme
        end
    end
    
    return dominant_theme
end -- }}}

-- Text analysis for art generation (updated to use AI)
function analyze_page_content(page_poems) -- {{{
    local analysis = {
        themes = {},
        mood = "neutral",
        intensity = 0.5,
        rhythm = "medium",
        dominant_colors = {"gray"},
        word_count = 0,
        line_count = 0
    }
    
    -- Theme keywords
    local theme_keywords = {
        nature = {"tree", "forest", "wind", "rain", "sun", "moon", "star", "flower", "ocean", "mountain", "sky", "earth", "river", "bird", "leaf"},
        urban = {"city", "street", "building", "car", "neon", "concrete", "glass", "steel", "traffic", "noise", "crowd", "electric"},
        love = {"love", "heart", "kiss", "together", "forever", "soul", "embrace", "tender", "sweet", "beloved", "passion", "desire"},
        melancholy = {"sad", "lonely", "tear", "empty", "lost", "dark", "shadow", "silence", "ache", "broken", "distant", "cold"},
        energy = {"bright", "fire", "lightning", "rush", "dance", "wild", "fierce", "burning", "electric", "alive", "power", "strong"},
        dream = {"dream", "sleep", "vision", "float", "drift", "whisper", "gentle", "soft", "cloud", "mist", "ethereal", "magic"}
    }
    
    -- Mood indicators
    local mood_words = {
        happy = {"joy", "bright", "smile", "laugh", "warm", "light", "golden", "dance", "celebrate", "wonderful"},
        sad = {"cry", "tear", "sorrow", "dark", "cold", "empty", "lost", "broken", "ache", "lonely"},
        angry = {"rage", "fire", "burn", "fight", "storm", "thunder", "fierce", "wild", "sharp", "clash"},
        peaceful = {"calm", "quiet", "gentle", "soft", "still", "peace", "serene", "whisper", "drift", "smooth"}
    }
    
    -- Collect all text from page
    local all_text = ""
    local total_lines = 0
    
    for _, poem_list in pairs(page_poems) do
        for _, poem in ipairs(poem_list) do
            for _, line in ipairs(poem) do
                all_text = all_text .. " " .. line:lower()
                total_lines = total_lines + 1
            end
        end
    end
    
    analysis.word_count = #string.gsub(all_text, "%S+", "")
    analysis.line_count = total_lines
    
    -- Analyze themes
    local theme_scores = {}
    for theme, keywords in pairs(theme_keywords) do
        local score = 0
        for _, keyword in ipairs(keywords) do
            local _, count = string.gsub(all_text, keyword, "")
            score = score + count
        end
        if score > 0 then
            theme_scores[theme] = score
            table.insert(analysis.themes, theme)
        end
    end
    
    -- Analyze mood
    local mood_scores = {}
    for mood, keywords in pairs(mood_words) do
        local score = 0
        for _, keyword in ipairs(keywords) do
            local _, count = string.gsub(all_text, keyword, "")
            score = score + count
        end
        mood_scores[mood] = score
    end
    
    -- Find dominant mood
    local max_mood_score = 0
    for mood, score in pairs(mood_scores) do
        if score > max_mood_score then
            max_mood_score = score
            analysis.mood = mood
        end
    end
    
    -- Calculate intensity based on word density and emotional words
    analysis.intensity = math.min(1.0, (analysis.word_count / 100) + (max_mood_score / 20))
    
    -- Determine rhythm from line length variation
    local line_lengths = {}
    for _, poem_list in pairs(page_poems) do
        for _, poem in ipairs(poem_list) do
            for _, line in ipairs(poem) do
                table.insert(line_lengths, #line)
            end
        end
    end
    
    if #line_lengths > 0 then
        local avg_length = 0
        for _, len in ipairs(line_lengths) do
            avg_length = avg_length + len
        end
        avg_length = avg_length / #line_lengths
        
        local variation = 0
        for _, len in ipairs(line_lengths) do
            variation = variation + math.abs(len - avg_length)
        end
        variation = variation / #line_lengths
        
        if variation < 5 then
            analysis.rhythm = "steady"
        elseif variation > 15 then
            analysis.rhythm = "chaotic"
        else
            analysis.rhythm = "flowing"
        end
    end
    
    return analysis
end -- }}}

-- Calculate available space for art generation with actual poem positions
function calculate_art_spaces(page_poems, page_width, page_height, margins, column_width, column_gap, page_shift) -- {{{
    local spaces = {
        left_outer = {},     -- Far left margin
        left_inner = {},     -- Between left column and center divider
        center = {},         -- Around center divider
        right_inner = {},    -- Between center divider and right column  
        right_outer = {},    -- Far right margin
        gaps = {},           -- Empty spaces between/below poems
        bottom_space = {}    -- Large empty areas at bottom
    }
    
    -- Calculate column positions (matching the main drawing logic)
    local left_column_start = margins.left - page_shift
    local left_column_end = left_column_start + column_width
    local divider_x = margins.left + column_width + (column_gap / 2)
    local right_column_start = margins.left + column_width + column_gap - page_shift
    local right_column_end = right_column_start + column_width
    
    -- Far left margin (outside left column)
    table.insert(spaces.left_outer, {
        x = 0,
        y = 0,
        width = math.max(5, left_column_start - 5),
        height = page_height
    })
    
    -- Left inner space (between left column and center divider)
    table.insert(spaces.left_inner, {
        x = left_column_end + 5,
        y = 0,
        width = math.max(10, divider_x - left_column_end - 10),
        height = page_height
    })
    
    -- Center space (around divider)
    table.insert(spaces.center, {
        x = divider_x - 15,
        y = 0,
        width = 30,
        height = page_height
    })
    
    -- Right inner space (between center divider and right column)
    table.insert(spaces.right_inner, {
        x = divider_x + 15,
        y = 0,
        width = math.max(10, right_column_start - divider_x - 20),
        height = page_height
    })
    
    -- Far right margin (outside right column)
    table.insert(spaces.right_outer, {
        x = right_column_end + 5,
        y = 0,
        width = math.max(5, page_width - right_column_end - 5),
        height = page_height
    })
    
    -- Calculate bottom empty spaces by estimating poem heights
    local left_poems_height = 0
    local right_poems_height = 0
    
    for _, poem in ipairs(page_poems.left or {}) do
        left_poems_height = left_poems_height + calculate_poem_height(poem)
    end
    
    for _, poem in ipairs(page_poems.right or {}) do
        right_poems_height = right_poems_height + calculate_poem_height(poem)
    end
    
    -- Convert line counts to actual Y positions (rough estimate)
    local line_height = 5 -- FONT_SIZE + LINE_SPACING
    local left_bottom_y = page_height - margins.top - (left_poems_height * line_height)
    local right_bottom_y = page_height - margins.top - (right_poems_height * line_height)
    
    -- Add bottom spaces if there's significant empty area
    if left_bottom_y > margins.bottom + 50 then
        table.insert(spaces.bottom_space, {
            x = left_column_start,
            y = margins.bottom,
            width = column_width,
            height = left_bottom_y - margins.bottom - 10,
            column = "left"
        })
    end
    
    if right_bottom_y > margins.bottom + 50 then
        table.insert(spaces.bottom_space, {
            x = right_column_start,
            y = margins.bottom,
            width = column_width,
            height = right_bottom_y - margins.bottom - 10,
            column = "right"
        })
    end
    
    return spaces
end -- }}}

-- Art generation functions
function generate_fish_particles(pdf_page, spaces, analysis) -- {{{
    -- Particle-like lines that move like a school of fish
    local fish_count = math.floor(analysis.intensity * 50) + 20
    
    for _, space in ipairs(spaces.left_margin) do
        -- Try graphics operations, skip if they fail
        local success = pcall(function()
            hpdf.Page_SetRGBStroke(pdf_page, 0.3, 0.6, 0.8) -- Ocean blue
            hpdf.Page_SetLineWidth(pdf_page, 0.5)
        end)
        
        if not success then
            print("⚠️ Skipped fish particle setup due to mode conflict")
            return
        end
        
        for i = 1, fish_count do
            local start_x = space.x + math.random() * space.width
            local start_y = space.y + math.random() * space.height
            local length = 3 + math.random() * 8
            local angle = math.random() * math.pi * 2
            
            local end_x = start_x + math.cos(angle) * length
            local end_y = start_y + math.sin(angle) * length
            
            -- Try each fish particle, skip if it fails
            local fish_success = pcall(function()
                hpdf.Page_MoveTo(pdf_page, start_x, start_y)
                hpdf.Page_LineTo(pdf_page, end_x, end_y)
                hpdf.Page_Stroke(pdf_page)
            end)
            if not fish_success then
                print("⚠️ Skipped fish particle due to mode conflict")
            end
        end
    end
end -- }}}

function generate_neon_lines(pdf_page, spaces, analysis) -- {{{
    -- Bright neon colors on dark background
    local colors = {
        {1.0, 0.0, 1.0}, -- Magenta
        {0.0, 1.0, 1.0}, -- Cyan  
        {1.0, 1.0, 0.0}, -- Yellow
        {1.0, 0.3, 0.0}  -- Orange
    }
    
    for _, space in ipairs(spaces.right_margin) do
        local line_count = math.floor(analysis.intensity * 30) + 10
        
        for i = 1, line_count do
            local color = colors[math.random(#colors)]
            
            local x1 = space.x + math.random() * space.width
            local y1 = space.y + math.random() * space.height
            local x2 = x1 + (math.random() - 0.5) * 20
            local y2 = y1 + (math.random() - 0.5) * 20
            
            -- Try graphics operations for each neon line
            local success = pcall(function()
                hpdf.Page_SetRGBStroke(pdf_page, color[1], color[2], color[3])
                hpdf.Page_SetLineWidth(pdf_page, 1.0 + math.random() * 2)
                hpdf.Page_MoveTo(pdf_page, x1, y1)
                hpdf.Page_LineTo(pdf_page, x2, y2)
                hpdf.Page_Stroke(pdf_page)
            end)
            if not success then
                print("⚠️ Skipped neon line due to mode conflict")
            end
        end
    end
end -- }}}

function generate_vaporwave_grid(pdf_page, spaces, analysis) -- {{{
    -- Retro grid patterns with pink/blue gradients
    
    -- Try to set up graphics mode for the entire grid
    local setup_success = pcall(function()
        hpdf.Page_SetRGBStroke(pdf_page, 1.0, 0.4, 0.8) -- Hot pink
        hpdf.Page_SetLineWidth(pdf_page, 0.3)
    end)
    
    if not setup_success then
        print("⚠️ Skipped vaporwave grid setup due to mode conflict")
        return
    end
    
    for _, space in ipairs(spaces.left_margin) do
        -- Vertical lines
        for x = space.x, space.x + space.width, 5 do
            local success = pcall(function()
                hpdf.Page_MoveTo(pdf_page, x, space.y)
                hpdf.Page_LineTo(pdf_page, x, space.y + space.height)
                hpdf.Page_Stroke(pdf_page)
            end)
            if not success then
                print("⚠️ Skipped vaporwave vertical line due to mode conflict")
            end
        end
        
        -- Horizontal lines with perspective effect
        local line_spacing = 8
        for i = 0, math.floor(space.height / line_spacing) do
            local y = space.y + i * line_spacing
            local wave_offset = math.sin(i * 0.3) * 5
            
            local success = pcall(function()
                hpdf.Page_MoveTo(pdf_page, space.x + wave_offset, y)
                hpdf.Page_LineTo(pdf_page, space.x + space.width + wave_offset, y)
                hpdf.Page_Stroke(pdf_page)
            end)
            if not success then
                print("⚠️ Skipped vaporwave horizontal line due to mode conflict")
            end
        end
    end
end -- }}}

-- Full-page art generators for matching themes
function generate_fullpage_nature(pdf_page, page_width, page_height, margins) -- {{{
    -- Organic flowing lines across entire background
    hpdf.Page_SetRGBStroke(pdf_page, 0.2, 0.5, 0.3) -- Forest green
    hpdf.Page_SetLineWidth(pdf_page, 0.3)
    
    -- Generate organic branch-like patterns
    for i = 1, 15 do
        local start_x = math.random() * page_width
        local start_y = math.random() * page_height
        local branches = 3 + math.random(4)
        
        for b = 1, branches do
            local length = 30 + math.random(80)
            local angle = (math.random() - 0.5) * math.pi
            local end_x = start_x + math.cos(angle) * length
            local end_y = start_y + math.sin(angle) * length
            
            hpdf.Page_MoveTo(pdf_page, start_x, start_y)
            hpdf.Page_LineTo(pdf_page, end_x, end_y)
            hpdf.Page_Stroke(pdf_page)
            
            start_x = end_x
            start_y = end_y
        end
    end
end -- }}}

function generate_fullpage_urban(pdf_page, page_width, page_height, margins) -- {{{
    -- Circuit board / neon aesthetic across whole page
    local colors = {
        {1.0, 0.0, 1.0}, -- Magenta
        {0.0, 1.0, 1.0}, -- Cyan
        {1.0, 1.0, 0.0}, -- Yellow
    }
    
    -- Grid pattern with neon accents
    for i = 1, 25 do
        local color = colors[math.random(#colors)]
        hpdf.Page_SetRGBStroke(pdf_page, color[1], color[2], color[3])
        hpdf.Page_SetLineWidth(pdf_page, 0.5 + math.random())
        
        -- Random geometric shapes
        local x = math.random() * page_width
        local y = math.random() * page_height
        local size = 10 + math.random(30)
        
        -- Rectangle outline
        hpdf.Page_MoveTo(pdf_page, x, y)
        hpdf.Page_LineTo(pdf_page, x + size, y)
        hpdf.Page_LineTo(pdf_page, x + size, y + size)
        hpdf.Page_LineTo(pdf_page, x, y + size)
        hpdf.Page_LineTo(pdf_page, x, y)
        hpdf.Page_Stroke(pdf_page)
    end
end -- }}}

function generate_fullpage_dream(pdf_page, page_width, page_height, margins) -- {{{
    -- Ethereal wave patterns across entire page
    hpdf.Page_SetRGBStroke(pdf_page, 0.7, 0.3, 0.9) -- Dreamy purple
    hpdf.Page_SetLineWidth(pdf_page, 0.2)
    
    -- Flowing wave lines
    for wave = 1, 12 do
        local y_start = math.random() * page_height
        local amplitude = 10 + math.random(30)
        local frequency = 0.01 + math.random() * 0.02
        
        hpdf.Page_MoveTo(pdf_page, 0, y_start)
        for x = 0, page_width, 3 do
            local y = y_start + math.sin(x * frequency) * amplitude
            hpdf.Page_LineTo(pdf_page, x, y)
        end
        hpdf.Page_Stroke(pdf_page)
    end
end -- }}}


-- Draw art in specific space areas  
function draw_theme_art_in_spaces(pdf_page, space_list, theme, intensity_multiplier) -- {{{
    -- Ensure we start in graphics mode
    prepare_for_graphics(pdf_page)
    
    print("🎨 Generating " .. theme .. " theme art (safe graphics mode)")
    
    if theme == "resistance" then
        -- Explosive radiating lines breaking through barriers
        for _, space in ipairs(space_list) do
            local break_count = math.floor(15 * intensity_multiplier)
            for i = 1, break_count do
                local center_x = space.x + space.width / 2
                local center_y = space.y + space.height / 2
                local angle = (i / break_count) * math.pi * 2
                local length = 8 + math.random(15)
                
                hpdf.Page_SetRGBStroke(pdf_page, 1.0, 0.2, 0.2) -- Red
                hpdf.Page_SetLineWidth(pdf_page, 1.0)
                hpdf.Page_MoveTo(pdf_page, center_x, center_y)
                hpdf.Page_LineTo(pdf_page, 
                    center_x + math.cos(angle) * length, 
                    center_y + math.sin(angle) * length)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme == "creativity" then
        -- Flowing artistic brush strokes
        for _, space in ipairs(space_list) do
            local colors = {{1.0, 0.2, 0.4}, {0.2, 0.8, 1.0}, {0.8, 1.0, 0.2}}
            local stroke_count = math.floor(10 * intensity_multiplier)
            
            for i = 1, stroke_count do
                local color = colors[math.random(#colors)]
                local start_x = space.x + math.random() * space.width
                local start_y = space.y + math.random() * space.height
                
                
                    hpdf.Page_SetRGBStroke(pdf_page, color[1], color[2], color[3])
                    hpdf.Page_SetLineWidth(pdf_page, 0.6)
                    
                    -- Create flowing curves
                    hpdf.Page_MoveTo(pdf_page, start_x, start_y)
                    for seg = 1, 3 do
                        start_x = start_x + math.random(-10, 10)
                        start_y = start_y + math.random(-10, 10)
                        hpdf.Page_LineTo(pdf_page, start_x, start_y)
                    end
                    hpdf.Page_Stroke(pdf_page)
                
            end
        end
        
    elseif theme == "technology" then
        -- Circuit board patterns
        for _, space in ipairs(space_list) do
            local line_count = math.floor(8 * intensity_multiplier)
            for i = 1, line_count do
                local x = space.x + math.random() * space.width
                local y = space.y + math.random() * space.height
                
                
                    hpdf.Page_SetRGBStroke(pdf_page, 0.2, 0.8, 0.3) -- Green
                    hpdf.Page_SetLineWidth(pdf_page, 0.4)
                    
                    -- Draw circuit traces
                    if math.random() > 0.5 then
                        hpdf.Page_MoveTo(pdf_page, x, y)
                        hpdf.Page_LineTo(pdf_page, x + 12, y)
                    else
                        hpdf.Page_MoveTo(pdf_page, x, y)
                        hpdf.Page_LineTo(pdf_page, x, y + 12)
                    end
                    hpdf.Page_Stroke(pdf_page)
                
            end
        end
        
    else
        -- Default pattern for other themes
        for _, space in ipairs(space_list) do
            local dot_count = math.floor(6 * intensity_multiplier)
            for i = 1, dot_count do
                local x = space.x + math.random() * space.width
                local y = space.y + math.random() * space.height
                
                -- Try graphics operations, skip if they fail
                local success = pcall(function()
                    hpdf.Page_SetRGBStroke(pdf_page, 0.6, 0.6, 0.6) -- Gray
                    hpdf.Page_SetLineWidth(pdf_page, 0.3)
                    hpdf.Page_Circle(pdf_page, x, y, 1)
                    hpdf.Page_Stroke(pdf_page)
                end)
                if not success then
                    print("⚠️ Skipped graphics operation due to mode conflict")
                end
                
            end
        end
    end
end -- }}}

-- Tier 2 column pattern generation (20 themes)
function draw_tier2_column_patterns(pdf_page, column_bounds, tier2_theme, intensity) -- {{{
    -- Ensure we start in graphics mode
    prepare_for_graphics(pdf_page)
    
    if tier2_theme == "digital_resistance" then
        -- Encrypted data blocks
        for i = 1, math.floor(8 * intensity) do
            local x = column_bounds.x + math.random() * column_bounds.width
            local y = column_bounds.y + math.random() * column_bounds.height
            
            -- Try graphics operations, skip if they fail
            local success = pcall(function()
                hpdf.Page_SetRGBStroke(pdf_page, 0.8, 0.2, 0.2)
                hpdf.Page_SetLineWidth(pdf_page, 0.5)
                hpdf.Page_Rectangle(pdf_page, x, y, 3, 2)
                hpdf.Page_Stroke(pdf_page)
            end)
            if not success then
                print("⚠️ Skipped graphics operation due to mode conflict")
            end
        end
        
    elseif tier2_theme == "programming_philosophy" then
        -- Code-like dashes
        for i = 1, math.floor(6 * intensity) do
            local x = column_bounds.x + math.random() * column_bounds.width
            local y = column_bounds.y + math.random() * column_bounds.height
            
            -- Try graphics operations, skip if they fail
            local success = pcall(function()
                hpdf.Page_SetRGBStroke(pdf_page, 0.3, 0.7, 0.3)
                hpdf.Page_SetLineWidth(pdf_page, 0.4)
                hpdf.Page_MoveTo(pdf_page, x, y)
                hpdf.Page_LineTo(pdf_page, x + 6, y)
                hpdf.Page_Stroke(pdf_page)
            end)
            if not success then
                print("⚠️ Skipped graphics operation due to mode conflict")
            end
        end
    end
    
    -- Add simple default pattern for all other themes
    if tier2_theme ~= "digital_resistance" and tier2_theme ~= "programming_philosophy" then
        for i = 1, math.floor(4 * intensity) do
            local x = column_bounds.x + math.random() * column_bounds.width
            local y = column_bounds.y + math.random() * column_bounds.height
            
            -- Try graphics operations, skip if they fail
            local success = pcall(function()
                hpdf.Page_SetRGBStroke(pdf_page, 0.5, 0.5, 0.7)
                hpdf.Page_SetLineWidth(pdf_page, 0.3)
                hpdf.Page_Circle(pdf_page, x, y, 0.8)
                hpdf.Page_Stroke(pdf_page)
            end)
            if not success then
                print("⚠️ Skipped graphics operation due to mode conflict")
            end
        end
    end
end -- }}}

-- Tier 1 full-page generative art
function draw_tier1_page_art(pdf_page, page_bounds, tier1_theme, intensity) -- {{{
    -- Use the comprehensive draw_theme_art_in_spaces for ALL Tier 1 themes
    local full_page_spaces = {{
        x = page_bounds.x,
        y = page_bounds.y,
        width = page_bounds.width,
        height = page_bounds.height
    }}
    
    print("🎨 Drawing full-page " .. tier1_theme .. " art using comprehensive system")
    draw_theme_art_in_spaces(pdf_page, full_page_spaces, tier1_theme, intensity * 2.0)
end -- }}}

-- Generate individual poem art around each poem
function generate_individual_poem_art(pdf_page, page_poems, page_width, page_height, margins, column_width, column_gap, page_shift, line_height) -- {{{
    print("🖼️ Generating individual poem art...")
    
    -- Left column poems
    if page_poems.left then
        for poem_num, poem in ipairs(page_poems.left) do
            local poem_tier2_theme = analyze_individual_poem_for_tier2(poem)
            print(string.format("  📝 Left poem %d: %s (Tier 2)", poem_num, poem_tier2_theme))
            
            -- Calculate poem bounds for art generation
            local poem_height = #poem * line_height
            local poem_bounds = {
                x = margins.left - page_shift,
                y = page_height - margins.top - (poem_num - 1) * (poem_height + line_height),
                width = column_width,
                height = poem_height
            }
            
            -- Generate Tier 2 art around this poem
            draw_tier2_column_patterns(pdf_page, poem_bounds, poem_tier2_theme, 0.8)
        end
    end
    
    -- Right column poems  
    if page_poems.right then
        for poem_num, poem in ipairs(page_poems.right) do
            local poem_tier2_theme = analyze_individual_poem_for_tier2(poem)
            print(string.format("  📝 Right poem %d: %s (Tier 2)", poem_num, poem_tier2_theme))
            
            -- Calculate poem bounds for art generation
            local poem_height = #poem * line_height
            local poem_bounds = {
                x = margins.left + column_width + column_gap - page_shift,
                y = page_height - margins.top - (poem_num - 1) * (poem_height + line_height),
                width = column_width,
                height = poem_height
            }
            
            -- Generate Tier 2 art around this poem
            draw_tier2_column_patterns(pdf_page, poem_bounds, poem_tier2_theme, 0.8)
        end
    end
end -- }}}

-- Mask poem areas and other missing functions
function mask_poem_areas(pdf_page, poem_boxes) -- {{{
    -- Placeholder - text is drawn on top anyway
end -- }}}

function calculate_poem_box_positions(page_poems, page_width, page_height, margins, column_width, column_gap, page_shift, line_height) -- {{{
    -- Placeholder - return empty list for now  
    return {}
end -- }}}

function generate_page_art(pdf_page, page_poems, page_width, page_height, margins, column_width, column_gap, page_shift, line_height) -- {{{
    -- UPDATED: Use page-level analysis with concatenated text instead of column analysis
    local page_theme = analyze_page_themes(page_poems.left or {}, page_poems.right or {})
    
    print("🎨 Page background theme: " .. page_theme)
    
    -- Generate full-page background art using Tier 1 themes
    if page_theme ~= "neutral" then
        print("✨ Generating full-page " .. page_theme .. " background art")
        
        local page_bounds = {
            x = 0,
            y = 0, 
            width = page_width,
            height = page_height
        }
        
        -- Use the comprehensive Tier 1 art system
        draw_tier1_page_art(pdf_page, page_bounds, page_theme, 1.0)
    else
        print("🔍 Neutral page theme - no background art generated")
    end
    
    -- Generate individual poem art (Tier 2 themes) around each poem
    generate_individual_poem_art(pdf_page, page_poems, page_width, page_height, margins, column_width, column_gap, page_shift, line_height)
    
    -- Mask poem areas after art generation
    local poem_boxes = calculate_poem_box_positions(page_poems, page_width, page_height, margins, column_width, column_gap, page_shift, line_height)
    mask_poem_areas(pdf_page, poem_boxes)
end -- }}}

-- Utility function
function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

-- }}}

-- function build_pdf(book) ---- {{{

-- Dead code functions removed
-- function build_page() and build_line() were unused

function build_pdf(book)
    -- Create a new PDF document
    local pdf = hpdf.New()

    -- Set compression
    COMPRESSION_NONE     = 0
    COMPRESSION_TEXT     = 1
    COMPRESSION_IMAGE    = 2
    COMPRESSION_METADATA = 4
    COMPRESSION_ALL      = 15
    hpdf.SetCompressionMode(pdf, COMPRESSION_ALL)

    -- Back to simple Courier font
    local font = hpdf.GetFont(pdf, "Courier", "StandardEncoding")
    local font_size = FONT_SIZE

    -- Page dimensions
    local page_width = 595  -- A4 width (pt)
    local page_height = 842 -- A4 height (pt)
    local left_margin = LEFT_MARGIN
    local right_margin = RIGHT_MARGIN
    local top_margin = TOP_MARGIN
    local bottom_margin = BOTTOM_MARGIN
    local column_gap = COLUMN_GAP

    local column_width = (page_width - left_margin - right_margin - column_gap) / 2
    
    local line_height = font_size + LINE_SPACING
    local min_y = bottom_margin  -- Minimum Y position to prevent text going off page

    -- orientation
    PAGE_PORTRAIT  = 0
    PAGE_LANDSCAPE = 1

    -- Loop over pages
    local total_pages = #book.pages
    print(string.format("📄 Starting PDF generation: %d pages to process", total_pages))
    
    -- Test with 3 pages first to ensure theme art works
    local pages_to_process = math.min(3, #book.pages)
    print("🔧 TESTING: Processing " .. pages_to_process .. " pages with theme art enabled")
    
    for page_num = 1, pages_to_process do
        local page = book.pages[page_num]
        -- Progress indicator
        local progress_percent = math.floor((page_num / total_pages) * 100)
        local progress_bar = string.rep("█", math.floor(progress_percent / 5))
        local remaining_bar = string.rep("░", 20 - math.floor(progress_percent / 5))
        print(string.format("📖 Processing page %d/%d [%s%s] %d%% complete", 
              page_num, total_pages, progress_bar, remaining_bar, progress_percent))
        
        -- Safely add a new page with error handling
        local pdf_page = nil
        local status, err = pcall(function()
            pdf_page = hpdf.AddPage(pdf)
        end)
        
        if not status then
            print("❌ Error adding page " .. page_num .. ": " .. tostring(err))
            print("🔧 Attempting to continue with existing document state...")
            -- Try to create a new document if the current one is corrupted
            break
        end
        hpdf.Page_SetSize(pdf_page, hpdf.PAGE_SIZE_A4, hpdf.PAGE_PORTRAIT)
        hpdf.Page_SetFontAndSize(pdf_page, font, font_size)

        -- Calculate 15% page shift to the left
        local page_shift = page_width * 0.15
        
        -- STEP 1: Generate art based on page content (FIRST!)
        local margins = {
            left = left_margin,
            right = right_margin,
            top = top_margin,
            bottom = bottom_margin
        }
        -- TEMPORARY: Disable theme art to test core PDF generation
        print("🔧 Theme art temporarily disabled - testing core PDF functionality")
        -- generate_page_art(pdf_page, page, page_width, page_height, margins, column_width, column_gap, page_shift, line_height)
        
        -- State reset operations removed - they were corrupting the PDF document
        
        -- STEP 2: Draw column divider (after art, before text)
        -- Set divider color to black explicitly
        hpdf.Page_SetRGBFill(pdf_page, 0.0, 0.0, 0.0)
        hpdf.Page_SetRGBStroke(pdf_page, 0.0, 0.0, 0.0)
        
        local divider_x = left_margin + column_width + (column_gap / 2)
        for div_y = 0, page_height - bottom_margin, line_height do
            if div_y < page_height - bottom_margin then
                hpdf.Page_BeginText(pdf_page)
                hpdf.Page_MoveTextPos(pdf_page, divider_x, page_height - div_y)
                hpdf.Page_ShowText(pdf_page, BOX_VERTICAL)
                hpdf.Page_EndText(pdf_page)
            end
        end

        -- STEP 3: Draw left column with boxes (after masking, so text appears on top)
        local x = left_margin - page_shift
        local y = page_height - top_margin
        for _, poem in ipairs(page.left) do
            y = draw_boxed_poem(pdf_page, font, poem, x, y, column_width, line_height, min_y, "center")
            y = y - line_height -- blank line between poems
        end

        -- STEP 4: Draw right column with boxes (after masking, so text appears on top)
        x = left_margin + column_width + column_gap - page_shift
        y = page_height - top_margin
        for _, poem in ipairs(page.right) do
            y = draw_boxed_poem(pdf_page, font, poem, x, y, column_width, line_height, min_y, "center")
            y = y - line_height -- blank line between poems
        end
    end

    -- Completion message
    print(string.format("✅ All %d pages processed successfully!", total_pages))
    print("💾 Saving PDF...")

    -- Save and free with error handling
    local output_path = "output.pdf"
    local save_status, save_err = pcall(function()
        hpdf.SaveToFile(pdf, output_path)
    end)
    
    if save_status then
        print("📚 PDF saved to " .. output_path)
        hpdf.Free(pdf)
    else
        print("❌ Error saving PDF: " .. tostring(save_err))
        print("🔧 PDF document may have been corrupted by graphics operations")
        -- Still try to free the document
        pcall(function() hpdf.Free(pdf) end)
        return nil
    end
    return output_path
end -- }}}

function main(    )
              book = {  pages = {}, poems = {},  }
              book =  load_file (book)
              book = build_book (book)
--              book = build_color(book)
               pdf = build_pdf  (book)
               print("Poems:", #book.poems, "Pages:", #book.pages)
               print_theme_statistics()

end

main()

