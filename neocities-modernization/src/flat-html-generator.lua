#!/usr/bin/env lua

-- Core flat HTML page generation system for neocities-modernization
-- Generates 13,680+ pages with similarity/diversity ranking in compiled.txt format

-- {{{ local function setup_dir_path
local function setup_dir_path(provided_dir)
    if provided_dir then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end
-- }}}

-- Script configuration - handle args properly to avoid -I interfering with DIR
local DIR = setup_dir_path()
if arg then
    for _, arg_val in ipairs(arg) do
        if arg_val ~= "-I" and not arg_val:match("^%-") then
            DIR = arg_val
            break
        end
    end
end

-- Load required libraries
package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. package.path
local utils = require("utils")
local dkjson = require("dkjson")

-- Initialize asset path configuration (CLI --dir takes precedence over config)
utils.init_assets_root(arg)

local M = {}

-- Mock color assignment for testing (until we have real embeddings)
local MOCK_POEM_COLORS = {
    [1] = "blue",    -- Introduction post
    [2] = "purple",  -- Philosophy/metaphysics  
    [3] = "red",     -- Passion/energy
    [5] = "orange",  -- Programming/technical
    [4625] = "red",  -- Politics/passion
    [4626] = "gray", -- Short post
    [4624] = "green" -- Hope/future themes
}

-- Color configuration for progress bars
local COLOR_CONFIG = {
    red = "#dc3c3c",
    blue = "#3c78dc", 
    green = "#3cb45a",
    purple = "#8c3cc8",
    orange = "#e68c3c",
    yellow = "#c8b428",
    gray = "#787878"
}

-- {{{ function load_poem_colors
local function load_poem_colors()
    local poem_colors_file = utils.embeddings_dir("EmbeddingGemma_latest") .. "/poem_colors.json"
    local poem_colors_data = utils.read_json_file(poem_colors_file)
    
    if poem_colors_data and poem_colors_data.poem_colors then
        utils.log_info(string.format("Loaded semantic colors for %d poems", poem_colors_data.total_poems))
        return poem_colors_data.poem_colors
    else
        utils.log_warn("Could not load poem colors, using mock colors")
        return MOCK_POEM_COLORS
    end
end
-- }}}

-- {{{ function get_file_creation_timestamp
local function get_file_creation_timestamp(file_path)
    -- Use bash stat command to get file modification time (best approximation)
    local cmd = string.format("stat -c %%Y '%s' 2>/dev/null", file_path)
    local handle = io.popen(cmd)
    
    if handle then
        local result = handle:read("*a")
        handle:close()
        
        if result and result:match("^%d+") then
            return tonumber(result:match("^%d+"))
        end
    end
    
    return nil
end
-- }}}

-- {{{ function extract_post_date_from_poem
local function extract_post_date_from_poem(poem_data)
    -- First, try to use the creation_date metadata field (if available)
    local creation_date = poem_data.creation_date or (poem_data.metadata and poem_data.metadata.creation_date)
    if creation_date then
        -- Parse ISO 8601 format: "2023-04-20T05:22:03" or "2023-04-20T05:22:03Z"
        local year, month, day, hour, min, sec = creation_date:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
        if year and month and day then
            local parsed_time = os.time({
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = tonumber(hour) or 0,
                min = tonumber(min) or 0,
                sec = tonumber(sec) or 0
            })
            if parsed_time then return parsed_time end
        end
        
        -- Fallback: try to extract just date part
        year, month, day = creation_date:match("(%d+)-(%d+)-(%d+)")
        if year and month and day then
            local parsed_time = os.time({
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = 0, min = 0, sec = 0
            })
            if parsed_time then return parsed_time end
        end
    end
    
    -- Fallback: Look for date patterns in poem content (legacy logic)
    local content = poem_data.content or ""
    
    -- First, try to extract YYYY-MM-DD from the very beginning (processing artifact dates)
    local year, month, day = content:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
    if year and month and day then
        return os.time({year=tonumber(year), month=tonumber(month), day=tonumber(day)})
    end
    
    -- Try to extract date from first line (other patterns)
    local date_line = content:match("^([^\n]+)")
    if date_line then        
        -- MM/DD/YYYY format  
        local month, day, year = date_line:match("(%d%d)/(%d%d)/(%d%d%d%d)")
        if month and day and year then
            return os.time({year=tonumber(year), month=tonumber(month), day=tonumber(day)})
        end
        
        -- Month DD, YYYY format (like "april 16th 2023")
        local month_name, day_num, year_num = date_line:match("(%w+)%s+(%d+)%w*%s+(%d%d%d%d)")
        if month_name and day_num and year_num then
            local month_map = {
                january=1, february=2, march=3, april=4, may=5, june=6,
                july=7, august=8, september=9, october=10, november=11, december=12
            }
            local month_num = month_map[month_name:lower()]
            if month_num then
                return os.time({year=tonumber(year_num), month=month_num, day=tonumber(day_num)})
            end
        end
    end
    
    -- Fallback to file creation time if available
    if poem_data.filepath then
        local timestamp = get_file_creation_timestamp(poem_data.filepath)
        if timestamp then
            return timestamp
        end
    end
    
    -- Final fallback to poem ID as timestamp approximation
    return poem_data.id or 0
end
-- }}}

-- {{{ function sort_poems_chronologically_by_dates
local function sort_poems_chronologically_by_dates(poems_data)
    local sorted_poems = {}
    
    -- Extract all poems with temporal sorting data
    for i, poem in ipairs(poems_data.poems) do
        if poem.id then
            local post_timestamp = extract_post_date_from_poem(poem)
            table.insert(sorted_poems, {
                poem = poem,
                timestamp = post_timestamp,
                sort_key = post_timestamp,
                original_index = i
            })
        end
    end
    
    -- Sort by actual temporal order
    table.sort(sorted_poems, function(a, b)
        -- If timestamps are equal, use original index as tiebreaker
        if a.sort_key == b.sort_key then
            return a.original_index < b.original_index
        end
        return a.sort_key < b.sort_key
    end)
    
    return sorted_poems
end
-- }}}

-- {{{ function calculate_chronological_progress
local function calculate_chronological_progress(poem_id, total_poems)
    -- Calculate percentage through chronological corpus
    local progress_percentage = (poem_id / total_poems) * 100
    
    return {
        poem_id = poem_id,
        total_poems = total_poems,
        percentage = progress_percentage,
        position = poem_id,
        quartile = math.ceil(progress_percentage / 25)
    }
end
-- }}}

