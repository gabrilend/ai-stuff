-- Enhanced chronological content merging system
-- Combines poems, art, chapters, and notes in chronological order

DIR = arg[1]
FILE = arg[2]  
ORDERING_MODE = arg[3] or "normal"  -- Default to normal ordering

print("🎛️  Configuration:")
print("   📂 Directory: " .. DIR)
print("   📄 Input file: " .. FILE)  
print("   🔄 Poem ordering: " .. ORDERING_MODE)

package.cpath = package.cpath .. ";" .. DIR .. "/libs/luahpdf/?.so"
package.cpath = package.cpath .. ";" .. DIR .. "/libs/libharu-RELEASE_2_3_0/build/src/?.so"
package.path = package.path .. ";" .. DIR .. "/libs/?.lua"

hpdf = require "hpdf"
fuzz = require "libs/fuzzy-computing"

-- Layout Configuration Variables
MAX_LINES_PER_PAGE = 155 -- Lines per page column (final spacing fix applied)
MAX_CHAR_PER_LINE  = 80  -- Characters per line (content width)

-- Box Drawing Characters - trying different characters that might connect better
BOX_TOP_LEFT     = "."   -- Top left corner (more rounded look)
BOX_TOP_RIGHT    = "."   -- Top right corner  
BOX_BOTTOM_LEFT  = "`"   -- Bottom left corner (more rounded look)
BOX_BOTTOM_RIGHT = "'"   -- Bottom right corner
BOX_HORIZONTAL   = "-"   -- Horizontal lines
BOX_VERTICAL     = "|"   -- Vertical lines

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

-- {{{ load_all_content_chronologically
function load_all_content_chronologically(book)
    local content_items = {}
    
    -- Load poems from compiled.txt
    load_poems_with_timestamps(content_items)
    
    -- Load art images
    load_art_images(content_items)
    
    -- Load chapter files
    load_chapter_files(content_items)
    
    -- Load notes files  
    load_notes_files(content_items)
    
    -- Sort all content by timestamp
    table.sort(content_items, function(a, b) return a.timestamp < b.timestamp end)
    
    -- Convert to book format
    for _, item in ipairs(content_items) do
        if item.type == "poem" then
            local processed_poem = normalize_poem_spacing(item.content)
            table.insert(book.poems, processed_poem)
        elseif item.type == "image" then
            -- Insert special image marker
            table.insert(book.poems, {"IMAGE:" .. item.path})
        elseif item.type == "chapter" or item.type == "note" then
            -- Convert file content to poem format
            local lines = split_text_to_lines(item.content)
            local processed_content = normalize_poem_spacing(lines)
            table.insert(book.poems, processed_content)
        end
    end
    
    return book
end
-- }}}

-- {{{ load_poems_with_timestamps
function load_poems_with_timestamps(content_items)
    local file = io.open(FILE, "r")
    if not file then 
        print("FILE cannot be found") 
        return
    end
    
    local poem = {}
    local current_timestamp = 1577836800 -- Default: Jan 1, 2020
    
    for line in file:lines() do
        if line ~= string.rep("-", 80) then
            table.insert(poem, line)
            -- Extract timestamp from file path if available
            if line:match("-> file:") then
                local file_path = line:match("-> file: (.+)")
                -- Try to get file timestamp (this is an approximation)
                current_timestamp = current_timestamp + 86400 -- Add 1 day per poem
            end
        else 
            if #poem > 0 then
                table.insert(content_items, {
                    type = "poem",
                    content = poem,
                    timestamp = current_timestamp
                })
                poem = {}
                current_timestamp = current_timestamp + 3600 -- Add 1 hour between poems
            end
        end
    end
    
    -- Handle last poem
    if #poem > 0 then
        table.insert(content_items, {
            type = "poem",
            content = poem,
            timestamp = current_timestamp
        })
    end
    
    file:close()
end
-- }}}

-- {{{ load_poems_from_compiled_file (fallback)
function load_poems_from_compiled_file(content_items)
    local file = io.open(FILE, "r")
    if not file then 
        print("FILE cannot be found") 
        return
    end
    
    local poem = {}
    local current_timestamp = 1577836800 -- Default: Jan 1, 2020
    
    for line in file:lines() do
        if line ~= string.rep("-", 80) then
            table.insert(poem, line)
            -- Extract timestamp from file path if available
            if line:match("-> file:") then
                current_timestamp = current_timestamp + 86400 -- Add 1 day per poem
            end
        else 
            if #poem > 0 then
                table.insert(content_items, {
                    type = "poem",
                    content = poem,
                    timestamp = current_timestamp
                })
                poem = {}
                current_timestamp = current_timestamp + 3600 -- Add 1 hour between poems
            end
        end
    end
    
    -- Handle last poem
    if #poem > 0 then
        table.insert(content_items, {
            type = "poem",
            content = poem,
            timestamp = current_timestamp
        })
    end
    
    file:close()
end
-- }}}

-- {{{ load_art_images
function load_art_images(content_items)
    local art_dir = "/home/ritz/pictures/my-art/"
    local cmd = "find '" .. art_dir .. "' -type f \\( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \\) -printf '%T@ %p\\n' | sort -n"
    local handle = io.popen(cmd)
    
    if handle then
        for line in handle:lines() do
            local timestamp_str, path = line:match("([%d%.]+) (.+)")
            if timestamp_str and path then
                local timestamp = tonumber(timestamp_str)
                table.insert(content_items, {
                    type = "image",
                    path = path,
                    timestamp = timestamp
                })
            end
        end
        handle:close()
    end
end
-- }}}

-- {{{ load_chapter_files
function load_chapter_files(content_items)
    local chapters_dir = "/home/ritz/documents/w7/chapters/"
    local cmd = "find '" .. chapters_dir .. "' -name '*.md' -printf '%T@ %p\\n' | sort -n"
    local handle = io.popen(cmd)
    
    if handle then
        for line in handle:lines() do
            local timestamp_str, path = line:match("([%d%.]+) (.+)")
            if timestamp_str and path then
                local timestamp = tonumber(timestamp_str)
                local content = read_file_content(path)
                if content then
                    table.insert(content_items, {
                        type = "chapter",
                        path = path,
                        content = content,
                        timestamp = timestamp
                    })
                end
            end
        end
        handle:close()
    end
end
-- }}}

