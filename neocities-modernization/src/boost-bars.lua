-- boost-bars.lua
--
-- The nested frame for "boost" (reshared) posts, shared by every render path so
-- the three copies can't drift (they had, in several different ways). A boost
-- frame is ASYMMETRIC like a golden poem: the LEFT edge is permanently double
-- (it anchors the frame), the RIGHT edge is a FILL FRONTIER -- single (┐│┴)
-- until the progress bar's ═ reaches the far-right column, then double (╗║╩),
-- which only happens for the chronologically-last poems. Arrows ride the
-- corners: ◀═ into the top-left, ─▶ out of the bottom-right.
--
-- Geometry (columns, 0-indexed; the whole line is 82 wide before the ─▶):
--   col 0-1 : ◀═ arrow (top) / two spaces (other lines)
--   col 2   : outer-left wall  (╦ top / ║ body / ╠ nav-sep / ╚ bottom)  -- DOUBLE
--   col 3-80: 78-wide interior (progress bar, or " inner-box ")
--   col 81  : outer-right wall (┐/│/┤/┴  -> ╗/║/┤?/╩ once filled)        -- FRONTIER
--   then    : ─▶ arrow on the bottom line only
--
-- Colors are injected (the project's boost palette) so this module is palette-
-- agnostic, mirroring poem-bars.

local M = {}

local BAR_WIDTH = 78     -- progress bar interior, columns 3..80
local LABEL = "[BOOST]"
local LABEL_LEN = 7

-- Visible content width inside the green box. It is 72 (not the old 74) because
-- the body lines are indented 2 columns so their ║ wall sits at col 2, aligned
-- under the top border's ╦ (which the ◀═ arrow pushes off col 0). Callers that
-- pre-wrap long content/URLs must wrap to THIS width.
M.CONTENT_WIDTH = 72

local palette = {
    arrow = "#dc3c3c", outer_frame = "#74C0FC", inner_box = "#38D9A9",
    content_text = "#c8b428",   -- the boosted text itself (yellow)
}

-- {{{ function M.configure()
function M.configure(p)
    palette = p or palette
end
-- }}}

-- {{{ local color()
local function color(ch, hex, bold)
    if bold then
        return string.format('<font color="%s"><b>%s</b></font>', hex, ch)
    end
    return string.format('<font color="%s">%s</font>', hex, ch)
end
-- }}}

-- right_filled(progress_chars): is the far-right column (the last bar cell)
-- filled? That decides whether the right frame edge is double or single.
local function right_filled(progress_chars)
    return progress_chars >= BAR_WIDTH
end

-- {{{ function M.top_border()
-- ◀═╦ ═══[BOOST]═══ ─── ┐   (┐ becomes ╗ when the bar is full)
function M.top_border(progress_pct)
    local progress_chars = math.floor(progress_pct * BAR_WIDTH)
    if progress_chars < LABEL_LEN + 2 then progress_chars = LABEL_LEN + 2 end
    local label_start = math.floor(progress_chars / 2) - math.floor(LABEL_LEN / 2)
    if label_start < 1 then label_start = 1 end

    -- Arrow ◀═ feeds into the ╦ tee (double, anchors the left frame edge).
    local out = { color("◀═", palette.arrow, true), color("╦", palette.outer_frame, true) }
    -- Single pass: never re-slice a multibyte string (that produced ▢ before).
    for i = 1, BAR_WIDTH do
        if i >= label_start and i < label_start + LABEL_LEN then
            local ch = LABEL:sub(i - label_start + 1, i - label_start + 1)  -- ASCII, safe
            out[#out + 1] = color(ch, palette.arrow, true)
        elseif i <= progress_chars then
            out[#out + 1] = color("═", palette.outer_frame, true)
        else
            out[#out + 1] = color("─", palette.outer_frame, false)
        end
    end
    -- Right corner: fill frontier.
    out[#out + 1] = right_filled(progress_chars)
        and color("╗", palette.outer_frame, true) or "┐"
    return table.concat(out)
end
-- }}}

-- outer_right(progress_chars, single_char, double_char): the right frame wall,
-- single until the bar fills the far-right column, then double.
local function outer_right(progress_chars, single_char, double_char)
    if right_filled(progress_chars) then
        return color(double_char, palette.outer_frame, true)
    end
    return single_char
end

-- {{{ function M.inner_top()  ->   ║ ┌──────────┐ │
function M.inner_top(progress_chars)
    return "  " .. color("║", palette.outer_frame, true) .. " "
        .. color("┌" .. string.rep("─", 74) .. "┐", palette.inner_box, false) .. " "
        .. outer_right(progress_chars, "│", "║")
end
-- }}}

-- {{{ function M.inner_bottom()  ->   ║ └──────────┘ │
function M.inner_bottom(progress_chars)
    return "  " .. color("║", palette.outer_frame, true) .. " "
        .. color("└" .. string.rep("─", 74) .. "┘", palette.inner_box, false) .. " "
        .. outer_right(progress_chars, "│", "║")
end
-- }}}

-- {{{ function M.content_line()  ->   ║ │ <content padded to 72> │ │
function M.content_line(content, progress_chars)
    content = content or ""
    -- Count UTF-8 codepoints of the tag-stripped text for an honest column width.
    local visible = content:gsub("<[^>]+>", "")
    local _, vlen = visible:gsub("[^\128-\191]", "")
    -- Color the text yellow, THEN pad with plain spaces (padding stays uncolored).
    local colored = string.format('<font color="%s">%s</font>', palette.content_text, content)
    local padded = colored .. string.rep(" ", math.max(0, M.CONTENT_WIDTH - vlen))
    local inner = color("│", palette.inner_box, false)
    return "  " .. color("║", palette.outer_frame, true) .. " "
        .. inner .. " " .. padded .. " " .. inner .. " "
        .. outer_right(progress_chars, "│", "║")
end
-- }}}

-- Nav-box geometry (within the 78-wide interior, cols 3..80):
--   similar box  : frame-wall(col2) + " similar " (9, cols 3-11) + box-wall(col12)
--   gap          : 56 spaces (cols 13-68)
--   different box: box-wall(col69) + " different " (11, cols 70-80) + frame-wall(col81)
-- The nav boxes are GREEN (inner_box) like the content box; only the FRAME's
-- right edge (col 81) is the fill frontier. The similar/different box walls
-- stay single green -- the user asked for the far-right frontier only on boosts
-- (the per-column "reflection" frontier is a golden-poem feature, in poem-bars).
local NAV_GAP = 56

-- {{{ function M.nav_separator()  ->  ╠─────────┐ ... ┌───────────┤
function M.nav_separator(progress_chars)
    local frame_wall = color("╠", palette.outer_frame, true)   -- frame left, always double
    local g_dash = color("─", palette.inner_box, false)
    local g_corner_l = color("┐", palette.inner_box, false)    -- similar box right corner
    local g_corner_r = color("┌", palette.inner_box, false)    -- different box left corner
    local similar_box = frame_wall .. string.rep(g_dash, 9) .. g_corner_l
    local different_box = g_corner_r .. string.rep(g_dash, 11)
        .. outer_right(progress_chars, "┤", "╣")               -- frame right = frontier
    return "  " .. similar_box .. string.rep(" ", NAV_GAP) .. different_box
end
-- }}}

-- {{{ function M.nav_line()  ->  ║ similar │ ... chronological ... │ different │
function M.nav_line(similar_link, different_link, chronological_link, progress_chars)
    local frame_wall = color("║", palette.outer_frame, true)   -- frame left, always double
    local g_wall = color("│", palette.inner_box, false)        -- green box wall
    local sim_html = similar_link or "similar"
    local dif_html = different_link or "different"
    local sim_vis = #(sim_html:gsub("<[^>]+>", ""))
    local dif_vis = #(dif_html:gsub("<[^>]+>", ""))
    -- " <link> " padded so the visible cell is exactly 9 / 11 wide.
    local similar_cell = " " .. sim_html .. string.rep(" ", math.max(0, 9 - 2 - sim_vis)) .. " "
    local different_cell = " " .. dif_html .. string.rep(" ", math.max(0, 11 - 2 - dif_vis)) .. " "
    -- Center the optional chronological link inside the 56-wide gap.
    local center = chronological_link or ""
    local center_vis = #(center:gsub("<[^>]+>", ""))
    local rem = NAV_GAP - center_vis
    local left_gap = string.rep(" ", math.floor(rem / 2))
    local right_gap = string.rep(" ", math.ceil(rem / 2))
    return "  " .. frame_wall .. similar_cell .. g_wall
        .. left_gap .. center .. right_gap
        .. g_wall .. different_cell .. outer_right(progress_chars, "│", "║")
end
-- }}}

-- {{{ function M.bottom_border()  ->  ╚═══╧═══...═══┴═══╩─▶
-- Junctions sit UNDER the nav-box walls: similar box wall at col 12 (bar-index
-- 10), different box wall at col 69 (bar-index 67). The bottom-right corner is
-- the fill frontier (┴ single -> ╩ double) and the ─▶ arrow exits to the right.
function M.bottom_border(progress_pct)
    local progress_chars = math.floor(progress_pct * BAR_WIDTH)
    local LEFT_JUNCTION = 10
    local RIGHT_JUNCTION = 67
    local out = { "  ", color("╚", palette.outer_frame, true) }
    for i = 1, BAR_WIDTH do
        local in_progress = i <= progress_chars
        -- Junction: the green nav wall above lands here. Double-down ╧ once the
        -- bar has filled past it, single ┴ until then.
        if i == LEFT_JUNCTION or i == RIGHT_JUNCTION then
            out[#out + 1] = in_progress
                and color("╧", palette.outer_frame, true) or color("┴", palette.outer_frame, false)
        elseif in_progress then
            out[#out + 1] = color("═", palette.outer_frame, true)
        else
            out[#out + 1] = color("─", palette.outer_frame, false)
        end
    end
    -- Bottom-right corner connects up(wall) + left(bar) + right(arrow): ┴/╩.
    out[#out + 1] = right_filled(progress_chars)
        and color("╩", palette.outer_frame, true) or color("┴", palette.outer_frame, false)
    out[#out + 1] = color("─▶", palette.arrow, true)
    return table.concat(out)
end
-- }}}

-- {{{ function M.format_boost()
-- Assemble a whole boost frame. content_lines is an array of pre-wrapped,
-- already-HTML-colored content strings (the caller handles URL wrapping etc.).
-- include_nav adds the similar/different/chronological row.
function M.format_boost(content_lines, progress_pct, similar_link, different_link, chronological_link, include_nav)
    local progress_chars = math.floor(progress_pct * BAR_WIDTH)
    local out = { M.top_border(progress_pct), M.inner_top(progress_chars) }
    for _, line in ipairs(content_lines) do
        out[#out + 1] = M.content_line(line, progress_chars)
    end
    out[#out + 1] = M.inner_bottom(progress_chars)
    if include_nav then
        out[#out + 1] = M.nav_separator(progress_chars)
        out[#out + 1] = M.nav_line(similar_link, different_link, chronological_link, progress_chars)
    end
    out[#out + 1] = M.bottom_border(progress_pct)
    return table.concat(out, "\n")
end
-- }}}

return M
