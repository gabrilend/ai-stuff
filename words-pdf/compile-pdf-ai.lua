-- don't forget to add the my-art and things-i-almost-posted to the pdf

 DIR = arg[1]
FILE = arg[2]

package.cpath = package.cpath .. ";" .. DIR .. "/libs/luahpdf/?.so"
package.cpath = package.cpath .. ";" .. DIR .. "/libs/libharu-RELEASE_2_3_0/build/src/?.so"
package.path = package.path .. ";" .. DIR .. "/libs/?.lua"
package.path = package.path .. ";" .. DIR .. "/?.lua"

hpdf = require "hpdf"
fuzz = require "libs/fuzzy-computing"
palette = require "themes/palette"
art = require "libs/art-primitives"
EMBEDDING_DRIVEN_PARAMS = require "themes/embedding-driven-params"

-- LLM settings - ENABLED for Ollama embeddings
-- Model name must match Ollama's loaded model exactly (lowercase per `ollama list`).
LLM_MODEL = "embeddinggemma:latest"
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

-- Per-(theme, parameter) axis vectors computed at startup from the
-- positive/negative keyword embeddings in themes/embedding-driven-params.lua.
-- Structure: PARAM_AXES[theme_name] = { {name, low, high, axis = vector}, ... }
PARAM_AXES = {}

-- Per-page percentile values for each (theme, parameter) axis, populated by
-- compute_page_percentiles() after build_book(). Structure:
-- PAGE_PERCENTILES[page_num][theme_name][param_name] = float in [0, 1]
PAGE_PERCENTILES = {}

-- Layout Configuration Variables
MAX_LINES_PER_PAGE = 155 -- Lines per page column (restored)
MAX_CHAR_PER_LINE  = 80  -- Characters per line (content width)

-- Threshold for rendering Tier 1 (page-level) art. The page's fill ratio
-- is the fraction of available column-lines that are occupied by poems.
-- Tier 1 art only renders when the page is LESS full than this threshold,
-- so dense text-heavy pages stay quiet and sparse pages get the expressive
-- background art filling their breathing room. Tunable.
-- 0.0 = never render Tier 1 art; 1.0 = always render it; 0.65 = render when
-- at least 35% of the page is empty. See docs/balance-updates.md for history.
TIER1_ART_THRESHOLD = 0.65

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
BACKGROUND_COLOR = palette.mask_color
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

    -- Draw the Tier 3 background fill behind the text, so the per-poem color
    -- is visible and Tier 1 art doesn't bleed through gaps between characters.
    -- The Tier 3 embedding call is warm-cached by this point because the
    -- Tier 2 classification in generate_individual_poem_art ran earlier on
    -- the same page and used the same poem embedding.
    local theme = analyze_individual_poem_theme(poem)
    local fill_color = palette.tier3_backgrounds[theme] or palette.tier3_backgrounds.neutral
    -- Box covers: top border + top padding + #poem content + bottom padding + bottom border = #poem + 4 lines
    local total_box_lines = #poem + 4
    local box_height_pts = total_box_lines * line_height
    -- Courier monospace at FONT_SIZE: each char ~ 0.6 * FONT_SIZE wide
    local box_width_pts = box_width * FONT_SIZE * 0.6
    hpdf.Page_SetRGBFill(pdf_page, table.unpack(fill_color))
    hpdf.Page_Rectangle(pdf_page, actual_x, start_y - box_height_pts + line_height * 0.5,
        box_width_pts, box_height_pts)
    hpdf.Page_Fill(pdf_page)

    -- Restore text color (black) after the fill, so subsequent text draws correctly
    hpdf.Page_SetRGBFill(pdf_page, table.unpack(palette.text_color))
    hpdf.Page_SetRGBStroke(pdf_page, table.unpack(palette.text_color))

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

-- {{{ vector helpers (small, used by axis math below)
local function vec_dot(a, b)
    local sum = 0
    for i = 1, #a do sum = sum + a[i] * b[i] end
    return sum
end

local function vec_subtract_normalized(pos, neg)
    -- Returns normalize(pos - neg). The axis points from neg-concept toward
    -- pos-concept; projecting a poem vector onto this axis says how far along
    -- the directed continuum the poem leans.
    local diff = {}
    local mag = 0
    for i = 1, #pos do
        diff[i] = pos[i] - neg[i]
        mag = mag + diff[i] * diff[i]
    end
    mag = math.sqrt(mag)
    if mag == 0 then return diff end  -- defensive; shouldn't happen in practice
    for i = 1, #diff do diff[i] = diff[i] / mag end
    return diff
end
-- }}}

-- {{{ initialize_param_axes()
-- For every (theme, parameter) in the embedding-driven config, embed the
-- positive and negative keyword strings and compute the axis between them.
-- Cached for the rest of the run via PARAM_AXES. With Issue 017's embedding
-- cache, this is a one-time cost across reruns.
function initialize_param_axes()
    print("🎯 Initializing embedding-driven parameter axes...")
    local axis_count = 0
    for theme_name, params in pairs(EMBEDDING_DRIVEN_PARAMS) do
        PARAM_AXES[theme_name] = {}
        for _, p in ipairs(params) do
            local pos_vec = fuzz.get_embedding(p.positive, LLM_MODEL)
            local neg_vec = fuzz.get_embedding(p.negative, LLM_MODEL)
            if pos_vec and neg_vec then
                table.insert(PARAM_AXES[theme_name], {
                    name = p.name,
                    low  = p.low,
                    high = p.high,
                    axis = vec_subtract_normalized(pos_vec, neg_vec),
                })
                axis_count = axis_count + 1
                print(string.format("  ✅ %s.%s axis ready (range %g..%g)",
                    theme_name, p.name, p.low, p.high))
            else
                print(string.format("  ❌ %s.%s: keyword embedding failed; this parameter will fall back to 0.5 percentile",
                    theme_name, p.name))
            end
        end
    end
    print(string.format("✨ %d parameter axes ready across %d themes", axis_count, table_length(PARAM_AXES)))
end
-- }}}