-- {{{ function generate_progress_dashes
local function generate_progress_dashes(progress_info, color_name, is_golden, position, has_corner_boxes)
    -- For golden poems: 82 chars (+ 2 corners = 84 total)
    -- For regular poems: 82 chars (+ 1 leading space = 83 total, or 84 with trailing)
    local total_chars = 82
    local progress_chars = math.floor((progress_info.percentage / 100) * total_chars)
    local remaining_chars = total_chars - progress_chars

    -- Get color information
    local hex_color = COLOR_CONFIG[color_name] or COLOR_CONFIG["gray"]

    -- For golden bottom borders with corner boxes, we need to insert junction characters
    -- Junction positions in the 82-char interior (0-indexed):
    -- - Position 9: "similar" box wall (uses ╧ if in ═ section, ┴ if in ─ section)
    -- - Position 70: "different" box wall (uses ╧ if in ═ section, ┴ if in ─ section)
    local LEFT_JUNCTION_POS = 9   -- After "║ similar │" (11 chars, minus corner = 10, 0-indexed = 9)
    local RIGHT_JUNCTION_POS = 70  -- Before "│ different │" (82 - 12 = 70)

    -- Junction positions for regular poems (different from golden due to no outer walls)
    -- Regular corner boxes: ┌─────────┐ (11 chars) + 58 spaces + ┌───────────┐ (13 chars) = 82 chars
    -- Inner walls at positions 10 and 69 (0-indexed)
    local REGULAR_LEFT_JUNCTION_POS = 10
    local REGULAR_RIGHT_JUNCTION_POS = 69

    local visual_output
    if is_golden and position == "bottom" and has_corner_boxes then
        -- Build progress bar with junction characters inserted
        -- We need to construct the bar character by character to insert junctions at the right spots

        -- Determine which junction character to use at each position
        -- ╧ (U+2567) - up single and horizontal double (connects to ═) - COLORED
        -- ┴ (U+2534) - up and horizontal single (connects to ─) - UNCOLORED
        local left_in_progress = LEFT_JUNCTION_POS < progress_chars
        local right_in_progress = RIGHT_JUNCTION_POS < progress_chars

        -- Build colored junctions (╧ when in progress section)
        local left_junction
        if left_in_progress then
            left_junction = string.format('<font color="%s"><b>╧</b></font>', hex_color)
        else
            left_junction = "┴"
        end

        local right_junction
        if right_in_progress then
            right_junction = string.format('<font color="%s"><b>╧</b></font>', hex_color)
        else
            right_junction = "┴"
        end

        -- Build the progress section (colored ═) and remaining section (─)
        -- We need to split around the junction positions
        local segments = {}
        local current_pos = 0

        -- Helper to add a segment with proper coloring
        local function add_segment(start_pos, end_pos)
            if end_pos <= start_pos then return end
            local seg_len = end_pos - start_pos

            -- Determine how much of this segment is progress vs remaining
            local progress_in_seg = math.max(0, math.min(seg_len, progress_chars - start_pos))
            local remaining_in_seg = seg_len - progress_in_seg

            if progress_in_seg > 0 then
                table.insert(segments, string.format('<font color="%s"><b>%s</b></font>',
                    hex_color, string.rep("═", progress_in_seg)))
            end
            if remaining_in_seg > 0 then
                table.insert(segments, string.rep("─", remaining_in_seg))
            end
        end

        -- Segment 1: from 0 to left junction (exclusive)
        add_segment(0, LEFT_JUNCTION_POS)
        -- Insert left junction (colored if ╧, plain if ┴)
        table.insert(segments, left_junction)

        -- Segment 2: from left junction + 1 to right junction (exclusive)
        add_segment(LEFT_JUNCTION_POS + 1, RIGHT_JUNCTION_POS)
        -- Insert right junction (colored if ╧, plain if ┴)
        table.insert(segments, right_junction)

        -- Segment 3: from right junction + 1 to end
        add_segment(RIGHT_JUNCTION_POS + 1, total_chars)

        local interior = table.concat(segments, "")
        -- Color the ╚ corner to match the progress bar
        local colored_corner = string.format('<font color="%s"><b>╚</b></font>', hex_color)
        visual_output = colored_corner .. interior .. "┘"

    elseif not is_golden and position == "bottom" and has_corner_boxes then
        -- Regular poem bottom border with corner characters and junctions connecting to corner boxes
        -- Structure: ╘ (pos 0) + progress bar + ┴/╧ (pos 10) + progress bar + ┴/╧ (pos 69) + progress bar + ┘ (pos 81)
        -- ╘ (U+2558) - up single and right double - closes left box, connects to ═ progress
        -- ┘ (U+2518) - light up and left - closes right box, connects to ─ remaining

        local left_in_progress = REGULAR_LEFT_JUNCTION_POS < progress_chars
        local right_in_progress = REGULAR_RIGHT_JUNCTION_POS < progress_chars

        -- Build colored junctions (╧ when in progress section, ┴ otherwise)
        local left_junction
        if left_in_progress then
            left_junction = string.format('<font color="%s"><b>╧</b></font>', hex_color)
        else
            left_junction = "┴"
        end

        local right_junction
        if right_in_progress then
            right_junction = string.format('<font color="%s"><b>╧</b></font>', hex_color)
        else
            right_junction = "┴"
        end

        -- Left corner ╘ - colored if progress > 0 (position 0 is always in progress section if any progress)
        local left_corner
        if progress_chars > 0 then
            left_corner = string.format('<font color="%s"><b>╘</b></font>', hex_color)
        else
            left_corner = "╘"
        end

        -- Right corner ┘ - always uncolored (position 81 is almost never in progress section)
        local right_corner = "┘"

        -- Build the progress bar with junctions
        local segments = {}

        -- Helper to add a segment with proper coloring
        -- Note: positions are now 1-80 since 0 and 81 are corner characters
        local function add_segment(start_pos, end_pos)
            if end_pos <= start_pos then return end
            local seg_len = end_pos - start_pos

            local progress_in_seg = math.max(0, math.min(seg_len, progress_chars - start_pos))
            local remaining_in_seg = seg_len - progress_in_seg

            if progress_in_seg > 0 then
                table.insert(segments, string.format('<font color="%s"><b>%s</b></font>',
                    hex_color, string.rep("═", progress_in_seg)))
            end
            if remaining_in_seg > 0 then
                table.insert(segments, string.rep("─", remaining_in_seg))
            end
        end

        -- Start with left corner
        table.insert(segments, left_corner)

        -- Segment 1: from 1 to left junction (exclusive) - 9 chars
        add_segment(1, REGULAR_LEFT_JUNCTION_POS)
        table.insert(segments, left_junction)

        -- Segment 2: from left junction + 1 to right junction (exclusive) - 58 chars
        add_segment(REGULAR_LEFT_JUNCTION_POS + 1, REGULAR_RIGHT_JUNCTION_POS)
        table.insert(segments, right_junction)

        -- Segment 3: from right junction + 1 to end - 1 (exclusive of right corner) - 11 chars
        add_segment(REGULAR_RIGHT_JUNCTION_POS + 1, total_chars - 1)

        -- End with right corner
        table.insert(segments, right_corner)

        -- Add 2-space padding to align with content (where ║ would be in golden poems)
        visual_output = "  " .. table.concat(segments, "")

    elseif is_golden then
        -- Golden poem top border or bottom without corner boxes
        -- Create progress visualization using equals/dash distinction
        local progress_section = string.rep("═", progress_chars)
        local remaining_section = string.rep("─", remaining_chars)

        local colored_progress = string.format(
            '<font color="%s"><b>%s</b></font>%s',
            hex_color, progress_section, remaining_section
        )

        -- Color the left corners to match the progress bar
        local colored_top_corner = string.format('<font color="%s"><b>╔</b></font>', hex_color)
        local colored_bottom_corner = string.format('<font color="%s"><b>╚</b></font>', hex_color)

        if position == "top" then
            visual_output = colored_top_corner .. colored_progress .. "┐"
        elseif position == "bottom" then
            visual_output = colored_bottom_corner .. colored_progress .. "┘"
        else
            visual_output = colored_top_corner .. colored_progress .. "┐"
        end
    else
        -- Regular poems: 2-space padding for alignment with content (where ║ would be in golden)
        local progress_section = string.rep("═", progress_chars)
        local remaining_section = string.rep("─", remaining_chars)

        local colored_progress = string.format(
            '<font color="%s"><b>%s</b></font>%s',
            hex_color, progress_section, remaining_section
        )
        visual_output = "  " .. colored_progress
    end

    -- Screen reader accessible version - brief format for frequent use
    local screen_reader_text
    if is_golden then
        screen_reader_text = string.format(
            'aria-label="golden poem border. %s."',
            color_name
        )
    else
        screen_reader_text = string.format(
            'aria-label="eighty dashes. %s."',
            color_name
        )
    end

    return {
        visual = visual_output,
        accessibility = screen_reader_text,
        raw_progress = progress_chars,
        raw_remaining = remaining_chars,
        color = color_name,
        percentage = progress_info.percentage,
        is_golden = is_golden or false
    }
end
-- }}}

