-- don't forget to add the my-art and things-i-almost-posted to the pdf

 DIR = arg[1]
FILE = arg[2]

-- Issue 027: --natural-themes (parsed positional-agnostically from arg[])
-- disables the frequency-weighted theme picker at all three tiers and
-- selects each theme by raw cosine similarity alone. The flag is for
-- comparing balanced-distribution output against natural-ranking output;
-- see issues/027-natural-themes-flag.md for the design discussion.
NATURAL_THEMES = false
for i = 1, #arg do
    if arg[i] == "--natural-themes" then NATURAL_THEMES = true end
end

package.cpath = package.cpath .. ";" .. DIR .. "/libs/luahpdf/?.so"
package.cpath = package.cpath .. ";" .. DIR .. "/libs/libharu-RELEASE_2_3_0/build/src/?.so"
package.path = package.path .. ";" .. DIR .. "/libs/?.lua"
package.path = package.path .. ";" .. DIR .. "/?.lua"

hpdf = require "hpdf"
fuzz = require "libs/fuzzy-computing"
palette = require "themes/palette"
art = require "libs/art-primitives"
-- Issue 030 Phase 3: parameter axes are no longer hand-curated per theme;
-- they are derived per-cluster by themes-v2/name-clusters.lua and stored
-- in themes/derived-taxonomy.lua's tier1_parameter_axes field.
generators = require "themes/generators"
-- Issue 026: in-place redrawing progress region for the page loop in build_pdf.
-- Owns the per-page status frame on /dev/tty (with colored gradient bar) and
-- mirrors every line into $LOG_FILE as plain text.
progress_ui = require "libs/progress-ui"

-- LLM settings — embedding model name must match the GGUF that the embedding
-- llama-server instance was launched with. scripts/start-llamacpp-server.sh
-- loads models/nomic-embed-text-v1.5.Q8_0.gguf and exposes it under the
-- model id "nomic-embed-text:v1.5" (the metadata field embedded in the
-- GGUF). If you change the model file or its tagged name, update this
-- constant to match.
-- nomic-embed-text:v1.5 is a purpose-built encoder-only embedder (137M params,
-- 768-dim output, 8K context). Chosen over qwen3-embedding:4b because qwen3
-- produced near-identical similarity scores for short-text-vs-keyword comparisons
-- (all in 0.88-0.90 range), making per-poem classification unreliable.
-- Nomic is better-calibrated for short-document retrieval and runs much faster.
--
-- Context window is fixed at server-launch time now (issue 025).
-- scripts/start-llamacpp-server.sh passes --ctx-size 8192 to the embedding
-- server, matching nomic-embed-text's native context. We can no longer
-- override it per-request the way Ollama allowed; if a longer window is
-- needed, raise it in the start script and restart the server.
--
-- NOMIC_PREFIX: nomic-embed-text-v1.5 is a task-prefixed model. Without a
-- prefix telling it what the embedding is for, quality drops noticeably.
-- Options the Nomic team documents:
--   "search_query: " / "search_document: " — retrieval (query-vs-document)
--   "classification: "                      — single text → class label
--   "clustering: "                          — finding similar/dissimilar items
-- Our workload is theme-classification + diversity ranking, which is closest
-- to clustering (each theme is a cluster centroid; we want similar poems
-- pulled toward the same centroid). Prepended to every embedding input so
-- theme descriptions, axis keywords, and poem text all land in the same
-- semantic space.
LLM_MODEL = "nomic-embed-text:v1.5"
NOMIC_PREFIX = "clustering: "    -- task prefix; required for quality on nomic v1.5

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

-- Issue 030 Phase 3: full per-cluster theme metadata loaded from
-- themes/derived-taxonomy.lua. Each entry:
--   THEMES[name] = {
--     centroid             = {.. 768 floats ..},
--     tier1_generator      = "circuit",
--     tier1_parameter_axes = { {name, min, max, axis = {..768..}}, ... },
--     tier2_generator      = "default",
--     tier2_parameter_axes = { ... },
--   }
-- Populated by initialize_theme_embeddings().
THEMES = {}

-- Per-page percentile values for each (theme, parameter) axis, populated by
-- compute_axis_percentiles() after build_book(). Structure:
-- PAGE_PERCENTILES[page_num][theme_name][param_name] = float in [0, 1]
PAGE_PERCENTILES = {}

-- Per-poem percentile values, the Tier 2 parallel to PAGE_PERCENTILES.
-- Tier 1 art is one motif per page, so its params key by page; Tier 2 art
-- is one motif per poem, so its params key by the poem's ordinal index
-- (book.poems_index, attached as poem._index in build_book). Populated by
-- compute_poem_axis_percentiles() after build_book(). Structure:
-- POEM_PERCENTILES[poem_index][theme_name][param_name] = float in [0, 1]
POEM_PERCENTILES = {}

-- Layout Configuration Variables
MAX_LINES_PER_PAGE = 155 -- Lines per page column (restored)
MAX_CHAR_PER_LINE  = 80  -- Characters per line (content width)