-- {{{ compute_page_percentiles(book)
-- For each page in the book, embed the concatenated page text once and
-- project onto every parameter axis. After all pages are scored, sort by
-- each (theme, parameter) and assign percentile ranks across the corpus.
-- Percentiles, not raw scores, are what generators consume — this ensures
-- the full [low, high] range is used regardless of how concentrated raw
-- cosine projections happen to be (they typically cluster in narrow bands
-- like [0.2, 0.6] rather than spanning [-1, 1]).
function compute_page_percentiles(book)
    if next(PARAM_AXES) == nil then
        print("📊 No parameter axes defined; skipping percentile pass")
        return
    end
    print("📊 Scoring pages against parameter axes...")

    -- raw[theme][param][page_num] = projection score
    local raw = {}
    for theme_name, params in pairs(PARAM_AXES) do
        raw[theme_name] = {}
        for _, p in ipairs(params) do raw[theme_name][p.name] = {} end
    end

    for page_num, page in ipairs(book.pages) do
        local page_text = ""
        for _, poem in ipairs(page.left or {}) do
            for _, line in ipairs(poem) do page_text = page_text .. " " .. line end
        end
        for _, poem in ipairs(page.right or {}) do
            for _, line in ipairs(poem) do page_text = page_text .. " " .. line end
        end
        page_text = page_text:gsub("%s+", " ")
        if #page_text >= 10 then
            local page_vec = fuzz.get_embedding(page_text, LLM_MODEL)
            if page_vec then
                for theme_name, params in pairs(PARAM_AXES) do
                    for _, p in ipairs(params) do
                        raw[theme_name][p.name][page_num] = vec_dot(page_vec, p.axis)
                    end
                end
            end
        end
    end

    -- Rank each (theme, param) independently. Pages with no score (empty,
    -- or embedding failed) get the median 0.5 percentile as a safe default.
    for theme_name, by_param in pairs(raw) do
        for param_name, by_page in pairs(by_param) do
            local ranked = {}
            for page_num, _ in pairs(by_page) do table.insert(ranked, page_num) end
            table.sort(ranked, function(a, b) return by_page[a] < by_page[b] end)
            local n = #ranked
            for rank, page_num in ipairs(ranked) do
                PAGE_PERCENTILES[page_num] = PAGE_PERCENTILES[page_num] or {}
                PAGE_PERCENTILES[page_num][theme_name] = PAGE_PERCENTILES[page_num][theme_name] or {}
                PAGE_PERCENTILES[page_num][theme_name][param_name] = (n > 1) and ((rank - 1) / (n - 1)) or 0.5
            end
        end
    end

    print(string.format("✨ Computed percentiles for %d pages × %d themes",
        #book.pages, table_length(PARAM_AXES)))
end
-- }}}

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
    local base_color = palette.tier3_backgrounds[theme] or palette.tier3_backgrounds.neutral
    
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

-- Tier 1 theme generators.
-- Each takes (page, space) and draws into the given rectangle.
-- The dispatch table below maps Tier 1 theme names to these functions,
-- so draw_theme_art_in_spaces can look up the right generator per page.

-- {{{ generate_resistance(page, space, params)
function generate_resistance(page, space, params)
    -- Explosive radiating lines from center
    params = params or {}
    local ray_count = math.floor(4 + (params.ray_count or 0.5) * 21 + 0.5)
    local max_length = math.floor(8 + (params.ray_length or 0.5) * 22 + 0.5)

    local cx = space.x + space.width / 2
    local cy = space.y + space.height / 2
    hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.resistance_red))
    hpdf.Page_SetLineWidth(page, 1.0)
    for i = 1, ray_count do
        local angle = (i / ray_count) * math.pi * 2
        local length = max_length * (0.5 + math.random() * 0.5)
        hpdf.Page_MoveTo(page, cx, cy)
        hpdf.Page_LineTo(page, cx + math.cos(angle) * length, cy + math.sin(angle) * length)
        hpdf.Page_Stroke(page)
    end
end
-- }}}

-- {{{ generate_technology(page, space, params)
function generate_technology(page, space, params)
    -- Green circuit traces, alternating horizontal and vertical
    params = params or {}
    local trace_count = math.floor(4 + (params.trace_count or 0.5) * 16 + 0.5)
    local trace_length = math.floor(6 + (params.trace_length or 0.5) * 18 + 0.5)

    hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.circuit_green))
    hpdf.Page_SetLineWidth(page, 0.4)
    for i = 1, trace_count do
        local x = space.x + math.random() * space.width
        local y = space.y + math.random() * space.height
        if math.random() > 0.5 then
            hpdf.Page_MoveTo(page, x, y); hpdf.Page_LineTo(page, x + trace_length, y)
        else
            hpdf.Page_MoveTo(page, x, y); hpdf.Page_LineTo(page, x, y + trace_length)
        end
        hpdf.Page_Stroke(page)
    end
end
-- }}}