-- {{{ function cosine_distance
local function cosine_distance(vec1, vec2)
    -- Calculate cosine distance (1 - cosine_similarity)
    if #vec1 ~= #vec2 then
        error("Vectors must have same dimension")
    end
    
    local dot_product = 0
    local norm1 = 0
    local norm2 = 0
    
    for i = 1, #vec1 do
        dot_product = dot_product + (vec1[i] * vec2[i])
        norm1 = norm1 + (vec1[i] * vec1[i])
        norm2 = norm2 + (vec2[i] * vec2[i])
    end
    
    norm1 = math.sqrt(norm1)
    norm2 = math.sqrt(norm2)
    
    if norm1 == 0 or norm2 == 0 then
        return 1.0  -- Maximum distance for zero vectors
    end
    
    local cosine_sim = dot_product / (norm1 * norm2)
    return 1.0 - cosine_sim
end
-- }}}

-- {{{ function calculate_embedding_centroid
local function calculate_embedding_centroid(embeddings_list)
    if #embeddings_list == 0 then
        return nil
    end
    
    local embedding_dim = #embeddings_list[1]
    local centroid = {}
    
    -- Initialize centroid with zeros
    for i = 1, embedding_dim do
        centroid[i] = 0
    end
    
    -- Sum all embeddings
    for _, embedding in ipairs(embeddings_list) do
        for i = 1, embedding_dim do
            centroid[i] = centroid[i] + embedding[i]
        end
    end
    
    -- Average (divide by count)
    for i = 1, embedding_dim do
        centroid[i] = centroid[i] / #embeddings_list
    end
    
    return centroid
end
-- }}}

-- {{{ function wrap_single_line_80_chars
local function wrap_single_line_80_chars(line)
    -- Wrap a single line to 80 characters, preserving words
    if #line <= 80 then
        return line
    end

    local result_lines = {}
    local words = {}

    for word in line:gmatch("%S+") do
        table.insert(words, word)
    end

    local current_line = ""
    for _, word in ipairs(words) do
        if #current_line == 0 then
            current_line = word
        elseif #current_line + 1 + #word <= 80 then
            current_line = current_line .. " " .. word
        else
            table.insert(result_lines, current_line)
            current_line = word
        end
    end

    if #current_line > 0 then
        table.insert(result_lines, current_line)
    end

    return table.concat(result_lines, "\n")
end
-- }}}

-- {{{ function strip_html_tags
local function strip_html_tags(content)
    -- Strip all HTML tags and decode HTML entities for TXT export
    -- Images should be converted with render_attachment_images_txt() separately
    local result = content

    -- Strip HTML tags
    result = result:gsub("<[^>]+>", "")

    -- Decode common HTML entities
    result = result:gsub("&amp;", "&")
    result = result:gsub("&lt;", "<")
    result = result:gsub("&gt;", ">")
    result = result:gsub("&quot;", '"')
    result = result:gsub("&#39;", "'")
    result = result:gsub("&nbsp;", " ")
    result = result:gsub("&#(%d+);", function(n)
        return string.char(tonumber(n))
    end)

    -- Normalize multiple consecutive spaces/newlines
    result = result:gsub("[ \t]+", " ")
    result = result:gsub("\n[ \t]+", "\n")
    result = result:gsub("[ \t]+\n", "\n")
    result = result:gsub("\n\n\n+", "\n\n")

    return result
end
-- }}}

-- {{{ function wrap_text_80_chars
local function wrap_text_80_chars(text)
    -- Wrap text to 80 chars while preserving existing newlines (paragraph breaks)
    local input_lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        table.insert(input_lines, line)
    end

    local output_lines = {}
    for _, line in ipairs(input_lines) do
        if #line == 0 then
            -- Preserve empty lines (paragraph breaks)
            table.insert(output_lines, "")
        else
            -- Wrap long lines
            local wrapped = wrap_single_line_80_chars(line)
            for wrapped_line in (wrapped .. "\n"):gmatch("(.-)\n") do
                table.insert(output_lines, wrapped_line)
            end
        end
    end

    return table.concat(output_lines, "\n")
end
-- }}}