-- {{{ load_notes_files
function load_notes_files(content_items)
    local notes_dir = "/home/ritz/documents/w7/notes/"
    local cmd = "find '" .. notes_dir .. "' -type f ! -name '*.png' -printf '%T@ %p\\n' | sort -n"
    local handle = io.popen(cmd)
    
    if handle then
        for line in handle:lines() do
            local timestamp_str, path = line:match("([%d%.]+) (.+)")
            if timestamp_str and path then
                local timestamp = tonumber(timestamp_str)
                local content = read_file_content(path)
                if content then
                    table.insert(content_items, {
                        type = "note",
                        path = path,
                        content = content,
                        timestamp = timestamp
                    })
                end
            end
        end
        handle:close()
    end
end
-- }}}

-- {{{ read_file_content
function read_file_content(file_path)
    local file = io.open(file_path, "r")
    if not file then return nil end
    
    local content = file:read("*all")
    file:close()
    
    return content
end
-- }}}

-- {{{ split_text_to_lines
function split_text_to_lines(text)
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    return lines
end
-- }}}

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

    -- Apply poem ordering based on configuration
    if ORDERING_MODE == "reverse" then
        print("🔄 Applying sophisticated reverse ordering with cross-compilation validation...")
        book = apply_reverse_poem_ordering_with_validation(book)
    else
        print("📄 Using normal poem ordering (original order)")
    end
    
    return book
end -- }}}