-- {{{ generate_creativity(page, space, params)
function generate_creativity(page, space, params)
    -- Flowing brush strokes; three axes pull on count, wildness, and palette breadth
    params = params or {}
    local stroke_count = math.floor(4 + (params.stroke_count or 0.5) * 14 + 0.5)
    local segments_per_stroke = math.floor(1 + (params.stroke_jaggedness or 0.5) * 5 + 0.5)
    local color_palette_size = math.floor(1 + (params.color_richness or 0.5) * 2 + 0.5)
    -- Use first N colors from brush_set, where N = color_palette_size (1..3)
    local colors = {}
    for i = 1, color_palette_size do colors[i] = palette.brush_set[i] end

    for i = 1, stroke_count do
        local color = colors[math.random(#colors)]
        local x = space.x + math.random() * space.width
        local y = space.y + math.random() * space.height
        hpdf.Page_SetRGBStroke(page, color[1], color[2], color[3])
        hpdf.Page_SetLineWidth(page, 0.6)
        hpdf.Page_MoveTo(page, x, y)
        for seg = 1, segments_per_stroke do
            x = x + math.random(-10, 10)
            y = y + math.random(-10, 10)
            hpdf.Page_LineTo(page, x, y)
        end
        hpdf.Page_Stroke(page)
    end
end
-- }}}

-- {{{ generate_isolation(page, space, params)
function generate_isolation(page, space, params)
    -- Density is fixed at 6 marks — isolation is communicated by emptiness,
    -- not by adjusting mark count. Only the alpha varies along the embedding
    -- axis (how present the loneliness is).
    params = params or {}
    local alpha = 0.3 + (params.alpha_level or 0.5) * 0.65
    local count = 6
    hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.lonely_blue))
    hpdf.Page_SetLineWidth(page, 0.4)
    art.with_alpha(page, alpha, function()
        for i = 1, count do
            local x = space.x + math.random() * space.width
            local y = space.y + math.random() * space.height
            hpdf.Page_Circle(page, x, y, 1.5)
            hpdf.Page_Stroke(page)
        end
    end)
end
-- }}}

-- {{{ generate_identity(page, space, params)
function generate_identity(page, space, params)
    -- Same square repeated in prism-set colors with small offsets — the
    -- mark refracts into multiple selves. Shape count and refraction
    -- offset both flow from the embedding.
    params = params or {}
    local count = math.floor(3 + (params.shape_count or 0.5) * 9 + 0.5)
    local offset_scale = 1 + (params.offset_magnitude or 0.5) * 5

    for i = 1, count do
        local cx = space.x + math.random() * space.width
        local cy = space.y + math.random() * space.height
        local size = 6 + math.random(8)
        for ci, color in ipairs(palette.brush_set) do
            local offset_x = (ci - 2) * offset_scale
            local offset_y = (ci - 2) * (offset_scale * 0.5)
            art.with_alpha(page, 0.5, function()
                hpdf.Page_SetRGBFill(page, color[1], color[2], color[3])
                hpdf.Page_Rectangle(page, cx + offset_x, cy + offset_y, size, size)
                hpdf.Page_Fill(page)
            end)
        end
    end
end
-- }}}

-- {{{ generate_systems(page, space, params)
function generate_systems(page, space, params)
    -- Blueprint nodes connected by Manhattan right-angle paths
    params = params or {}
    local node_count = math.floor(4 + (params.node_count or 0.5) * 12 + 0.5)
    local line_weight = 0.3 + (params.line_weight or 0.5) * 0.9

    local nodes = {}
    hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.blueprint_blue))
    hpdf.Page_SetLineWidth(page, line_weight)
    for i = 1, node_count do
        local x = space.x + math.random() * space.width
        local y = space.y + math.random() * space.height
        nodes[i] = { x = x, y = y }
        hpdf.Page_Circle(page, x, y, 1.5)
        hpdf.Page_Stroke(page)
    end
    for i = 2, #nodes do
        local a, b = nodes[i - 1], nodes[i]
        hpdf.Page_MoveTo(page, a.x, a.y)
        hpdf.Page_LineTo(page, b.x, a.y)
        hpdf.Page_LineTo(page, b.x, b.y)
        hpdf.Page_Stroke(page)
    end
end
-- }}}

-- {{{ generate_connection(page, space, params)
function generate_connection(page, space, params)
    -- Warm bezier curves linking distant points, low alpha so layers weave
    params = params or {}
    local curve_count = math.floor(3 + (params.curve_count or 0.5) * 11 + 0.5)
    local max_sway = 8 + (params.sway_magnitude or 0.5) * 42
    local alpha = 0.3 + (params.alpha_layering or 0.5) * 0.4

    hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.warm_amber))
    hpdf.Page_SetLineWidth(page, 0.6)
    art.with_alpha(page, alpha, function()
        for i = 1, curve_count do
            local x1 = space.x + math.random() * space.width
            local y1 = space.y + math.random() * space.height
            local x2 = space.x + math.random() * space.width
            local y2 = space.y + math.random() * space.height
            local sway = (math.random() - 0.5) * 2 * max_sway
            art.flowing_curve(page, x1, y1, x2, y2, sway)
            hpdf.Page_Stroke(page)
        end
    end)
end
-- }}}