-- Minimum area (as a fraction of total page area) that an outside region
-- must have to qualify as a canvas for Tier 1 page-level art. Issue 028
-- replaced the old global fill-ratio gate with this per-region filter, so
-- a page with one big empty zone gets art there even when the page is
-- otherwise full, and a page full of tiny slivers gets no noisy scraps.
-- 0.08 = a region must be at least 8% of the page (~ a third of a column
-- at full height). See docs/balance-updates.md for tuning history.
TIER1_MIN_REGION_AREA_FRACTION = 0.08

-- Vertical nudge (in PDF points) applied to the Tier 3 per-poem background
-- rectangle in draw_boxed_poem. Without this, the rectangle's top sits
-- flush with the top dashed border but its bottom extends ~2.5 pt below
-- the bottom border, looking visually bottom-heavy. A small upward shift
-- (PDF Y increases upward, so larger value = box moves up) rebalances
-- the gap. See docs/balance-updates.md.
TIER3_BOX_VERTICAL_NUDGE = 2

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

    -- Issue 032: drop structural lines now that detect_poem_type has used
    -- them to classify. Two kinds, neither of which is poem content:
    --   * the "-> file: <path>" source header — injects path tokens (mainly
    --     "fediverse", ~77% of blocks) into the embedding and prints the
    --     path inside the rendered poem box; and
    --   * lines whose whole body is an attachment filename or bare timestamp
    --     ("screenshot_20250414_154457.jpg", "temp1239...PDF",
    --     "cameron-king-resume.txt") — image-only / file-only posts that
    --     otherwise form spurious filename-token micro-clusters.
    -- Keep this block byte-identical with the copy in
    -- themes-v2/load-poem-embeddings.lua: the embedding cache key is the
    -- normalized text, so any divergence desyncs the cache.
    do
        local KNOWN_EXT = " jpg jpeg png gif webp bmp heic pdf txt mp4 mov webm "
        local function is_structural(line)
            if line:match("^%s*%-+>%s*file:") then return true end
            local s = line:gsub("^%s+", ""):gsub("%s+$", "")
            if s:match("^[%w._%-]+$") then  -- one token, no spaces
                local ext = s:match("%.([%a%d]+)$")
                if ext and KNOWN_EXT:find(" " .. ext:lower() .. " ", 1, true) then
                    return true
                end
                if s:match("^%d%d%d%d%d%d%d%d_%d%d%d%d%d%d$") then return true end
            end
            return false
        end
        local stripped = {}
        for _, line in ipairs(poem) do
            if not is_structural(line) then table.insert(stripped, line) end
        end
        poem = stripped
    end

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
      -- Issue 029, slice 0: each segment inherits the parent poem's
      -- _full_text so the per-poem theme analysis sees whole-poem
      -- semantics, not the slice that happens to fit in this column.
      segment._full_text = poem._full_text
      -- Issue 031, slice B: each segment inherits the parent poem's ordinal
      -- index so POEM_PERCENTILES (keyed by original-poem index) can be
      -- looked up at render time regardless of how the poem was split.
      segment._index = poem._index
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
      -- Issue 029, slice 0: attach the whole-poem text to the table so
      -- per-poem theme analysis can use it regardless of whether the
      -- poem ends up unsplit in a column (poem reference goes straight
      -- into book.pages) or split across columns (append_long_poem
      -- propagates _full_text onto each segment it inserts). Without
      -- this attachment, segments would be themed by half-poem text and
      -- the cache key would diverge from the whole-poem hash.
      poem._full_text = table.concat(poem, " ")
      -- Issue 031, slice B: stamp the poem's ordinal index (its position in
      -- book.poems) so the per-poem Tier 2 percentile pass and the renderer
      -- can agree on which poem's params to use. Segments inherit this in
      -- append_long_poem.
      poem._index = index
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
    hpdf.Page_Rectangle(pdf_page, actual_x,
        start_y - box_height_pts + line_height * 0.5 + TIER3_BOX_VERTICAL_NUDGE,
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

    -- Issue 029: load themes from themes/derived-taxonomy.lua (produced
    -- by themes-v2/run.sh / `./run themes-rebuild`). All three rendering
    -- tiers consume the SAME cluster set — the pyramid (tier1=10,
    -- tier2=20, tier3=40 with nesting) is retired. A poem's per-page-art
    -- theme, per-poem-art theme, and per-poem-color theme now all derive
    -- from the same HDBSCAN cluster, which gives a coherent visual
    -- identity across rendering layers.
    --
    -- The taxonomy file stores each cluster's centroid as a 768-float
    -- table, so this function skips the old "embed every description"
    -- pass — embeddings are already there, ready for cosine ranking.
    -- ./run's stale-check guarantees the taxonomy exists before we get
    -- here; if it doesn't, we still hard-error for any direct lua
    -- invocation that bypassed ./run.
    local taxonomy_path = DIR .. "/themes/derived-taxonomy.lua"
    local f = io.open(taxonomy_path, "r")
    if not f then
        error("themes/derived-taxonomy.lua is missing. Run './run themes-rebuild' first. (See issue 029.)")
    end
    f:close()
    local taxonomy = dofile(taxonomy_path)
    if not taxonomy or not taxonomy.themes or #taxonomy.themes == 0 then
        error("themes/derived-taxonomy.lua is empty or malformed. Re-run './run themes-rebuild'.")
    end

    print(string.format("📚 Loading %d themes from %s", #taxonomy.themes, taxonomy_path))
    local theme_map = {}
    for _, t in ipairs(taxonomy.themes) do
        if not t.name or not t.centroid then
            error(string.format("Taxonomy entry id=%s missing name or centroid", tostring(t.id)))
        end
        theme_map[t.name] = t.centroid
        -- Issue 030 Phase 3: store the cluster's full metadata in THEMES
        -- keyed by name so the runtime can look up generator + axes
        -- in one hop. tier1_generator may be absent in taxonomies built
        -- before Phase 2; default to "neutral" to keep this resilient.
        THEMES[t.name] = {
            centroid             = t.centroid,
            tier1_generator      = t.tier1_generator      or "neutral",
            tier1_parameter_axes = t.tier1_parameter_axes or {},
            tier2_generator      = t.tier2_generator      or "default",
            tier2_parameter_axes = t.tier2_parameter_axes or {},
        }
    end

    -- Synthetic "neutral" theme: returned by analyze_X when raw similarity
    -- is below threshold. It's not a real cluster (no centroid), but the
    -- rest of the runtime treats it as a theme name and looks it up
    -- against THEMES. Empty centroid would break cosine math; we put a
    -- zero vector there as a placeholder — no cluster will ever match it
    -- in similarity ranking because zero vectors have undefined cosine.
    THEMES["neutral"] = THEMES["neutral"] or {
        centroid             = nil,
        tier1_generator      = "neutral",
        tier1_parameter_axes = {},
        tier2_generator      = "default",
        tier2_parameter_axes = {},
    }

    -- All three tiers point at the SAME map. Cheap (table reference);
    -- nothing iterates the tiers in a way that would mutate one and
    -- surprise the others.
    THEME_EMBEDDINGS.tier1 = theme_map
    THEME_EMBEDDINGS.tier2 = theme_map
    THEME_EMBEDDINGS.tier3 = theme_map

    print(string.format("✅ %d themes ready (centroid embeddings loaded directly; no server pass)",
        #taxonomy.themes))
    if taxonomy.noise_count and taxonomy.noise_count > 0 then
        print(string.format("   (%d corpus poems were classified as noise by HDBSCAN)",
            taxonomy.noise_count))
    end

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

-- {{{ compute_axis_percentiles(book)
-- Issue 030 Phase 3 replacement for the old initialize_param_axes +
-- compute_page_percentiles pair. The axes themselves come pre-computed
-- per-cluster from themes/derived-taxonomy.lua (built by themes-v2/
-- name-clusters.lua's Phase-2 work) — no need to embed positive/negative
-- keywords at runtime. We just project pages onto those axes and rank.
--
-- For each cluster in THEMES, for each of its tier1_parameter_axes:
--   1. Project every page's embedding onto the axis (dot product).
--   2. Sort projections across pages, assign percentile ranks ∈ [0, 1].
--   3. Store at PAGE_PERCENTILES[page_num][theme_name][param_name].
--
-- The runtime later reads PAGE_PERCENTILES to feed parametric generators.
-- Memory: O(pages × themes × axes) floats; typical scale is ~500 pages ×
-- ~50 themes × ~2 axes = ~50k floats, trivial.
function compute_axis_percentiles(book)
    local theme_count = 0
    for _ in pairs(THEMES) do theme_count = theme_count + 1 end
    if theme_count == 0 then
        print("📊 No themes loaded; skipping percentile pass")
        return
    end
    print("📊 Scoring pages against per-cluster parameter axes...")

    -- raw[theme][param][page_num] = projection score
    local raw = {}
    for theme_name, theme in pairs(THEMES) do
        if theme.tier1_parameter_axes and #theme.tier1_parameter_axes > 0 then
            raw[theme_name] = {}
            for _, p in ipairs(theme.tier1_parameter_axes) do
                raw[theme_name][p.name] = {}
            end
        end
    end

    local total_pages = #book.pages
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
            local page_vec = fuzz.get_embedding(page_text, LLM_MODEL, NOMIC_PREFIX)
            if page_vec then
                for theme_name, axes_by_param in pairs(raw) do
                    for _, p in ipairs(THEMES[theme_name].tier1_parameter_axes) do
                        axes_by_param[p.name][page_num] = vec_dot(page_vec, p.axis)
                    end
                end
            end
        end
        -- This loop embeds every page (one server round-trip each), so it
        -- is the slow part of the pass — show an in-place bar rather than
        -- leaving the terminal frozen on the "Scoring pages..." line.
        progress_ui.bar("📊 Scoring pages", page_num, total_pages)
    end
    progress_ui.bar_finish()

    -- Rank each (theme, param) independently. Pages with no score (empty,
    -- or embedding failed) get the median 0.5 percentile as a safe default.
    local axis_total = 0
    for theme_name, by_param in pairs(raw) do
        for param_name, by_page in pairs(by_param) do
            axis_total = axis_total + 1
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

    print(string.format("✨ Computed percentiles for %d pages × %d themes × %d total axes",
        #book.pages, theme_count, axis_total))
end
-- }}}

-- {{{ compute_poem_axis_percentiles(book)
-- Issue 031, slice B: the Tier 2 parallel to compute_axis_percentiles. The
-- Tier 1 pass keys params by page because Tier 1 draws one motif per page;
-- Tier 2 draws one motif per POEM, and poems on the same page can sit in
-- very different parts of embedding space (a programming poem next to a
-- grief poem). Averaging them into a per-page percentile would wash out the
-- distinction, so Tier 2 ranks each poem independently.
--
-- For each cluster in THEMES with tier2_parameter_axes:
--   1. Project every poem's whole-poem embedding onto each axis (dot product).
--   2. Rank projections across all poems, assign percentiles ∈ [0, 1].
--   3. Store at POEM_PERCENTILES[poem_index][theme_name][param_name].
--
-- Poems too short to embed (< 10 chars) are skipped; they get no entry, so
-- the renderer's lookup falls through to the per-param 0.5 default — the
-- same "average art rather than degenerate art" convention the page pass
-- uses. The text embedded here is poem._full_text verbatim (no whitespace
-- normalization) so the cache key matches analyze_individual_poem_for_tier2,
-- which embeds the same poems during build_pdf — the second pass is a cache
-- hit, not a second round of server calls.
function compute_poem_axis_percentiles(book)
    local theme_count = 0
    for _ in pairs(THEMES) do theme_count = theme_count + 1 end
    if theme_count == 0 then
        print("📊 No themes loaded; skipping per-poem percentile pass")
        return
    end
    print("📊 Scoring poems against per-cluster Tier 2 parameter axes...")

    -- raw[theme][param][poem_index] = projection score
    local raw = {}
    for theme_name, theme in pairs(THEMES) do
        if theme.tier2_parameter_axes and #theme.tier2_parameter_axes > 0 then
            raw[theme_name] = {}
            for _, p in ipairs(theme.tier2_parameter_axes) do
                raw[theme_name][p.name] = {}
            end
        end
    end

    local total_poems = #book.poems
    for poem_index, poem in ipairs(book.poems) do
        local poem_text = poem._full_text or table.concat(poem, " ")
        if #poem_text >= 10 then
            local poem_vec = fuzz.get_embedding(poem_text, LLM_MODEL, NOMIC_PREFIX)
            if poem_vec then
                for theme_name, axes_by_param in pairs(raw) do
                    for _, p in ipairs(THEMES[theme_name].tier2_parameter_axes) do
                        axes_by_param[p.name][poem_index] = vec_dot(poem_vec, p.axis)
                    end
                end
            end
        end
        -- The per-poem pass is the longest embedding loop in the run (one
        -- round-trip per poem, ~thousands of poems), so the bar matters
        -- most here. Cache-warm runs fly; a cold cache crawls — either way
        -- the operator can watch it advance instead of guessing.
        progress_ui.bar("📊 Scoring poems", poem_index, total_poems)
    end
    progress_ui.bar_finish()

    -- Rank each (theme, param) independently. Poems with no score (too short
    -- or embedding failed) get no entry and fall back to 0.5 at render time.
    local axis_total = 0
    for theme_name, by_param in pairs(raw) do
        for param_name, by_poem in pairs(by_param) do
            axis_total = axis_total + 1
            local ranked = {}
            for poem_index, _ in pairs(by_poem) do table.insert(ranked, poem_index) end
            table.sort(ranked, function(a, b) return by_poem[a] < by_poem[b] end)
            local n = #ranked
            for rank, poem_index in ipairs(ranked) do
                POEM_PERCENTILES[poem_index] = POEM_PERCENTILES[poem_index] or {}
                POEM_PERCENTILES[poem_index][theme_name] = POEM_PERCENTILES[poem_index][theme_name] or {}
                POEM_PERCENTILES[poem_index][theme_name][param_name] = (n > 1) and ((rank - 1) / (n - 1)) or 0.5
            end
        end
    end

    print(string.format("✨ Computed per-poem percentiles for %d poems × %d themes × %d total axes",
        #book.poems, theme_count, axis_total))
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
    
    -- Initialize theme embeddings if not already done. A missing Tier 1
    -- table at this point means the embedding server never produced one,
    -- which is a hard failure — we cannot classify anything without the
    -- centroids to compare against. Halt so the operator fixes the
    -- inference stack rather than producing a "neutral"-everything PDF.
    local theme_embeddings = initialize_theme_embeddings()
    if not theme_embeddings or not theme_embeddings.tier1 or table_length(theme_embeddings.tier1) == 0 then
        error("analyze_text_themes: Tier 1 theme embeddings are empty/unavailable. "
            .. "The embedding server (see scripts/start-llamacpp-server.sh) probably failed to "
            .. "initialize the theme set. Check tmp/shared-memory/logs/llamacpp-embed.log.")
    end

    -- Get embedding for the column text
    print("Getting embedding for column text (" .. #column_text .. " chars)...")
    local text_embedding = fuzz.get_embedding(column_text, LLM_MODEL, NOMIC_PREFIX)

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
    -- Issue 029, slice 0: prefer the whole-poem text attached by build_book
    -- so split-across-columns poems get themed by the whole-poem semantics,
    -- not by the half-poem fragment that fits in this particular column.
    -- The or-fallback handles callers that don't go through build_book
    -- (none expected today, kept for safety).
    local poem_text = poem._full_text or table.concat(poem, " ")

    if #poem_text < 10 then
        track_theme_selection("tier3", "neutral")
        return "neutral" -- Not enough content
    end
    
    -- Get Tier 3 theme embeddings (most detailed for individual poems).
    -- Empty Tier 3 = embedding server didn't initialize the 40-theme set;
    -- hard-error rather than mis-label every poem as "neutral".
    local theme_embeddings = initialize_theme_embeddings()
    if not theme_embeddings or not theme_embeddings.tier3 or table_length(theme_embeddings.tier3) == 0 then
        error("analyze_individual_poem_theme: Tier 3 theme embeddings are empty/unavailable. "
            .. "Check tmp/shared-memory/logs/llamacpp-embed.log.")
    end

    -- Get embedding for the poem text
    local poem_embedding = fuzz.get_embedding(poem_text, LLM_MODEL, NOMIC_PREFIX)

    -- Issue 027: --natural-themes flag picks Tier 3 by raw cosine
    -- similarity alone, bypassing the frequency-weighted diversity boost.
    local best_theme, raw_similarity
    if NATURAL_THEMES then
        best_theme, raw_similarity = fuzz.find_most_similar_theme(
            poem_embedding, theme_embeddings.tier3)
    else
        best_theme, raw_similarity = fuzz.find_most_similar_theme_weighted(
            poem_embedding, theme_embeddings.tier3, THEME_STATS.tier3_counts)
    end

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
    -- Issue 029, slice 0: see analyze_individual_poem_theme. Same fix:
    -- consume the whole-poem text attached by build_book.
    local poem_text = poem._full_text or table.concat(poem, " ")

    if #poem_text < 10 then
        track_theme_selection("tier2", "neutral")
        return "neutral" -- Not enough content
    end
    
    -- Get Tier 2 theme embeddings (for individual poem art, different from page background).
    -- Empty Tier 2 = embedding server didn't initialize the 20-theme set; hard-error.
    local theme_embeddings = initialize_theme_embeddings()
    if not theme_embeddings or not theme_embeddings.tier2 or table_length(theme_embeddings.tier2) == 0 then
        error("analyze_individual_poem_for_tier2: Tier 2 theme embeddings are empty/unavailable. "
            .. "Check tmp/shared-memory/logs/llamacpp-embed.log.")
    end

    -- Get embedding for the poem text. get_embedding hard-errors on failure,
    -- so a returned value is always usable — no post-check needed.
    local poem_embedding = fuzz.get_embedding(poem_text, LLM_MODEL, NOMIC_PREFIX)


    -- Issue 027: --natural-themes flag picks Tier 2 by raw cosine
    -- similarity alone, bypassing the frequency-weighted diversity boost.
    local best_theme, raw_similarity
    if NATURAL_THEMES then
        best_theme, raw_similarity = fuzz.find_most_similar_theme(
            poem_embedding, theme_embeddings.tier2)
    else
        best_theme, raw_similarity = fuzz.find_most_similar_theme_weighted(
            poem_embedding, theme_embeddings.tier2, THEME_STATS.tier2_counts)
    end

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
        error("combined-themes pass: Tier 2 theme embeddings are empty/unavailable. "
            .. "Check tmp/shared-memory/logs/llamacpp-embed.log.")
    end

    -- Get embedding for the combined themes. get_embedding hard-errors on
    -- failure so the returned vector is always usable.
    local themes_embedding = fuzz.get_embedding(themes_text, LLM_MODEL, NOMIC_PREFIX)

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
    
    progress_ui.log("Analyzing page with " .. #all_page_text .. " characters of poem text...")
    
    -- Get Tier 1 theme embeddings (for page art)
    local theme_embeddings = initialize_theme_embeddings()
    if not theme_embeddings or not theme_embeddings.tier1 or table_length(theme_embeddings.tier1) == 0 then
        error("page-themes pass: Tier 1 theme embeddings are empty/unavailable. "
            .. "Check tmp/shared-memory/logs/llamacpp-embed.log.")
    end

    -- Get embedding for the entire page text. get_embedding hard-errors on
    -- failure so the returned vector is always usable.
    local page_embedding = fuzz.get_embedding(all_page_text, LLM_MODEL, NOMIC_PREFIX)

    -- Issue 027: --natural-themes flag picks Tier 1 by raw cosine
    -- similarity alone. When on, the weighted_score is the raw
    -- similarity so the log line below stays well-formed; when off,
    -- the two values may differ and both are shown for the operator.
    local best_theme, raw_similarity, weighted_score
    if NATURAL_THEMES then
        best_theme, raw_similarity = fuzz.find_most_similar_theme(
            page_embedding, theme_embeddings.tier1)
        weighted_score = raw_similarity
    else
        best_theme, raw_similarity, weighted_score = fuzz.find_most_similar_theme_weighted(
            page_embedding, theme_embeddings.tier1, THEME_STATS.tier1_counts)
    end

    -- Use result if raw similarity is decent
    if raw_similarity > 0.15 then
        track_theme_selection("tier1", best_theme)
        if NATURAL_THEMES then
            progress_ui.log(string.format("🎨 Page theme selected: %s (raw: %.3f)",
                  best_theme, raw_similarity))
        else
            progress_ui.log(string.format("🎨 Page theme selected: %s (raw: %.3f, weighted: %.3f)",
                  best_theme, raw_similarity, weighted_score))
        end
        return best_theme
    end

    track_theme_selection("tier1", "neutral")
    progress_ui.log("🎨 Page theme selected: neutral (low similarity)")
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

-- {{{ draw_theme_art_in_spaces(page, space_list, theme, page_num)
-- Issue 030 Phase 3: the theme name (returned by analyze_page_themes) is
-- looked up in THEMES to find its mapped tier1_generator, then the actual
-- draw function comes from the generators registry. PAGE_PERCENTILES
-- provides the per-page parameter values, populated from the cluster's
-- own tier1_parameter_axes during compute_axis_percentiles.
function draw_theme_art_in_spaces(pdf_page, space_list, theme, page_num)
    local theme_info = THEMES[theme] or THEMES["neutral"]
    local gen_name = theme_info.tier1_generator or "neutral"
    local gen_entry = generators.tier1[gen_name] or generators.tier1.neutral
    progress_ui.log(string.format(
        "🎨 Generating %s art (cluster theme: %s)",
        gen_name, theme))
    local params = (page_num and PAGE_PERCENTILES[page_num] and PAGE_PERCENTILES[page_num][theme]) or {}
    for _, space in ipairs(space_list) do
        gen_entry.draw(pdf_page, space, params)
    end
end
-- }}}

-- Tier 1 page art, drawn only in the regions outside the poem boxes.
-- The space_list comes from calculate_art_spaces, filtered down to the
-- regions a generator should occupy without overlapping any poem.
function draw_tier1_page_art(pdf_page, space_list, tier1_theme, page_num) -- {{{
    progress_ui.log(string.format("🎨 Drawing %s art in %d outside region(s)", tier1_theme, #space_list))
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

-- {{{ compute_tier2_art_spaces(box, col_is_left, column_gap, line_height, page_width)
-- Build the rectangles where a poem's Tier 2 art is allowed to live.
-- Tier 2 art does NOT go inside the box — draw_boxed_poem covers the
-- box with a solid Tier 3 background fill, so anything drawn under the
-- box would be hidden. Art lives in the gaps adjacent to the box,
-- where it tints the otherwise-blank stretches of page and visually
-- ties each poem to its neighbors.
--
-- PINWHEEL LAYOUT (Issue 031): four strips wrap the box, and each
-- strip extends into the ONE adjacent corner area, rotating around
-- the box. The four extensions together cover every corner of the
-- bounding region exactly once, with no overlap between strips —
-- motifs drawn in one strip flow into the corner without colliding
-- with the next strip:
--
--   * TOP    extends into the INNER side's corner (top-inner corner)
--             width  = box.width + column_gap
--             height = line_height
--   * INNER  extends DOWN into the BOTTOM's corner (bottom-inner corner)
--             width  = column_gap
--             height = box.height + line_height
--   * BOTTOM extends into the OUTER side's corner (bottom-outer corner)
--             width  = box.width + outer_w   (only when outer exists)
--             height = line_height
--   * OUTER  extends UP into the TOP's corner (top-outer corner)
--             width  = outer_w               (only when outer exists)
--             height = box.height + line_height
--
-- Rotation direction MIRRORS between columns: CW around a left-column
-- box (inner=right, outer=left), CCW around a right-column box
-- (inner=left, outer=right). This creates visually balanced flow when
-- the two columns are seen as a spread.
--
-- "outer_w" is the width of the page-margin area between the box and
-- the nearest page edge on the side opposite the gutter. In the
-- current 15%-shift layout it's ~99pt for right-column boxes and 0pt
-- for left-column boxes (box.x is negative, clamping outer_w to 0).
-- When outer doesn't exist, BOTTOM's outer-extension and the OUTER
-- strip itself are both omitted — the bottom-outer and top-outer
-- corners stay uncovered for left-column poems in that layout.
--
-- Motifs may overflow these bounds; whatever crosses into a poem box
-- ends up under the Tier 3 fill and isn't visible from above.
local function compute_tier2_art_spaces(box, col_is_left, column_gap, line_height, page_width)
    local spaces = {}

    if col_is_left then
        -- LEFT column: inner gutter is to the RIGHT of the box; outer
        -- margin (if it exists) is to the LEFT.
        local outer_w = math.max(0, box.x)
        local has_outer = outer_w >= 5

        -- TOP — extends RIGHT into INNER corner.
        table.insert(spaces, {
            x = box.x,
            y = box.y + box.height,
            width = box.width + column_gap,
            height = line_height,
        })
        -- BOTTOM — extends LEFT into OUTER corner (if outer exists).
        table.insert(spaces, {
            x = box.x - (has_outer and outer_w or 0),
            y = box.y - line_height,
            width = box.width + (has_outer and outer_w or 0),
            height = line_height,
        })
        -- INNER — gutter right of box, extended DOWN into BOTTOM corner.
        table.insert(spaces, {
            x = box.x + box.width,
            y = box.y - line_height,
            width = column_gap,
            height = box.height + line_height,
        })
        -- OUTER — page margin left of box, extended UP into TOP corner.
        if has_outer then
            table.insert(spaces, {
                x = 0,
                y = box.y,
                width = outer_w,
                height = box.height + line_height,
            })
        end
    else
        -- RIGHT column: inner gutter is to the LEFT of the box; outer
        -- margin (if it exists) is to the RIGHT.
        local outer_w = math.max(0, page_width - (box.x + box.width))
        local has_outer = outer_w >= 5

        -- TOP — extends LEFT into INNER corner.
        table.insert(spaces, {
            x = box.x - column_gap,
            y = box.y + box.height,
            width = box.width + column_gap,
            height = line_height,
        })
        -- BOTTOM — extends RIGHT into OUTER corner (if outer exists).
        table.insert(spaces, {
            x = box.x,
            y = box.y - line_height,
            width = box.width + (has_outer and outer_w or 0),
            height = line_height,
        })
        -- INNER — gutter left of box, extended DOWN into BOTTOM corner.
        table.insert(spaces, {
            x = box.x - column_gap,
            y = box.y - line_height,
            width = column_gap,
            height = box.height + line_height,
        })
        -- OUTER — page margin right of box, extended UP into TOP corner.
        if has_outer then
            table.insert(spaces, {
                x = box.x + box.width,
                y = box.y,
                width = outer_w,
                height = box.height + line_height,
            })
        end
    end

    return spaces
end
-- }}}

-- Generate individual poem art around each poem
-- {{{ generate_individual_poem_art(pdf_page, page_poems, ...)
-- Issue 031, slice C: Tier 2 now goes through the generator registry,
-- mirroring draw_theme_art_in_spaces for Tier 1. For each poem we classify
-- its cluster (analyze_individual_poem_for_tier2), look up that cluster's
-- tier2_generator in THEMES, fetch the matching draw function from
-- generators.tier2, and call it once per pinwheel art-space with the poem's
-- own percentile params from POEM_PERCENTILES. The legacy monolithic
-- draw_tier2_column_patterns is gone; generators.tier2.default is the only
-- fallback (when a cluster's generator name isn't in the registry).
local function draw_poem_tier2_art(pdf_page, box, col_is_left, column_gap, line_height, page_width, label)
    local poem_theme = analyze_individual_poem_for_tier2(box.poem)
    local theme_info = THEMES[poem_theme] or THEMES["neutral"]
    local gen_name   = theme_info.tier2_generator or "default"
    local gen_entry  = generators.tier2[gen_name] or generators.tier2.default
    progress_ui.log(string.format("  📝 %s: %s → %s (Tier 2)", label, poem_theme, gen_name))
    local art_spaces = compute_tier2_art_spaces(box, col_is_left, column_gap, line_height, page_width)
    -- POEM_PERCENTILES is keyed by the poem's ordinal index (poem._index),
    -- attached in build_book. Missing index / missing entry → empty params,
    -- and each generator's draw defaults every param to 0.5 (middle of axis).
    local params = (box.poem._index
                    and POEM_PERCENTILES[box.poem._index]
                    and POEM_PERCENTILES[box.poem._index][poem_theme])
                   or {}
    for _, space in ipairs(art_spaces) do
        gen_entry.draw(pdf_page, space, params)
    end
end

function generate_individual_poem_art(pdf_page, page_poems, page_width, page_height, margins, column_width, column_gap, page_shift, line_height)
    progress_ui.log("🖼️ Generating individual poem art...")
    local layout = compute_poem_layout(page_poems, page_height, margins, column_width, column_gap, page_shift, line_height)

    for poem_num, box in ipairs(layout.left) do
        draw_poem_tier2_art(pdf_page, box, true, column_gap, line_height, page_width,
            string.format("Left poem %d", poem_num))
    end

    for poem_num, box in ipairs(layout.right) do
        draw_poem_tier2_art(pdf_page, box, false, column_gap, line_height, page_width,
            string.format("Right poem %d", poem_num))
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
    progress_ui.log("🎨 Page background theme: " .. page_theme)

    if page_theme == "neutral" then
        progress_ui.log("🔍 Neutral page theme — no background art generated")
    else
        -- Issue 028: gate Tier 1 art on per-region area rather than global
        -- page fullness. Compute the outside regions first (the same set
        -- the renderer would draw into anyway) and keep only those whose
        -- area is at least TIER1_MIN_REGION_AREA_FRACTION of the page.
        -- A 70%-full page with one big empty strip still gets art there;
        -- a 30%-full page whose empty space is scattered into useless
        -- slivers gets no noisy scraps.
        local spaces = calculate_art_spaces(page_poems, page_width, page_height, margins, column_width, column_gap, page_shift)
        local outside_regions = {}
        for _, region in ipairs(spaces.bottom_space) do table.insert(outside_regions, region) end
        for _, region in ipairs(spaces.left_outer)   do table.insert(outside_regions, region) end
        for _, region in ipairs(spaces.right_outer)  do table.insert(outside_regions, region) end
        for _, region in ipairs(spaces.center)       do table.insert(outside_regions, region) end

        local page_area = page_width * page_height
        local min_area = page_area * TIER1_MIN_REGION_AREA_FRACTION
        local qualifying_regions = {}
        local largest_area = 0
        for _, region in ipairs(outside_regions) do
            local area = region.width * region.height
            if area > largest_area then largest_area = area end
            if area >= min_area then table.insert(qualifying_regions, region) end
        end

        local threshold_pct = math.floor(TIER1_MIN_REGION_AREA_FRACTION * 100)
        if #qualifying_regions > 0 then
            progress_ui.log(string.format(
                "✨ Tier 1 art enabled: %d/%d outside region(s) ≥ %d%% of page area",
                #qualifying_regions, #outside_regions, threshold_pct))
            draw_tier1_page_art(pdf_page, qualifying_regions, page_theme, page_num)
        else
            progress_ui.log(string.format(
                "🔍 Tier 1 art skipped: no outside region ≥ %d%% of page area (largest: %d%%, total regions: %d)",
                threshold_pct, math.floor((largest_area / page_area) * 100), #outside_regions))
        end
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
    -- Issue 026: progress_ui takes over the per-page status frame from here on.
    -- The header bar is owned by start_page; every print() inside the loop body
    -- has been converted to progress_ui.log() so the redraw region stays clean.
    progress_ui.init(total_pages)

    for page_num = 1, total_pages do
        local page = book.pages[page_num]
        progress_ui.start_page(page_num)

        local pdf_page = hpdf.AddPage(pdf)
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

        progress_ui.end_page()
    end
    progress_ui.finish()

    -- Completion message
    print(string.format("✅ All %d pages processed successfully!", total_pages))
    print("💾 Saving PDF...")

    -- Save and free — any failure here crashes loudly with a real stack trace
    -- per the project's "fallbacks are warnings, warnings are errors" rule
    local output_path = "output/compile-ai/output.pdf"
    hpdf.SaveToFile(pdf, output_path)
    print("📚 PDF saved to " .. output_path)
    hpdf.Free(pdf)
    return output_path
end -- }}}

function main(    )
              if NATURAL_THEMES then
                  print("🎲 Natural theme selection enabled (--natural-themes): "
                      .. "frequency weighting OFF, raw cosine similarity only")
              end
              local cache_count = fuzz.embedding_cache_status()
              print(string.format("🗄️  Embedding cache: %d entries on disk%s",
                    cache_count,
                    cache_count == 0 and " (cold start — full embedding-server pass ahead)" or ""))
              book = {  pages = {}, poems = {},  }
              book =  load_file (book)
              book = build_book (book)
              -- Issue 030 Phase 3: themes load first (taxonomy contains
              -- centroids + per-cluster parameter axes already computed
              -- by themes-v2/name-clusters.lua), then we project pages
              -- onto those axes to get per-page percentile values that
              -- feed the parametric generators.
              initialize_theme_embeddings()
              compute_axis_percentiles(book)
              -- Issue 031, slice B: the per-poem parallel to the per-page
              -- pass above. Ranks every poem on each cluster's Tier 2 axes
              -- so generate_individual_poem_art can tune each poem's motif
              -- density to where that poem sits in embedding space.
              compute_poem_axis_percentiles(book)
--              book = build_color(book)
               pdf = build_pdf  (book)
               print("Poems:", #book.poems, "Pages:", #book.pages)
               print_theme_statistics()

end

main()