-- {{{ apply_reverse_poem_ordering_with_validation
function apply_reverse_poem_ordering_with_validation(book)
    if #book.poems <= 1 then
        print("DEBUG: Too few poems for sophisticated ordering")
        return book
    end
    
    print("DEBUG: Applying sophisticated reverse ordering with cross-compilation validation...")
    print("DEBUG: Original poem count: " .. #book.poems)
    
    -- Step 1: Implement pair-swapping algorithm with intermediary processing
    local reversed_poems = perform_pair_swapping_with_intermediary(book.poems)
    
    -- Step 2: Identify middle poem for validation anchor
    local middle_index = identify_middle_poem(reversed_poems)
    print("DEBUG: Middle poem index identified: " .. middle_index)
    
    -- Step 3: Perform cross-compilation validation (middle → top → end → middle)
    local validation_result = perform_cross_compilation_validation(reversed_poems, middle_index)
    
    -- Step 4: Evaluate middle poem ownership and generate shared conclusion if needed
    local final_poems = evaluate_middle_poem_ownership(reversed_poems, middle_index, validation_result)
    
    book.poems = final_poems
    print("DEBUG: Final poem count after validation: " .. #book.poems)
    
    return book
end
-- }}}

-- {{{ perform_pair_swapping_with_intermediary
function perform_pair_swapping_with_intermediary(poems)
    local result = {}
    local total_count = #poems
    
    print("DEBUG: Starting pair-swapping with intermediary processing...")
    
    -- Create a copy for manipulation
    for i, poem in ipairs(poems) do
        result[i] = poem
    end
    
    -- Perform sophisticated pair swapping
    local left_index = 1
    local right_index = total_count
    
    while left_index < right_index do
        print("DEBUG: Swapping pair: " .. left_index .. " ↔ " .. right_index)
        
        -- Intermediary processing: analyze poems before swapping
        local left_poem_signature = generate_poem_signature(result[left_index])
        local right_poem_signature = generate_poem_signature(result[right_index])
        
        print("DEBUG: Left poem signature: " .. left_poem_signature)
        print("DEBUG: Right poem signature: " .. right_poem_signature)
        
        -- Perform the swap with intermediary validation
        if validate_swap_compatibility(result[left_index], result[right_index]) then
            result[left_index], result[right_index] = result[right_index], result[left_index]
            print("DEBUG: Swap completed successfully")
        else
            print("DEBUG: Swap validation failed, maintaining original positions")
        end
        
        left_index = left_index + 1
        right_index = right_index - 1
    end
    
    return result
end
-- }}}

-- {{{ identify_middle_poem
function identify_middle_poem(poems)
    local middle_index = math.ceil(#poems / 2)
    print("DEBUG: Middle poem calculation: " .. #poems .. " poems → index " .. middle_index)
    return middle_index
end
-- }}}

-- {{{ perform_cross_compilation_validation
function perform_cross_compilation_validation(poems, middle_index)
    print("DEBUG: Starting cross-compilation validation...")
    
    -- Phase 1: Middle → Top (first poem)
    print("DEBUG: Phase 1: Validating middle (" .. middle_index .. ") → top (1)")
    local middle_to_top_validation = validate_poem_sequence(poems, middle_index, 1)
    
    -- Phase 2: Top → End (last poem) 
    print("DEBUG: Phase 2: Validating top (1) → end (" .. #poems .. ")")
    local top_to_end_validation = validate_poem_sequence(poems, 1, #poems)
    
    -- Phase 3: End → Middle (return validation)
    print("DEBUG: Phase 3: Validating end (" .. #poems .. ") → middle (" .. middle_index .. ")")
    local end_to_middle_validation = validate_poem_sequence(poems, #poems, middle_index)
    
    local validation_result = {
        middle_to_top = middle_to_top_validation,
        top_to_end = top_to_end_validation,
        end_to_middle = end_to_middle_validation,
        overall_valid = middle_to_top_validation and top_to_end_validation and end_to_middle_validation
    }
    
    print("DEBUG: Cross-compilation validation result: " .. (validation_result.overall_valid and "PASSED" or "FAILED"))
    
    return validation_result
end
-- }}}

-- {{{ evaluate_middle_poem_ownership
function evaluate_middle_poem_ownership(poems, middle_index, validation_result)
    local middle_poem = poems[middle_index]
    
    print("DEBUG: Evaluating middle poem ownership...")
    
    -- Determine if middle poem content belongs to current processor
    local ownership_status = determine_poem_ownership(middle_poem)
    print("DEBUG: Middle poem ownership: " .. ownership_status)
    
    if ownership_status == "theirs" then
        print("DEBUG: Middle poem belongs to external processor, examining alternatives...")
        
        -- Generate shared conclusion including both versions
        local shared_conclusion = generate_shared_conclusion(middle_poem, validation_result)
        
        -- Insert shared conclusion while preserving original
        table.insert(poems, middle_index + 1, shared_conclusion)
        print("DEBUG: Added shared conclusion at index " .. (middle_index + 1))
    else
        print("DEBUG: Middle poem ownership confirmed as ours, proceeding with current arrangement")
    end
    
    return poems
end
-- }}}

-- {{{ generate_poem_signature
function generate_poem_signature(poem)
    if #poem == 0 then return "empty" end
    
    local first_line = poem[1] or ""
    local last_line = poem[#poem] or ""
    local line_count = #poem
    
    -- Create a simple signature based on structure
    local signature = "lines:" .. line_count .. "|first:" .. string.sub(first_line, 1, 10) .. "|last:" .. string.sub(last_line, 1, 10)
    return signature
end
-- }}}

-- {{{ validate_swap_compatibility  
function validate_swap_compatibility(poem1, poem2)
    -- Simple compatibility check based on poem structure
    local poem1_lines = #poem1
    local poem2_lines = #poem2
    
    -- Allow swaps if line count difference is reasonable
    local line_diff = math.abs(poem1_lines - poem2_lines)
    local compatibility = line_diff <= 5  -- Allow up to 5 line difference
    
    print("DEBUG: Swap compatibility check: " .. poem1_lines .. " vs " .. poem2_lines .. " lines → " .. (compatibility and "COMPATIBLE" or "INCOMPATIBLE"))
    
    return compatibility
end
-- }}}

-- {{{ validate_poem_sequence
function validate_poem_sequence(poems, start_index, end_index)
    if start_index == end_index then return true end
    
    local start_poem = poems[start_index]
    local end_poem = poems[end_index]
    
    -- Simple validation: ensure both poems exist and have content
    local validation = start_poem and #start_poem > 0 and end_poem and #end_poem > 0
    
    print("DEBUG: Sequence validation " .. start_index .. "→" .. end_index .. ": " .. (validation and "VALID" or "INVALID"))
    
    return validation
end
-- }}}

-- {{{ determine_poem_ownership
function determine_poem_ownership(poem)
    if #poem == 0 then return "unknown" end
    
    local first_line = poem[1] or ""
    
    -- Simple heuristic: check for external markers
    if first_line:match("^%s*[@#]") or first_line:match("RT:") or first_line:match("via:") then
        return "theirs"
    else
        return "ours"
    end
end
-- }}}

-- {{{ generate_shared_conclusion
function generate_shared_conclusion(original_poem, validation_result)
    local shared_conclusion = {
        "--- SHARED CONCLUSION ---",
        "",
        "Cross-compilation validation status: " .. (validation_result.overall_valid and "VALIDATED" or "UNRESOLVED"),
        "Original poem ownership: EXTERNAL",
        "Processing method: INTERMEDIARY PAIR-SWAPPING",
        "",
        "This conclusion bridges both versions:",
        "- Original external content (preserved above)",
        "- Local processor interpretation (integrated below)",
        "",
        "Validation phases completed:",
        "✓ Middle → Top: " .. (validation_result.middle_to_top and "PASSED" or "FAILED"),
        "✓ Top → End: " .. (validation_result.top_to_end and "PASSED" or "FAILED"), 
        "✓ End → Middle: " .. (validation_result.end_to_middle and "PASSED" or "FAILED"),
        "",
        "--- END SHARED CONCLUSION ---"
    }
    
    print("DEBUG: Generated shared conclusion with " .. #shared_conclusion .. " lines")
    
    return shared_conclusion
end
-- }}}

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
            book.pages[page_num] = { left = {}, right = {}, type = "text" }
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
   local page_num =  1;           book.pages[1] = { left = {}, right = {}, type = "text" }
   
   for index, poem in ipairs(book.poems) do
      -- Check if this is an image
      if #poem == 1 and poem[1]:match("^IMAGE:") then
         local image_path = poem[1]:match("^IMAGE:(.+)$")
         
         -- Images get their own dedicated page
         page_num = page_num + 1
         book.pages[page_num] = { type = "image", image_path = image_path }
         
         -- Reset for next text page
         page_num = page_num + 1
         book.pages[page_num] = { left = {}, right = {}, type = "text" }
         column = -1
         height = 0
         
      else
         -- Handle regular text content
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
                  book.pages[page_num] = { left = {}, right = {}, type = "text" }
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
               book.pages[page_num] = { left = {}, right = {}, type = "text" }
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
   end
   return book
end -- }}}

-- }}}

-- {{{ draw_image_page
function draw_image_page(pdf_page, font, image_path, page_width, page_height, margins)
    -- Check if file exists and is supported format
    if not file_exists(image_path) then
        print("Warning: Image file not found: " .. image_path)
        return false
    end
    
    local file_ext = image_path:match("%.([^%.]+)$")
    if not file_ext then
        print("Warning: Could not determine file extension for: " .. image_path)
        return false
    end
    file_ext = file_ext:lower()
    
    local image = nil
    
    -- Load image based on file type
    if file_ext == "png" then
        image = hpdf.LoadPngImageFromFile(pdf_global, image_path)
    elseif file_ext == "jpg" or file_ext == "jpeg" then
        image = hpdf.LoadJpegImageFromFile(pdf_global, image_path)
    else
        print("Warning: Unsupported image format: " .. file_ext)
        return false
    end
    
    if not image then
        print("Warning: Failed to load image: " .. image_path)
        return false
    end
    
    -- Get image dimensions
    local img_width = hpdf.Image_GetWidth(image)
    local img_height = hpdf.Image_GetHeight(image)
    
    -- Calculate available space (leaving margins)
    local available_width = page_width - margins.left - margins.right
    local available_height = page_height - margins.top - margins.bottom
    
    -- Scale image to fit while maintaining aspect ratio
    local scale_x = available_width / img_width
    local scale_y = available_height / img_height
    local scale = math.min(scale_x, scale_y, 1.0) -- Don't upscale
    
    local display_width = img_width * scale
    local display_height = img_height * scale
    
    -- Center the image on the page
    local x = margins.left + (available_width - display_width) / 2
    local y = margins.bottom + (available_height - display_height) / 2
    
    -- Draw the image
    hpdf.Page_DrawImage(pdf_page, image, x, y, display_width, display_height)
    
    -- Add image caption/filename at bottom
    local filename = image_path:match("([^/]+)$")
    hpdf.Page_SetFontAndSize(pdf_page, font, FONT_SIZE * 2)
    hpdf.Page_SetRGBFill(pdf_page, 0.3, 0.3, 0.3) -- Dark gray text
    
    hpdf.Page_BeginText(pdf_page)
    local caption_x = margins.left + (available_width / 2) - (#filename * FONT_SIZE)
    hpdf.Page_MoveTextPos(pdf_page, caption_x, margins.bottom - 20)
    hpdf.Page_ShowText(pdf_page, filename)
    hpdf.Page_EndText(pdf_page)
    
    return true
end
-- }}}

-- {{{ file_exists
function file_exists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end
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

-- AI-powered theme analysis using fuzzy-computing
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
    
    -- Try to get AI analysis (disabled for now due to missing luasocket)
    -- local success, result = pcall(fuzz.generate, context, "llama3.2:latest")
    -- if success and result then
    --     local theme = result:lower():match("(%a+)")
    --     if theme and (theme == "nature" or theme == "urban" or theme == "love" or 
    --                   theme == "melancholy" or theme == "energy" or theme == "dream" or
    --                   theme == "constellation" or theme == "spiral" or theme == "circuit" or
    --                   theme == "lightning" or theme == "crystal") then
    --         return theme
    --     end
    -- end
    
    -- Fallback to basic analysis (using this for now)
    return analyze_column_basic(column_poems)
end -- }}}

-- Individual poem theme analysis (using same logic as column analysis but for single poem)
function analyze_individual_poem_theme(poem) -- {{{
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

-- Theme-based color generation (much faster than individual AI analysis)
function generate_poem_color_from_theme(poem, theme) -- {{{
    local theme_colors = {
        nature =      {0.90, 0.95, 0.85}, -- Light green tint
        urban =       {0.85, 0.90, 0.95}, -- Light blue tint  
        love =        {0.98, 0.88, 0.90}, -- Light pink tint
        melancholy =  {0.88, 0.88, 0.93}, -- Light gray-blue
        energy =      {0.98, 0.93, 0.80}, -- Light yellow tint
        dream =       {0.93, 0.90, 0.98}, -- Light purple tint
        constellation = {0.88, 0.88, 0.88}, -- Light gray
        spiral =      {0.92, 0.88, 0.95}, -- Light lavender
        circuit =     {0.85, 0.95, 0.90}, -- Light mint
        lightning =   {0.95, 0.95, 0.85}, -- Light cream-yellow
        crystal =     {0.90, 0.93, 0.98}, -- Light crystal blue
        neutral =     {0.93, 0.93, 0.93}  -- Light gray
    }
    
    local base_color = theme_colors[theme] or theme_colors.neutral
    
    -- Add slight variation based on poem content for uniqueness
    local poem_text = table.concat(poem, " ")
    local variation = 0.03 * ((#poem_text % 7) / 7 - 0.5) -- Small variation ±0.015
    
    return {
        math.max(0.75, math.min(0.98, base_color[1] + variation)),
        math.max(0.75, math.min(0.98, base_color[2] + variation)),
        math.max(0.75, math.min(0.98, base_color[3] + variation))
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
        hpdf.Page_SetRGBStroke(pdf_page, 0.3, 0.6, 0.8) -- Ocean blue
        hpdf.Page_SetLineWidth(pdf_page, 0.5)
        
        for i = 1, fish_count do
            local start_x = space.x + math.random() * space.width
            local start_y = space.y + math.random() * space.height
            local length = 3 + math.random() * 8
            local angle = math.random() * math.pi * 2
            
            local end_x = start_x + math.cos(angle) * length
            local end_y = start_y + math.sin(angle) * length
            
            hpdf.Page_MoveTo(pdf_page, start_x, start_y)
            hpdf.Page_LineTo(pdf_page, end_x, end_y)
            hpdf.Page_Stroke(pdf_page)
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
            hpdf.Page_SetRGBStroke(pdf_page, color[1], color[2], color[3])
            hpdf.Page_SetLineWidth(pdf_page, 1.0 + math.random() * 2)
            
            local x1 = space.x + math.random() * space.width
            local y1 = space.y + math.random() * space.height
            local x2 = x1 + (math.random() - 0.5) * 20
            local y2 = y1 + (math.random() - 0.5) * 20
            
            hpdf.Page_MoveTo(pdf_page, x1, y1)
            hpdf.Page_LineTo(pdf_page, x2, y2)
            hpdf.Page_Stroke(pdf_page)
        end
    end
end -- }}}

function generate_vaporwave_grid(pdf_page, spaces, analysis) -- {{{
    -- Retro grid patterns with pink/blue gradients
    hpdf.Page_SetRGBStroke(pdf_page, 1.0, 0.4, 0.8) -- Hot pink
    hpdf.Page_SetLineWidth(pdf_page, 0.3)
    
    for _, space in ipairs(spaces.left_margin) do
        -- Vertical lines
        for x = space.x, space.x + space.width, 5 do
            hpdf.Page_MoveTo(pdf_page, x, space.y)
            hpdf.Page_LineTo(pdf_page, x, space.y + space.height)
            hpdf.Page_Stroke(pdf_page)
        end
        
        -- Horizontal lines with perspective effect
        local line_spacing = 8
        for i = 0, math.floor(space.height / line_spacing) do
            local y = space.y + i * line_spacing
            local wave_offset = math.sin(i * 0.3) * 5
            
            hpdf.Page_MoveTo(pdf_page, space.x + wave_offset, y)
            hpdf.Page_LineTo(pdf_page, space.x + space.width + wave_offset, y)
            hpdf.Page_Stroke(pdf_page)
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
    if theme == "nature" then
        -- Organic flowing particles
        for _, space in ipairs(space_list) do
            hpdf.Page_SetRGBStroke(pdf_page, 0.3, 0.6, 0.3) -- Forest green
            hpdf.Page_SetLineWidth(pdf_page, 0.5)
            
            local particle_count = math.floor(20 * intensity_multiplier)
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
            local shape_count = math.floor(15 * intensity_multiplier)
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
            
            local burst_count = math.floor(25 * intensity_multiplier)
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
            
            local curve_count = math.floor(18 * intensity_multiplier)
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
            
            local drop_count = math.floor(22 * intensity_multiplier)
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
            
            local wave_count = math.floor(12 * intensity_multiplier)
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
            local star_count = math.floor(8 * intensity_multiplier)
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
                        if distance < 50 and math.random() > 0.3 then
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
            
            local spiral_count = math.floor(6 * intensity_multiplier)
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
            
            local path_count = math.floor(10 * intensity_multiplier)
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
            
            local bolt_count = math.floor(8 * intensity_multiplier)
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
            
            local crystal_count = math.floor(12 * intensity_multiplier)
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
        -- Sharp stalagmites and stalactites (cursed default theme)
        generate_sharp_stalagmites(pdf_page, space_list, intensity_multiplier)
    end
end -- }}}

-- Column-specific art generators (updated to use all available spaces)
function generate_column_art(pdf_page, spaces, theme, is_left_column) -- {{{
    if is_left_column then
        -- Use left-side spaces
        draw_theme_art_in_spaces(pdf_page, spaces.left_outer, theme, 0.8)
        draw_theme_art_in_spaces(pdf_page, spaces.left_inner, theme, 1.2)
        -- Also add some art in bottom empty spaces
        for _, space in ipairs(spaces.bottom_space) do
            if space.column == "left" then
                draw_theme_art_in_spaces(pdf_page, {space}, theme, 1.5)
            end
        end
    else
        -- Use right-side spaces
        draw_theme_art_in_spaces(pdf_page, spaces.right_inner, theme, 1.2)
        draw_theme_art_in_spaces(pdf_page, spaces.right_outer, theme, 0.8)
        -- Also add some art in bottom empty spaces
        for _, space in ipairs(spaces.bottom_space) do
            if space.column == "right" then
                draw_theme_art_in_spaces(pdf_page, {space}, theme, 1.5)
            end
        end
    end
    
    -- Always add subtle art around center divider
    draw_theme_art_in_spaces(pdf_page, spaces.center, theme, 0.4)
end -- }}}

-- Calculate poem box positions for masking
function calculate_poem_box_positions(page_poems, page_width, page_height, margins, column_width, column_gap, page_shift, line_height) -- {{{
    local poem_boxes = {}
    
    -- Calculate column positions (matching main drawing logic)
    local left_column_x = margins.left - page_shift
    local right_column_x = margins.left + column_width + column_gap - page_shift
    
    -- Process left column poems
    local current_y = page_height - margins.top
    for _, poem in ipairs(page_poems.left or {}) do
        if #poem > 0 then
            -- Calculate poem box dimensions (matching draw_boxed_poem logic)
            local poem_width = 0
            for _, line in ipairs(poem) do
                if #line > poem_width then poem_width = #line end
            end
            poem_width = poem_width + 4 -- Add padding
            local box_width = math.min(poem_width, column_width - 2)
            
            -- For masking, we need to convert character count to pixel width
            -- Courier font at size 5: approximately 0.6 * font_size per character
            local char_width = 0.6 * FONT_SIZE
            local mask_width_pixels = math.max(box_width, poem_width) * char_width
            
            -- Debug: Let's see what's happening with width calculations
            if page_num == 1 then
                print("Poem lines:", #poem, "Poem width calc:", poem_width, "Box width:", box_width, "Mask width pixels:", mask_width_pixels, "Column width:", column_width)
            end
            
            -- Calculate poem height (including borders and padding)
            local poem_box_height = (#poem + 4) * line_height -- poem + top/bottom borders + padding
            
            -- Center the box within the column (matching draw_boxed_poem centering logic)
            local actual_x = left_column_x + (column_width - box_width) / 2
            
            -- Generate theme-based color for this poem (using individual poem analysis)
            local individual_theme = analyze_individual_poem_theme(poem)
            local poem_color = generate_poem_color_from_theme(poem, individual_theme)
            
            table.insert(poem_boxes, {
                x = actual_x,
                y = current_y - poem_box_height + line_height, -- Move up one line
                width = mask_width_pixels, -- Use pixel-based mask width
                height = poem_box_height,
                color = poem_color -- Add AI-generated color
            })
            
            current_y = current_y - poem_box_height - line_height -- Move down for next poem
        end
    end
    
    -- Process right column poems
    current_y = page_height - margins.top
    for _, poem in ipairs(page_poems.right or {}) do
        if #poem > 0 then
            -- Calculate poem box dimensions
            local poem_width = 0
            for _, line in ipairs(poem) do
                if #line > poem_width then poem_width = #line end
            end
            poem_width = poem_width + 4
            local box_width = math.min(poem_width, column_width - 2)
            
            -- For masking, we need to convert character count to pixel width
            -- Courier font at size 5: approximately 0.6 * font_size per character
            local char_width = 0.6 * FONT_SIZE
            local mask_width_pixels = math.max(box_width, poem_width) * char_width
            
            -- Calculate poem height
            local poem_box_height = (#poem + 4) * line_height
            
            -- Center the box within the column
            local actual_x = right_column_x + (column_width - box_width) / 2
            
            -- Generate theme-based color for this poem (using individual poem analysis)
            local individual_theme = analyze_individual_poem_theme(poem)
            local poem_color = generate_poem_color_from_theme(poem, individual_theme)
            
            table.insert(poem_boxes, {
                x = actual_x,
                y = current_y - poem_box_height + line_height, -- Move up one line
                width = mask_width_pixels, -- Use pixel-based mask width
                height = poem_box_height,
                color = poem_color -- Add AI-generated color
            })
            
            current_y = current_y - poem_box_height - line_height
        end
    end
    
    return poem_boxes
end -- }}}

-- Mask poem areas with individual colors (AI-generated)
function mask_poem_areas(pdf_page, poem_boxes) -- {{{
    -- Draw filled rectangles with individual colors for each poem area
    for _, box in ipairs(poem_boxes) do
        -- Use poem's individual color or fallback to default
        local color = box.color or BACKGROUND_COLOR
        hpdf.Page_SetRGBFill(pdf_page, color[1], color[2], color[3])
        
        hpdf.Page_Rectangle(pdf_page, box.x, box.y, box.width, box.height)
        hpdf.Page_Fill(pdf_page)
    end
end -- }}}

-- Main art generation dispatcher (updated for AI analysis)
function generate_page_art(pdf_page, page_poems, page_width, page_height, margins, column_width, column_gap, page_shift, line_height) -- {{{
    -- Analyze each column separately with AI
    local left_theme = analyze_column_with_ai(page_poems.left or {})
    local right_theme = analyze_column_with_ai(page_poems.right or {})
    
    print("Page themes: Left=" .. left_theme .. ", Right=" .. right_theme)
    
    -- Calculate all available spaces
    local spaces = calculate_art_spaces(page_poems, page_width, page_height, margins, column_width, column_gap, page_shift)
    
    -- If both columns have same theme, generate full-page art
    if left_theme == right_theme and left_theme ~= "neutral" then
        print("Generating full-page " .. left_theme .. " art")
        if left_theme == "nature" then
            generate_fullpage_nature(pdf_page, page_width, page_height, margins)
        elseif left_theme == "urban" then
            generate_fullpage_urban(pdf_page, page_width, page_height, margins)
        elseif left_theme == "dream" then
            generate_fullpage_dream(pdf_page, page_width, page_height, margins)
        end
    else
        -- Generate column-specific art in all available spaces
        generate_column_art(pdf_page, spaces, left_theme, true)
        generate_column_art(pdf_page, spaces, right_theme, false)
    end
    
    -- Generate evil yeti (every ~40 pages)
    if should_draw_yeti(page_num) then
        -- Place yeti in background areas where they won't interfere with text
        local yeti_count = 1 + math.random(2)  -- 1-3 yeti per page when they appear
        
        for i = 1, yeti_count do
            -- Choose background location (margins, bottom spaces)
            local location_type = math.random(4)
            local yeti_x, yeti_y
            
            if location_type == 1 then
                -- Left outer margin
                yeti_x = 15 + math.random(20)
                yeti_y = 50 + math.random(page_height - 200)
            elseif location_type == 2 then
                -- Right outer margin
                yeti_x = page_width - 60 + math.random(20)
                yeti_y = 50 + math.random(page_height - 200)
            elseif location_type == 3 then
                -- Center divider area
                local divider_pos = left_margin + column_width + (column_gap / 2)
                yeti_x = divider_pos - 25 + math.random(50)
                yeti_y = 50 + math.random(page_height - 200)
            else
                -- Bottom area
                yeti_x = 50 + math.random(page_width - 100)
                yeti_y = 20 + math.random(50)
            end
            
            local size_variant = math.random()  -- 0.0 to 1.0 for size variation
            generate_evil_yeti(pdf_page, yeti_x, yeti_y, size_variant)
        end
        
        print("🏔️ Evil yeti summoned on page " .. page_num .. "!")
    end
    
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

-- CURSED YETI AND STALAGMITE GENERATION ---- {{{

-- {{{ generate_sharp_stalagmites
function generate_sharp_stalagmites(pdf_page, spaces, intensity_multiplier)
    -- Sharp, painful stalagmite and stalactite patterns
    -- Like lines carved in butter, blood, or stone
    
    hpdf.Page_SetRGBStroke(pdf_page, 0.1, 0.1, 0.1) -- Very dark gray, almost black
    hpdf.Page_SetLineWidth(pdf_page, 0.8)
    
    for _, space in ipairs(spaces) do
        local formation_count = math.floor(8 * intensity_multiplier)
        
        for i = 1, formation_count do
            -- Randomly choose stalagmite or stalactite
            local is_stalactite = math.random() > 0.5
            local base_x = space.x + math.random() * (space.width - 20)
            local formation_height = 15 + math.random(25)
            
            if is_stalactite then
                -- Stalactites hang from top
                local top_y = space.y + space.height - 5
                local tip_y = top_y - formation_height
                
                -- Create sharp, jagged formation with mathematical precision
                local segments = 4 + math.random(6)
                local current_y = top_y
                local current_width = 8 + math.random(8)
                
                for seg = 1, segments do
                    local segment_height = formation_height / segments
                    local next_y = current_y - segment_height
                    local width_reduction = current_width * (0.7 + math.random() * 0.2)
                    
                    -- Left edge with sharp variations
                    local left_x = base_x - current_width/2 + (math.random() - 0.5) * 3
                    local right_x = base_x + current_width/2 + (math.random() - 0.5) * 3
                    local next_left_x = base_x - width_reduction/2 + (math.random() - 0.5) * 2
                    local next_right_x = base_x + width_reduction/2 + (math.random() - 0.5) * 2
                    
                    -- Draw jagged edges
                    hpdf.Page_MoveTo(pdf_page, left_x, current_y)
                    hpdf.Page_LineTo(pdf_page, next_left_x, next_y)
                    hpdf.Page_Stroke(pdf_page)
                    
                    hpdf.Page_MoveTo(pdf_page, right_x, current_y)
                    hpdf.Page_LineTo(pdf_page, next_right_x, next_y)
                    hpdf.Page_Stroke(pdf_page)
                    
                    current_y = next_y
                    current_width = width_reduction
                end
                
                -- Sharp tip
                hpdf.Page_MoveTo(pdf_page, base_x - current_width/2, current_y)
                hpdf.Page_LineTo(pdf_page, base_x, current_y - 5)
                hpdf.Page_LineTo(pdf_page, base_x + current_width/2, current_y)
                hpdf.Page_Stroke(pdf_page)
                
            else
                -- Stalagmites rise from bottom
                local bottom_y = space.y + 5
                local tip_y = bottom_y + formation_height
                
                -- Create sharp, jagged formation
                local segments = 4 + math.random(6)
                local current_y = bottom_y
                local current_width = 8 + math.random(8)
                
                for seg = 1, segments do
                    local segment_height = formation_height / segments
                    local next_y = current_y + segment_height
                    local width_reduction = current_width * (0.7 + math.random() * 0.2)
                    
                    -- Jagged edges with statistical fuzziness
                    local left_x = base_x - current_width/2 + (math.random() - 0.5) * 3
                    local right_x = base_x + current_width/2 + (math.random() - 0.5) * 3
                    local next_left_x = base_x - width_reduction/2 + (math.random() - 0.5) * 2
                    local next_right_x = base_x + width_reduction/2 + (math.random() - 0.5) * 2
                    
                    hpdf.Page_MoveTo(pdf_page, left_x, current_y)
                    hpdf.Page_LineTo(pdf_page, next_left_x, next_y)
                    hpdf.Page_Stroke(pdf_page)
                    
                    hpdf.Page_MoveTo(pdf_page, right_x, current_y)
                    hpdf.Page_LineTo(pdf_page, next_right_x, next_y)
                    hpdf.Page_Stroke(pdf_page)
                    
                    current_y = next_y
                    current_width = width_reduction
                end
                
                -- Sharp tip pointing upward
                hpdf.Page_MoveTo(pdf_page, base_x - current_width/2, current_y)
                hpdf.Page_LineTo(pdf_page, base_x, current_y + 5)
                hpdf.Page_LineTo(pdf_page, base_x + current_width/2, current_y)
                hpdf.Page_Stroke(pdf_page)
            end
        end
        
        -- Add some horizontal cutting lines for extra sharpness
        local cut_count = math.floor(5 * intensity_multiplier)
        hpdf.Page_SetLineWidth(pdf_page, 0.4)
        for c = 1, cut_count do
            local y = space.y + math.random() * space.height
            local x1 = space.x + math.random() * (space.width - 30)
            local x2 = x1 + 10 + math.random(20)
            
            hpdf.Page_MoveTo(pdf_page, x1, y)
            hpdf.Page_LineTo(pdf_page, x2, y)
            hpdf.Page_Stroke(pdf_page)
        end
    end
end
-- }}}

-- {{{ generate_evil_yeti
function generate_evil_yeti(pdf_page, x, y, size_variant)
    -- Generate an evil yeti with emerald eyes and possibly cypress weapons
    -- Grayish dark light coloring with various shapes and sizes
    
    local base_size = 20 + size_variant * 15  -- Varying sizes
    local body_color = {0.2, 0.2, 0.25}  -- Grayish dark
    local eye_color = {0.0, 0.8, 0.4}    -- Emerald green
    local weapon_color = {0.4, 0.2, 0.1} -- Dark brown for cypress
    
    -- Body shape (varies between humanoid shapes)
    local shape_type = math.random(4)
    
    if shape_type == 1 then
        -- Bulky rectangular yeti
        hpdf.Page_SetRGBFill(pdf_page, body_color[1], body_color[2], body_color[3])
        hpdf.Page_Rectangle(pdf_page, x - base_size/2, y, base_size, base_size * 1.5)
        hpdf.Page_Fill(pdf_page)
        
        -- Arms
        hpdf.Page_Rectangle(pdf_page, x - base_size * 0.8, y + base_size * 0.3, base_size * 0.3, base_size * 0.8)
        hpdf.Page_Fill(pdf_page)
        hpdf.Page_Rectangle(pdf_page, x + base_size * 0.5, y + base_size * 0.3, base_size * 0.3, base_size * 0.8)
        hpdf.Page_Fill(pdf_page)
        
    elseif shape_type == 2 then
        -- Triangular/pyramid yeti
        hpdf.Page_SetRGBFill(pdf_page, body_color[1], body_color[2], body_color[3])
        hpdf.Page_MoveTo(pdf_page, x, y + base_size * 1.5)  -- Top point
        hpdf.Page_LineTo(pdf_page, x - base_size, y)         -- Bottom left
        hpdf.Page_LineTo(pdf_page, x + base_size, y)         -- Bottom right
        hpdf.Page_LineTo(pdf_page, x, y + base_size * 1.5)   -- Back to top
        hpdf.Page_Fill(pdf_page)
        
    elseif shape_type == 3 then
        -- Hunched, organic yeti
        hpdf.Page_SetRGBFill(pdf_page, body_color[1], body_color[2], body_color[3])
        -- Body segments for organic look
        for i = 1, 5 do
            local segment_y = y + (i-1) * base_size * 0.3
            local segment_width = base_size * (0.8 - i * 0.1)
            hpdf.Page_Rectangle(pdf_page, x - segment_width/2, segment_y, segment_width, base_size * 0.35)
            hpdf.Page_Fill(pdf_page)
        end
        
    else
        -- Tall, spindly yeti
        hpdf.Page_SetRGBFill(pdf_page, body_color[1], body_color[2], body_color[3])
        hpdf.Page_Rectangle(pdf_page, x - base_size * 0.3, y, base_size * 0.6, base_size * 2)
        hpdf.Page_Fill(pdf_page)
        
        -- Long thin arms
        hpdf.Page_Rectangle(pdf_page, x - base_size * 0.9, y + base_size * 0.8, base_size * 0.2, base_size * 1.2)
        hpdf.Page_Fill(pdf_page)
        hpdf.Page_Rectangle(pdf_page, x + base_size * 0.7, y + base_size * 0.8, base_size * 0.2, base_size * 1.2)
        hpdf.Page_Fill(pdf_page)
    end
    
    -- Emerald eyes (always present)
    hpdf.Page_SetRGBFill(pdf_page, eye_color[1], eye_color[2], eye_color[3])
    local eye_y = y + base_size * 1.2
    hpdf.Page_Rectangle(pdf_page, x - base_size * 0.2, eye_y, base_size * 0.1, base_size * 0.1)
    hpdf.Page_Fill(pdf_page)
    hpdf.Page_Rectangle(pdf_page, x + base_size * 0.1, eye_y, base_size * 0.1, base_size * 0.1)
    hpdf.Page_Fill(pdf_page)
    
    -- Cypress weapon (50% chance)
    if math.random() > 0.5 then
        hpdf.Page_SetRGBStroke(pdf_page, weapon_color[1], weapon_color[2], weapon_color[3])
        hpdf.Page_SetLineWidth(pdf_page, 2.0)
        
        local weapon_type = math.random(3)
        if weapon_type == 1 then
            -- Cypress staff
            local staff_x = x + base_size * 0.8
            local staff_length = base_size * 2.5
            hpdf.Page_MoveTo(pdf_page, staff_x, y)
            hpdf.Page_LineTo(pdf_page, staff_x, y + staff_length)
            hpdf.Page_Stroke(pdf_page)
            
            -- Staff head (sharp)
            hpdf.Page_MoveTo(pdf_page, staff_x - 3, y + staff_length - 5)
            hpdf.Page_LineTo(pdf_page, staff_x, y + staff_length + 3)
            hpdf.Page_LineTo(pdf_page, staff_x + 3, y + staff_length - 5)
            hpdf.Page_Stroke(pdf_page)
            
        elseif weapon_type == 2 then
            -- Cypress club
            local club_x = x - base_size * 0.8
            local club_length = base_size * 1.8
            hpdf.Page_MoveTo(pdf_page, club_x, y + base_size * 0.5)
            hpdf.Page_LineTo(pdf_page, club_x - club_length * 0.7, y + base_size * 1.2)
            hpdf.Page_Stroke(pdf_page)
            
            -- Club head (thick)
            hpdf.Page_SetLineWidth(pdf_page, 4.0)
            hpdf.Page_MoveTo(pdf_page, club_x - club_length * 0.7 - 5, y + base_size * 1.2 - 5)
            hpdf.Page_LineTo(pdf_page, club_x - club_length * 0.7 + 5, y + base_size * 1.2 + 5)
            hpdf.Page_Stroke(pdf_page)
            
        else
            -- Cypress spear
            local spear_x = x + base_size * 0.6
            local spear_length = base_size * 3
            local spear_angle = math.random() * 0.5 - 0.25  -- Slight angle variation
            
            local end_x = spear_x + math.sin(spear_angle) * spear_length
            local end_y = y + base_size + math.cos(spear_angle) * spear_length
            
            hpdf.Page_MoveTo(pdf_page, spear_x, y + base_size)
            hpdf.Page_LineTo(pdf_page, end_x, end_y)
            hpdf.Page_Stroke(pdf_page)
            
            -- Spear tip
            hpdf.Page_MoveTo(pdf_page, end_x - 3, end_y - 8)
            hpdf.Page_LineTo(pdf_page, end_x, end_y)
            hpdf.Page_LineTo(pdf_page, end_x + 3, end_y - 8)
            hpdf.Page_Stroke(pdf_page)
        end
    end
end
-- }}}

-- {{{ should_draw_yeti
function should_draw_yeti(page_num)
    -- Every 40 pages or so (with some randomness for unpredictability)
    local base_interval = 40
    local variation = 10  -- ±10 pages
    local next_yeti_page = base_interval + math.random(-variation, variation)
    
    return (page_num % next_yeti_page) == 0 or 
           (page_num > 1 and (page_num - 1) % next_yeti_page == 0)
end
-- }}}

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

    -- Add content warning page (first page)
    local warning_page = hpdf.AddPage(pdf)
    hpdf.Page_SetSize(warning_page, hpdf.PAGE_SIZE_A4, hpdf.PAGE_PORTRAIT)
    hpdf.Page_SetFontAndSize(warning_page, font, font_size * 3) -- Larger font for warning
    
    -- Set background to milky white with very faint red tint
    hpdf.Page_SetRGBFill(warning_page, 0.98, 0.95, 0.97) -- Milky white with hint of pink
    hpdf.Page_Rectangle(warning_page, 0, 0, page_width, page_height)
    hpdf.Page_Fill(warning_page)
    
    -- Content warning text in bright red
    hpdf.Page_SetRGBFill(warning_page, 0.9, 0.2, 0.1) -- Bright red, slightly orange
    hpdf.Page_BeginText(warning_page)
    hpdf.Page_MoveTextPos(warning_page, page_width/2 - 150, page_height/2 + 50)
    hpdf.Page_ShowText(warning_page, "WARNING:")
    hpdf.Page_EndText(warning_page)
    
    -- Main warning text
    hpdf.Page_SetFontAndSize(warning_page, font, font_size * 2)
    hpdf.Page_BeginText(warning_page)
    hpdf.Page_MoveTextPos(warning_page, page_width/2 - 180, page_height/2 - 20)
    hpdf.Page_ShowText(warning_page, "This book will spontaneously")
    hpdf.Page_EndText(warning_page)
    
    hpdf.Page_BeginText(warning_page)
    hpdf.Page_MoveTextPos(warning_page, page_width/2 - 100, page_height/2 - 50)
    hpdf.Page_ShowText(warning_page, "summon yetis")
    hpdf.Page_EndText(warning_page)
    
    -- Additional safety warning
    hpdf.Page_SetFontAndSize(warning_page, font, font_size * 1.5)
    hpdf.Page_SetRGBFill(warning_page, 0.8, 0.1, 0.0) -- Darker red for additional warning
    hpdf.Page_BeginText(warning_page)
    hpdf.Page_MoveTextPos(warning_page, page_width/2 - 160, page_height/2 - 120)
    hpdf.Page_ShowText(warning_page, "Please only read while")
    hpdf.Page_EndText(warning_page)
    
    hpdf.Page_BeginText(warning_page)
    hpdf.Page_MoveTextPos(warning_page, page_width/2 - 140, page_height/2 - 150)
    hpdf.Page_ShowText(warning_page, "bearing a sword, in public")
    hpdf.Page_EndText(warning_page)
    
    -- Add some ominous stalagmite decorations around the warning
    local warning_spaces = {
        {x = 50, y = 100, width = 100, height = 200},
        {x = page_width - 150, y = 100, width = 100, height = 200},
        {x = page_width/2 - 50, y = 50, width = 100, height = 100},
        {x = page_width/2 - 50, y = page_height - 150, width = 100, height = 100}
    }
    generate_sharp_stalagmites(warning_page, warning_spaces, 1.5)
    
    -- Loop over content pages
    for page_num, page in ipairs(book.pages) do
        local pdf_page = hpdf.AddPage(pdf)
        hpdf.Page_SetSize(pdf_page, hpdf.PAGE_SIZE_A4, hpdf.PAGE_PORTRAIT)
        hpdf.Page_SetFontAndSize(pdf_page, font, font_size)

        if page.type == "image" then
            -- Handle image page
            local margins = {
                left = left_margin,
                right = right_margin,
                top = top_margin,
                bottom = bottom_margin
            }
            
            -- Store current PDF reference for image loading
            pdf_global = pdf
            draw_image_page(pdf_page, font, page.image_path, page_width, page_height, margins)
            
        else
            -- Handle text page
            -- Calculate 15% page shift to the left
            local page_shift = page_width * 0.15
            
            -- STEP 1: Generate art based on page content (FIRST!)
            local margins = {
                left = left_margin,
                right = right_margin,
                top = top_margin,
                bottom = bottom_margin
            }
            generate_page_art(pdf_page, page, page_width, page_height, margins, column_width, column_gap, page_shift, line_height)
            
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
            for _, poem in ipairs(page.left or {}) do
                y = draw_boxed_poem(pdf_page, font, poem, x, y, column_width, line_height, min_y, "center")
                y = y - line_height -- blank line between poems
            end

            -- STEP 4: Draw right column with boxes (after masking, so text appears on top)
            x = left_margin + column_width + column_gap - page_shift
            y = page_height - top_margin
            for _, poem in ipairs(page.right or {}) do
                y = draw_boxed_poem(pdf_page, font, poem, x, y, column_width, line_height, min_y, "center")
                y = y - line_height -- blank line between poems
            end
        end
    end

    -- Save and free
    local output_path = "output.pdf"
    hpdf.SaveToFile(pdf, output_path)
    hpdf.Free(pdf)

    print("PDF saved to " .. output_path)
    return output_path
end -- }}}

function main(    )
              book = {  pages = {}, poems = {},  }
              book = load_all_content_chronologically(book)
              book = build_book (book)
--              book = build_color(book)
               pdf = build_pdf  (book)
               print("Content items:", #book.poems, "Pages:", #book.pages)

end

main()