-- {{{ generate_chaos(page, space, params)
function generate_chaos(page, space, params)
    -- RGB-channel-separated overlapping rectangles for a glitch-print look
    params = params or {}
    local count = math.floor(4 + (params.glitch_count or 0.5) * 16 + 0.5)
    local shift_scale = 1 + (params.shift_magnitude or 0.5) * 5

    local channels = {
        palette.accents.glitch_red,
        palette.accents.glitch_green,
        palette.accents.glitch_blue,
    }
    for i = 1, count do
        local x = space.x + math.random() * space.width
        local y = space.y + math.random() * space.height
        local size = 8 + math.random(10)
        art.with_alpha(page, 0.6, function()
            for ci, color in ipairs(channels) do
                local off = (ci - 2) * shift_scale
                hpdf.Page_SetRGBStroke(page, color[1], color[2], color[3])
                hpdf.Page_SetLineWidth(page, 0.5)
                hpdf.Page_Rectangle(page, x + off, y + off, size, size)
                hpdf.Page_Stroke(page)
            end
        end)
    end
end
-- }}}

-- {{{ generate_transcendence(page, space, params)
-- Concentric mandala from radial arc segments with a gold center.
-- This is the first generator to consume embedding-driven parameters
-- (Issue 024). The three percentile values in `params` map to:
--   ring_count       — how many concentric rings (axis: layered/recursive
--                      vs singular/direct meaning)
--   radial_count     — how many radial subdivisions per ring (axis: ritual/
--                      structured vs spontaneous/free-form expression)
--   gold_center_size — radius of the gold core (axis: revelation/clear focus
--                      vs diffuse/peripheral feeling)
-- All percentiles default to 0.5 if the params table is empty, so this
-- generator still produces a reasonable mandala when called without the
-- embedding-driven pipeline.
function generate_transcendence(page, space, params)
    params = params or {}
    local p_rings  = params.ring_count       or 0.5
    local p_radial = params.radial_count     or 0.5
    local p_gold   = params.gold_center_size or 0.5

    local cx = space.x + space.width / 2
    local cy = space.y + space.height / 2

    -- Map percentiles to ranges declared in themes/embedding-driven-params.lua
    local ring_count       = math.floor(2 + p_rings  * 6 + 0.5)   -- [2, 8]
    local radial_count     = math.floor(4 + p_radial * 12 + 0.5)  -- [4, 16]
    local gold_center_size = 1 + p_gold * 5                       -- [1, 6]

    hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.sacred_purple))
    hpdf.Page_SetLineWidth(page, 0.5)
    art.with_alpha(page, 0.7, function()
        for r = 1, ring_count do
            local radius = r * 8
            for s = 0, radial_count - 1 do
                local start_deg = s * (360 / radial_count)
                local end_deg = start_deg + (360 / radial_count) * 0.7
                art.arc(page, cx, cy, radius, start_deg, end_deg)
                hpdf.Page_Stroke(page)
            end
        end
        hpdf.Page_SetRGBFill(page, table.unpack(palette.accents.temple_gold))
        hpdf.Page_Circle(page, cx, cy, gold_center_size)
        hpdf.Page_Fill(page)
    end)
end
-- }}}

-- {{{ generate_survival(page, space, params)
function generate_survival(page, space, params)
    -- Vertical trunks with branching root-curves recursing one level
    params = params or {}
    local trunk_count = math.floor(1 + (params.trunk_count or 0.5) * 5 + 0.5)
    local branches_per_trunk = math.floor(2 + (params.branch_count or 0.5) * 8 + 0.5)

    hpdf.Page_SetLineWidth(page, 0.5)
    for t = 1, trunk_count do
        local x = space.x + math.random() * space.width
        local y_top = space.y + space.height
        local y_bot = space.y
        hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.earth_brown))
        art.flowing_curve(page, x, y_top, x + math.random(-10, 10), y_bot, math.random(-5, 5))
        hpdf.Page_Stroke(page)
        hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.root_tan))
        hpdf.Page_SetLineWidth(page, 0.3)
        for b = 1, branches_per_trunk do
            local fx = x + math.random(-3, 3)
            local fy = y_top - math.random() * space.height * 0.7
            local bx = fx + math.random(-20, 20)
            local by = fy + math.random(-10, 10)
            art.flowing_curve(page, fx, fy, bx, by, math.random(-3, 3))
            hpdf.Page_Stroke(page)
        end
    end
end
-- }}}

-- {{{ generate_nature(page, space, params)
function generate_nature(page, space, params)
    -- Branching curves rooted at random points, growing organically
    params = params or {}
    local stems = math.floor(4 + (params.stem_count or 0.5) * 14 + 0.5)
    local branches_per_stem = math.floor(2 + (params.branch_recursion or 0.5) * 6 + 0.5)

    hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.forest_green))
    hpdf.Page_SetLineWidth(page, 0.3)
    for i = 1, stems do
        local x = space.x + math.random() * space.width
        local y = space.y + math.random() * space.height
        for b = 1, branches_per_stem do
            local angle = (math.random() - 0.5) * math.pi
            local length = 15 + math.random(30)
            local ex = x + math.cos(angle) * length
            local ey = y + math.sin(angle) * length
            art.flowing_curve(page, x, y, ex, ey, math.random(-4, 4))
            hpdf.Page_Stroke(page)
            x, y = ex, ey
        end
    end
end
-- }}}

