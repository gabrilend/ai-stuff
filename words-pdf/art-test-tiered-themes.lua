#!/usr/bin/env lua5.2

-- art-test-tiered-themes.lua
-- Test script implementing the three-tier theme taxonomy system
-- Tier 1: Full-page background art (primary themes)
-- Tier 2: Individual poem artwork (secondary themes)
-- Tier 3: Color determination for poem backgrounds and artwork

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/words-pdf"

package.cpath = package.cpath .. ";" .. DIR .. "/libs/luahpdf/?.so"
package.cpath = package.cpath .. ";" .. DIR .. "/libs/libharu-RELEASE_2_3_0/build/src/?.so"
package.path = package.path .. ";" .. DIR .. "/libs/?.lua"

hpdf = require "hpdf"

-- Theme taxonomy from final-theme-taxonomy-3.md
-- {{{ theme_taxonomy
local theme_taxonomy = {
    -- Tier 1: Core themes for full-page background art
    tier1 = {
        resistance = {
            description = "Anti-authoritarian sentiment, revolutionary politics",
            visual_style = "Bold reds and blacks, sharp angular forms, broken chains, jagged lightning patterns",
            prevalence = 35
        },
        technology = {
            description = "Deep technical knowledge mixed with philosophical questioning",
            visual_style = "Electric blues and greens, circuit board layouts, binary cascades, network topologies",
            prevalence = 30
        },
        isolation = {
            description = "Profound loneliness and social disconnection despite digital connectivity",
            visual_style = "Muted grays and blues, sparse compositions, vast negative space, isolated cells",
            prevalence = 25
        },
        identity = {
            description = "Fluid exploration of gender, sexuality, neurodivergence, and authentic selfhood",
            visual_style = "Prismatic refractions, rainbow spectrums, morphing shapes, kaleidoscope effects",
            prevalence = 20
        },
        systems = {
            description = "Analysis of complex organizational patterns from economic to computational architectures",
            visual_style = "Blueprint blues, network diagrams, hierarchical trees, grid systems, modular components",
            prevalence = 18
        },
        connection = {
            description = "Yearning for authentic human bonds contrasted against digital isolation",
            visual_style = "Warm oranges and yellows, interconnected webs, flowing connections, bridge structures",
            prevalence = 15
        },
        chaos = {
            description = "Stream-of-consciousness fragmentation and breakdown of systematic thinking",
            visual_style = "Glitch aesthetics, RGB separation, broken grids, fragmented compositions",
            prevalence = 12
        },
        transcendence = {
            description = "Mystical and spiritual exploration combining witchcraft with cosmic consciousness",
            visual_style = "Deep purples and golds, sacred geometry, mandala forms, spiral galaxies",
            prevalence = 10
        },
        survival = {
            description = "Practical concerns about basic needs and resource management under economic precarity",
            visual_style = "Earth tones, root systems, resource flow networks, utilitarian patterns",
            prevalence = 8
        },
        creativity = {
            description = "Artistic expression and intersection of human imagination with technological tools",
            visual_style = "Artist palette variations, brush strokes, organic flows, dynamic creative energy",
            prevalence = 5
        }
    },
    
    -- Tier 2: Extended themes for individual poem artwork
    tier2 = {
        digital_resistance = "encryption, open-source, surveillance, privacy, digital-rights, technical-activism",
        neurodivergence = "autism, ADHD, masking, stimming, sensory, executive-function, hyperfocus",
        gender_fluidity = "trans, transgender, pronouns, transition, HRT, binary, non-binary, fluid, spectrum",
        digital_loneliness = "social-media, fediverse, mastodon, shadowbanned, digital-void, screen, parasocial",
        mutual_aid = "mutual-aid, community-care, helping, sharing, neighbors, collective-care, cooperation",
        economic_anxiety = "broke, money, rent, unemployment, poverty, capitalism, inequality, exploitation",
        technomysticism = "digital-magic, AI-consciousness, cyber-witchcraft, computational-mysticism",
        fragmented_consciousness = "plurality, headmates, fragmented, multiple, voices, stream-of-consciousness",
        gaming_culture = "games, gaming, mechanics, strategy, MMO, pokemon, gameboy, retro, nostalgia",
        environmental_awareness = "nature, trees, forest, earth, environment, organic, growth, ecology"
    },
    
    -- Tier 3: Detailed themes for color determination
    tier3 = {
        direct_action = {r=0.8, g=0.1, b=0.1},      -- Revolutionary red
        programming_philosophy = {r=0.0, g=0.6, b=0.8}, -- Code blue
        autistic_masking = {r=0.7, g=0.7, b=0.9},     -- Soft purple
        trans_experience = {r=0.9, g=0.5, b=0.8},     -- Trans pink
        witchcraft_practice = {r=0.4, g=0.1, b=0.6},  -- Deep purple
        cosmic_consciousness = {r=0.1, g=0.1, b=0.4}, -- Deep space blue
        food_security = {r=0.6, g=0.4, b=0.2},        -- Earth brown
        artistic_expression = {r=0.9, g=0.7, b=0.2},  -- Creative gold
        social_media_fatigue = {r=0.5, g=0.5, b=0.5}, -- Digital gray
        economic_systems = {r=0.8, g=0.3, b=0.1}      -- Economic orange
    }
}
-- }}}

-- Sample poems for testing (creative, short, 4-6 lines each)
-- {{{ sample_poems
local sample_poems = {
    {
        "digital rivers flow through midnight screens",
        "pixels dance where dreams and code convene",
        "algorithms whisper secrets in the dark",
        "while consciousness uploads spark by spark"
    },
    {
        "resistance blooms in encrypted fields",
        "where freedom's flag to no tyrant yields",
        "each keystroke carves tomorrow's path",
        "through silicon valleys of righteous wrath"
    },
    {
        "alone in crowds of glowing faces",
        "connection lost in digital spaces",
        "hearts reach out through fiber cables",
        "seeking truth beyond the fables"
    },
    {
        "identity shifts like morning mist",
        "authentic self through masks persist",
        "spectrum colors paint the soul",
        "making broken spirits whole"
    },
    {
        "systems dance in perfect order",
        "crossing every coded border",
        "networks weave their silver threads",
        "connecting hearts and thoughts and dreads"
    },
    {
        "bridges built from hope and wire",
        "lifting souls from digital mire",
        "connection sparks across the void",
        "where loneliness once was deployed"
    },
    {
        "chaos fragments break the screen",
        "static noise where peace has been",
        "glitched reality tears apart",
        "the systematic beating heart"
    },
    {
        "stardust spirals through the night",
        "cosmic wisdom burning bright",
        "sacred patterns in the sky",
        "teach us how to live and die"
    },
    {
        "roots dig deep for sustenance",
        "survival's ancient eloquence",
        "gather strength from earth below",
        "help the tender seedlings grow"
    },
    {
        "colors burst from brush to canvas",
        "creativity's wild dance",
        "imagination takes its flight",
        "painting darkness into light"
    }
}
-- }}}

