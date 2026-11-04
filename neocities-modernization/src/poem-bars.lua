-- poem-bars.lua
--
-- The box-drawing for poem entries: the top progress bar, the corner-boxed
-- nav line (│ similar │ ... │ different │), and the bottom bar with junctions
-- (╘══╧══╧══┘). Extracted from flat-html-generator's main-thread originals so
-- the parallel effil workers can require the SAME code instead of carrying a
-- drifted inline copy. That drift is what produced 88-char bars with doubled
-- ╧╧ junctions on similar/different pages while the main-thread chronological
-- pages stayed correct at 83. One module -> one bar -> no drift.
--
-- Geometry (owner, 2026-10-25): a poem's text is at most text_width
-- characters (80, config.lua layout.text_content_width), and a golden poem's
-- frame is a wall, a space, the text, a space, a wall -- text_width + 4 = 84
-- columns, 0-indexed 0..83. Only golden poems are walled (that is what sets
-- them apart); a regular poem's bars and boxes span the same 84 columns and
-- its text is indented to the same column (src/poem-entry.lua), so only the
-- borders tell the two apart:
--   left corner box  : columns 0-10  (11 wide; walls at 0 and 10)
--   gap              : columns 11-70 (60 spaces)
--   right corner box : columns 71-83 (13 wide; walls at 71 and 83)
-- Bottom-bar junctions sit UNDER the inner walls, at columns 10 and 71. A
-- regular poem's bar fills all 84 columns; a golden poem's fills the 82
-- inside its two outer walls. (Regular poems were drawn 83 wide until
-- 2026-10-25, one column short of the rule.)

local M = {}

-- Color config (name -> hex) and the frame's columns, set by configure()
-- once per Lua state (main thread and each worker): the host injects them so
-- this module needs no knowledge of the project's palette or config.
local color_config = {}
local F = nil

-- {{{ function M.frame()
-- The frame's columns for a text width (number): { width, left_box,
-- right_box, gap, left_junction, right_junction, regular_fill, golden_fill }.
function M.frame(text_width)
    local width = text_width + 4                -- wall, space, text, space, wall
    local left_box, right_box = 11, 13          -- "│ similar │", "│ different │"
    return {
        width = width,
        left_box = left_box,
        right_box = right_box,
        gap = width - left_box - right_box,
        left_junction = left_box - 1,           -- the similar box's right wall
        right_junction = width - right_box,     -- the different box's left wall
        regular_fill = width,
        golden_fill = width - 2,                -- inside the two outer walls
    }
end
-- }}}

-- {{{ function M.configure()
-- palette    : { colour name -> hex }
-- text_width : the widest a poem's line may be (config.lua layout.text_content_width)
function M.configure(palette, text_width)
    if type(text_width) ~= "number" then
        error("poem-bars.configure: text_width (config.lua layout.text_content_width) is required")
    end
    color_config = palette or {}
    F = M.frame(text_width)
end
-- }}}

-- {{{ local function frame()
local function frame()
    return F or error("poem-bars: configure() first (it sets the frame's width)")
end
-- }}}

-- {{{ function M.colorize_char()
function M.colorize_char(char, hex_color)
    if hex_color then
        return string.format('<font color="%s"><b>%s</b></font>', hex_color, char)
    end
    return char
end
-- }}}

local colorize_char = M.colorize_char