-- {{{ generate_urban(page, space, params)
function generate_urban(page, space, params)
    -- Scattered neon rectangle outlines suggesting a city map
    params = params or {}
    local count = math.floor(5 + (params.block_count or 0.5) * 25 + 0.5)
    local max_size = math.floor(10 + (params.block_scale or 0.5) * 25 + 0.5)

    local colors = { palette.neon_set[1], palette.neon_set[2], palette.neon_set[3] }
    for i = 1, count do
        local color = colors[math.random(#colors)]
        hpdf.Page_SetRGBStroke(page, color[1], color[2], color[3])
        hpdf.Page_SetLineWidth(page, 0.5 + math.random())
        local x = space.x + math.random() * space.width
        local y = space.y + math.random() * space.height
        local size = max_size * (0.4 + math.random() * 0.6)
        hpdf.Page_Rectangle(page, x, y, size, size)
        hpdf.Page_Stroke(page)
    end
end
-- }}}

-- {{{ generate_energy(page, space, params)
function generate_energy(page, space, params)
    -- Radiating bursts from one or more focal points, white at core to orange at edge
    params = params or {}
    local focal_count = math.floor(1 + (params.focal_count or 0.5) * 3 + 0.5)
    local rays_per_focal = math.floor(8 + (params.ray_count or 0.5) * 27 + 0.5)

    for f = 1, focal_count do
        local cx = space.x + space.width * (0.2 + math.random() * 0.6)
        local cy = space.y + space.height * (0.2 + math.random() * 0.6)
        for i = 1, rays_per_focal do
            local angle = (i / rays_per_focal) * math.pi * 2 + math.random() * 0.2
            local length = 10 + math.random(25)
            local mid_x = cx + math.cos(angle) * length * 0.5
            local mid_y = cy + math.sin(angle) * length * 0.5
            hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.burst_white))
            hpdf.Page_SetLineWidth(page, 1.2)
            hpdf.Page_MoveTo(page, cx, cy)
            hpdf.Page_LineTo(page, mid_x, mid_y)
            hpdf.Page_Stroke(page)
            hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.burst_orange))
            hpdf.Page_SetLineWidth(page, 0.4)
            hpdf.Page_MoveTo(page, mid_x, mid_y)
            hpdf.Page_LineTo(page, cx + math.cos(angle) * length, cy + math.sin(angle) * length)
            hpdf.Page_Stroke(page)
        end
    end
end
-- }}}

-- {{{ generate_love(page, space, params)
function generate_love(page, space, params)
    -- Paired pink curves that braid — each pair swings opposite ways
    params = params or {}
    local pair_count = math.floor(2 + (params.braid_count or 0.5) * 8 + 0.5)
    local max_sway = 6 + (params.sway_intensity or 0.5) * 18

    hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.soft_pink))
    hpdf.Page_SetLineWidth(page, 0.7)
    art.with_alpha(page, 0.6, function()
        for i = 1, pair_count do
            local x1 = space.x + math.random() * space.width
            local y1 = space.y + math.random() * space.height
            local x2 = space.x + math.random() * space.width
            local y2 = space.y + math.random() * space.height
            local sway = max_sway * (0.5 + math.random() * 0.5)
            art.flowing_curve(page, x1, y1, x2, y2, sway)
            hpdf.Page_Stroke(page)
            art.flowing_curve(page, x1 + 3, y1, x2 + 3, y2, -sway)
            hpdf.Page_Stroke(page)
        end
    end)
end
-- }}}

-- {{{ generate_melancholy(page, space, params)
function generate_melancholy(page, space, params)
    -- Downward strokes, color washes from tear_blue at top to rain_gray at bottom.
    -- One axis (saturation) drives both drop count and drop length together;
    -- giving sorrow independent knobs would feel mechanical.
    params = params or {}
    local saturation = 0.2 + (params.saturation or 0.5) * 0.8
    local count = math.floor(8 + saturation * 32 + 0.5)
    local max_drop = 2 + saturation * 10

    local c1 = palette.accents.tear_blue
    local c2 = palette.accents.rain_gray
    for i = 1, count do
        local x = space.x + math.random() * space.width
        local y = space.y + math.random() * space.height
        local t = (y - space.y) / space.height
        hpdf.Page_SetRGBStroke(page,
            c1[1] * t + c2[1] * (1 - t),
            c1[2] * t + c2[2] * (1 - t),
            c1[3] * t + c2[3] * (1 - t))
        hpdf.Page_SetLineWidth(page, 0.4)
        hpdf.Page_MoveTo(page, x, y)
        hpdf.Page_LineTo(page, x, y - max_drop * (0.4 + math.random() * 0.6))
        hpdf.Page_Stroke(page)
    end
end
-- }}}

-- {{{ generate_dream(page, space, params)
function generate_dream(page, space, params)
    -- Smooth Bezier sine waves at varied amplitudes, layered at low alpha
    params = params or {}
    local wave_count = math.floor(3 + (params.wave_count or 0.5) * 11 + 0.5)
    local max_amplitude = 6 + (params.amplitude or 0.5) * 24

    hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.dreamy_purple))
    hpdf.Page_SetLineWidth(page, 0.3)
    art.with_alpha(page, 0.5, function()
        for w = 1, wave_count do
            local y_base = space.y + math.random() * space.height
            local amplitude = max_amplitude * (0.4 + math.random() * 0.6)
            local segs = 6
            local seg_width = space.width / segs
            hpdf.Page_MoveTo(page, space.x, y_base)
            for s = 1, segs do
                local x1 = space.x + s * seg_width
                local sign = (s % 2 == 0) and 1 or -1
                local y1 = y_base + sign * amplitude
                local cx1 = x1 - seg_width * 0.6
                local cy1 = y_base + sign * -amplitude
                local cx2 = x1 - seg_width * 0.4
                local cy2 = y_base + sign * amplitude
                hpdf.Page_CurveTo(page, cx1, cy1, cx2, cy2, x1, y1)
            end
            hpdf.Page_Stroke(page)
        end
    end)
end
-- }}}