-- {{{ function M.generate_similarity_ranked_list
function M.generate_similarity_ranked_list(starting_poem_id, poems_data, similarity_data)
    utils.log_info(string.format("Generating similarity-ranked list starting from poem %s", starting_poem_id))
    
    local ranked_poems = {}
    local similarities = similarity_data[tostring(starting_poem_id)] or {}
    
    -- Initialize with starting poem
    local starting_poem = poems_data.poems[starting_poem_id]
    table.insert(ranked_poems, {
        id = starting_poem_id,
        poem = starting_poem,
        similarity = 1.0,  -- Perfect similarity to self
        rank = 1
    })
    
    -- Create list of all other poems with their direct similarity scores
    local other_poems = {}
    for poem_id, poem in ipairs(poems_data.poems) do
        if poem_id ~= starting_poem_id and poem.id then
            local similarity_score = similarities[tostring(poem.id)] or 0
            table.insert(other_poems, {
                id = poem.id,
                poem = poem,
                similarity = similarity_score
            })
        end
    end
    
    -- Sort by similarity (descending = most similar first)  
    table.sort(other_poems, function(a, b)
        return a.similarity > b.similarity
    end)
    
    -- Add to ranked list with rank numbers
    for i, poem_info in ipairs(other_poems) do
        poem_info.rank = i + 1  -- +1 because starting poem is rank 1
        table.insert(ranked_poems, poem_info)
    end
    
    utils.log_info(string.format("Generated similarity ranking of %d poems", #ranked_poems))
    
    return ranked_poems
end
-- }}}

-- {{{ function M.generate_maximum_diversity_sequence
function M.generate_maximum_diversity_sequence(starting_poem_id, poems_data, embeddings_data)
    utils.log_info(string.format("Generating maximum diversity sequence starting from poem %s", starting_poem_id))
    
    local diversity_sequence = {}
    local remaining_poems = {}
    local selected_embeddings = {}
    
    -- Initialize with starting poem
    local starting_poem = nil
    local starting_embedding = nil
    
    -- Find starting poem and its embedding
    for i, poem in ipairs(poems_data.poems) do
        if poem.id == starting_poem_id then
            starting_poem = poem
            starting_embedding = embeddings_data.embeddings[i] and embeddings_data.embeddings[i].embedding
            break
        end
    end
    
    if not starting_poem or not starting_embedding then
        utils.log_error("Could not find starting poem or embedding for ID: " .. starting_poem_id)
        return {}
    end
    
    table.insert(diversity_sequence, {
        id = starting_poem_id,
        poem = starting_poem,
        step = 1
    })
    table.insert(selected_embeddings, starting_embedding)
    
    -- Create list of all other poems with embeddings
    for i, poem in ipairs(poems_data.poems) do
        if poem.id and poem.id ~= starting_poem_id then
            local embedding = embeddings_data.embeddings[i] and embeddings_data.embeddings[i].embedding
            if embedding then
                table.insert(remaining_poems, {
                    id = poem.id,
                    poem = poem,
                    embedding = embedding
                })
            end
        end
    end
    
    -- Progressive centroid-based selection
    while #remaining_poems > 0 and #diversity_sequence < #poems_data.poems do
        -- Calculate cumulative centroid of selected poems
        local centroid = calculate_embedding_centroid(selected_embeddings)
        if not centroid then break end
        
        -- Find poem with maximum distance from current centroid
        local max_distance = -1
        local max_distance_poem = nil
        local max_distance_index = -1
        
        for i, poem_info in ipairs(remaining_poems) do
            local distance = cosine_distance(centroid, poem_info.embedding)
            if distance > max_distance then
                max_distance = distance
                max_distance_poem = poem_info
                max_distance_index = i
            end
        end
        
        -- Add most diverse poem to sequence
        if max_distance_poem then
            table.insert(diversity_sequence, {
                id = max_distance_poem.id,
                poem = max_distance_poem.poem,
                step = #diversity_sequence + 1,
                diversity_score = max_distance
            })
            table.insert(selected_embeddings, max_distance_poem.embedding)
            table.remove(remaining_poems, max_distance_index)
        else
            break
        end
    end
    
    utils.log_info(string.format("Generated diversity sequence of %d poems", #diversity_sequence))
    
    return diversity_sequence
end
-- }}}

-- {{{ function render_attachment_images
local function render_attachment_images(attachments)
    -- Render HTML for poem attachments (images)
    -- Returns empty string if no attachments or no image attachments
    -- Image output format designed for 80-char width aesthetic
    --
    -- ATTACHMENT STRUCTURE (from ActivityPub extraction):
    -- {
    --   media_type = "image/png",
    --   url = "https://server.com/media/files/123/456/original/abc.png",
    --   relative_path = "files/123/456/original/abc.png",
    --   alt_text = "User description" or nil,
    --   width = 1920,
    --   height = 1080
    -- }

    if not attachments or #attachments == 0 then
        return ""
    end

    local image_html = {}

    for _, attachment in ipairs(attachments) do
        -- Only process image types
        local media_type = attachment.media_type or ""
        if media_type:match("^image/") then
            -- Build image path relative to output directory
            -- Images are served from ../input/media_attachments/{relative_path}
            local img_src = "../input/media_attachments/" .. (attachment.relative_path or "")

            -- Use alt text if available, otherwise generate generic description
            local alt_text = attachment.alt_text or "Image attachment"
            -- Escape quotes in alt text for HTML attribute
            alt_text = alt_text:gsub('"', '&quot;')

            -- Build image tag with lazy loading for performance
            -- width/height hints help browser reserve space before load
            local img_tag
            if attachment.width and attachment.height then
                img_tag = string.format(
                    '  <img src="%s" alt="%s" loading="lazy" width="%d" height="%d" style="max-width:100%%; height:auto;">',
                    img_src, alt_text, attachment.width, attachment.height
                )
            else
                img_tag = string.format(
                    '  <img src="%s" alt="%s" loading="lazy" style="max-width:100%%; height:auto;">',
                    img_src, alt_text
                )
            end

            table.insert(image_html, img_tag)
        end
    end

    if #image_html == 0 then
        return ""
    end

    -- Return with newline prefix/suffix for proper spacing in poem layout
    return "\n" .. table.concat(image_html, "\n") .. "\n"
end
-- }}}

-- {{{ function render_attachment_images_txt
local function render_attachment_images_txt(attachments)
    -- Render plain text placeholders for poem attachments (images)
    -- Returns [Image: alt-text] format for TXT export
    -- Unlike render_attachment_images(), this outputs plain text, not HTML
    --
    -- This function exists because TXT exports cannot contain HTML <img> tags.
    -- Images are replaced with bracketed alt-text descriptions.

    if not attachments or #attachments == 0 then
        return ""
    end

    local image_lines = {}

    for _, attachment in ipairs(attachments) do
        -- Only process image types
        local media_type = attachment.media_type or ""
        if media_type:match("^image/") then
            -- Use alt text if available, otherwise indicate no description
            local alt_text = attachment.alt_text or "no description"

            -- Format as bracketed placeholder, wrapped at 80 chars if needed
            local placeholder = string.format("[Image: %s]", alt_text)

            -- Wrap long alt-text to 80 characters
            if #placeholder > 80 then
                placeholder = wrap_text_80_chars(placeholder)
            end

            table.insert(image_lines, placeholder)
        end
    end

    if #image_lines == 0 then
        return ""
    end

    -- Return with newline prefix/suffix for proper spacing
    return "\n" .. table.concat(image_lines, "\n") .. "\n"
end
-- }}}

-- {{{ function format_warning_box
local function format_warning_box(warning_text)
    -- Create simple ASCII box around content warning
    local content = wrap_text_80_chars(warning_text)
    local lines = {}
    for line in content:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    
    -- Find longest line for box width
    local max_width = 0
    for _, line in ipairs(lines) do
        max_width = math.max(max_width, #line)
    end
    
    -- Ensure minimum width and maximum of 76 chars (leave room for box borders)
    max_width = math.min(math.max(max_width, 20), 76)
    
    local boxed = {}
    table.insert(boxed, "┌" .. string.rep("─", max_width + 2) .. "┐")
    
    for _, line in ipairs(lines) do
        local padded = line .. string.rep(" ", max_width - #line)
        table.insert(boxed, "│ " .. padded .. " │")
    end
    
    table.insert(boxed, "└" .. string.rep("─", max_width + 2) .. "┘")
    
    return table.concat(boxed, "\n")
end
-- }}}

-- {{{ function apply_markdown_formatting
local function apply_markdown_formatting(text)
    -- Handle *\*text*\* (italics with asterisks)
    text = text:gsub("%*\\%*([^%*]+)%*\\%*", "<em>*%1*</em>")
    
    -- Handle *text* (simple italics)
    text = text:gsub("%*([^%*]+)%*", "<em>%1</em>")
    
    return text
end
-- }}}

-- {{{ function is_golden_poem
local function is_golden_poem(poem)
    -- Check if poem is exactly 1024 characters (golden)
    if poem.content then
        local content_length = #poem.content
        return content_length == 1024
    end
    return false
end
-- }}}

-- {{{ function generate_corner_box_separator
local function generate_corner_box_separator(hex_color)
    -- Generate the separator line with corner box tops for GOLDEN poems
    -- Format: ╟─────────┐                    ┌───────────┤
    -- Left box: 11 chars (╟ + 9×─ + ┐)
    -- Right box: 13 chars (┌ + 11×─ + ┤)
    -- Gap: 60 chars (spaces)
    -- Total: 84 chars
    -- The left junction ╟ is colored to match the progress bar
    local colored_junction = string.format('<font color="%s"><b>╟</b></font>', hex_color)
    local left_box = colored_junction .. string.rep("─", 9) .. "┐"
    local right_box = "┌" .. string.rep("─", 11) .. "┤"
    local gap = string.rep(" ", 60)
    return left_box .. gap .. right_box
end
-- }}}

-- {{{ function generate_regular_corner_box_top
local function generate_regular_corner_box_top()
    -- Generate the top line of corner boxes for REGULAR poems (no side walls)
    -- Format: ┌─────────┐                    ┌───────────┐
    -- Left box: 11 chars (┌ + 9×─ + ┐)
    -- Right box: 13 chars (┌ + 11×─ + ┐)
    -- Gap: 58 chars (spaces) - slightly less to account for no side walls
    -- Total: 82 chars (matching regular poem width)
    -- Add 2-space padding to align with content
    local left_box = "┌" .. string.rep("─", 9) .. "┐"
    local right_box = "┌" .. string.rep("─", 11) .. "┐"
    local gap = string.rep(" ", 58)
    return "  " .. left_box .. gap .. right_box
end
-- }}}

-- {{{ function generate_regular_corner_box_bottom
local function generate_regular_corner_box_bottom()
    -- Generate the bottom line of corner boxes for REGULAR poems
    -- Format: └─────────┘                    └───────────┘
    local left_box = "└" .. string.rep("─", 9) .. "┘"
    local right_box = "└" .. string.rep("─", 11) .. "┘"
    local gap = string.rep(" ", 58)
    return left_box .. gap .. right_box
end
-- }}}

-- {{{ function generate_corner_box_nav_line
local function generate_corner_box_nav_line(similar_link, different_link, hex_color)
    -- Generate the navigation line with corner box walls for GOLDEN poems
    -- Format: ║ similar │                    │ different │
    -- Left box: ║ + space + link + space + │ = 11 chars
    -- Right box: │ + space + link + space + │ = 13 chars
    -- Gap: 60 chars (spaces)
    -- Total: 84 chars
    -- The left wall ║ is colored to match the progress bar

    -- Calculate padding for link text within boxes
    -- "similar" = 7 chars, left box content = 9 chars (11 - ║ - │)
    -- "different" = 9 chars, right box content = 11 chars (13 - │ - │)

    -- The links contain HTML, so we need to measure visible text
    local similar_visible = similar_link:gsub("<[^>]+>", "")  -- "similar"
    local different_visible = different_link:gsub("<[^>]+>", "")  -- "different"

    -- Left box: ║ (colored) + space + similar + padding + │
    local colored_wall = string.format('<font color="%s"><b>║</b></font>', hex_color)
    local left_content_width = 9  -- space between ║ and │
    local similar_padding = left_content_width - 1 - #similar_visible  -- 1 for leading space
    local left_box = colored_wall .. " " .. similar_link .. string.rep(" ", similar_padding) .. "│"

    -- Right box: │ + space + different + padding + │
    local right_content_width = 11  -- space between │ and │
    local different_padding = right_content_width - 1 - #different_visible  -- 1 for leading space
    local right_box = "│ " .. different_link .. string.rep(" ", different_padding) .. "│"

    local gap = string.rep(" ", 60)

    return left_box .. gap .. right_box
end
-- }}}

-- {{{ function generate_regular_corner_box_nav_line
local function generate_regular_corner_box_nav_line(similar_link, different_link)
    -- Generate the navigation line with corner box walls for REGULAR poems
    -- Format: │ similar │                    │ different │
    -- Left box: │ + space + link + space + │ = 11 chars
    -- Right box: │ + space + link + space + │ = 13 chars
    -- Gap: 58 chars (spaces)
    -- Total: 82 chars (matching regular poem width)
    -- Add 2-space padding to align with content

    local similar_visible = similar_link:gsub("<[^>]+>", "")
    local different_visible = different_link:gsub("<[^>]+>", "")

    -- Left box: │ + space + similar + padding + │
    local left_content_width = 9
    local similar_padding = left_content_width - 1 - #similar_visible
    local left_box = "│ " .. similar_link .. string.rep(" ", similar_padding) .. "│"

    -- Right box: │ + space + different + padding + │
    local right_content_width = 11
    local different_padding = right_content_width - 1 - #different_visible
    local right_box = "│ " .. different_link .. string.rep(" ", different_padding) .. "│"

    local gap = string.rep(" ", 58)

    return "  " .. left_box .. gap .. right_box
end
-- }}}

-- {{{ function apply_golden_poem_formatting
local function apply_golden_poem_formatting(content, is_golden, similar_link, different_link, hex_color)
    -- Golden poem side borders: ║ on left (colored), │ on right
    -- Interior width: 80 characters for content (with 1 space padding on each side)
    -- Format: ║ + space + 80 chars content (padded) + space + │ = 84 total
    -- The left wall ║ is colored to match the progress bar
    if not is_golden then
        return content
    end

    local CONTENT_WIDTH = 80  -- Content area between padding spaces
    local color = hex_color or "#787878"  -- Default to gray if no color provided

    -- Split content into lines (append newline to handle last line without trailing newline)
    local lines = {}
    for line in (content .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end

    local formatted_lines = {}
    local colored_wall = string.format('<font color="%s"><b>║</b></font>', color)

    for _, line in ipairs(lines) do
        -- Calculate visible length (excluding HTML tags)
        local visible_line = line:gsub("<[^>]+>", "")
        local visible_length = #visible_line

        -- Pad or handle line to fit content width
        local padded_line
        if visible_length >= CONTENT_WIDTH then
            -- Line is already at or over width - use as-is
            padded_line = line
        else
            -- Pad with spaces to reach content width
            local padding_needed = CONTENT_WIDTH - visible_length
            padded_line = line .. string.rep(" ", padding_needed)
        end

        -- Add side borders with padding: ║ (colored) content │
        table.insert(formatted_lines, colored_wall .. " " .. padded_line .. " │")
    end

    -- Add corner box navigation (separator + nav line) if links provided
    if similar_link and different_link then
        -- Add separator line with corner box tops: ╟─────────┐      ┌───────────┤
        table.insert(formatted_lines, generate_corner_box_separator(color))
        -- Add navigation line with corner box walls: ║ similar │      │ different │
        table.insert(formatted_lines, generate_corner_box_nav_line(similar_link, different_link, color))
    end

    return table.concat(formatted_lines, "\n")
end
-- }}}

-- {{{ function format_content_with_warnings
local function format_content_with_warnings(text, poem_category, poem, similar_link, different_link, hex_color)
    -- Apply markdown formatting first
    text = apply_markdown_formatting(text)

    -- Check if this is a golden poem
    local is_golden = poem and is_golden_poem(poem)

    -- Detect content warning patterns (CW:, content warning:, etc.)
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        table.insert(lines, line)
    end

    local formatted_lines = {}
    local i = 1

    while i <= #lines do
        local line = lines[i]

        -- Check if line starts with content warning
        if line:lower():match("^%s*cw%s*:") or line:lower():match("^%s*content warning%s*:") then
            -- Format content warning with box
            local warning_box = format_warning_box(line)
            table.insert(formatted_lines, warning_box)
            table.insert(formatted_lines, "") -- First newline
            table.insert(formatted_lines, "") -- Second newline for spacing
        else
            -- Preserve whitespace for notes-dir poems (artistic formatting)
            if poem_category == "notes" then
                table.insert(formatted_lines, line)
            else
                -- Wrap long lines to 80 chars while preserving paragraph breaks
                local wrapped = wrap_text_80_chars(line)
                for wrapped_line in (wrapped .. "\n"):gmatch("(.-)\n") do
                    table.insert(formatted_lines, wrapped_line)
                end
            end
        end

        i = i + 1
    end

    local formatted_content = table.concat(formatted_lines, "\n")

    -- Apply golden poem box-drawing formatting (with corner box nav inside)
    if is_golden then
        formatted_content = apply_golden_poem_formatting(formatted_content, true, similar_link, different_link, hex_color)
    else
        -- For regular poems, add 2-space left padding to each line
        -- This aligns content with where golden poem's "║ " would be
        local padded_lines = {}
        for line in (formatted_content .. "\n"):gmatch("(.-)\n") do
            table.insert(padded_lines, "  " .. line)
        end
        formatted_content = table.concat(padded_lines, "\n")
    end

    return formatted_content, is_golden
end
-- }}}

-- {{{ function format_single_poem_with_progress_and_color
local function format_single_poem_with_progress_and_color(poem, total_poems, poem_colors)
    local formatted = ""

    -- Get semantic color for this poem
    local poem_color_data = poem_colors[poem.id]
    local semantic_color = poem_color_data and poem_color_data.color or "gray"
    local hex_color = COLOR_CONFIG[semantic_color] or COLOR_CONFIG["gray"]

    -- Calculate chronological progress
    local progress_info = calculate_chronological_progress(poem.id, total_poems)

    -- Check if this is a golden poem (exactly 1024 characters)
    local is_golden = is_golden_poem(poem)

    -- Build navigation links for this poem
    local similar_link = string.format("<a href='similar/%03d.html'>similar</a>", poem.id)
    local different_link = string.format("<a href='different/%03d.html'>different</a>", poem.id)

    -- Add file header
    formatted = formatted .. string.format(" -> file: %s/%s.txt\n",
                                          poem.category or "unknown",
                                          poem.id or "unknown")

    -- Generate top progress bar separator (with golden corners if applicable)
    local top_dashes = generate_progress_dashes(progress_info, semantic_color, is_golden, "top")
    formatted = formatted .. string.format('<span %s>%s</span>',
                                          top_dashes.accessibility,
                                          top_dashes.visual)

    -- For golden poems, no newline (border connects directly to content)
    -- For regular poems, add newline for visual separation
    if not is_golden then
        formatted = formatted .. "\n"
    end

    -- Format poem content with content warning handling and whitespace preservation
    -- Pass nav links and hex_color for golden poems
    local content_formatted = format_content_with_warnings(
        poem.content or "", poem.category, poem,
        is_golden and similar_link or nil,
        is_golden and different_link or nil,
        is_golden and hex_color or nil
    )
    formatted = formatted .. content_formatted

    -- Render attached images if present (from ActivityPub extraction)
    -- Images appear after poem content, before navigation links
    if poem.attachments then
        formatted = formatted .. render_attachment_images(poem.attachments)
    end

    -- For golden poems, content already includes nav in corner boxes
    -- For regular poems, add corner-boxed navigation links (top and nav lines only, bottom connects to progress bar)
    if not is_golden then
        formatted = formatted .. "\n"
        formatted = formatted .. generate_regular_corner_box_top() .. "\n"
        formatted = formatted .. generate_regular_corner_box_nav_line(similar_link, different_link) .. "\n"
        -- No bottom line - corner boxes connect directly to progress bar via junctions
    else
        -- Golden poems: add newline after nav line (content_formatted doesn't end with newline)
        formatted = formatted .. "\n"
    end

    -- Generate bottom progress bar separator (with junctions for both golden and regular poems)
    -- The has_corner_boxes parameter enables junction characters at wall positions
    local bottom_dashes = generate_progress_dashes(progress_info, semantic_color, is_golden, "bottom", true)
    formatted = formatted .. string.format('<span %s>%s</span>\n',
                                          bottom_dashes.accessibility,
                                          bottom_dashes.visual)

    return {
        content = formatted,
        semantic_color = semantic_color,
        progress_percentage = progress_info.percentage,
        poem_id = poem.id
    }
end
-- }}}

-- {{{ function format_single_poem_with_warnings
local function format_single_poem_with_warnings(poem)
    local formatted = ""

    -- Add file header (matching compiled.txt format)
    formatted = formatted .. string.format(" -> file: %s/%s.txt\n",
                                          poem.category or "unknown",
                                          poem.id or "unknown")
    formatted = formatted .. string.rep("-", 80) .. "\n"

    -- Format poem content with content warning handling and whitespace preservation
    formatted = formatted .. format_content_with_warnings(poem.content or "", poem.category, poem)

    -- Render attached images if present
    if poem.attachments then
        formatted = formatted .. render_attachment_images(poem.attachments)
    end

    return formatted
end
-- }}}

-- {{{ function format_single_poem_80_width
local function format_single_poem_80_width(poem)
    -- Format a single poem for TXT export (80-character width, no HTML)
    -- Uses strip_html_tags() to remove HTML and render_attachment_images_txt() for images
    local formatted = ""

    -- Add file header (matching compiled.txt format)
    formatted = formatted .. string.format(" -> file: %s/%s\n",
                                          poem.category or "unknown",
                                          poem.id or "unknown")
    formatted = formatted .. string.rep("-", 80) .. "\n"

    -- Strip HTML tags and format poem content to 80-character width
    local clean_content = strip_html_tags(poem.content or "")
    formatted = formatted .. wrap_text_80_chars(clean_content)

    -- Render attached images as [Image: alt-text] placeholders (not HTML)
    if poem.attachments then
        formatted = formatted .. render_attachment_images_txt(poem.attachments)
    end

    return formatted
end
-- }}}

-- {{{ function format_all_poems_with_progress_and_color
local function format_all_poems_with_progress_and_color(starting_poem, sorted_poems, total_poems, poem_colors)
    local content = ""
    
    -- Add starting poem first with progress visualization
    local formatted_starting = format_single_poem_with_progress_and_color(starting_poem, total_poems, poem_colors)
    content = content .. formatted_starting.content .. "\n\n"
    
    -- Add all other poems sorted by similarity/diversity
    for _, poem_info in ipairs(sorted_poems) do
        if poem_info.id ~= starting_poem.id then  -- Skip starting poem since we already added it
            local formatted_poem = format_single_poem_with_progress_and_color(poem_info.poem, total_poems, poem_colors)
            content = content .. formatted_poem.content .. "\n\n"
        end
    end
    
    return content
end
-- }}}

-- {{{ function format_all_poems_with_content_warnings
local function format_all_poems_with_content_warnings(starting_poem, sorted_poems)
    local content = ""
    
    -- Add starting poem first
    content = content .. format_single_poem_with_warnings(starting_poem)
    content = content .. "\n\n"
    
    -- Add all other poems sorted by similarity/diversity
    for _, poem_info in ipairs(sorted_poems) do
        if poem_info.id ~= starting_poem.id then  -- Skip starting poem since we already added it
            content = content .. format_single_poem_with_warnings(poem_info.poem)
            content = content .. "\n\n"
        end
    end
    
    return content
end
-- }}}

-- {{{ function format_all_poems_80_width
local function format_all_poems_80_width(starting_poem, sorted_poems)
    local content = ""
    
    -- Add starting poem first
    content = content .. format_single_poem_80_width(starting_poem)
    content = content .. "\n\n"
    
    -- Add all other poems sorted by similarity/diversity
    for _, poem_info in ipairs(sorted_poems) do
        if poem_info.id ~= starting_poem.id then  -- Skip starting poem since we already added it
            content = content .. format_single_poem_80_width(poem_info.poem)
            content = content .. "\n\n"
        end
    end
    
    return content
end
-- }}}

-- {{{ function M.generate_flat_poem_list_html_with_progress
function M.generate_flat_poem_list_html_with_progress(starting_poem, sorted_poems, page_type, starting_poem_id, use_progress)
    local template = [[<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Poems sorted by %s to: %s</title>
</head>
<body>
<center>
<h1>Poetry Collection</h1>
<p>All poems sorted by %s to: %s</p>
</center>
<pre style="text-align: left; max-width: 90ch; margin: 0 auto;">
%s
</pre>
</body>
</html>]]
    
    local formatted_content
    
    if use_progress then
        -- Load poem colors and use enhanced formatting
        local poem_colors = load_poem_colors()
        
        -- Calculate actual total poems by finding the maximum poem ID
        -- This represents the total chronological span of the corpus
        local max_poem_id = starting_poem.id or 1
        
        for _, poem_info in ipairs(sorted_poems) do
            if poem_info.id and poem_info.id > max_poem_id then
                max_poem_id = poem_info.id
            elseif poem_info.poem and poem_info.poem.id and poem_info.poem.id > max_poem_id then
                max_poem_id = poem_info.poem.id
            end
        end
        
        local total_poems = max_poem_id
        
        formatted_content = format_all_poems_with_progress_and_color(starting_poem, sorted_poems, total_poems, poem_colors)
    else
        -- Use standard formatting with content warnings
        formatted_content = format_all_poems_with_content_warnings(starting_poem, sorted_poems)
    end
    
    local page_type_desc = (page_type == "similar") and "similarity" or "difference"
    local starting_title = starting_poem.title or ("Poem " .. starting_poem_id)
    
    return string.format(template, 
                        page_type_desc,
                        starting_title,
                        page_type_desc, 
                        starting_title,
                        formatted_content)
end
-- }}}

-- {{{ function M.generate_flat_poem_list_html
function M.generate_flat_poem_list_html(starting_poem, sorted_poems, page_type, starting_poem_id)
    -- Default to using progress bars
    return M.generate_flat_poem_list_html_with_progress(starting_poem, sorted_poems, page_type, starting_poem_id, true)
end
-- }}}

-- {{{ function M.generate_chronological_index_with_navigation
function M.generate_chronological_index_with_navigation(poems_data, output_dir)
    local template = [[<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Poetry Collection - Chronological Order</title>
</head>
<body>
<center>
<h1>Poetry Collection</h1>
<p>All poems in true chronological order by post date</p>
<p><a href="explore.html">How to explore this collection</a></p>
</center>
<pre style="text-align: left; max-width: 90ch; margin: 0 auto;">
%s
</pre>
</body>
</html>]]

    -- Sort poems chronologically (by actual post dates)
    local sorted_poems_with_timestamps = sort_poems_chronologically_by_dates(poems_data)
    
    -- Load poem colors for progress bars
    local poem_colors = load_poem_colors()
    local total_poems = #sorted_poems_with_timestamps
    
    -- Generate content with timeline progress and navigation links
    local content = ""
    for i, poem_info in ipairs(sorted_poems_with_timestamps) do
        local poem = poem_info.poem
        local poem_id = poem.id
        
        -- Calculate chronological progress based on temporal position (not ID)
        local temporal_progress = (i / total_poems) * 100
        local progress_info = {
            poem_id = poem_id,
            total_poems = total_poems,
            percentage = temporal_progress,
            position = i,
            temporal_index = i
        }
        
        -- Get semantic color for this poem
        local poem_color_data = poem_colors[poem_id]
        local semantic_color = poem_color_data and poem_color_data.color or "gray"

        -- Check if this is a golden poem (exactly 1024 characters)
        local is_golden = is_golden_poem(poem)

        -- Add file header without timestamps (user requested removal)
        content = content .. string.format(" -> file: %s/%s.txt\n",
                                          poem.category or "unknown",
                                          poem_id or "unknown")

        -- Build navigation links
        local similar_link = string.format("<a href='similar/%03d.html'>similar</a>", poem_id)
        local different_link = string.format("<a href='different/%03d.html'>different</a>", poem_id)

        -- Generate top progress bar separator (with golden corners if applicable)
        local top_dashes = generate_progress_dashes(progress_info, semantic_color, is_golden, "top")
        content = content .. string.format('<span %s>%s</span>',
                                          top_dashes.accessibility,
                                          top_dashes.visual)

        -- For golden poems, no newline after top border (border connects directly to content)
        -- For regular poems, add newline for visual separation
        if not is_golden then
            content = content .. "\n"
        end

        -- Add poem content with content warning handling and whitespace preservation
        -- Pass separate links for golden poems (corner boxes) or nil for regular poems
        -- Also pass hex color for golden poem wall coloring
        local hex_color = COLOR_CONFIG[semantic_color] or COLOR_CONFIG["gray"]
        local formatted_content, was_golden = format_content_with_warnings(
            poem.content or "", poem.category, poem,
            is_golden and similar_link or nil,
            is_golden and different_link or nil,
            is_golden and hex_color or nil
        )
        content = content .. formatted_content

        -- For regular poems, add newline and corner-boxed navigation links (top and nav lines only)
        if not is_golden then
            content = content .. "\n"
            -- Add corner-boxed navigation links for regular poems
            content = content .. generate_regular_corner_box_top() .. "\n"
            content = content .. generate_regular_corner_box_nav_line(similar_link, different_link) .. "\n"
            -- No bottom line - corner boxes connect directly to progress bar via junctions
        else
            -- Golden poems: add newline after nav line (formatted_content doesn't end with newline)
            content = content .. "\n"
        end

        -- Generate bottom progress bar separator (with junctions for both golden and regular poems)
        local bottom_dashes = generate_progress_dashes(progress_info, semantic_color, is_golden, "bottom", true)
        content = content .. string.format('<span %s>%s</span>\n\n',
                                          bottom_dashes.accessibility,
                                          bottom_dashes.visual)
    end
    
    local final_html = string.format(template, content)
    local output_file = output_dir .. "/chronological.html"
    os.execute("mkdir -p " .. output_dir)
    
    -- Write chronological.html
    local success = utils.write_file(output_file, final_html)
    
    if success then
        -- Create index.html as a copy of chronological.html (main entry point)
        local index_file = output_dir .. "/index.html"
        os.execute(string.format("cp '%s' '%s'", output_file, index_file))
        utils.log_info("Created index.html as main entry point (copy of chronological.html)")
    end
    
    return success and output_file or nil
end
-- }}}

-- {{{ function M.generate_simple_discovery_instructions
function M.generate_simple_discovery_instructions(output_dir)
    local template = [[<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Poetry Collection - How to Explore</title>
</head>
<body>
<h1>Poetry Collection - Exploration Guide</h1>
<pre>
%s
</pre>
</body>
</html>]]
    
    local instructions = wrap_text_80_chars([[
Welcome to the Poetry Collection.

This collection contains all poems with two ways to explore:

1. SIMILARITY EXPLORATION:
   Click "similar" next to any poem to see all other poems ranked by
   how similar they are to that poem. Most similar poems appear first.

2. DIFFERENCE EXPLORATION:
   Click "different" next to any poem to see all other poems ranked by
   maximum difference (most contrasting) from that poem. Creates surprising
   reading experiences by showing contrasting content.

Start from the main chronological index to browse all poems.
Every poem has both "similar" and "different" links for exploration.

Each exploration method shows ALL poems in the collection, just sorted
differently based on your chosen starting point.

The "similar" pages help you find more of what resonates with you.
The "different" pages help you discover unexpected contrasts and new perspectives.
]])
    
    local final_html = string.format(template, instructions)
    local output_file = output_dir .. "/explore.html"
    
    return utils.write_file(output_file, final_html) and output_file or nil
end
-- }}}

-- {{{ function generate_txt_file_header
local function generate_txt_file_header(title, total_poems)
    -- Generate a consistent header for TXT export files
    -- Matches the compiled.txt aesthetic with 80-character width
    local separator = string.rep("=", 80)
    local header = separator .. "\n"

    -- Center the title
    local padding = math.floor((80 - #title) / 2)
    header = header .. string.rep(" ", padding) .. title .. "\n"

    header = header .. separator .. "\n"
    header = header .. string.format("Total poems: %d\n", total_poems)
    header = header .. string.format("Generated: %s\n", os.date("%Y-%m-%d %H:%M:%S"))
    header = header .. separator .. "\n\n"

    return header
end
-- }}}

-- {{{ function generate_similarity_txt_file
function generate_similarity_txt_file(starting_poem, sorted_poems, output_file)
    -- Generate TXT export for similarity-sorted poems
    -- Includes file header with metadata and all poems formatted at 80-char width
    local title = string.format("POEMS SORTED BY SIMILARITY TO POEM %s", starting_poem.id or "?")
    local header = generate_txt_file_header(title, #sorted_poems + 1)
    local poems_content = format_all_poems_80_width(starting_poem, sorted_poems)
    local content = header .. poems_content
    return utils.write_file(output_file, content) and output_file or nil
end
-- }}}

-- {{{ function generate_diversity_txt_file
function generate_diversity_txt_file(starting_poem, sorted_poems, output_file)
    -- Generate TXT export for diversity-sorted poems
    -- Includes file header with metadata and all poems formatted at 80-char width
    local title = string.format("POEMS SORTED BY DIVERSITY FROM POEM %s", starting_poem.id or "?")
    local header = generate_txt_file_header(title, #sorted_poems + 1)
    local poems_content = format_all_poems_80_width(starting_poem, sorted_poems)
    local content = header .. poems_content
    return utils.write_file(output_file, content) and output_file or nil
end
-- }}}

-- {{{ function M.generate_chronological_txt_file
function M.generate_chronological_txt_file(poems_data, output_file)
    -- Generate TXT export for all poems in chronological order
    -- Uses actual post dates for sorting (not poem IDs)
    -- Includes file header with metadata and all poems formatted at 80-char width

    -- Sort poems chronologically by actual post dates
    local sorted_poems = sort_poems_chronologically_by_dates(poems_data)
    local total_poems = #sorted_poems

    -- Generate header
    local title = "POEMS IN CHRONOLOGICAL ORDER"
    local header = generate_txt_file_header(title, total_poems)

    -- Generate content for each poem
    local content = header
    for i, poem_info in ipairs(sorted_poems) do
        content = content .. format_single_poem_80_width(poem_info.poem)
        content = content .. "\n\n"
    end

    return utils.write_file(output_file, content) and output_file or nil
end
-- }}}

-- {{{ function M.generate_complete_flat_html_collection
function M.generate_complete_flat_html_collection(poems_data, similarity_data, embeddings_data, output_dir)
    -- Count poems with valid IDs
    local valid_poems = {}
    for i, poem in ipairs(poems_data.poems) do
        if poem.id then
            valid_poems[poem.id] = poem
        end
    end
    
    local total_poems = 0
    for _ in pairs(valid_poems) do 
        total_poems = total_poems + 1 
    end
    
    utils.log_info(string.format("Generating complete collection: %d similarity + %d diversity pages (total: %d)", 
                                total_poems, total_poems, total_poems * 2))
    
    local results = {
        similarity_pages = {},
        diversity_pages = {},
        chronological_index = nil,
        txt_files = {},
        instructions_page = nil
    }
    
    -- Generate similarity and diversity pages for each poem
    local progress_count = 0
    for poem_id, poem_data in pairs(valid_poems) do
        progress_count = progress_count + 1
        
        if progress_count % 100 == 0 then
            utils.log_info(string.format("Progress: %d/%d poems processed (%.1f%%)", 
                                        progress_count, total_poems, 
                                        (progress_count / total_poems) * 100))
        end
        
        -- Generate similarity page (all poems sorted by similarity to this one)
        local similar_ranking = M.generate_similarity_ranked_list(poem_id, poems_data, similarity_data)
        local similar_html = M.generate_flat_poem_list_html(poem_data, similar_ranking, "similar", poem_id)
        local similar_file = string.format("%s/similar/%03d.html", output_dir, poem_id)
        os.execute("mkdir -p " .. output_dir .. "/similar")
        
        if utils.write_file(similar_file, similar_html) then
            table.insert(results.similarity_pages, similar_file)
            
            -- Generate TXT version
            local similar_txt = generate_similarity_txt_file(poem_data, similar_ranking, 
                                                           string.format("%s/similar/%03d.txt", output_dir, poem_id))
            if similar_txt then
                table.insert(results.txt_files, similar_txt)
            end
        end
        
        -- Generate diversity page (all poems sorted by diversity from this one) 
        local diverse_sequence = M.generate_maximum_diversity_sequence(poem_id, poems_data, embeddings_data)
        local diverse_html = M.generate_flat_poem_list_html(poem_data, diverse_sequence, "different", poem_id)
        local diverse_file = string.format("%s/different/%03d.html", output_dir, poem_id)
        os.execute("mkdir -p " .. output_dir .. "/different")
        
        if utils.write_file(diverse_file, diverse_html) then
            table.insert(results.diversity_pages, diverse_file)
            
            -- Generate TXT version
            local diverse_txt = generate_diversity_txt_file(poem_data, diverse_sequence,
                                                          string.format("%s/different/%03d.txt", output_dir, poem_id))
            if diverse_txt then
                table.insert(results.txt_files, diverse_txt)
            end
        end
    end
    
    -- Generate chronological index (HTML)
    results.chronological_index = M.generate_chronological_index_with_navigation(poems_data, output_dir)

    -- Generate chronological TXT export
    local chrono_txt_file = output_dir .. "/chronological.txt"
    local chrono_txt = M.generate_chronological_txt_file(poems_data, chrono_txt_file)
    if chrono_txt then
        table.insert(results.txt_files, chrono_txt)
        results.chronological_txt = chrono_txt
    end

    -- Generate instructions page
    results.instructions_page = M.generate_simple_discovery_instructions(output_dir)
    
    utils.log_info(string.format("Generation complete: %d similarity pages, %d diversity pages, %d txt files", 
                                #results.similarity_pages, #results.diversity_pages, #results.txt_files))
    
    return results
end
-- }}}

-- {{{ function M.main
function M.main(interactive_mode)
    if interactive_mode then
        print("Flat HTML Generator - Interactive Mode")
        print("1. Generate complete flat HTML collection")
        print("2. Generate chronological index only")
        print("3. Generate instructions page only")
        print("4. Test single similarity page")
        print("5. Test single difference page")
        io.write("Select option (1-5): ")
        local choice = io.read()
        
        local poems_file = utils.asset_path("poems.json")
        local similarity_file = utils.embeddings_dir("EmbeddingGemma_latest") .. "/similarity_matrix.json"
        local embeddings_file = utils.embeddings_dir("EmbeddingGemma_latest") .. "/embeddings.json"
        local output_dir = DIR .. "/output"
        
        if choice == "1" then
            utils.log_info("Loading data files...")
            local poems_data = utils.read_json_file(poems_file)
            local similarity_data = utils.read_json_file(similarity_file)
            local embeddings_data = utils.read_json_file(embeddings_file)
            
            if poems_data and similarity_data and embeddings_data then
                M.generate_complete_flat_html_collection(poems_data, similarity_data.similarities, embeddings_data, output_dir)
            else
                utils.log_error("Failed to load required data files")
            end
        elseif choice == "2" then
            local poems_data = utils.read_json_file(poems_file)
            if poems_data then
                M.generate_chronological_index_with_navigation(poems_data, output_dir)
                M.generate_chronological_txt_file(poems_data, output_dir .. "/chronological.txt")
                utils.log_info("Generated chronological.html and chronological.txt")
            end
        elseif choice == "3" then
            M.generate_simple_discovery_instructions(output_dir)
        elseif choice == "4" then
            io.write("Enter poem ID for similarity test: ")
            local poem_id = tonumber(io.read())
            if poem_id then
                local poems_data = utils.read_json_file(poems_file)
                local similarity_data = utils.read_json_file(similarity_file)
                
                if poems_data and similarity_data then
                    local poem_data = nil
                    for _, poem in ipairs(poems_data.poems) do
                        if poem.id == poem_id then
                            poem_data = poem
                            break
                        end
                    end
                    
                    if poem_data then
                        local ranking = M.generate_similarity_ranked_list(poem_id, poems_data, similarity_data.similarities)
                        local html = M.generate_flat_poem_list_html(poem_data, ranking, "similar", poem_id)
                        local test_file = string.format("%s/test_similar_%03d.html", output_dir, poem_id)
                        os.execute("mkdir -p " .. output_dir)
                        utils.write_file(test_file, html)
                        utils.log_info("Test file written: " .. test_file)
                    end
                end
            end
        elseif choice == "5" then
            io.write("Enter poem ID for difference test: ")
            local poem_id = tonumber(io.read())
            if poem_id then
                local poems_data = utils.read_json_file(poems_file)
                local embeddings_data = utils.read_json_file(embeddings_file)

                if poems_data and embeddings_data then
                    local poem_data = nil
                    for _, poem in ipairs(poems_data.poems) do
                        if poem.id == poem_id then
                            poem_data = poem
                            break
                        end
                    end

                    if poem_data then
                        local sequence = M.generate_maximum_diversity_sequence(poem_id, poems_data, embeddings_data)
                        local html = M.generate_flat_poem_list_html(poem_data, sequence, "different", poem_id)
                        local test_file = string.format("%s/test_different_%03d.html", output_dir, poem_id)
                        os.execute("mkdir -p " .. output_dir)
                        utils.write_file(test_file, html)
                        utils.log_info("Test file written: " .. test_file)
                    end
                end
            end
        end
    else
        utils.log_info("Use -I flag for interactive mode")
    end
end
-- }}}

-- Command line execution
if arg then
    -- Check for interactive flag
    local interactive = false
    for _, arg_val in ipairs(arg) do
        if arg_val == "-I" then
            interactive = true
            break
        end
    end
    
    M.main(interactive)
end

return M