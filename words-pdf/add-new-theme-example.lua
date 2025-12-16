#!/usr/bin/env lua5.2

-- add-new-theme-example.lua
-- Example of how to add a new art theme to the JSON file

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/words-pdf"

package.path = package.path .. ";" .. DIR .. "/libs/?.lua"
json = require "dkjson"

-- {{{ local function add_new_theme
local function add_new_theme(theme_name, description, function_body)
    -- Load existing themes
    local file = io.open(DIR .. "/art-themes.json", "r")
    if not file then
        error("Could not open art-themes.json file")
    end
    
    local content = file:read("*a")
    file:close()
    
    local themes_data, pos, err = json.decode(content, 1, nil)
    if err then
        error("JSON decode error: " .. err)
    end
    
    -- Add new theme
    themes_data.art_themes[theme_name] = {
        description = description,
        function_body = function_body
    }
    
    -- Write back to file
    local new_json = json.encode(themes_data, { indent = true })
    local output_file = io.open(DIR .. "/art-themes.json", "w")
    output_file:write(new_json)
    output_file:close()
    
    print("Added new theme: " .. theme_name)
end -- }}}

-- Example: Add a "fire" theme
local fire_function_body = [[for _, space in ipairs(space_list) do
    -- Fire-like flickering particles
    local colors = {{1.0, 0.4, 0.0}, {1.0, 0.6, 0.0}, {1.0, 0.8, 0.2}} -- Orange/yellow fire colors
    
    local flame_count = math.floor(150 * intensity_multiplier)
    for i = 1, flame_count do
        local color = colors[math.random(#colors)]
        hpdf.Page_SetRGBStroke(pdf_page, color[1], color[2], color[3])
        hpdf.Page_SetLineWidth(pdf_page, 0.3 + math.random() * 0.5)
        
        local base_x = space.x + math.random() * space.width
        local base_y = space.y + math.random() * (space.height * 0.3) -- Start from bottom third
        local flame_height = 10 + math.random(25)
        local flicker = (math.random() - 0.5) * 8 -- Horizontal flicker
        
        -- Draw flickering flame line
        hpdf.Page_MoveTo(pdf_page, base_x, base_y)
        hpdf.Page_LineTo(pdf_page, base_x + flicker, base_y + flame_height)
        hpdf.Page_Stroke(pdf_page)
        
        -- Add some spark particles
        if math.random() > 0.8 then
            local spark_x = base_x + flicker + (math.random() - 0.5) * 5
            local spark_y = base_y + flame_height + math.random(10)
            hpdf.Page_MoveTo(pdf_page, spark_x - 1, spark_y)
            hpdf.Page_LineTo(pdf_page, spark_x + 1, spark_y)
            hpdf.Page_Stroke(pdf_page)
        end
    end
end]]

-- Uncomment the line below to actually add the theme
-- add_new_theme("fire", "Flickering flame patterns with orange and yellow sparks", fire_function_body)

print("This is an example of how to add a new theme.")
print("To actually add the 'fire' theme, uncomment the add_new_theme line at the bottom.")
print("")
print("The new theme would include:")
print("- Theme name: fire")
print("- Description: Flickering flame patterns with orange and yellow sparks") 
print("- Custom drawing function with fire-like particle effects")