-- {{{ generate_constellation(page, space, params)
function generate_constellation(page, space, params)
    -- Gold star points with thin night-blue lines between consecutive stars
    params = params or {}
    local star_count = math.floor(6 + (params.star_count or 0.5) * 18 + 0.5)
    local star_size = 0.5 + (params.star_size or 0.5) * 2.0

    local stars = {}
    for i = 1, star_count do
        stars[i] = {
            x = space.x + math.random() * space.width,
            y = space.y + math.random() * space.height,
        }
    end
    hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.night_blue))
    hpdf.Page_SetLineWidth(page, 0.2)
    art.with_alpha(page, 0.5, function()
        for i = 1, #stars - 1 do
            hpdf.Page_MoveTo(page, stars[i].x, stars[i].y)
            hpdf.Page_LineTo(page, stars[i + 1].x, stars[i + 1].y)
            hpdf.Page_Stroke(page)
        end
    end)
    hpdf.Page_SetRGBFill(page, table.unpack(palette.accents.star_gold))
    for _, s in ipairs(stars) do
        hpdf.Page_Circle(page, s.x, s.y, star_size)
        hpdf.Page_Fill(page)
    end
end
-- }}}

-- {{{ generate_spiral(page, space, params)
function generate_spiral(page, space, params)
    -- Single growing spiral built from arc segments at increasing radii
    params = params or {}
    local segments = math.floor(10 + (params.segment_count or 0.5) * 30 + 0.5)
    local growth_rate = 0.8 + (params.growth_rate or 0.5) * 1.7

    local cx = space.x + space.width / 2
    local cy = space.y + space.height / 2
    hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.sacred_purple))
    hpdf.Page_SetLineWidth(page, 0.4)
    for i = 1, segments do
        local radius = i * growth_rate
        local start_deg = i * 25
        local end_deg = start_deg + 30
        art.arc(page, cx, cy, radius, start_deg, end_deg)
        hpdf.Page_Stroke(page)
    end
end
-- }}}

-- {{{ generate_circuit(page, space, params)
function generate_circuit(page, space, params)
    -- Manhattan-geometry circuit traces with junction nodes at each turn
    params = params or {}
    local trace_count = math.floor(4 + (params.trace_count or 0.5) * 16 + 0.5)
    local segs_per_trace = math.floor(2 + (params.segments_per_trace or 0.5) * 6 + 0.5)

    hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.circuit_green))
    hpdf.Page_SetLineWidth(page, 0.5)
    for i = 1, trace_count do
        local x = space.x + math.random() * space.width
        local y = space.y + math.random() * space.height
        for s = 1, segs_per_trace do
            local len = 6 + math.random(10)
            local nx, ny = x, y
            if math.random() > 0.5 then
                nx = x + (math.random() > 0.5 and len or -len)
            else
                ny = y + (math.random() > 0.5 and len or -len)
            end
            hpdf.Page_MoveTo(page, x, y)
            hpdf.Page_LineTo(page, nx, ny)
            hpdf.Page_Stroke(page)
            hpdf.Page_Circle(page, nx, ny, 0.8)
            hpdf.Page_Stroke(page)
            x, y = nx, ny
        end
    end
end
-- }}}

-- {{{ generate_lightning(page, space, params)
function generate_lightning(page, space, params)
    -- Jagged bolts from top to bottom, drawn twice: thick blue glow + thin white core
    params = params or {}
    local bolt_count = math.floor(1 + (params.bolt_count or 0.5) * 4 + 0.5)
    local jag_max = 4 + (params.jaggedness or 0.5) * 12

    for b = 1, bolt_count do
        local x = space.x + math.random() * space.width
        local y = space.y + space.height
        local path_x, path_y = { x }, { y }
        while y > space.y do
            y = y - 6 - math.random() * 8
            x = x + (math.random() - 0.5) * jag_max
            table.insert(path_x, x)
            table.insert(path_y, y)
        end
        hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.bolt_blue))
        hpdf.Page_SetLineWidth(page, 1.5)
        hpdf.Page_MoveTo(page, path_x[1], path_y[1])
        for j = 2, #path_x do hpdf.Page_LineTo(page, path_x[j], path_y[j]) end
        hpdf.Page_Stroke(page)
        hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.bolt_white))
        hpdf.Page_SetLineWidth(page, 0.4)
        hpdf.Page_MoveTo(page, path_x[1], path_y[1])
        for j = 2, #path_x do hpdf.Page_LineTo(page, path_x[j], path_y[j]) end
        hpdf.Page_Stroke(page)
    end
end
-- }}}

-- {{{ generate_crystal(page, space, params)
function generate_crystal(page, space, params)
    -- Hexagonal facets with internal subdivision lines suggesting refraction
    params = params or {}
    local count = math.floor(2 + (params.facet_count or 0.5) * 8 + 0.5)
    local max_radius = 6 + (params.facet_radius or 0.5) * 12

    hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.crystal_cyan))
    hpdf.Page_SetLineWidth(page, 0.4)
    for i = 1, count do
        local cx = space.x + math.random() * space.width
        local cy = space.y + math.random() * space.height
        local radius = max_radius * (0.5 + math.random() * 0.5)
        local first_x, first_y = cx + radius, cy
        hpdf.Page_MoveTo(page, first_x, first_y)
        for s = 1, 5 do
            local angle = s * math.pi / 3
            hpdf.Page_LineTo(page, cx + math.cos(angle) * radius, cy + math.sin(angle) * radius)
        end
        hpdf.Page_LineTo(page, first_x, first_y)
        hpdf.Page_Stroke(page)
        for s = 0, 5 do
            local angle = s * math.pi / 3
            hpdf.Page_MoveTo(page, cx, cy)
            hpdf.Page_LineTo(page, cx + math.cos(angle) * radius, cy + math.sin(angle) * radius)
            hpdf.Page_Stroke(page)
        end
    end
end
-- }}}

