-- don't forget to add the my-art and things-i-almost-posted to the pdf

 DIR = arg[1]
FILE = arg[2]

package.cpath = package.cpath .. ";" .. DIR .. "/libs/luahpdf/?.so"
package.cpath = package.cpath .. ";" .. DIR .. "/libs/libharu-RELEASE_2_3_0/build/src/?.so"
package.path = package.path .. ";" .. DIR .. "/libs/?.lua"

hpdf = require "hpdf"
-- fuzz = require "fuzzy-computing"  -- Disabled for now

-- Layout Configuration Variables
MAX_LINES_PER_PAGE = 155  -- Lines per page column (reduced for padding and larger boxes)
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
     local poem = {    }
             local file =  io.open( FILE, "r")
            if not file then print("FILE cannot be found") end
       for line in file:lines() do
        if line ~= string.rep("-", 80) then
                 table.insert(--[[ --> ]] poem, line)
            else table.insert(book.poems, poem)
                                          poem = {}
        end;
       end;        file:close()

            return book
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
    for page_num, page in ipairs(book.pages) do
        local pdf_page = hpdf.AddPage(pdf)
        hpdf.Page_SetSize(pdf_page, hpdf.PAGE_SIZE_A4, hpdf.PAGE_PORTRAIT)
        hpdf.Page_SetFontAndSize(pdf_page, font, font_size)

        -- Draw column divider (all the way to top)
        local divider_x = left_margin + column_width + (column_gap / 2)
        for div_y = 0, page_height - bottom_margin, line_height do
            if div_y < page_height - bottom_margin then
                hpdf.Page_BeginText(pdf_page)
                hpdf.Page_MoveTextPos(pdf_page, divider_x, page_height - div_y)
                hpdf.Page_ShowText(pdf_page, BOX_VERTICAL)
                hpdf.Page_EndText(pdf_page)
            end
        end

        -- Calculate 15% page shift to the left
        local page_shift = page_width * 0.15
        
        -- Draw left column with boxes (centered, shifted left)
        local x = left_margin - page_shift
        local y = page_height - top_margin
        for _, poem in ipairs(page.left) do
            y = draw_boxed_poem(pdf_page, font, poem, x, y, column_width, line_height, min_y, "center")
            y = y - line_height -- blank line between poems
        end

        -- Draw right column with boxes (centered, shifted left)
        x = left_margin + column_width + column_gap - page_shift
        y = page_height - top_margin
        for _, poem in ipairs(page.right) do
            y = draw_boxed_poem(pdf_page, font, poem, x, y, column_width, line_height, min_y, "center")
            y = y - line_height -- blank line between poems
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
              book =  load_file (book)
              book = build_book (book)
--              book = build_color(book)
               pdf = build_pdf  (book)
               print("Poems:", #book.poems, "Pages:", #book.pages)

end

main()

