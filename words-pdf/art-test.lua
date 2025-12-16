#!/usr/bin/env lua5.2

-- art-test.lua
-- Test script to display each generative art option on a separate page

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/words-pdf"

package.cpath = package.cpath .. ";" .. DIR .. "/libs/luahpdf/?.so"
package.cpath = package.cpath .. ";" .. DIR .. "/libs/libharu-RELEASE_2_3_0/build/src/?.so"
package.path = package.path .. ";" .. DIR .. "/libs/?.lua"

hpdf = require "hpdf"

-- {{{ local function generate_theme_art
local function generate_theme_art(pdf_page, space_list, theme, intensity_multiplier)
    if theme == "nature" then
        -- Organic flowing particles
        for _, space in ipairs(space_list) do
            hpdf.Page_SetRGBStroke(pdf_page, 0.3, 0.6, 0.3) -- Forest green
            hpdf.Page_SetLineWidth(pdf_page, 0.5)
            
            local particle_count = math.floor(100 * intensity_multiplier)
            for i = 1, particle_count do
                local start_x = space.x + math.random() * space.width
                local start_y = space.y + math.random() * space.height
                local length = 5 + math.random() * 15
                local angle = math.random() * math.pi * 2
                
                local end_x = start_x + math.cos(angle) * length
                local end_y = start_y + math.sin(angle) * length
                
                hpdf.Page_MoveTo(pdf_page, start_x, start_y)
                hpdf.Page_LineTo(pdf_page, end_x, end_y)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme == "urban" then
        -- Geometric neon patterns
        local colors = {{1.0, 0.0, 1.0}, {0.0, 1.0, 1.0}, {1.0, 1.0, 0.0}}
        for _, space in ipairs(space_list) do
            local shape_count = math.floor(75 * intensity_multiplier)
            for i = 1, shape_count do
                local color = colors[math.random(#colors)]
                hpdf.Page_SetRGBStroke(pdf_page, color[1], color[2], color[3])
                hpdf.Page_SetLineWidth(pdf_page, 0.8 + math.random())
                
                local x = space.x + math.random() * (space.width - 20)
                local y = space.y + math.random() * (space.height - 20)
                local size = 8 + math.random(15)
                
                -- Draw rectangle
                hpdf.Page_MoveTo(pdf_page, x, y)
                hpdf.Page_LineTo(pdf_page, x + size, y)
                hpdf.Page_LineTo(pdf_page, x + size, y + size)
                hpdf.Page_LineTo(pdf_page, x, y + size)
                hpdf.Page_LineTo(pdf_page, x, y)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme == "energy" then
        -- Explosive radiating lines
        for _, space in ipairs(space_list) do
            hpdf.Page_SetRGBStroke(pdf_page, 1.0, 0.4, 0.0) -- Orange
            hpdf.Page_SetLineWidth(pdf_page, 1.0)
            
            local burst_count = math.floor(125 * intensity_multiplier)
            for i = 1, burst_count do
                local center_x = space.x + math.random() * space.width
                local center_y = space.y + math.random() * space.height
                local radius = 8 + math.random(20)
                local angle = math.random() * math.pi * 2
                
                hpdf.Page_MoveTo(pdf_page, center_x, center_y)
                hpdf.Page_LineTo(pdf_page, center_x + math.cos(angle) * radius, 
                                center_y + math.sin(angle) * radius)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme == "love" then
        -- Gentle curved flowing lines
        for _, space in ipairs(space_list) do
            hpdf.Page_SetRGBStroke(pdf_page, 1.0, 0.6, 0.8) -- Soft pink
            hpdf.Page_SetLineWidth(pdf_page, 0.6)
            
            local curve_count = math.floor(90 * intensity_multiplier)
            for i = 1, curve_count do
                local x1 = space.x + math.random() * space.width
                local y1 = space.y + math.random() * space.height
                local x2 = x1 + (math.random() - 0.5) * 30
                local y2 = y1 + (math.random() - 0.5) * 30
                
                hpdf.Page_MoveTo(pdf_page, x1, y1)
                hpdf.Page_LineTo(pdf_page, x2, y2)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme == "melancholy" then
        -- Downward flowing drops
        for _, space in ipairs(space_list) do
            hpdf.Page_SetRGBStroke(pdf_page, 0.4, 0.4, 0.7) -- Muted blue
            hpdf.Page_SetLineWidth(pdf_page, 0.4)
            
            local drop_count = math.floor(110 * intensity_multiplier)
            for i = 1, drop_count do
                local x = space.x + math.random() * space.width
                local y = space.y + math.random() * space.height
                local length = 10 + math.random(15)
                
                hpdf.Page_MoveTo(pdf_page, x, y)
                hpdf.Page_LineTo(pdf_page, x, y - length)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme == "dream" then
        -- Ethereal wavy patterns
        for _, space in ipairs(space_list) do
            hpdf.Page_SetRGBStroke(pdf_page, 0.6, 0.3, 0.8) -- Purple
            hpdf.Page_SetLineWidth(pdf_page, 0.3)
            
            local wave_count = math.floor(60 * intensity_multiplier)
            for wave = 1, wave_count do
                local y_start = space.y + math.random() * space.height
                local amplitude = 5 + math.random(15)
                local frequency = 0.05 + math.random() * 0.1
                
                hpdf.Page_MoveTo(pdf_page, space.x, y_start)
                for x = space.x, space.x + space.width, 4 do
                    local y = y_start + math.sin((x - space.x) * frequency) * amplitude
                    hpdf.Page_LineTo(pdf_page, x, y)
                end
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme == "constellation" then
        -- Star constellation patterns with connecting lines
        for _, space in ipairs(space_list) do
            hpdf.Page_SetRGBStroke(pdf_page, 0.9, 0.9, 0.3) -- Golden stars
            hpdf.Page_SetLineWidth(pdf_page, 0.4)
            
            -- Generate star positions
            local stars = {}
            local star_count = math.floor(40 * intensity_multiplier)
            for i = 1, star_count do
                table.insert(stars, {
                    x = space.x + math.random() * space.width,
                    y = space.y + math.random() * space.height
                })
            end
            
            -- Draw connecting lines between nearby stars
            for i, star1 in ipairs(stars) do
                for j, star2 in ipairs(stars) do
                    if i < j then
                        local distance = math.sqrt((star2.x - star1.x)^2 + (star2.y - star1.y)^2)
                        if distance < 80 and math.random() > 0.3 then
                            hpdf.Page_MoveTo(pdf_page, star1.x, star1.y)
                            hpdf.Page_LineTo(pdf_page, star2.x, star2.y)
                            hpdf.Page_Stroke(pdf_page)
                        end
                    end
                end
            end
            
            -- Draw stars as small crosses
            hpdf.Page_SetLineWidth(pdf_page, 0.8)
            for _, star in ipairs(stars) do
                hpdf.Page_MoveTo(pdf_page, star.x - 2, star.y)
                hpdf.Page_LineTo(pdf_page, star.x + 2, star.y)
                hpdf.Page_MoveTo(pdf_page, star.x, star.y - 2)
                hpdf.Page_LineTo(pdf_page, star.x, star.y + 2)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme == "spiral" then
        -- Spiral/mandala patterns
        for _, space in ipairs(space_list) do
            hpdf.Page_SetRGBStroke(pdf_page, 0.7, 0.2, 0.6) -- Deep purple
            hpdf.Page_SetLineWidth(pdf_page, 0.5)
            
            local spiral_count = math.floor(30 * intensity_multiplier)
            for i = 1, spiral_count do
                local center_x = space.x + math.random() * space.width
                local center_y = space.y + math.random() * space.height
                local max_radius = 15 + math.random(20)
                
                hpdf.Page_MoveTo(pdf_page, center_x, center_y)
                for angle = 0, math.pi * 6, 0.2 do
                    local radius = (angle / (math.pi * 6)) * max_radius
                    local x = center_x + math.cos(angle) * radius
                    local y = center_y + math.sin(angle) * radius
                    hpdf.Page_LineTo(pdf_page, x, y)
                end
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme == "circuit" then
        -- Circuit board pathways
        for _, space in ipairs(space_list) do
            local colors = {{0.0, 1.0, 0.3}, {0.3, 0.8, 1.0}} -- Green and blue circuits
            local color = colors[math.random(#colors)]
            hpdf.Page_SetRGBStroke(pdf_page, color[1], color[2], color[3])
            hpdf.Page_SetLineWidth(pdf_page, 0.6)
            
            local path_count = math.floor(50 * intensity_multiplier)
            for i = 1, path_count do
                -- Create L-shaped circuit paths
                local start_x = space.x + math.random() * space.width
                local start_y = space.y + math.random() * space.height
                local mid_x = start_x + (math.random() - 0.5) * 40
                local end_y = start_y + (math.random() - 0.5) * 40
                
                hpdf.Page_MoveTo(pdf_page, start_x, start_y)
                hpdf.Page_LineTo(pdf_page, mid_x, start_y) -- Horizontal
                hpdf.Page_LineTo(pdf_page, mid_x, end_y)   -- Vertical
                hpdf.Page_Stroke(pdf_page)
                
                -- Add small circuit nodes
                hpdf.Page_Rectangle(pdf_page, mid_x - 1, start_y - 1, 2, 2)
                hpdf.Page_Rectangle(pdf_page, mid_x - 1, end_y - 1, 2, 2)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme == "lightning" then
        -- Electrical discharge patterns
        for _, space in ipairs(space_list) do
            hpdf.Page_SetRGBStroke(pdf_page, 0.9, 0.9, 1.0) -- Electric blue-white
            hpdf.Page_SetLineWidth(pdf_page, 0.8)
            
            local bolt_count = math.floor(40 * intensity_multiplier)
            for i = 1, bolt_count do
                local start_x = space.x + math.random() * space.width
                local start_y = space.y + math.random() * space.height
                local length = 20 + math.random(30)
                local segments = 5 + math.random(8)
                
                local current_x, current_y = start_x, start_y
                hpdf.Page_MoveTo(pdf_page, current_x, current_y)
                
                for seg = 1, segments do
                    local next_x = current_x + (math.random() - 0.5) * 15
                    local next_y = current_y + (length / segments) * (math.random() + 0.5)
                    hpdf.Page_LineTo(pdf_page, next_x, next_y)
                    current_x, current_y = next_x, next_y
                end
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme == "crystal" then
        -- Crystalline geometric patterns
        for _, space in ipairs(space_list) do
            hpdf.Page_SetRGBStroke(pdf_page, 0.3, 0.9, 0.9) -- Crystal cyan
            hpdf.Page_SetLineWidth(pdf_page, 0.4)
            
            local crystal_count = math.floor(60 * intensity_multiplier)
            for i = 1, crystal_count do
                local center_x = space.x + math.random() * space.width
                local center_y = space.y + math.random() * space.height
                local size = 5 + math.random(15)
                local sides = 3 + math.random(3) -- 3-6 sided crystals
                
                -- Draw crystal polygon
                local angles = {}
                for s = 1, sides do
                    table.insert(angles, (s - 1) * (2 * math.pi / sides))
                end
                
                hpdf.Page_MoveTo(pdf_page, center_x + math.cos(angles[1]) * size, center_y + math.sin(angles[1]) * size)
                for _, angle in ipairs(angles) do
                    local x = center_x + math.cos(angle) * size
                    local y = center_y + math.sin(angle) * size
                    hpdf.Page_LineTo(pdf_page, x, y)
                end
                hpdf.Page_LineTo(pdf_page, center_x + math.cos(angles[1]) * size, center_y + math.sin(angles[1]) * size)
                hpdf.Page_Stroke(pdf_page)
                
                -- Add inner lines
                for _, angle in ipairs(angles) do
                    local x = center_x + math.cos(angle) * size
                    local y = center_y + math.sin(angle) * size
                    hpdf.Page_MoveTo(pdf_page, center_x, center_y)
                    hpdf.Page_LineTo(pdf_page, x, y)
                    hpdf.Page_Stroke(pdf_page)
                end
            end
        end
        
    else -- neutral or default
        -- Subtle particle drift
        for _, space in ipairs(space_list) do
            hpdf.Page_SetRGBStroke(pdf_page, 0.7, 0.7, 0.7) -- Neutral gray
            hpdf.Page_SetLineWidth(pdf_page, 0.2)
            
            local particle_count = math.floor(75 * intensity_multiplier)
            for i = 1, particle_count do
                local x = space.x + math.random() * space.width
                local y = space.y + math.random() * space.height
                local length = 3 + math.random(8)
                local angle = math.random() * math.pi * 2
                
                hpdf.Page_MoveTo(pdf_page, x, y)
                hpdf.Page_LineTo(pdf_page, x + math.cos(angle) * length, y + math.sin(angle) * length)
                hpdf.Page_Stroke(pdf_page)
            end
        end
    end
end -- }}}

-- {{{ local function create_test_pdf
local function create_test_pdf()
    local pdf = hpdf.New()
    hpdf.SetCompressionMode(pdf, 15) -- All compression
    
    local font = hpdf.GetFont(pdf, "Courier", "StandardEncoding")
    local title_font = hpdf.GetFont(pdf, "Helvetica-Bold", "StandardEncoding")
    
    -- Page dimensions
    local page_width = 595  -- A4 width
    local page_height = 842 -- A4 height
    local margin = 50
    
    -- Art themes to demonstrate
    local themes = {
        {name = "nature", description = "Organic flowing particles in forest green"},
        {name = "urban", description = "Geometric neon patterns in magenta/cyan/yellow"},
        {name = "love", description = "Gentle curved flowing lines in soft pink"},
        {name = "melancholy", description = "Downward flowing drops in muted blue"},
        {name = "energy", description = "Explosive radiating lines in orange"},
        {name = "dream", description = "Ethereal wavy patterns in purple"},
        {name = "constellation", description = "Star constellation patterns with golden connecting lines"},
        {name = "spiral", description = "Spiral/mandala patterns in deep purple"},
        {name = "circuit", description = "Circuit board pathways in green and blue"},
        {name = "lightning", description = "Electrical discharge patterns in electric blue-white"},
        {name = "crystal", description = "Crystalline geometric patterns in crystal cyan"}
    }
    
    for i, theme in ipairs(themes) do
        local pdf_page = hpdf.AddPage(pdf)
        hpdf.Page_SetSize(pdf_page, hpdf.PAGE_SIZE_A4, hpdf.PAGE_PORTRAIT)
        
        -- Draw title
        hpdf.Page_SetFontAndSize(pdf_page, title_font, 24)
        hpdf.Page_SetRGBFill(pdf_page, 0.0, 0.0, 0.0)
        hpdf.Page_BeginText(pdf_page)
        hpdf.Page_MoveTextPos(pdf_page, margin, page_height - margin - 30)
        hpdf.Page_ShowText(pdf_page, "Art Theme: " .. theme.name:upper())
        hpdf.Page_EndText(pdf_page)
        
        -- Draw description
        hpdf.Page_SetFontAndSize(pdf_page, font, 12)
        hpdf.Page_BeginText(pdf_page)
        hpdf.Page_MoveTextPos(pdf_page, margin, page_height - margin - 60)
        hpdf.Page_ShowText(pdf_page, theme.description)
        hpdf.Page_EndText(pdf_page)
        
        -- Create art spaces for demonstration
        local test_spaces = {
            {x = margin, y = margin, width = page_width - 2*margin, height = page_height - 2*margin - 100}
        }
        
        -- Generate art for this theme
        generate_theme_art(pdf_page, test_spaces, theme.name, 2.0)
    end
    
    return pdf
end -- }}}

-- {{{ local function generate_theme_art
local function generate_theme_art(pdf_page, space_list, theme, intensity_multiplier)
    if theme == "nature" then
        -- Organic flowing particles
        for _, space in ipairs(space_list) do
            hpdf.Page_SetRGBStroke(pdf_page, 0.3, 0.6, 0.3) -- Forest green
            hpdf.Page_SetLineWidth(pdf_page, 0.5)
            
            local particle_count = math.floor(100 * intensity_multiplier)
            for i = 1, particle_count do
                local start_x = space.x + math.random() * space.width
                local start_y = space.y + math.random() * space.height
                local length = 5 + math.random() * 15
                local angle = math.random() * math.pi * 2
                
                local end_x = start_x + math.cos(angle) * length
                local end_y = start_y + math.sin(angle) * length
                
                hpdf.Page_MoveTo(pdf_page, start_x, start_y)
                hpdf.Page_LineTo(pdf_page, end_x, end_y)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme == "urban" then
        -- Geometric neon patterns
        local colors = {{1.0, 0.0, 1.0}, {0.0, 1.0, 1.0}, {1.0, 1.0, 0.0}}
        for _, space in ipairs(space_list) do
            local shape_count = math.floor(75 * intensity_multiplier)
            for i = 1, shape_count do
                local color = colors[math.random(#colors)]
                hpdf.Page_SetRGBStroke(pdf_page, color[1], color[2], color[3])
                hpdf.Page_SetLineWidth(pdf_page, 0.8 + math.random())
                
                local x = space.x + math.random() * (space.width - 20)
                local y = space.y + math.random() * (space.height - 20)
                local size = 8 + math.random(15)
                
                -- Draw rectangle
                hpdf.Page_MoveTo(pdf_page, x, y)
                hpdf.Page_LineTo(pdf_page, x + size, y)
                hpdf.Page_LineTo(pdf_page, x + size, y + size)
                hpdf.Page_LineTo(pdf_page, x, y + size)
                hpdf.Page_LineTo(pdf_page, x, y)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme == "energy" then
        -- Explosive radiating lines
        for _, space in ipairs(space_list) do
            hpdf.Page_SetRGBStroke(pdf_page, 1.0, 0.4, 0.0) -- Orange
            hpdf.Page_SetLineWidth(pdf_page, 1.0)
            
            local burst_count = math.floor(125 * intensity_multiplier)
            for i = 1, burst_count do
                local center_x = space.x + math.random() * space.width
                local center_y = space.y + math.random() * space.height
                local radius = 8 + math.random(20)
                local angle = math.random() * math.pi * 2
                
                hpdf.Page_MoveTo(pdf_page, center_x, center_y)
                hpdf.Page_LineTo(pdf_page, center_x + math.cos(angle) * radius, 
                                center_y + math.sin(angle) * radius)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme == "love" then
        -- Gentle curved flowing lines
        for _, space in ipairs(space_list) do
            hpdf.Page_SetRGBStroke(pdf_page, 1.0, 0.6, 0.8) -- Soft pink
            hpdf.Page_SetLineWidth(pdf_page, 0.6)
            
            local curve_count = math.floor(90 * intensity_multiplier)
            for i = 1, curve_count do
                local x1 = space.x + math.random() * space.width
                local y1 = space.y + math.random() * space.height
                local x2 = x1 + (math.random() - 0.5) * 30
                local y2 = y1 + (math.random() - 0.5) * 30
                
                hpdf.Page_MoveTo(pdf_page, x1, y1)
                hpdf.Page_LineTo(pdf_page, x2, y2)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme == "melancholy" then
        -- Downward flowing drops
        for _, space in ipairs(space_list) do
            hpdf.Page_SetRGBStroke(pdf_page, 0.4, 0.4, 0.7) -- Muted blue
            hpdf.Page_SetLineWidth(pdf_page, 0.4)
            
            local drop_count = math.floor(110 * intensity_multiplier)
            for i = 1, drop_count do
                local x = space.x + math.random() * space.width
                local y = space.y + math.random() * space.height
                local length = 10 + math.random(15)
                
                hpdf.Page_MoveTo(pdf_page, x, y)
                hpdf.Page_LineTo(pdf_page, x, y - length)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme == "dream" then
        -- Ethereal wavy patterns
        for _, space in ipairs(space_list) do
            hpdf.Page_SetRGBStroke(pdf_page, 0.6, 0.3, 0.8) -- Purple
            hpdf.Page_SetLineWidth(pdf_page, 0.3)
            
            local wave_count = math.floor(60 * intensity_multiplier)
            for wave = 1, wave_count do
                local y_start = space.y + math.random() * space.height
                local amplitude = 5 + math.random(15)
                local frequency = 0.05 + math.random() * 0.1
                
                hpdf.Page_MoveTo(pdf_page, space.x, y_start)
                for x = space.x, space.x + space.width, 4 do
                    local y = y_start + math.sin((x - space.x) * frequency) * amplitude
                    hpdf.Page_LineTo(pdf_page, x, y)
                end
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme == "constellation" then
        -- Star constellation patterns with connecting lines
        for _, space in ipairs(space_list) do
            hpdf.Page_SetRGBStroke(pdf_page, 0.9, 0.9, 0.3) -- Golden stars
            hpdf.Page_SetLineWidth(pdf_page, 0.4)
            
            -- Generate star positions
            local stars = {}
            local star_count = math.floor(40 * intensity_multiplier)
            for i = 1, star_count do
                table.insert(stars, {
                    x = space.x + math.random() * space.width,
                    y = space.y + math.random() * space.height
                })
            end
            
            -- Draw connecting lines between nearby stars
            for i, star1 in ipairs(stars) do
                for j, star2 in ipairs(stars) do
                    if i < j then
                        local distance = math.sqrt((star2.x - star1.x)^2 + (star2.y - star1.y)^2)
                        if distance < 80 and math.random() > 0.3 then
                            hpdf.Page_MoveTo(pdf_page, star1.x, star1.y)
                            hpdf.Page_LineTo(pdf_page, star2.x, star2.y)
                            hpdf.Page_Stroke(pdf_page)
                        end
                    end
                end
            end
            
            -- Draw stars as small crosses
            hpdf.Page_SetLineWidth(pdf_page, 0.8)
            for _, star in ipairs(stars) do
                hpdf.Page_MoveTo(pdf_page, star.x - 2, star.y)
                hpdf.Page_LineTo(pdf_page, star.x + 2, star.y)
                hpdf.Page_MoveTo(pdf_page, star.x, star.y - 2)
                hpdf.Page_LineTo(pdf_page, star.x, star.y + 2)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme == "spiral" then
        -- Spiral/mandala patterns
        for _, space in ipairs(space_list) do
            hpdf.Page_SetRGBStroke(pdf_page, 0.7, 0.2, 0.6) -- Deep purple
            hpdf.Page_SetLineWidth(pdf_page, 0.5)
            
            local spiral_count = math.floor(30 * intensity_multiplier)
            for i = 1, spiral_count do
                local center_x = space.x + math.random() * space.width
                local center_y = space.y + math.random() * space.height
                local max_radius = 15 + math.random(20)
                
                hpdf.Page_MoveTo(pdf_page, center_x, center_y)
                for angle = 0, math.pi * 6, 0.2 do
                    local radius = (angle / (math.pi * 6)) * max_radius
                    local x = center_x + math.cos(angle) * radius
                    local y = center_y + math.sin(angle) * radius
                    hpdf.Page_LineTo(pdf_page, x, y)
                end
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme == "circuit" then
        -- Circuit board pathways
        for _, space in ipairs(space_list) do
            local colors = {{0.0, 1.0, 0.3}, {0.3, 0.8, 1.0}} -- Green and blue circuits
            local color = colors[math.random(#colors)]
            hpdf.Page_SetRGBStroke(pdf_page, color[1], color[2], color[3])
            hpdf.Page_SetLineWidth(pdf_page, 0.6)
            
            local path_count = math.floor(50 * intensity_multiplier)
            for i = 1, path_count do
                -- Create L-shaped circuit paths
                local start_x = space.x + math.random() * space.width
                local start_y = space.y + math.random() * space.height
                local mid_x = start_x + (math.random() - 0.5) * 40
                local end_y = start_y + (math.random() - 0.5) * 40
                
                hpdf.Page_MoveTo(pdf_page, start_x, start_y)
                hpdf.Page_LineTo(pdf_page, mid_x, start_y) -- Horizontal
                hpdf.Page_LineTo(pdf_page, mid_x, end_y)   -- Vertical
                hpdf.Page_Stroke(pdf_page)
                
                -- Add small circuit nodes
                hpdf.Page_Rectangle(pdf_page, mid_x - 1, start_y - 1, 2, 2)
                hpdf.Page_Rectangle(pdf_page, mid_x - 1, end_y - 1, 2, 2)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme == "lightning" then
        -- Electrical discharge patterns
        for _, space in ipairs(space_list) do
            hpdf.Page_SetRGBStroke(pdf_page, 0.9, 0.9, 1.0) -- Electric blue-white
            hpdf.Page_SetLineWidth(pdf_page, 0.8)
            
            local bolt_count = math.floor(40 * intensity_multiplier)
            for i = 1, bolt_count do
                local start_x = space.x + math.random() * space.width
                local start_y = space.y + math.random() * space.height
                local length = 20 + math.random(30)
                local segments = 5 + math.random(8)
                
                local current_x, current_y = start_x, start_y
                hpdf.Page_MoveTo(pdf_page, current_x, current_y)
                
                for seg = 1, segments do
                    local next_x = current_x + (math.random() - 0.5) * 15
                    local next_y = current_y + (length / segments) * (math.random() + 0.5)
                    hpdf.Page_LineTo(pdf_page, next_x, next_y)
                    current_x, current_y = next_x, next_y
                end
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
    elseif theme == "crystal" then
        -- Crystalline geometric patterns
        for _, space in ipairs(space_list) do
            hpdf.Page_SetRGBStroke(pdf_page, 0.3, 0.9, 0.9) -- Crystal cyan
            hpdf.Page_SetLineWidth(pdf_page, 0.4)
            
            local crystal_count = math.floor(60 * intensity_multiplier)
            for i = 1, crystal_count do
                local center_x = space.x + math.random() * space.width
                local center_y = space.y + math.random() * space.height
                local size = 5 + math.random(15)
                local sides = 3 + math.random(3) -- 3-6 sided crystals
                
                -- Draw crystal polygon
                local angles = {}
                for s = 1, sides do
                    table.insert(angles, (s - 1) * (2 * math.pi / sides))
                end
                
                hpdf.Page_MoveTo(pdf_page, center_x + math.cos(angles[1]) * size, center_y + math.sin(angles[1]) * size)
                for _, angle in ipairs(angles) do
                    local x = center_x + math.cos(angle) * size
                    local y = center_y + math.sin(angle) * size
                    hpdf.Page_LineTo(pdf_page, x, y)
                end
                hpdf.Page_LineTo(pdf_page, center_x + math.cos(angles[1]) * size, center_y + math.sin(angles[1]) * size)
                hpdf.Page_Stroke(pdf_page)
                
                -- Add inner lines
                for _, angle in ipairs(angles) do
                    local x = center_x + math.cos(angle) * size
                    local y = center_y + math.sin(angle) * size
                    hpdf.Page_MoveTo(pdf_page, center_x, center_y)
                    hpdf.Page_LineTo(pdf_page, x, y)
                    hpdf.Page_Stroke(pdf_page)
                end
            end
        end
        
    else -- neutral or default
        -- Subtle particle drift
        for _, space in ipairs(space_list) do
            hpdf.Page_SetRGBStroke(pdf_page, 0.7, 0.7, 0.7) -- Neutral gray
            hpdf.Page_SetLineWidth(pdf_page, 0.2)
            
            local particle_count = math.floor(75 * intensity_multiplier)
            for i = 1, particle_count do
                local x = space.x + math.random() * space.width
                local y = space.y + math.random() * space.height
                local length = 3 + math.random(8)
                local angle = math.random() * math.pi * 2
                
                hpdf.Page_MoveTo(pdf_page, x, y)
                hpdf.Page_LineTo(pdf_page, x + math.cos(angle) * length, y + math.sin(angle) * length)
                hpdf.Page_Stroke(pdf_page)
            end
        end
    end
end -- }}}

-- {{{ local function main
local function main()
    local pdf = create_test_pdf()
    
    local output_path = DIR .. "/art-test-output.pdf"
    hpdf.SaveToFile(pdf, output_path)
    hpdf.Free(pdf)
    
    print("Art test PDF saved to " .. output_path)
    print("Generated 11 pages showcasing each generative art theme")
    return output_path
end -- }}}

main()