-- {{{ generate_neutral(page, space)
function generate_neutral(page, space)
    -- Intentionally minimal: a single faint horizon line. Neutral should
    -- feel chosen, not absent.
    hpdf.Page_SetRGBStroke(page, table.unpack(palette.accents.pale_gray))
    hpdf.Page_SetLineWidth(page, 0.3)
    art.with_alpha(page, 0.4, function()
        local y = space.y + space.height * 0.5
        hpdf.Page_MoveTo(page, space.x + 10, y)
        hpdf.Page_LineTo(page, space.x + space.width - 10, y)
        hpdf.Page_Stroke(page)
    end)
end
-- }}}

-- {{{ theme_generators dispatch table
-- Maps Tier 1 theme names to their generator functions. Adding a new theme
-- is a single-line addition here plus a new generator function above.
local theme_generators = {
    resistance    = generate_resistance,
    technology    = generate_technology,
    creativity    = generate_creativity,
    isolation     = generate_isolation,
    identity      = generate_identity,
    systems       = generate_systems,
    connection    = generate_connection,
    chaos         = generate_chaos,
    transcendence = generate_transcendence,
    survival      = generate_survival,
    nature        = generate_nature,
    urban         = generate_urban,
    energy        = generate_energy,
    love          = generate_love,
    melancholy    = generate_melancholy,
    dream         = generate_dream,
    constellation = generate_constellation,
    spiral        = generate_spiral,
    circuit       = generate_circuit,
    lightning     = generate_lightning,
    crystal       = generate_crystal,
    neutral       = generate_neutral,
}
-- }}}

-- {{{ draw_theme_art_in_spaces(page, space_list, theme, page_num)
function draw_theme_art_in_spaces(pdf_page, space_list, theme, page_num)
    prepare_for_graphics(pdf_page)
    print("🎨 Generating " .. theme .. " theme art")
    local gen = theme_generators[theme] or theme_generators.neutral
    -- Pull this page's percentile-driven params for this theme, if any.
    -- Generators that don't have configured axes get an empty params table
    -- and fall back to their 0.5-percentile defaults internally.
    local params = (page_num and PAGE_PERCENTILES[page_num] and PAGE_PERCENTILES[page_num][theme]) or {}
    for _, space in ipairs(space_list) do
        gen(pdf_page, space, params)
    end
end
-- }}}

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
                hpdf.Page_SetRGBStroke(pdf_page, table.unpack(palette.accents.encrypted_red))
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
                hpdf.Page_SetRGBStroke(pdf_page, table.unpack(palette.accents.code_green))
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
                hpdf.Page_SetRGBStroke(pdf_page, table.unpack(palette.accents.fallback_lavender))
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

