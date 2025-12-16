#!/usr/bin/env lua5.2

-- art-test-json.lua
-- Test script to display each generative art option on a separate page
-- Uses JSON-defined functions for dynamic loading

local DIR = arg[1] or "/mnt/mtwo/programming/ai-stuff/words-pdf"

package.cpath = package.cpath .. ";" .. DIR .. "/libs/luahpdf/?.so"
package.cpath = package.cpath .. ";" .. DIR .. "/libs/libharu-RELEASE_2_3_0/build/src/?.so"
package.path = package.path .. ";" .. DIR .. "/libs/?.lua"

hpdf = require "hpdf"
json = require "dkjson"

-- {{{ local function load_art_themes
local function load_art_themes()
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
    
    return themes_data.art_themes
end -- }}}

-- {{{ local function create_theme_function
local function create_theme_function(function_body)
    -- Create a function that takes the required parameters and executes the function body
    local func_string = "return function(pdf_page, space_list, intensity_multiplier)\n" .. 
                       function_body .. "\nend"
    
    -- Load the function string as Lua code
    local chunk, err = loadstring(func_string)
    if not chunk then
        error("Error loading function: " .. err)
    end
    
    -- Execute the chunk to get the actual function
    local success, func = pcall(chunk)
    if not success then
        error("Error creating function: " .. func)
    end
    
    return func
end -- }}}

-- {{{ local function generate_theme_art
local function generate_theme_art(pdf_page, space_list, theme_name, intensity_multiplier, themes)
    local theme = themes[theme_name]
    if not theme then
        -- Fallback to neutral if theme not found
        theme = themes["neutral"]
        if not theme then
            error("Neither " .. theme_name .. " nor neutral theme found")
        end
    end
    
    -- Create and execute the dynamic function
    local theme_func = create_theme_function(theme.function_body)
    theme_func(pdf_page, space_list, intensity_multiplier)
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
    
    -- Load art themes from JSON
    local themes = load_art_themes()
    
    -- Create a list of theme names for iteration
    local theme_names = {}
    for name, _ in pairs(themes) do
        table.insert(theme_names, name)
    end
    -- Sort for consistent ordering
    table.sort(theme_names)
    
    for i, theme_name in ipairs(theme_names) do
        local theme = themes[theme_name]
        local pdf_page = hpdf.AddPage(pdf)
        hpdf.Page_SetSize(pdf_page, hpdf.PAGE_SIZE_A4, hpdf.PAGE_PORTRAIT)
        
        -- Draw title
        hpdf.Page_SetFontAndSize(pdf_page, title_font, 24)
        hpdf.Page_SetRGBFill(pdf_page, 0.0, 0.0, 0.0)
        hpdf.Page_BeginText(pdf_page)
        hpdf.Page_MoveTextPos(pdf_page, margin, page_height - margin - 30)
        hpdf.Page_ShowText(pdf_page, "Art Theme: " .. theme_name:upper())
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
        
        -- Generate art for this theme using dynamic function loading
        generate_theme_art(pdf_page, test_spaces, theme_name, 2.0, themes)
    end
    
    return pdf
end -- }}}

-- {{{ local function main
local function main()
    local pdf = create_test_pdf()
    
    local output_path = DIR .. "/art-test-json-output.pdf"
    hpdf.SaveToFile(pdf, output_path)
    hpdf.Free(pdf)
    
    print("Art test PDF (JSON-based) saved to " .. output_path)
    print("Generated pages showcasing each generative art theme from JSON definitions")
    return output_path
end -- }}}

main()