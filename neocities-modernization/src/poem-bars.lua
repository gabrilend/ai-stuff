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
-- Geometry (regular poems, 83 chars wide, 0-indexed):
--   left corner box  : positions 0-10  (┌ + 9×─ + ┐ , walls at 0 and 10)
--   gap              : positions 11-69 (59 spaces)
--   right corner box : positions 70-82 (┌ + 11×─ + ┐, walls at 70 and 82)
-- Bottom-bar junctions sit UNDER the inner walls, at positions 10 and 70.
-- Golden poems are 84 wide (2 outer ║ walls); the right junction shifts to 71.

local M = {}

-- Color config (name -> hex). Injected by the host so this module needs no
-- knowledge of the project's palette. configure() is called once per Lua state
-- (main thread and each worker).
local color_config = {}

-- {{{ function M.configure()
function M.configure(cfg)
    color_config = cfg or {}
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

-- {{{ function M.progress_dashes()
-- The top/bottom separator bar. position is "top" or "bottom"; has_corner_boxes
-- inserts the ╧/┴ junctions that connect a bottom bar to the nav corner boxes.
-- Returns { visual = <html>, accessibility = <aria-label attr> }.
function M.progress_dashes(progress_info, color_name, is_golden, position, has_corner_boxes)
    local total_chars = is_golden and 82 or 83
    local progress_chars = math.floor((progress_info.percentage / 100) * total_chars)
    local remaining_chars = total_chars - progress_chars

    local hex_color = color_config[color_name] or color_config["gray"]

    local LEFT_JUNCTION_POS = 10
    local RIGHT_JUNCTION_POS = 71            -- golden: right inner wall (1 wider)
    local REGULAR_LEFT_JUNCTION_POS = 10
    local REGULAR_RIGHT_JUNCTION_POS = 70

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

        -- Junctions sit at columns 10 and 71, under the nav-box corners. The ╚
        -- corner is column 0 so the first dash segment starts at 1; the last
        -- segment runs to total_chars+1 so the interior is exactly 82 wide and
        -- the junctions line up with the separator above (the reflection).
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
-- Top line of the nav corner boxes for REGULAR poems: ┌──┐ ... ┌────┐ (83 wide).
function M.corner_box_top(progress_chars, hex_color)
    progress_chars = progress_chars or 0
    local left = {}
    left[#left + 1] = progress_chars > 0 and colorize_char("┌", hex_color) or "┌"
    for i = 1, 9 do left[#left + 1] = progress_chars > i and colorize_char("─", hex_color) or "─" end
    left[#left + 1] = progress_chars > 10 and colorize_char("┐", hex_color) or "┐"
    local gap = string.rep(" ", 59)
    local right = {}
    right[#right + 1] = progress_chars > 70 and colorize_char("┌", hex_color) or "┌"
    for i = 71, 81 do right[#right + 1] = progress_chars > i and colorize_char("─", hex_color) or "─" end
    right[#right + 1] = progress_chars > 82 and colorize_char("┐", hex_color) or "┐"
    return table.concat(left) .. gap .. table.concat(right)
end
-- }}}

-- {{{ function M.corner_box_nav_line()
-- The │ similar │ ... chronological ... │ different │ line for REGULAR poems
-- (83 wide). chronological_link is nil on the chronological page itself.
function M.corner_box_nav_line(similar_link, different_link, chronological_link, progress_chars, hex_color)
    progress_chars = progress_chars or 0
    local similar_visible = similar_link:gsub("<[^>]+>", "")
    local different_visible = different_link:gsub("<[^>]+>", "")

    local center_text, center_visible_len = "", 0
    if chronological_link then
        center_text = chronological_link
        center_visible_len = chronological_link:gsub("<[^>]+>", ""):len()
    end

    local left_wall = progress_chars > 0 and colorize_char("│", hex_color) or "│"
    local right_wall_of_left = progress_chars > 10 and colorize_char("│", hex_color) or "│"
    local similar_padding = 9 - 1 - #similar_visible
    local left_box = left_wall .. " " .. similar_link .. string.rep(" ", similar_padding) .. right_wall_of_left

    local left_wall_of_right = progress_chars > 70 and colorize_char("│", hex_color) or "│"
    local right_wall = progress_chars > 82 and colorize_char("│", hex_color) or "│"
    local different_padding = 11 - 1 - #different_visible
    local right_box = left_wall_of_right .. " " .. different_link .. string.rep(" ", different_padding) .. right_wall

    local left_gap, right_gap
    if center_visible_len > 0 then
        left_gap, right_gap = string.rep(" ", 23), string.rep(" ", 23)
    else
        left_gap, right_gap = string.rep(" ", 29), string.rep(" ", 30)
    end
    return left_box .. left_gap .. center_text .. right_gap .. right_box
end
-- }}}

-- {{{ function M.corner_box_bottom()
function M.corner_box_bottom()
    return "└" .. string.rep("─", 9) .. "┘" .. string.rep(" ", 59) .. "└" .. string.rep("─", 11) .. "┘"
end
-- }}}

-- {{{ function M.golden_corner_box_separator()
-- GOLDEN poem nav separator (84 wide): ╠═════════╗ ... ┌───────────┤
-- The LEFT box is DOUBLE-line (╠ + 9×═ + ╗) because it fuses with the golden
-- poem's ║ outer wall; the RIGHT box is single-line (┌ + 11×─ + ┤) because the
-- golden poem's right wall is │. 60-space gap between.
function M.golden_corner_box_separator(hex_color, progress_chars)
    progress_chars = progress_chars or 84  -- default: fully filled (back-compat)
    -- Each dash MIRRORS the progress bar at that column: ═ (double, colored)
    -- where progress has reached, ─ (single) where it has not -- so the box top
    -- reads as a continuation of the bar. Corners are structural: ╠ joins the
    -- ║ frame, ╗ caps the double-line left box, ┌/┤ the single-line right box.
    local function dash(pos)
        return (progress_chars > pos) and colorize_char("═", hex_color) or "─"
    end
    local left = { colorize_char("╠", hex_color) }
    for i = 1, 9 do left[#left + 1] = dash(i) end
    -- Right corner of the similar box is the FILL FRONTIER: double (╗) only once
    -- progress has swept past column 10, single (┐) until then.
    left[#left + 1] = (progress_chars > 10) and colorize_char("╗", hex_color) or "┐"
    local right = { (progress_chars > 70) and colorize_char("┌", hex_color) or "┌" }
    for i = 71, 81 do right[#right + 1] = dash(i) end
    right[#right + 1] = (progress_chars > 82) and colorize_char("┤", hex_color) or "┤"
    return table.concat(left) .. string.rep(" ", 60) .. table.concat(right)
end
-- }}}

-- {{{ function M.golden_corner_box_nav_line()
-- GOLDEN poem nav line (84 wide): ║ similar ║ ... chronological ... │ different │
-- Left box ║...║ = 11 (double-line, joins the ║ frame), right box │...│ = 13
-- (single-line); gaps 22+25 with center, 30+30 without.
function M.golden_corner_box_nav_line(similar_link, different_link, chronological_link, hex_color, progress_chars)
    progress_chars = progress_chars or 84  -- default fully filled (back-compat)
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
    local right_wall_of_left = (progress_chars > 10) and colored_wall or "│"
    local left_box = colored_wall .. " " .. similar_link .. string.rep(" ", 9 - 1 - #similar_visible) .. right_wall_of_left
    local right_box = "│ " .. different_link .. string.rep(" ", 11 - 1 - #different_visible) .. "│"
    local left_gap, right_gap
    if center_visible_len > 0 then
        left_gap, right_gap = string.rep(" ", 22), string.rep(" ", 25)
    else
        left_gap, right_gap = string.rep(" ", 30), string.rep(" ", 30)
    end
    return left_box .. left_gap .. center_text .. right_gap .. right_box
end
-- }}}

return M