-- Tier 1 page art, drawn only in the regions outside the poem boxes.
-- The space_list comes from calculate_art_spaces, filtered down to the
-- regions a generator should occupy without overlapping any poem.
function draw_tier1_page_art(pdf_page, space_list, tier1_theme, page_num) -- {{{
    print(string.format("🎨 Drawing %s art in %d outside region(s)", tier1_theme, #space_list))
    draw_theme_art_in_spaces(pdf_page, space_list, tier1_theme, page_num)
end -- }}}

-- {{{ compute_poem_layout(page_poems, page_height, margins, column_width, column_gap, page_shift, line_height)
-- Single source of truth for poem-box positions on a page.
-- Returns { left = { {x,y,width,height,poem}, ... }, right = { ... } }
-- where (x, y) is the bottom-left corner (libharu Y convention) and the
-- height includes the top/bottom borders and padding lines drawn by
-- draw_boxed_poem.
--
-- Both generate_individual_poem_art (per-poem Tier 2 art positioning) and
-- calculate_poem_box_positions (for Tier 1 art space calculation) consume
-- this so the layout math has one place to maintain. If draw_boxed_poem's
-- height arithmetic ever changes, only update this helper.
function compute_poem_layout(page_poems, page_height, margins, column_width, column_gap, page_shift, line_height)
    local layout = { left = {}, right = {} }

    local function lay_out_column(poems, x_origin, dest_table)
        local y_cursor = page_height - margins.top
        for _, poem in ipairs(poems or {}) do
            -- calculate_poem_height returns content lines + 5 (borders, padding, inter-poem gap).
            -- The visible box itself is +4 lines; the +1 is the gap after, not part of the box.
            local box_lines = calculate_poem_height(poem) - 1
            local box_height = box_lines * line_height
            table.insert(dest_table, {
                x = x_origin,
                y = y_cursor - box_height,
                width = column_width,
                height = box_height,
                poem = poem,
            })
            y_cursor = y_cursor - box_height - line_height
        end
    end

    lay_out_column(page_poems.left,
        margins.left - page_shift, layout.left)
    lay_out_column(page_poems.right,
        margins.left + column_width + column_gap - page_shift, layout.right)
    return layout
end
-- }}}

-- Generate individual poem art around each poem
function generate_individual_poem_art(pdf_page, page_poems, page_width, page_height, margins, column_width, column_gap, page_shift, line_height) -- {{{
    print("🖼️ Generating individual poem art...")
    local layout = compute_poem_layout(page_poems, page_height, margins, column_width, column_gap, page_shift, line_height)

    for poem_num, box in ipairs(layout.left) do
        local poem_tier2_theme = analyze_individual_poem_for_tier2(box.poem)
        print(string.format("  📝 Left poem %d: %s (Tier 2)", poem_num, poem_tier2_theme))
        draw_tier2_column_patterns(pdf_page, box, poem_tier2_theme, 0.8)
    end

    for poem_num, box in ipairs(layout.right) do
        local poem_tier2_theme = analyze_individual_poem_for_tier2(box.poem)
        print(string.format("  📝 Right poem %d: %s (Tier 2)", poem_num, poem_tier2_theme))
        draw_tier2_column_patterns(pdf_page, box, poem_tier2_theme, 0.8)
    end
end -- }}}

-- {{{ calculate_poem_box_positions(page_poems, page_width, page_height, margins, column_width, column_gap, page_shift, line_height)
-- Returns a flat list of every poem-box rectangle on the page, for use by
-- calculate_art_spaces (which needs to know where the boxes are so it can
-- compute the regions around them).
function calculate_poem_box_positions(page_poems, page_width, page_height, margins, column_width, column_gap, page_shift, line_height)
    local layout = compute_poem_layout(page_poems, page_height, margins, column_width, column_gap, page_shift, line_height)
    local flat = {}
    for _, box in ipairs(layout.left) do table.insert(flat, box) end
    for _, box in ipairs(layout.right) do table.insert(flat, box) end
    return flat
end
-- }}}

-- mask_poem_areas removed: Issue 022 places Tier 1 art only in spaces
-- outside the poem boxes, and Issue 020 fills each box with its Tier 3
-- color, so explicit masking after the fact is no longer needed.

function generate_page_art(pdf_page, page_poems, page_width, page_height, margins, column_width, column_gap, page_shift, line_height, page_num) -- {{{
    local page_theme = analyze_page_themes(page_poems.left or {}, page_poems.right or {})
    print("🎨 Page background theme: " .. page_theme)

    -- Compute how full the page is. Sum content lines across both columns,
    -- divided by total available column-lines (Issue 023). Dense pages skip
    -- the Tier 1 layer entirely; sparse pages get the full expressive art.
    local used_lines = 0
    for _, poem in ipairs(page_poems.left or {})  do used_lines = used_lines + calculate_poem_height(poem) end
    for _, poem in ipairs(page_poems.right or {}) do used_lines = used_lines + calculate_poem_height(poem) end
    local fill_ratio = used_lines / (2 * MAX_LINES_PER_PAGE)
    local fill_pct = math.floor(fill_ratio * 100)

    local should_draw_tier1 = (page_theme ~= "neutral") and (fill_ratio < TIER1_ART_THRESHOLD)

    if should_draw_tier1 then
        print(string.format("✨ Tier 1 art enabled: page is %d%% full (threshold %d%%)", fill_pct, math.floor(TIER1_ART_THRESHOLD * 100)))
        -- Regions outside the poem boxes (Issue 022) — Tier 1 art draws only
        -- here so it never competes with text for the same pixels.
        local spaces = calculate_art_spaces(page_poems, page_width, page_height, margins, column_width, column_gap, page_shift)
        local outside_regions = {}
        for _, region in ipairs(spaces.bottom_space) do table.insert(outside_regions, region) end
        for _, region in ipairs(spaces.left_outer)   do table.insert(outside_regions, region) end
        for _, region in ipairs(spaces.right_outer)  do table.insert(outside_regions, region) end
        for _, region in ipairs(spaces.center)       do table.insert(outside_regions, region) end

        if #outside_regions > 0 then
            draw_tier1_page_art(pdf_page, outside_regions, page_theme, page_num)
        else
            print("🔍 No outside regions on this page — skipping Tier 1 art")
        end
    elseif page_theme == "neutral" then
        print("🔍 Neutral page theme - no background art generated")
    else
        print(string.format("🔍 Tier 1 art skipped: page is %d%% full (threshold %d%%)", fill_pct, math.floor(TIER1_ART_THRESHOLD * 100)))
    end

    -- Tier 2 art around individual poems still runs unconditionally
    generate_individual_poem_art(pdf_page, page_poems, page_width, page_height, margins, column_width, column_gap, page_shift, line_height)
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

    -- Hand the pdf to the art-primitives module so with_alpha and
    -- with_blend_mode can create ExtGState objects against this document
    art.init(pdf)

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

    for page_num = 1, total_pages do
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
        generate_page_art(pdf_page, page, page_width, page_height, margins, column_width, column_gap, page_shift, line_height, page_num)
        
        -- STEP 2: Draw column divider (after art, before text)
        -- Set divider color to black explicitly
        hpdf.Page_SetRGBFill(pdf_page, table.unpack(palette.text_color))
        hpdf.Page_SetRGBStroke(pdf_page, table.unpack(palette.text_color))
        
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
    local output_path = "output/compile-ai/output.pdf"
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
              local cache_count = fuzz.embedding_cache_status()
              print(string.format("🗄️  Embedding cache: %d entries on disk%s",
                    cache_count,
                    cache_count == 0 and " (cold start — full Ollama pass ahead)" or ""))
              book = {  pages = {}, poems = {},  }
              book =  load_file (book)
              book = build_book (book)
              initialize_param_axes()
              compute_page_percentiles(book)
--              book = build_color(book)
               pdf = build_pdf  (book)
               print("Poems:", #book.poems, "Pages:", #book.pages)
               print_theme_statistics()

end

main()