-- {{{ function M.check_percentage()
-- Issue 8-045: a bar's fill is a share of its width, so a percentage outside
-- 0-100 has no drawing.  Above 100 the old code drew more cells than the frame
-- holds (a 117% bar ran 14 columns past its box); below 0 it drew a negative
-- count, which string.rep turns into nothing.  Both mean the number feeding the
-- bar is wrong -- in 8-045's case a poem's position divided by the wrong total --
-- so the build stops and names the poem rather than drawing a guess.
--
-- progress_info : table with .percentage (number) and, when the caller has it,
--                 .poem_id (the poem's global index) for the error message.
function M.check_percentage(progress_info)
    local pct = progress_info.percentage
    if type(pct) ~= "number" or pct ~= pct or pct < 0 or pct > 100 then
        error(string.format(
            "progress bar percentage out of range (0-100): %s for poem %s",
            tostring(pct), tostring(progress_info.poem_id or "(no poem id given)")), 2)
    end
end
-- }}}

-- {{{ function M.progress_dashes()
-- The top/bottom separator bar. position is "top" or "bottom"; has_corner_boxes
-- inserts the ╧/┴ junctions that connect a bottom bar to the nav corner boxes.
-- Returns { visual = <html>, accessibility = <aria-label attr> }.
function M.progress_dashes(progress_info, color_name, is_golden, position, has_corner_boxes)
    M.check_percentage(progress_info)
    local f = frame()
    local total_chars = is_golden and f.golden_fill or f.regular_fill
    local progress_chars = math.floor((progress_info.percentage / 100) * total_chars)
    local remaining_chars = total_chars - progress_chars

    local hex_color = color_config[color_name] or color_config["gray"]

    local LEFT_JUNCTION_POS = f.left_junction
    local RIGHT_JUNCTION_POS = f.right_junction
    local REGULAR_LEFT_JUNCTION_POS = f.left_junction
    local REGULAR_RIGHT_JUNCTION_POS = f.right_junction

    local visual_output
    if is_golden and position == "bottom" and has_corner_boxes then
        local left_in_progress = LEFT_JUNCTION_POS < progress_chars
        local right_in_progress = RIGHT_JUNCTION_POS < progress_chars
        -- LEFT junction is DOUBLE-up (╩ over ═, ╨ over ─) because the left nav
        -- box is double-line; RIGHT junction is single-up (╧/┴) for the
        -- single-line right box. This matches the golden ║-left / │-right frame.
        -- Left junction is the fill frontier of the similar box: double-up (╩)
        -- only when progress has passed column 10, single-up (┴) until then.
        local left_junction = left_in_progress
            and string.format('<font color="%s"><b>╩</b></font>', hex_color) or "┴"
        local right_junction = right_in_progress
            and string.format('<font color="%s"><b>╧</b></font>', hex_color) or "┴"

        local segments = {}
        local function add_segment(start_pos, end_pos)
            if end_pos <= start_pos then return end
            local seg_len = end_pos - start_pos
            local progress_in_seg = math.max(0, math.min(seg_len, progress_chars - start_pos))
            local remaining_in_seg = seg_len - progress_in_seg
            if progress_in_seg > 0 then
                segments[#segments + 1] = string.format('<font color="%s"><b>%s</b></font>',
                    hex_color, string.rep("═", progress_in_seg))
            end
            if remaining_in_seg > 0 then
                segments[#segments + 1] = string.rep("─", remaining_in_seg)
            end
        end

        -- Junctions sit at the inner walls, under the nav-box corners. The ╚
        -- corner is column 0 so the first dash segment starts at 1; the last
        -- segment runs to total_chars+1 so the interior is exactly golden_fill
        -- wide and the junctions line up with the separator above.
        add_segment(1, LEFT_JUNCTION_POS)
        segments[#segments + 1] = left_junction
        add_segment(LEFT_JUNCTION_POS + 1, RIGHT_JUNCTION_POS)
        segments[#segments + 1] = right_junction
        add_segment(RIGHT_JUNCTION_POS + 1, total_chars + 1)

        local colored_corner = string.format('<font color="%s"><b>╚</b></font>', hex_color)
        visual_output = colored_corner .. table.concat(segments, "") .. "┘"

    elseif not is_golden and position == "bottom" and has_corner_boxes then
        local left_in_progress = REGULAR_LEFT_JUNCTION_POS < progress_chars
        local right_in_progress = REGULAR_RIGHT_JUNCTION_POS < progress_chars
        local left_junction = left_in_progress
            and string.format('<font color="%s"><b>╧</b></font>', hex_color) or "┴"
        local right_junction = right_in_progress
            and string.format('<font color="%s"><b>╧</b></font>', hex_color) or "┴"
        local left_corner = progress_chars > 0
            and string.format('<font color="%s"><b>╘</b></font>', hex_color) or "╘"
        local right_corner = "┘"

        local segments = { left_corner }
        local function add_segment(start_pos, end_pos)
            if end_pos <= start_pos then return end
            local seg_len = end_pos - start_pos
            local progress_in_seg = math.max(0, math.min(seg_len, progress_chars - start_pos))
            local remaining_in_seg = seg_len - progress_in_seg
            if progress_in_seg > 0 then
                segments[#segments + 1] = string.format('<font color="%s"><b>%s</b></font>',
                    hex_color, string.rep("═", progress_in_seg))
            end
            if remaining_in_seg > 0 then
                segments[#segments + 1] = string.rep("─", remaining_in_seg)
            end
        end

        add_segment(1, REGULAR_LEFT_JUNCTION_POS)
        segments[#segments + 1] = left_junction
        add_segment(REGULAR_LEFT_JUNCTION_POS + 1, REGULAR_RIGHT_JUNCTION_POS)
        segments[#segments + 1] = right_junction
        add_segment(REGULAR_RIGHT_JUNCTION_POS + 1, total_chars - 1)
        segments[#segments + 1] = right_corner
        visual_output = table.concat(segments, "")

    elseif is_golden then
        local progress_section = string.rep("═", progress_chars)
        local remaining_section = string.rep("─", remaining_chars)
        local colored_progress = string.format('<font color="%s"><b>%s</b></font>%s',
            hex_color, progress_section, remaining_section)
        local colored_top_corner = string.format('<font color="%s"><b>╔</b></font>', hex_color)
        local colored_bottom_corner = string.format('<font color="%s"><b>╚</b></font>', hex_color)
        if position == "top" then
            visual_output = colored_top_corner .. colored_progress .. "┐"
        else
            visual_output = colored_bottom_corner .. colored_progress .. "┘"
        end
    else
        local progress_section = string.rep("═", progress_chars)
        local remaining_section = string.rep("─", remaining_chars)
        visual_output = string.format('<font color="%s"><b>%s</b></font>%s',
            hex_color, progress_section, remaining_section)
    end

    local screen_reader_text = is_golden
        and string.format('aria-label="golden poem border. %s."', color_name)
        or string.format('aria-label="eighty dashes. %s."', color_name)

    return {
        visual = visual_output,
        accessibility = screen_reader_text,
        raw_progress = progress_chars,
        raw_remaining = remaining_chars,
        color = color_name,
        percentage = progress_info.percentage,
        is_golden = is_golden or false,
    }
end
-- }}}

-- {{{ function M.corner_box_top()
-- Top line of the nav corner boxes for REGULAR poems: ┌──┐ ... ┌────┐
-- (frame width). A column is coloured once the bar above has filled it.
function M.corner_box_top(progress_chars, hex_color)
    local f = frame()
    progress_chars = progress_chars or 0
    local lj, rj, last = f.left_junction, f.right_junction, f.width - 1
    local left = {}
    left[#left + 1] = progress_chars > 0 and colorize_char("┌", hex_color) or "┌"
    for i = 1, lj - 1 do left[#left + 1] = progress_chars > i and colorize_char("─", hex_color) or "─" end
    left[#left + 1] = progress_chars > lj and colorize_char("┐", hex_color) or "┐"
    local gap = string.rep(" ", f.gap)
    local right = {}
    right[#right + 1] = progress_chars > rj and colorize_char("┌", hex_color) or "┌"
    for i = rj + 1, last - 1 do right[#right + 1] = progress_chars > i and colorize_char("─", hex_color) or "─" end
    right[#right + 1] = progress_chars > last and colorize_char("┐", hex_color) or "┐"
    return table.concat(left) .. gap .. table.concat(right)
end
-- }}}

-- {{{ function M.corner_box_nav_line()
-- The │ similar │ ... chronological ... │ different │ line for REGULAR poems
-- (frame width). chronological_link is nil on the chronological page itself.
function M.corner_box_nav_line(similar_link, different_link, chronological_link, progress_chars, hex_color)
    local f = frame()
    progress_chars = progress_chars or 0
    local similar_visible = similar_link:gsub("<[^>]+>", "")
    local different_visible = different_link:gsub("<[^>]+>", "")

    local center_text, center_visible_len = "", 0
    if chronological_link then
        center_text = chronological_link
        center_visible_len = chronological_link:gsub("<[^>]+>", ""):len()
    end

    local left_wall = progress_chars > 0 and colorize_char("│", hex_color) or "│"
    local right_wall_of_left = progress_chars > f.left_junction and colorize_char("│", hex_color) or "│"
    local similar_padding = f.left_box - 3 - #similar_visible
    local left_box = left_wall .. " " .. similar_link .. string.rep(" ", similar_padding) .. right_wall_of_left

    local left_wall_of_right = progress_chars > f.right_junction and colorize_char("│", hex_color) or "│"
    local right_wall = progress_chars > f.width - 1 and colorize_char("│", hex_color) or "│"
    local different_padding = f.right_box - 3 - #different_visible
    local right_box = left_wall_of_right .. " " .. different_link .. string.rep(" ", different_padding) .. right_wall

    -- the gap between the boxes, split around the centre link (if any)
    local spare = f.gap - center_visible_len
    local left_gap = string.rep(" ", math.floor(spare / 2))
    local right_gap = string.rep(" ", spare - math.floor(spare / 2))
    return left_box .. left_gap .. center_text .. right_gap .. right_box
end
-- }}}

-- {{{ function M.corner_box_bottom()
function M.corner_box_bottom()
    local f = frame()
    return "└" .. string.rep("─", f.left_box - 2) .. "┘" .. string.rep(" ", f.gap)
        .. "└" .. string.rep("─", f.right_box - 2) .. "┘"
end
-- }}}

-- {{{ function M.golden_corner_box_separator()
-- GOLDEN poem nav separator (frame width): ╠═════════╗ ... ┌───────────┤
-- The LEFT box is DOUBLE-line (╠ + 9×═ + ╗) because it fuses with the golden
-- poem's ║ outer wall; the RIGHT box is single-line (┌ + 11×─ + ┤) because the
-- golden poem's right wall is │. 60-space gap between.
function M.golden_corner_box_separator(hex_color, progress_chars)
    local f = frame()
    progress_chars = progress_chars or f.width  -- default: fully filled (back-compat)
    local lj, rj, last = f.left_junction, f.right_junction, f.width - 1
    -- Each dash MIRRORS the progress bar at that column: ═ (double, colored)
    -- where progress has reached, ─ (single) where it has not -- so the box top
    -- reads as a continuation of the bar. Corners are structural: ╠ joins the
    -- ║ frame, ╗ caps the double-line left box, ┌/┤ the single-line right box.
    local function dash(pos)
        return (progress_chars > pos) and colorize_char("═", hex_color) or "─"
    end
    local left = { colorize_char("╠", hex_color) }
    for i = 1, lj - 1 do left[#left + 1] = dash(i) end
    -- Right corner of the similar box is the FILL FRONTIER: double (╗) only once
    -- progress has swept past it, single (┐) until then.
    left[#left + 1] = (progress_chars > lj) and colorize_char("╗", hex_color) or "┐"
    -- a golden bar's fill counts from inside the ║ wall, one column behind
    local right = { (progress_chars > rj - 1) and colorize_char("┌", hex_color) or "┌" }
    for i = rj, last - 2 do right[#right + 1] = dash(i) end
    right[#right + 1] = (progress_chars > last - 1) and colorize_char("┤", hex_color) or "┤"
    return table.concat(left) .. string.rep(" ", f.gap) .. table.concat(right)
end
-- }}}

-- {{{ function M.golden_corner_box_nav_line()
-- GOLDEN poem nav line (frame width): ║ similar ║ ... chronological ... │ different │
-- Left box ║...║ = 11 (double-line, joins the ║ frame), right box │...│ = 13
-- (single-line); gaps 22+25 with center, 30+30 without.
function M.golden_corner_box_nav_line(similar_link, different_link, chronological_link, hex_color, progress_chars)
    local f = frame()
    progress_chars = progress_chars or f.width  -- default fully filled (back-compat)
    local similar_visible = similar_link:gsub("<[^>]+>", "")
    local different_visible = different_link:gsub("<[^>]+>", "")
    local center_text, center_visible_len = "", 0
    if chronological_link then
        center_text = chronological_link
        center_visible_len = chronological_link:gsub("<[^>]+>", ""):len()
    end
    local colored_wall = string.format('<font color="%s"><b>║</b></font>', hex_color)
    -- Left wall joins the ║ frame (always double). The RIGHT wall is the fill
    -- frontier: double ║ once progress passes column 10, single │ until then.
    local right_wall_of_left = (progress_chars > f.left_junction) and colored_wall or "│"
    local left_box = colored_wall .. " " .. similar_link .. string.rep(" ", f.left_box - 3 - #similar_visible) .. right_wall_of_left
    local right_box = "│ " .. different_link .. string.rep(" ", f.right_box - 3 - #different_visible) .. "│"
    -- the gap split around the centre link, as on a regular poem's nav line
    -- (the golden line put it one column left of the regular one until
    -- 2026-10-25; now the two sit in the same column)
    local spare = f.gap - center_visible_len
    local left_gap = string.rep(" ", math.floor(spare / 2))
    local right_gap = string.rep(" ", spare - math.floor(spare / 2))
    return left_box .. left_gap .. center_text .. right_gap .. right_box
end
-- }}}

return M
