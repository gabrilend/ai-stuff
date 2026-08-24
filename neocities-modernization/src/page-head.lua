-- {{{ page-head.lua
-- The one place that decides what goes inside every generated page's <head>.
--
-- In a sentence: it hands back the charset, the mobile viewport declaration and
-- the stylesheet that pins the poem grid to a real monospace font, so that a
-- frame drawn 83 columns wide is 83 columns wide on a phone too.
--
-- It exists because the same font stack had been pasted into four separate
-- generators, none of which declared a viewport, so a fix applied to one page
-- type silently left the other three alone.
-- }}}

local M = {}

-- {{{ M.FONT_DIR_NAME
-- Where the font files land under the site root. The generators copy
-- fonts/ to output/<this>/ and reference it relatively, so the site works
-- from a file:// preview as well as from the deployed domain.
M.FONT_DIR_NAME = "fonts"
-- }}}

-- {{{ M.FONT_FILES
-- The files that must be present for the layout to hold. Both weights, because
-- every progress bar is bold across its filled portion and regular across the
-- rest; a synthesized bold does not reliably keep the advance width, and a
-- half-bold bar with two different advances tears down the middle.
M.FONT_FILES = {
    "HackNerdFont-Regular.ttf",
    "HackNerdFont-Bold.ttf",
}
-- }}}

-- {{{ local function font_face_rules
-- Declares the shipped font under a name of our own -- "PoemGrid" -- rather than
-- under "Hack Nerd Font".
--
-- The distinction matters. If the @font-face name matched a font the visitor
-- already has installed, the browser is free to prefer the local copy, and a
-- local copy may be a different version with different coverage. Naming it
-- something no system ships guarantees every visitor renders from the same file
-- we tested, which is the entire point of shipping it.
local function font_face_rules(font_base)
    return string.format([[
@font-face {
  font-family: 'PoemGrid';
  src: url('%s/HackNerdFont-Regular.ttf') format('truetype');
  font-weight: normal;
  font-style: normal;
  font-display: swap;
}
@font-face {
  font-family: 'PoemGrid';
  src: url('%s/HackNerdFont-Bold.ttf') format('truetype');
  font-weight: bold;
  font-style: normal;
  font-display: swap;
}]], font_base, font_base)
end
-- }}}

-- {{{ local function base_style
-- The rules the poem grid depends on, in the order they matter.
--
-- font-family: our shipped face first, then the old stack as the interim answer
-- while the font file is still downloading (font-display:swap shows fallback
-- text rather than nothing), then generic monospace as the last resort.
--
-- text-size-adjust: turns OFF the automatic text inflation that iOS Safari and
-- Chrome-on-Android apply to blocks they judge to be body copy. That inflation
-- is computed per block, so two blocks can end up at two different font sizes --
-- and two font sizes means two cell widths, which means the frames stop lining
-- up with each other even when every character is correct.
local function base_style()
    return [[
body, pre {
  font-family: 'PoemGrid', 'Hack Nerd Font', 'Hack', 'Fira Code', 'JetBrains Mono',
               'Cascadia Code', 'Consolas', 'Monaco', 'Liberation Mono',
               'Courier New', monospace;
  -webkit-text-size-adjust: 100%;
  -moz-text-size-adjust: 100%;
  text-size-adjust: 100%;
}
/* The poem column is a fixed 83-character grid and must never reflow. On a
   screen narrower than that the page scrolls sideways, which is the honest
   outcome: wrapping the frames would break the alignment they exist to show. */
pre {
  white-space: pre;
  overflow-x: auto;
}]]
end
-- }}}

-- {{{ function M.viewport_meta
-- Tells a mobile browser to lay the page out at the device's real width.
--
-- Without this tag a phone assumes a 980-pixel desktop viewport, lays everything
-- out for that, then scales the result down to the physical screen -- so the
-- site arrives unreadably small. It also leaves the browser's automatic text
-- inflation switched on, which this tag disables as a side effect.
--
-- initial-scale=1 starts unzoomed; the user is deliberately left able to zoom,
-- since an 83-column grid on a phone is something people will want to pinch.
function M.viewport_meta()
    return '<meta name="viewport" content="width=device-width, initial-scale=1">'
end
-- }}}

-- {{{ function M.style_block
-- The <style> element for a page, given how deep that page sits.
--
-- base_path is the relative route back to the site root -- "." for a page at the
-- root, ".." for one inside output/similar/ or output/wordcloud/. It is a
-- required argument rather than a defaulted one: guessing wrong yields a 404 on
-- the font and a silent return to the broken rendering, which is precisely the
-- failure this module was written to end.
function M.style_block(base_path, extra_css)
    assert(type(base_path) == "string" and base_path ~= "",
        "page-head.style_block: base_path is required (\".\" at site root, \"..\" one level down)")
    local font_base = base_path .. "/" .. M.FONT_DIR_NAME
    return table.concat({
        "<style>",
        font_face_rules(font_base),
        base_style(),
        extra_css or "",
        "</style>",
    }, "\n")
end
-- }}}

-- {{{ function M.head
-- The whole <head> for a generated page.
--
-- opts.title      : string, the page title (already HTML-safe).
-- opts.base_path  : string, relative route to the site root (see style_block).
-- opts.extra_css  : optional string, page-specific rules appended to the sheet.
-- opts.extra_meta : optional string, additional <meta>/<link> markup.
function M.head(opts)
    opts = opts or {}
    local parts = {
        "<head>",
        '<meta charset="UTF-8">',
        M.viewport_meta(),
    }
    if opts.title then
        table.insert(parts, "<title>" .. opts.title .. "</title>")
    end
    if opts.extra_meta then
        table.insert(parts, opts.extra_meta)
    end
    table.insert(parts, M.style_block(opts.base_path, opts.extra_css))
    table.insert(parts, "</head>")
    return table.concat(parts, "\n")
end
-- }}}

return M