-- Tier 1: Full-page background art generators
-- {{{ generate_tier1_background
local function generate_tier1_background(pdf_page, theme_name, page_width, page_height)
    if theme_name == "resistance" then
        -- Bold reds and blacks, sharp angular forms
        hpdf.Page_SetRGBStroke(pdf_page, 0.8, 0.1, 0.1)
        hpdf.Page_SetLineWidth(pdf_page, 1.0)
        
        for i = 1, 25 do
            local x1 = math.random() * page_width
            local y1 = math.random() * page_height
            local x2 = x1 + (math.random() - 0.5) * 100
            local y2 = y1 + (math.random() - 0.5) * 100
            
            -- Sharp angular lines
            hpdf.Page_MoveTo(pdf_page, x1, y1)
            hpdf.Page_LineTo(pdf_page, x2, y2)
            hpdf.Page_Stroke(pdf_page)
            
            -- Broken chain elements
            if math.random() > 0.7 then
                hpdf.Page_SetRGBStroke(pdf_page, 0.0, 0.0, 0.0)
                hpdf.Page_Rectangle(pdf_page, x1-3, y1-3, 6, 6)
                hpdf.Page_Stroke(pdf_page)
                hpdf.Page_SetRGBStroke(pdf_page, 0.8, 0.1, 0.1)
            end
        end
        
    elseif theme_name == "technology" then
        -- Electric blues and greens, circuit board layouts
        local colors = {{0.0, 0.4, 0.8}, {0.0, 0.8, 0.4}, {0.4, 0.8, 1.0}}
        
        for i = 1, 30 do
            local color = colors[math.random(#colors)]
            hpdf.Page_SetRGBStroke(pdf_page, color[1], color[2], color[3])
            hpdf.Page_SetLineWidth(pdf_page, 0.5)
            
            -- Circuit board patterns
            local x = math.random() * page_width
            local y = math.random() * page_height
            local width = 20 + math.random(60)
            local height = 20 + math.random(60)
            
            -- Grid pattern
            for gx = 0, width, 10 do
                hpdf.Page_MoveTo(pdf_page, x + gx, y)
                hpdf.Page_LineTo(pdf_page, x + gx, y + height)
                hpdf.Page_Stroke(pdf_page)
            end
            for gy = 0, height, 10 do
                hpdf.Page_MoveTo(pdf_page, x, y + gy)
                hpdf.Page_LineTo(pdf_page, x + width, y + gy)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme_name == "isolation" then
        -- Muted grays and blues, sparse compositions, vast negative space
        hpdf.Page_SetRGBStroke(pdf_page, 0.4, 0.4, 0.6)
        hpdf.Page_SetLineWidth(pdf_page, 0.3)
        
        -- Sparse, isolated elements
        for i = 1, 16 do
            local x = math.random() * page_width
            local y = math.random() * page_height
            local size = 10 + math.random(20)
            
            -- Isolated cells
            hpdf.Page_Rectangle(pdf_page, x, y, size, size)
            hpdf.Page_Stroke(pdf_page)
            
            -- Single connecting line to emphasize isolation
            if math.random() > 0.5 then
                local x2 = x + (math.random() - 0.5) * 200
                local y2 = y + (math.random() - 0.5) * 200
                hpdf.Page_MoveTo(pdf_page, x + size/2, y + size/2)
                hpdf.Page_LineTo(pdf_page, x2, y2)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme_name == "identity" then
        -- Prismatic refractions, rainbow spectrums
        local rainbow_colors = {
            {1.0, 0.0, 0.0}, {1.0, 0.5, 0.0}, {1.0, 1.0, 0.0},
            {0.0, 1.0, 0.0}, {0.0, 0.0, 1.0}, {0.4, 0.0, 0.8}, {0.8, 0.0, 0.8}
        }
        
        for i = 1, 20 do
            local center_x = math.random() * page_width
            local center_y = math.random() * page_height
            local radius = 30 + math.random(50)
            
            -- Kaleidoscope effects
            for j = 1, 12 do
                local angle = (j / 12) * 2 * math.pi
                local color = rainbow_colors[((j-1) % #rainbow_colors) + 1]
                hpdf.Page_SetRGBStroke(pdf_page, color[1], color[2], color[3])
                hpdf.Page_SetLineWidth(pdf_page, 2.0)
                
                local x1 = center_x + math.cos(angle) * radius * 0.5
                local y1 = center_y + math.sin(angle) * radius * 0.5
                local x2 = center_x + math.cos(angle) * radius
                local y2 = center_y + math.sin(angle) * radius
                
                hpdf.Page_MoveTo(pdf_page, x1, y1)
                hpdf.Page_LineTo(pdf_page, x2, y2)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme_name == "systems" then
        -- Blueprint blues, network diagrams, hierarchical trees
        hpdf.Page_SetRGBStroke(pdf_page, 0.2, 0.4, 0.8)
        hpdf.Page_SetLineWidth(pdf_page, 0.5)
        
        -- Network topology
        local nodes = {}
        for i = 1, 30 do
            table.insert(nodes, {
                x = math.random() * page_width,
                y = math.random() * page_height
            })
        end
        
        -- Connect nodes
        for i, node1 in ipairs(nodes) do
            for j, node2 in ipairs(nodes) do
                if i < j then
                    local distance = math.sqrt((node2.x - node1.x)^2 + (node2.y - node1.y)^2)
                    if distance < 150 and math.random() > 0.4 then
                        hpdf.Page_MoveTo(pdf_page, node1.x, node1.y)
                        hpdf.Page_LineTo(pdf_page, node2.x, node2.y)
                        hpdf.Page_Stroke(pdf_page)
                    end
                end
            end
        end
        
        -- Draw nodes
        hpdf.Page_SetLineWidth(pdf_page, 2.0)
        for _, node in ipairs(nodes) do
            hpdf.Page_Rectangle(pdf_page, node.x-3, node.y-3, 6, 6)
            hpdf.Page_Stroke(pdf_page)
        end
        
    elseif theme_name == "connection" then
        -- Warm oranges and yellows, interconnected webs, flowing connections
        local warm_colors = {{1.0, 0.6, 0.0}, {1.0, 0.8, 0.0}, {1.0, 0.4, 0.2}}
        
        for i = 1, 40 do
            local color = warm_colors[math.random(#warm_colors)]
            hpdf.Page_SetRGBStroke(pdf_page, color[1], color[2], color[3])
            hpdf.Page_SetLineWidth(pdf_page, 0.8)
            
            -- Flowing connections
            local x1 = math.random() * page_width
            local y1 = math.random() * page_height
            local x2 = x1 + (math.random() - 0.5) * 150
            local y2 = y1 + (math.random() - 0.5) * 150
            
            -- Curved connections
            hpdf.Page_MoveTo(pdf_page, x1, y1)
            for t = 0, 1, 0.1 do
                local curve_x = x1 + t * (x2 - x1) + math.sin(t * math.pi * 2) * 20
                local curve_y = y1 + t * (y2 - y1) + math.cos(t * math.pi * 2) * 20
                hpdf.Page_LineTo(pdf_page, curve_x, curve_y)
            end
            hpdf.Page_Stroke(pdf_page)
        end
        
    elseif theme_name == "chaos" then
        -- Glitch aesthetics, RGB separation, broken grids
        local glitch_colors = {{1.0, 0.0, 0.0}, {0.0, 1.0, 0.0}, {0.0, 0.0, 1.0}}
        
        for i = 1, 50 do
            local color = glitch_colors[math.random(#glitch_colors)]
            hpdf.Page_SetRGBStroke(pdf_page, color[1], color[2], color[3])
            hpdf.Page_SetLineWidth(pdf_page, 1.0 + math.random() * 2)
            
            -- Fragmented compositions
            local x = math.random() * page_width
            local y = math.random() * page_height
            local size = 5 + math.random(30)
            
            -- Broken rectangles
            if math.random() > 0.5 then
                hpdf.Page_MoveTo(pdf_page, x, y)
                hpdf.Page_LineTo(pdf_page, x + size, y)
                hpdf.Page_LineTo(pdf_page, x + size + math.random(10) - 5, y + size + math.random(10) - 5)
                hpdf.Page_LineTo(pdf_page, x + math.random(10) - 5, y + size)
                hpdf.Page_LineTo(pdf_page, x, y)
                hpdf.Page_Stroke(pdf_page)
            else
                -- Glitch lines
                hpdf.Page_MoveTo(pdf_page, x, y)
                hpdf.Page_LineTo(pdf_page, x + size + math.random(20) - 10, y + math.random(20) - 10)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme_name == "transcendence" then
        -- Deep purples and golds, sacred geometry, mandala forms
        local transcendent_colors = {{0.4, 0.1, 0.6}, {0.8, 0.6, 0.0}, {0.6, 0.2, 0.8}}
        
        for i = 1, 12 do
            local center_x = math.random() * page_width
            local center_y = math.random() * page_height
            local radius = 20 + math.random(40)
            
            -- Sacred geometry patterns
            for ring = 1, 3 do
                local color = transcendent_colors[ring]
                hpdf.Page_SetRGBStroke(pdf_page, color[1], color[2], color[3])
                hpdf.Page_SetLineWidth(pdf_page, 0.5)
                
                local ring_radius = radius * ring / 3
                local points = 6 + ring * 2
                
                for p = 1, points do
                    local angle1 = (p / points) * 2 * math.pi
                    local angle2 = ((p + 1) / points) * 2 * math.pi
                    
                    local x1 = center_x + math.cos(angle1) * ring_radius
                    local y1 = center_y + math.sin(angle1) * ring_radius
                    local x2 = center_x + math.cos(angle2) * ring_radius
                    local y2 = center_y + math.sin(angle2) * ring_radius
                    
                    hpdf.Page_MoveTo(pdf_page, x1, y1)
                    hpdf.Page_LineTo(pdf_page, x2, y2)
                    hpdf.Page_Stroke(pdf_page)
                end
            end
        end
        
    elseif theme_name == "survival" then
        -- Earth tones, root systems, resource flow networks
        local earth_colors = {{0.6, 0.4, 0.2}, {0.4, 0.6, 0.2}, {0.8, 0.6, 0.4}}
        
        for i = 1, 40 do
            local color = earth_colors[math.random(#earth_colors)]
            hpdf.Page_SetRGBStroke(pdf_page, color[1], color[2], color[3])
            hpdf.Page_SetLineWidth(pdf_page, 1.0)
            
            -- Root system patterns distributed across full page
            local root_x = math.random() * page_width
            local root_y = math.random() * page_height
            
            -- Main root
            hpdf.Page_MoveTo(pdf_page, root_x, root_y)
            hpdf.Page_LineTo(pdf_page, root_x, root_y - 50 - math.random(100))
            hpdf.Page_Stroke(pdf_page)
            
            -- Branch roots
            for branch = 1, 3 + math.random(4) do
                local branch_angle = (math.random() - 0.5) * math.pi * 0.8
                local branch_length = 20 + math.random(60)
                local end_x = root_x + math.sin(branch_angle) * branch_length
                local end_y = root_y - math.cos(branch_angle) * branch_length
                
                hpdf.Page_MoveTo(pdf_page, root_x, root_y)
                hpdf.Page_LineTo(pdf_page, end_x, end_y)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme_name == "creativity" then
        -- Artist palette variations, brush strokes, organic flows
        local creative_colors = {
            {1.0, 0.2, 0.4}, {0.2, 0.8, 0.6}, {0.8, 0.6, 0.2},
            {0.6, 0.2, 0.8}, {0.2, 0.6, 1.0}, {0.8, 0.8, 0.2}
        }
        
        for i = 1, 35 do
            local color = creative_colors[math.random(#creative_colors)]
            hpdf.Page_SetRGBStroke(pdf_page, color[1], color[2], color[3])
            hpdf.Page_SetLineWidth(pdf_page, 1.0 + math.random() * 3)
            
            -- Brush stroke patterns
            local x = math.random() * page_width
            local y = math.random() * page_height
            local length = 30 + math.random(80)
            local angle = math.random() * math.pi * 2
            
            -- Organic flowing strokes
            hpdf.Page_MoveTo(pdf_page, x, y)
            for t = 0, 1, 0.1 do
                local stroke_x = x + t * math.cos(angle) * length + math.sin(t * math.pi * 4) * 10
                local stroke_y = y + t * math.sin(angle) * length + math.cos(t * math.pi * 4) * 10
                hpdf.Page_LineTo(pdf_page, stroke_x, stroke_y)
            end
            hpdf.Page_Stroke(pdf_page)
        end
    end
end
-- }}}

-- Tier 2: Individual poem artwork generators
-- {{{ generate_tier2_poem_art
local function generate_tier2_poem_art(pdf_page, theme_name, poem_x, poem_y, poem_width, poem_height)
    local margin = 10
    local art_spaces = {
        -- Left side of poem
        {x = poem_x - margin - 30, y = poem_y, width = 25, height = poem_height},
        -- Right side of poem
        {x = poem_x + poem_width + margin, y = poem_y, width = 25, height = poem_height},
        -- Above poem
        {x = poem_x, y = poem_y + poem_height + margin, width = poem_width, height = 20},
        -- Below poem
        {x = poem_x, y = poem_y - margin - 20, width = poem_width, height = 15}
    }
    
    if theme_name == "digital_resistance" then
        -- Encryption patterns, lock symbols
        hpdf.Page_SetRGBStroke(pdf_page, 0.0, 0.8, 0.4)
        hpdf.Page_SetLineWidth(pdf_page, 0.5)
        
        for _, space in ipairs(art_spaces) do
            for i = 1, 8 do
                local x = space.x + math.random() * space.width
                local y = space.y + math.random() * space.height
                
                -- Lock symbols
                hpdf.Page_Rectangle(pdf_page, x, y, 4, 3)
                hpdf.Page_MoveTo(pdf_page, x+1, y+3)
                hpdf.Page_LineTo(pdf_page, x+1, y+5)
                hpdf.Page_LineTo(pdf_page, x+3, y+5)
                hpdf.Page_LineTo(pdf_page, x+3, y+3)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme_name == "neurodivergence" then
        -- Complex geometric patterns representing different neural pathways
        hpdf.Page_SetRGBStroke(pdf_page, 0.7, 0.3, 0.9)
        hpdf.Page_SetLineWidth(pdf_page, 0.3)
        
        for _, space in ipairs(art_spaces) do
            -- Neural pathway patterns
            local center_x = space.x + space.width / 2
            local center_y = space.y + space.height / 2
            
            for pathway = 1, 6 do
                local angle = (pathway / 6) * 2 * math.pi
                local length = 8 + math.random(15)
                
                hpdf.Page_MoveTo(pdf_page, center_x, center_y)
                local end_x = center_x + math.cos(angle) * length
                local end_y = center_y + math.sin(angle) * length
                
                -- Branching pathways
                for segment = 1, 3 do
                    local seg_x = center_x + (segment/3) * math.cos(angle) * length
                    local seg_y = center_y + (segment/3) * math.sin(angle) * length
                    local branch_angle = angle + (math.random() - 0.5) * 0.8
                    local branch_length = 3 + math.random(8)
                    
                    hpdf.Page_MoveTo(pdf_page, seg_x, seg_y)
                    hpdf.Page_LineTo(pdf_page, seg_x + math.cos(branch_angle) * branch_length,
                                    seg_y + math.sin(branch_angle) * branch_length)
                end
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme_name == "gender_fluidity" then
        -- Flowing, morphing shapes with gradient-like effects
        local fluid_colors = {{0.9, 0.5, 0.8}, {0.5, 0.8, 0.9}, {0.8, 0.9, 0.5}}
        
        for _, space in ipairs(art_spaces) do
            for flow = 1, 5 do
                local color = fluid_colors[math.random(#fluid_colors)]
                hpdf.Page_SetRGBStroke(pdf_page, color[1], color[2], color[3])
                hpdf.Page_SetLineWidth(pdf_page, 0.8)
                
                -- Flowing wave patterns
                local start_x = space.x
                local start_y = space.y + math.random() * space.height
                
                hpdf.Page_MoveTo(pdf_page, start_x, start_y)
                for x = start_x, start_x + space.width, 2 do
                    local wave_y = start_y + math.sin((x - start_x) * 0.1) * 8
                    hpdf.Page_LineTo(pdf_page, x, wave_y)
                end
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme_name == "digital_loneliness" then
        -- Network nodes with broken connections
        hpdf.Page_SetRGBStroke(pdf_page, 0.4, 0.4, 0.6)
        hpdf.Page_SetLineWidth(pdf_page, 0.4)
        
        for _, space in ipairs(art_spaces) do
            -- Isolated nodes
            for i = 1, 4 do
                local x = space.x + math.random() * space.width
                local y = space.y + math.random() * space.height
                
                -- Node
                hpdf.Page_Rectangle(pdf_page, x-1, y-1, 2, 2)
                hpdf.Page_Stroke(pdf_page)
                
                -- Broken connection (dashed line)
                if math.random() > 0.5 then
                    local target_x = x + (math.random() - 0.5) * 20
                    local target_y = y + (math.random() - 0.5) * 20
                    
                    -- Dashed line effect
                    for dash = 0, 1, 0.3 do
                        local dash_x1 = x + dash * (target_x - x)
                        local dash_y1 = y + dash * (target_y - y)
                        local dash_x2 = x + (dash + 0.15) * (target_x - x)
                        local dash_y2 = y + (dash + 0.15) * (target_y - y)
                        
                        hpdf.Page_MoveTo(pdf_page, dash_x1, dash_y1)
                        hpdf.Page_LineTo(pdf_page, dash_x2, dash_y2)
                        hpdf.Page_Stroke(pdf_page)
                    end
                end
            end
        end
        
    elseif theme_name == "mutual_aid" then
        -- Interconnected helping hands and community networks
        hpdf.Page_SetRGBStroke(pdf_page, 0.2, 0.8, 0.4)
        hpdf.Page_SetLineWidth(pdf_page, 0.6)
        
        for _, space in ipairs(art_spaces) do
            -- Network of helping connections
            local nodes = {}
            for i = 1, 6 do
                table.insert(nodes, {
                    x = space.x + math.random() * space.width,
                    y = space.y + math.random() * space.height
                })
            end
            
            -- Connect nodes with caring links
            for i, node1 in ipairs(nodes) do
                for j, node2 in ipairs(nodes) do
                    if i < j and math.random() > 0.4 then
                        hpdf.Page_MoveTo(pdf_page, node1.x, node1.y)
                        hpdf.Page_LineTo(pdf_page, node2.x, node2.y)
                        hpdf.Page_Stroke(pdf_page)
                    end
                end
            end
            
            -- Draw nodes as small circles (helping hands)
            for _, node in ipairs(nodes) do
                hpdf.Page_Circle(pdf_page, node.x, node.y, 2)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme_name == "economic_anxiety" then
        -- Jagged stress lines and unstable patterns
        hpdf.Page_SetRGBStroke(pdf_page, 0.8, 0.3, 0.1)
        hpdf.Page_SetLineWidth(pdf_page, 0.4)
        
        for _, space in ipairs(art_spaces) do
            for i = 1, 8 do
                local x = space.x + math.random() * space.width
                local y = space.y + math.random() * space.height
                
                -- Jagged stress lines
                hpdf.Page_MoveTo(pdf_page, x, y)
                for segment = 1, 4 do
                    local next_x = x + (math.random() - 0.5) * 15
                    local next_y = y + (math.random() - 0.5) * 8
                    hpdf.Page_LineTo(pdf_page, next_x, next_y)
                    x, y = next_x, next_y
                end
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme_name == "technomysticism" then
        -- Mystical circuit patterns and digital magic symbols
        hpdf.Page_SetRGBStroke(pdf_page, 0.6, 0.1, 0.8)
        hpdf.Page_SetLineWidth(pdf_page, 0.3)
        
        for _, space in ipairs(art_spaces) do
            for i = 1, 5 do
                local center_x = space.x + math.random() * space.width
                local center_y = space.y + math.random() * space.height
                local radius = 3 + math.random(8)
                
                -- Mystical circuit mandala
                for spoke = 1, 8 do
                    local angle = (spoke / 8) * 2 * math.pi
                    local x1 = center_x + math.cos(angle) * radius * 0.3
                    local y1 = center_y + math.sin(angle) * radius * 0.3
                    local x2 = center_x + math.cos(angle) * radius
                    local y2 = center_y + math.sin(angle) * radius
                    
                    hpdf.Page_MoveTo(pdf_page, x1, y1)
                    hpdf.Page_LineTo(pdf_page, x2, y2)
                    hpdf.Page_Stroke(pdf_page)
                    
                    -- Digital nodes
                    hpdf.Page_Rectangle(pdf_page, x2-1, y2-1, 2, 2)
                    hpdf.Page_Stroke(pdf_page)
                end
            end
        end
        
    elseif theme_name == "fragmented_consciousness" then
        -- Scattered, broken patterns representing plurality
        local fragment_colors = {{0.8, 0.2, 0.6}, {0.2, 0.6, 0.8}, {0.6, 0.8, 0.2}}
        
        for _, space in ipairs(art_spaces) do
            for fragment = 1, 6 do
                local color = fragment_colors[math.random(#fragment_colors)]
                hpdf.Page_SetRGBStroke(pdf_page, color[1], color[2], color[3])
                hpdf.Page_SetLineWidth(pdf_page, 0.5)
                
                -- Fragmented shapes
                local x = space.x + math.random() * space.width
                local y = space.y + math.random() * space.height
                local size = 4 + math.random(8)
                
                -- Broken circle/fragments
                for arc = 1, 3 do
                    local start_angle = math.random() * math.pi * 2
                    local arc_length = math.pi * 0.3 + math.random() * math.pi * 0.4
                    
                    -- Approximate arc with line segments
                    for step = 0, 5 do
                        local angle1 = start_angle + (step / 5) * arc_length
                        local angle2 = start_angle + ((step + 1) / 5) * arc_length
                        local x1 = x + math.cos(angle1) * size
                        local y1 = y + math.sin(angle1) * size
                        local x2 = x + math.cos(angle2) * size
                        local y2 = y + math.sin(angle2) * size
                        
                        if step < 5 then
                            hpdf.Page_MoveTo(pdf_page, x1, y1)
                            hpdf.Page_LineTo(pdf_page, x2, y2)
                            hpdf.Page_Stroke(pdf_page)
                        end
                    end
                end
            end
        end
        
    elseif theme_name == "gaming_culture" then
        -- Pixelated patterns and game-like geometric shapes
        hpdf.Page_SetRGBStroke(pdf_page, 0.1, 0.8, 0.2)
        hpdf.Page_SetLineWidth(pdf_page, 0.6)
        
        for _, space in ipairs(art_spaces) do
            for i = 1, 8 do
                local x = space.x + math.random() * (space.width - 12)
                local y = space.y + math.random() * (space.height - 12)
                
                -- Pixelated/8-bit style blocks
                local pattern = math.random(3)
                if pattern == 1 then
                    -- Power-up cube
                    hpdf.Page_Rectangle(pdf_page, x, y, 6, 6)
                    hpdf.Page_Rectangle(pdf_page, x+2, y+2, 2, 2)
                    hpdf.Page_Stroke(pdf_page)
                elseif pattern == 2 then
                    -- Plus/cross shape
                    hpdf.Page_Rectangle(pdf_page, x+2, y, 2, 6)
                    hpdf.Page_Rectangle(pdf_page, x, y+2, 6, 2)
                    hpdf.Page_Stroke(pdf_page)
                else
                    -- Diamond/gem shape
                    hpdf.Page_MoveTo(pdf_page, x+3, y)
                    hpdf.Page_LineTo(pdf_page, x+6, y+3)
                    hpdf.Page_LineTo(pdf_page, x+3, y+6)
                    hpdf.Page_LineTo(pdf_page, x, y+3)
                    hpdf.Page_LineTo(pdf_page, x+3, y)
                    hpdf.Page_Stroke(pdf_page)
                end
            end
        end
        
    elseif theme_name == "environmental_awareness" then
        -- Organic growth patterns and leaf motifs
        hpdf.Page_SetRGBStroke(pdf_page, 0.2, 0.7, 0.3)
        hpdf.Page_SetLineWidth(pdf_page, 0.4)
        
        for _, space in ipairs(art_spaces) do
            for i = 1, 6 do
                local stem_x = space.x + math.random() * space.width
                local stem_y = space.y + math.random() * space.height
                local growth_angle = math.random() * math.pi * 2
                local stem_length = 8 + math.random(15)
                
                -- Stem
                local end_x = stem_x + math.cos(growth_angle) * stem_length
                local end_y = stem_y + math.sin(growth_angle) * stem_length
                hpdf.Page_MoveTo(pdf_page, stem_x, stem_y)
                hpdf.Page_LineTo(pdf_page, end_x, end_y)
                hpdf.Page_Stroke(pdf_page)
                
                -- Leaves
                for leaf = 1, 2 do
                    local leaf_angle = growth_angle + (leaf == 1 and 0.5 or -0.5)
                    local leaf_length = 4 + math.random(6)
                    local leaf_x = end_x + math.cos(leaf_angle) * leaf_length
                    local leaf_y = end_y + math.sin(leaf_angle) * leaf_length
                    
                    -- Simple leaf shape
                    hpdf.Page_MoveTo(pdf_page, end_x, end_y)
                    hpdf.Page_LineTo(pdf_page, leaf_x, leaf_y)
                    hpdf.Page_LineTo(pdf_page, end_x + math.cos(leaf_angle + 0.3) * leaf_length * 0.7, 
                                    end_y + math.sin(leaf_angle + 0.3) * leaf_length * 0.7)
                    hpdf.Page_Stroke(pdf_page)
                end
            end
        end
        
    else
        -- Default minimal decoration
        hpdf.Page_SetRGBStroke(pdf_page, 0.6, 0.6, 0.6)
        hpdf.Page_SetLineWidth(pdf_page, 0.2)
        
        for _, space in ipairs(art_spaces) do
            -- Simple decorative elements
            for i = 1, 3 do
                local x = space.x + math.random() * space.width
                local y = space.y + math.random() * space.height
                local size = 2 + math.random(4)
                
                hpdf.Page_Rectangle(pdf_page, x, y, size, 1)
                hpdf.Page_Stroke(pdf_page)
            end
        end
    end
end
-- }}}

-- Tier 3: Color generation for poem backgrounds
-- {{{ generate_tier3_color
local function generate_tier3_color(theme_name)
    local color = theme_taxonomy.tier3[theme_name]
    if color then
        -- Add slight variation to base color
        local variation = 0.1
        return {
            math.max(0.8, math.min(1.0, color.r + (math.random() - 0.5) * variation)),
            math.max(0.8, math.min(1.0, color.g + (math.random() - 0.5) * variation)),
            math.max(0.8, math.min(1.0, color.b + (math.random() - 0.5) * variation))
        }
    else
        -- Default light color
        return {0.95, 0.95, 0.95}
    end
end
-- }}}

-- Draw a boxed poem with proper spacing
-- {{{ draw_boxed_poem
local function draw_boxed_poem(pdf_page, font, poem, start_x, start_y, max_width, line_height, background_color)
    if #poem == 0 then return start_y end
    
    -- Calculate poem dimensions
    local poem_width = 0
    for _, line in ipairs(poem) do
        if #line > poem_width then poem_width = #line end
    end
    poem_width = poem_width + 4 -- Add padding
    
    local box_width = math.min(poem_width * 4, max_width - 2) -- Approximate character width
    local box_height = (#poem + 4) * line_height -- poem + borders + padding
    
    -- Center the box
    local actual_x = start_x + (max_width - box_width) / 2
    
    -- Draw background
    if background_color then
        hpdf.Page_SetRGBFill(pdf_page, background_color[1], background_color[2], background_color[3])
        hpdf.Page_Rectangle(pdf_page, actual_x, start_y - box_height, box_width, box_height)
        hpdf.Page_Fill(pdf_page)
    end
    
    -- Set text color to black
    hpdf.Page_SetRGBFill(pdf_page, 0.0, 0.0, 0.0)
    
    local current_y = start_y
    
    -- Draw top border
    hpdf.Page_BeginText(pdf_page)
    hpdf.Page_MoveTextPos(pdf_page, actual_x, current_y)
    hpdf.Page_ShowText(pdf_page, "." .. string.rep("-", math.floor(box_width/4) - 2) .. ".")
    hpdf.Page_EndText(pdf_page)
    current_y = current_y - line_height
    
    -- Draw poem content with side borders
    for _, line in ipairs(poem) do
        hpdf.Page_BeginText(pdf_page)
        hpdf.Page_MoveTextPos(pdf_page, actual_x, current_y)
        local padded_line = "| " .. line .. string.rep(" ", math.max(0, math.floor(box_width/4) - #line - 4)) .. " |"
        hpdf.Page_ShowText(pdf_page, padded_line)
        hpdf.Page_EndText(pdf_page)
        current_y = current_y - line_height
    end
    
    -- Draw bottom border
    hpdf.Page_BeginText(pdf_page)
    hpdf.Page_MoveTextPos(pdf_page, actual_x, current_y - line_height)
    hpdf.Page_ShowText(pdf_page, "`" .. string.rep("-", math.floor(box_width/4) - 2) .. "'")
    hpdf.Page_EndText(pdf_page)
    
    return current_y - line_height * 2
end
-- }}}

-- Create the test PDF
-- {{{ create_tiered_test_pdf
local function create_tiered_test_pdf()
    local pdf = hpdf.New()
    hpdf.SetCompressionMode(pdf, 15) -- All compression
    
    local font = hpdf.GetFont(pdf, "Courier", "StandardEncoding")
    local title_font = hpdf.GetFont(pdf, "Helvetica-Bold", "StandardEncoding")
    
    -- Page dimensions
    local page_width = 595  -- A4 width
    local page_height = 842 -- A4 height
    local margin = 50
    local column_width = (page_width - 3 * margin) / 2
    local line_height = 6
    
    -- Generate test pages for each Tier 1 theme
    local tier1_themes = {"resistance", "technology", "isolation", "identity", "systems", 
                         "connection", "chaos", "transcendence", "survival", "creativity"}
    
    for i, tier1_theme in ipairs(tier1_themes) do
        local pdf_page = hpdf.AddPage(pdf)
        hpdf.Page_SetSize(pdf_page, hpdf.PAGE_SIZE_A4, hpdf.PAGE_PORTRAIT)
        hpdf.Page_SetFontAndSize(pdf_page, font, 5)
        
        -- STEP 1: Generate Tier 1 background art
        generate_tier1_background(pdf_page, tier1_theme, page_width, page_height)
        
        -- Draw title
        hpdf.Page_SetFontAndSize(pdf_page, title_font, 18)
        hpdf.Page_SetRGBFill(pdf_page, 0.0, 0.0, 0.0)
        hpdf.Page_BeginText(pdf_page)
        hpdf.Page_MoveTextPos(pdf_page, margin, page_height - margin - 25)
        hpdf.Page_ShowText(pdf_page, "TIER 1: " .. tier1_theme:upper() .. " (Background)")
        hpdf.Page_EndText(pdf_page)
        
        -- Draw description
        hpdf.Page_SetFontAndSize(pdf_page, font, 10)
        hpdf.Page_BeginText(pdf_page)
        hpdf.Page_MoveTextPos(pdf_page, margin, page_height - margin - 45)
        local description = theme_taxonomy.tier1[tier1_theme].description
        hpdf.Page_ShowText(pdf_page, description)
        hpdf.Page_EndText(pdf_page)
        
        -- Draw visual style info
        hpdf.Page_SetFontAndSize(pdf_page, font, 8)
        hpdf.Page_BeginText(pdf_page)
        hpdf.Page_MoveTextPos(pdf_page, margin, page_height - margin - 65)
        local visual_style = theme_taxonomy.tier1[tier1_theme].visual_style
        hpdf.Page_ShowText(pdf_page, "Style: " .. visual_style)
        hpdf.Page_EndText(pdf_page)
        
        -- STEP 2: Add sample poems with Tier 2 and Tier 3 themes
        hpdf.Page_SetFontAndSize(pdf_page, font, 5)
        
        -- Left column poem
        local left_poem = sample_poems[i] or sample_poems[1]
        local tier2_theme = "digital_resistance"  -- Example Tier 2 theme
        local tier3_theme = "direct_action"      -- Example Tier 3 theme for color
        
        local poem_bg_color = generate_tier3_color(tier3_theme)
        local left_y = page_height - margin - 100
        
        -- Draw poem with background color
        left_y = draw_boxed_poem(pdf_page, font, left_poem, margin, left_y, column_width, line_height, poem_bg_color)
        
        -- Generate Tier 2 art around the poem
        local poem_x = margin + (column_width - 200) / 2
        local poem_height = (#left_poem + 4) * line_height
        generate_tier2_poem_art(pdf_page, tier2_theme, poem_x, left_y, 200, poem_height)
        
        -- Right column poem (if we have another sample)
        if sample_poems[i + 5] then
            local right_poem = sample_poems[i + 5]
            local right_tier2 = "neurodivergence"     -- Different Tier 2 theme
            local right_tier3 = "autistic_masking"    -- Different Tier 3 theme
            
            local right_bg_color = generate_tier3_color(right_tier3)
            local right_y = page_height - margin - 100
            
            right_y = draw_boxed_poem(pdf_page, font, right_poem, margin + column_width + margin, 
                                    right_y, column_width, line_height, right_bg_color)
            
            local right_poem_x = margin + column_width + margin + (column_width - 200) / 2
            generate_tier2_poem_art(pdf_page, right_tier2, right_poem_x, right_y, 200, poem_height)
        end
        
        -- Add legend
        hpdf.Page_SetFontAndSize(pdf_page, font, 8)
        hpdf.Page_SetRGBFill(pdf_page, 0.2, 0.2, 0.2)
        hpdf.Page_BeginText(pdf_page)
        hpdf.Page_MoveTextPos(pdf_page, margin, margin + 60)
        hpdf.Page_ShowText(pdf_page, "TIER 2 (Poem Art): " .. tier2_theme)
        hpdf.Page_EndText(pdf_page)
        
        hpdf.Page_BeginText(pdf_page)
        hpdf.Page_MoveTextPos(pdf_page, margin, margin + 45)
        hpdf.Page_ShowText(pdf_page, "TIER 3 (Colors): " .. tier3_theme)
        hpdf.Page_EndText(pdf_page)
    end
    
    return pdf
end
-- }}}

-- {{{ local function generate_tier2_showcase
local function generate_tier2_showcase(pdf, font, title_font)
    -- Create showcase pages for all Tier 2 poem graphics
    local tier2_themes = {
        "digital_resistance", "neurodivergence", "gender_fluidity", 
        "digital_loneliness", "mutual_aid", "economic_anxiety",
        "technomysticism", "fragmented_consciousness", "gaming_culture", "environmental_awareness"
    }
    
    local page_width = 595  -- A4 width
    local page_height = 842 -- A4 height
    local margin = 50
    
    -- Create one showcase page with multiple Tier 2 examples
    local pdf_page = hpdf.AddPage(pdf)
    hpdf.Page_SetSize(pdf_page, hpdf.PAGE_SIZE_A4, hpdf.PAGE_PORTRAIT)
    
    -- Draw title
    hpdf.Page_SetFontAndSize(pdf_page, title_font, 18)
    hpdf.Page_SetRGBFill(pdf_page, 0.0, 0.0, 0.0)
    hpdf.Page_BeginText(pdf_page)
    hpdf.Page_MoveTextPos(pdf_page, margin, page_height - margin - 25)
    hpdf.Page_ShowText(pdf_page, "TIER 2: POEM GRAPHICS SHOWCASE")
    hpdf.Page_EndText(pdf_page)
    
    -- Description
    hpdf.Page_SetFontAndSize(pdf_page, font, 10)
    hpdf.Page_BeginText(pdf_page)
    hpdf.Page_MoveTextPos(pdf_page, margin, page_height - margin - 45)
    hpdf.Page_ShowText(pdf_page, "Individual artwork applied around each poem - 10 different themes")
    hpdf.Page_EndText(pdf_page)
    
    -- Display Tier 2 graphics in a grid
    local cols = 2
    local rows = 5
    local cell_width = (page_width - 3 * margin) / cols
    local cell_height = (page_height - margin - 120) / rows
    
    for i, theme in ipairs(tier2_themes) do
        local col = ((i - 1) % cols) + 1
        local row = math.floor((i - 1) / cols) + 1
        
        local x = margin + (col - 1) * cell_width
        local y = page_height - margin - 80 - (row * cell_height)
        
        -- Theme label
        hpdf.Page_SetFontAndSize(pdf_page, font, 8)
        hpdf.Page_SetRGBFill(pdf_page, 0.0, 0.0, 0.0)
        hpdf.Page_BeginText(pdf_page)
        hpdf.Page_MoveTextPos(pdf_page, x, y + cell_height - 15)
        hpdf.Page_ShowText(pdf_page, theme:upper())
        hpdf.Page_EndText(pdf_page)
        
        -- Create sample poem area for this theme
        local poem_x = x + 20
        local poem_y = y + 20
        local poem_width = cell_width - 60
        local poem_height = cell_height - 50
        
        -- Draw poem text area outline
        hpdf.Page_SetRGBStroke(pdf_page, 0.8, 0.8, 0.8)
        hpdf.Page_SetLineWidth(pdf_page, 0.5)
        hpdf.Page_Rectangle(pdf_page, poem_x, poem_y, poem_width, poem_height)
        hpdf.Page_Stroke(pdf_page)
        
        -- Generate the Tier 2 artwork around this poem area
        generate_tier2_poem_art(pdf_page, theme, poem_x, poem_y, poem_width, poem_height)
        
        -- Add sample text
        hpdf.Page_SetFontAndSize(pdf_page, font, 6)
        hpdf.Page_SetRGBFill(pdf_page, 0.3, 0.3, 0.3)
        hpdf.Page_BeginText(pdf_page)
        hpdf.Page_MoveTextPos(pdf_page, poem_x + 5, poem_y + poem_height/2)
        hpdf.Page_ShowText(pdf_page, "sample poem")
        hpdf.Page_EndText(pdf_page)
    end
end
-- }}}

-- {{{ local function generate_poem_effects_showcase
local function generate_poem_effects_showcase(pdf, font, title_font)
    local pdf_page = hpdf.AddPage(pdf)
    hpdf.Page_SetSize(pdf_page, hpdf.PAGE_SIZE_A4, hpdf.PAGE_PORTRAIT)
    
    local page_width = 595  -- A4 width
    local page_height = 842 -- A4 height
    local margin = 50
    
    -- Draw title
    hpdf.Page_SetFontAndSize(pdf_page, title_font, 24)
    hpdf.Page_SetRGBFill(pdf_page, 0.0, 0.0, 0.0)
    hpdf.Page_BeginText(pdf_page)
    hpdf.Page_MoveTextPos(pdf_page, margin, page_height - margin - 30)
    hpdf.Page_ShowText(pdf_page, "POEM TEXT EFFECTS SHOWCASE")
    hpdf.Page_EndText(pdf_page)
    
    -- Sample poem text
    local sample_text = "Digital dreams dissolve"
    
    -- Text rendering modes to showcase with VERY distinct fill/stroke colors
    local text_effects = {
        {mode = "HPDF_FILL", name = "FILL (Normal)", fill_color = {0.0, 0.0, 0.0}, stroke_color = {0.0, 0.0, 0.0}, line_width = 1.0},
        {mode = "HPDF_STROKE", name = "STROKE (Outline Only)", fill_color = {1.0, 1.0, 1.0}, stroke_color = {1.0, 0.0, 0.0}, line_width = 3.0},
        {mode = "HPDF_FILL_THEN_STROKE", name = "FILL + STROKE", fill_color = {0.0, 0.8, 1.0}, stroke_color = {1.0, 0.0, 1.0}, line_width = 2.5},
        {mode = "HPDF_FILL_CLIPPING", name = "FILL with CLIPPING", fill_color = {1.0, 0.0, 0.5}, stroke_color = {0.0, 1.0, 0.0}, line_width = 1.0},
        {mode = "HPDF_STROKE_CLIPPING", name = "STROKE with CLIPPING", fill_color = {1.0, 1.0, 0.0}, stroke_color = {0.0, 0.5, 0.0}, line_width = 3.0},
        {mode = "HPDF_FILL_STROKE_CLIPPING", name = "FILL+STROKE CLIPPING", fill_color = {1.0, 0.5, 0.0}, stroke_color = {0.5, 0.0, 1.0}, line_width = 2.5}
    }
    
    local y_pos = page_height - margin - 100
    local font_size = 24  -- Larger font to see effects better
    
    for i, effect in ipairs(text_effects) do
        -- Label for the effect
        hpdf.Page_SetFontAndSize(pdf_page, font, 10)
        hpdf.Page_SetRGBFill(pdf_page, 0.0, 0.0, 0.0)
        hpdf.Page_BeginText(pdf_page)
        hpdf.Page_MoveTextPos(pdf_page, margin, y_pos + 20)
        hpdf.Page_ShowText(pdf_page, effect.name .. ":")
        hpdf.Page_EndText(pdf_page)
        
        -- Set font first
        hpdf.Page_SetFontAndSize(pdf_page, title_font, font_size)
        
        -- Set colors and line width BEFORE text rendering mode
        hpdf.Page_SetRGBFill(pdf_page, effect.fill_color[1], effect.fill_color[2], effect.fill_color[3])
        hpdf.Page_SetRGBStroke(pdf_page, effect.stroke_color[1], effect.stroke_color[2], effect.stroke_color[3])
        hpdf.Page_SetLineWidth(pdf_page, effect.line_width)
        
        -- Apply clipping effects need special handling
        if effect.mode:find("CLIPPING") then
            hpdf.Page_GSave(pdf_page)
            hpdf.Page_SetTextRenderingMode(pdf_page, effect.mode)
            hpdf.Page_BeginText(pdf_page)
            hpdf.Page_TextOut(pdf_page, margin + 20, y_pos, sample_text)
            hpdf.Page_EndText(pdf_page)
            
            -- Add colorful pattern for clipping effects to show the clipping
            local pattern_colors = {{1.0, 0.2, 0.2}, {0.2, 1.0, 0.2}, {0.2, 0.2, 1.0}}
            for j = 1, 15 do
                local color = pattern_colors[((j-1) % 3) + 1]
                hpdf.Page_SetRGBStroke(pdf_page, color[1], color[2], color[3])
                hpdf.Page_SetLineWidth(pdf_page, 3.0)
                local stripe_x = margin + 20 + (j * 10)
                hpdf.Page_MoveTo(pdf_page, stripe_x, y_pos - 10)
                hpdf.Page_LineTo(pdf_page, stripe_x, y_pos + font_size + 10)
                hpdf.Page_Stroke(pdf_page)
            end
            
            hpdf.Page_GRestore(pdf_page)
        else
            -- Normal text effects - follow demo pattern exactly
            hpdf.Page_SetTextRenderingMode(pdf_page, effect.mode)
            hpdf.Page_BeginText(pdf_page)
            hpdf.Page_TextOut(pdf_page, margin + 20, y_pos, sample_text)
            hpdf.Page_EndText(pdf_page)
        end
        
        -- Move to next line (more space for bigger font)
        y_pos = y_pos - 120
    end
    
    -- Reset text rendering mode
    hpdf.Page_SetTextRenderingMode(pdf_page, "HPDF_FILL")
    hpdf.Page_SetRGBFill(pdf_page, 0.0, 0.0, 0.0)
    
    -- Add some additional text effects info
    hpdf.Page_SetFontAndSize(pdf_page, font, 8)
    hpdf.Page_BeginText(pdf_page)
    hpdf.Page_MoveTextPos(pdf_page, margin, 80)
    hpdf.Page_ShowText(pdf_page, "These text rendering modes can be applied to individual poems for visual variety.")
    hpdf.Page_EndText(pdf_page)
end
-- }}}

-- {{{ main
local function main()
    local pdf = create_tiered_test_pdf()
    
    -- Add comprehensive Tier 2 poem graphics showcase
    local font = hpdf.GetFont(pdf, "Courier", "StandardEncoding")
    local title_font = hpdf.GetFont(pdf, "Helvetica-Bold", "StandardEncoding")
    generate_tier2_showcase(pdf, font, title_font)
    
    -- Add poem text effects showcase page
    generate_poem_effects_showcase(pdf, font, title_font)
    
    local output_path = DIR .. "/art-test-tiered-output.pdf"
    hpdf.SaveToFile(pdf, output_path)
    hpdf.Free(pdf)
    
    print("Tiered theme test PDF saved to " .. output_path)
    print("Generated 12 pages showcasing the three-tier theme taxonomy system + all graphics")
    print("Tier 1: Full-page background art (resistance, technology, isolation, etc.)")
    print("Tier 2: Individual poem artwork showcase - ALL 10 Tier 2 themes displayed")
    print("Tier 3: Color determination (direct-action, autistic-masking, etc.)")
    print("Text Effects: Showcase of all 6 text rendering modes for poems")
    return output_path
    
end
-- }}}

main()