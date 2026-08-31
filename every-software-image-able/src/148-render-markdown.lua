#!/usr/bin/env luajit
-- 148-render-markdown.lua
--
-- One written document to the HTML of its body. The rendering half of the
-- documentation site; `149` is the half that decides what gets rendered.
--
-- For a general: the documents in this project are written in the plain-text
-- convention where a line starting with a hash is a heading and a run of pipes
-- is a table. Something has to turn that into what a browser draws. This is
-- that, and it is deliberately small: it handles what these documents actually
-- contain rather than everything the convention allows.
--
-- WHY IT IS SEPARATE FROM THE SITE. Turning text into HTML and deciding which
-- files exist are different jobs with different failure modes -- one produces
-- ugly output and the other produces a broken link -- and keeping them apart
-- means the renderer can be exercised on a string with no directory anywhere
-- near it.
--
-- HOW CROSS-REFERENCING GETS IN WITHOUT THIS KNOWING ABOUT IT. Every entry
-- point takes a `link` function, which is handed the text inside a code span
-- and answers with a destination or nothing. So this never learns what a ticket
-- is, what a source file is, or which of them a bare number means; it only
-- knows that some code spans turn out to be links.
--
-- WHAT IT DOES NOT HANDLE, ON PURPOSE. Nested emphasis, reference-style links,
-- footnotes, and lists more than two deep. None of them appear in these
-- documents, and anything unrecognised comes out as a paragraph, which is the
-- harmless failure rather than the silent one.
--
-- library:
--   local render = dofile(DIR .. "/src/148-render-markdown.lua")
--   local body, headings = render.markdown("# a heading\n\nand a paragraph")

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

local M = {}

-- {{{ local function escape(text)
-- The three characters that would otherwise be read as markup. Done first, on
-- everything, so that nothing downstream has to remember.
local function escape(text)
  text = text:gsub("&", "&amp;")
  text = text:gsub("<", "&lt;")
  text = text:gsub(">", "&gt;")
  return text
end
-- }}}

-- {{{ local function slug(text)
-- A heading to the name of the place it can be jumped to. Lower case, letters
-- and digits, hyphens for everything else -- the ordinary shape, chosen because
-- it survives being typed into an address bar by hand.
local function slug(text)
  text = text:gsub("<[^>]->", "")
  text = text:gsub("&[%a]+;", "")
  text = text:lower():gsub("[^%w]+", "-")
  return (text:gsub("^%-+", ""):gsub("%-+$", ""))
end
-- }}}

-- {{{ local function highlight(code, language)
--
-- Colour for a fenced block. Lua and shell get real tokenising; everything else
-- is left alone rather than guessed at, because assembly listings and serial
-- logs are most of what remains and a highlighter that guesses at those makes
-- them harder to read rather than easier.
--
-- Order matters: strings and comments are taken out first and put back last, so
-- a keyword inside a string is not coloured and a quote inside a comment does
-- not open a string.
local KEYWORDS = {
  ["local"] = true, ["function"] = true, ["end"] = true, ["if"] = true,
  ["then"] = true, ["else"] = true, ["elseif"] = true, ["for"] = true,
  ["while"] = true, ["do"] = true, ["return"] = true, ["and"] = true,
  ["or"] = true, ["not"] = true, ["nil"] = true, ["true"] = true,
  ["false"] = true, ["in"] = true, ["repeat"] = true, ["until"] = true,
  ["break"] = true,
}
local SHELL_WORDS = {
  ["if"] = true, ["then"] = true, ["fi"] = true, ["for"] = true, ["do"] = true,
  ["done"] = true, ["case"] = true, ["esac"] = true, ["echo"] = true,
  ["printf"] = true, ["local"] = true, ["exit"] = true, ["return"] = true,
  ["while"] = true, ["read"] = true, ["luajit"] = true,
}

local function highlight(code, language)
  if language ~= "lua" and language ~= "sh" and language ~= "bash" then
    return escape(code)
  end
  local words = (language == "lua") and KEYWORDS or SHELL_WORDS

  local kept, out = {}, {}
  -- {{{ take the strings and comments out, leaving markers behind
  --
  -- The marker's number is written in letters rather than digits, and that is
  -- not decoration. The first version used digits, and the pass below that
  -- colours numbers found them and coloured the markers -- so every comment in
  -- every fenced block was replaced by the marker's own index. The output was
  -- valid, looked deliberate, and had silently eaten the commentary.
  local function keep(class, text)
    kept[#kept + 1] = '<span class="' .. class .. '">' .. escape(text) .. "</span>"
    local label = tostring(#kept):gsub("%d", function(digit)
      return string.char(97 + tonumber(digit))
    end)
    return "\1" .. label .. "\2"
  end

  local text = code
  if language == "lua" then
    text = text:gsub("%-%-%[%[.-%]%]", function(m) return keep("c", m) end)
    text = text:gsub("%-%-[^\n]*", function(m) return keep("c", m) end)
  else
    text = text:gsub("#[^\n]*", function(m) return keep("c", m) end)
  end
  text = text:gsub('"[^"\n]*"', function(m) return keep("s", m) end)
  text = text:gsub("'[^'\n]*'", function(m) return keep("s", m) end)
  -- }}}

  -- {{{ colour what is left, then put the markers back
  text = escape(text)
  text = text:gsub("()([%a_][%w_]*)", function(_, word)
    if words[word] then return '<span class="k">' .. word .. "</span>" end
    return word
  end)
  text = text:gsub("%f[%w](0[xX]%x+)", '<span class="n">%1</span>')
  text = text:gsub("%f[%w](%d+%.?%d*)%f[%W]", '<span class="n">%1</span>')

  text = text:gsub("\1(%a+)\2", function(label)
    local digits = label:gsub("%a", function(letter)
      return tostring(string.byte(letter) - 97)
    end)
    return kept[tonumber(digits)]
  end)
  -- }}}

  out[#out + 1] = text
  return table.concat(out)
end
-- }}}

-- {{{ local function inline(text, link)
--
-- The markup that happens inside a line: code spans, bold, italic, and written
-- links. `link` is a function from the text of a code span to a destination, or
-- nil -- which is how the cross-referencing gets in without this knowing what a
-- ticket is.
--
-- Code spans are handled first and held aside, because everything else here
-- would otherwise reach inside them: a path with underscores would come out
-- italic, and this project's paths are full of them.
local function inline(text, link)
  local kept = {}
  text = text:gsub("`([^`]+)`", function(body)
    local shown = escape(body)
    local target = link and link(body)
    local piece
    if target then
      piece = '<a class="ref" href="' .. target .. '"><code>' .. shown .. "</code></a>"
    else
      piece = "<code>" .. shown .. "</code>"
    end
    kept[#kept + 1] = piece
    return "\1" .. #kept .. "\2"
  end)

  text = escape(text)
  text = text:gsub("%[([^%]]+)%]%(([^%)]+)%)", '<a href="%2">%1</a>')
  text = text:gsub("%*%*([^%*]+)%*%*", "<strong>%1</strong>")
  text = text:gsub("%f[%*]%*([^%*\n]+)%*%f[^%*]", "<em>%1</em>")

  text = text:gsub("\1(%d+)\2", function(index) return kept[tonumber(index)] end)
  return text
end
-- }}}

-- {{{ M.markdown(source, link)
--
-- A markdown document to the HTML of its body. Returns the html and a list of
-- its headings, each { level, text, id }, which is what builds the outline that
-- sits beside a long page.
--
-- Handles what this project actually writes: fenced code, headings, tables,
-- bulleted and numbered lists, quotes, rules and paragraphs. It is a renderer
-- for these documents rather than a general one, and anything it does not know
-- comes out as a paragraph, which is the harmless failure.
function M.markdown(source, link)
  local out, headings = {}, {}
  local lines = {}
  for line in (source .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end

  local index, paragraph = 1, {}

  -- {{{ local function flush() -- close whatever paragraph is open
  local function flush()
    if #paragraph > 0 then
      out[#out + 1] = "<p>" .. inline(table.concat(paragraph, " "), link) .. "</p>"
      paragraph = {}
    end
  end
  -- }}}

  while index <= #lines do
    local line = lines[index]

    -- {{{ a fenced block, which swallows everything until it closes
    local fence, language = line:match("^(```+)(%w*)")
    if fence then
      flush()
      local body = {}
      index = index + 1
      while index <= #lines and not lines[index]:match("^```") do
        body[#body + 1] = lines[index]
        index = index + 1
      end
      local code = table.concat(body, "\n")
      out[#out + 1] = '<pre class="code"><code>' .. highlight(code, language) .. "</code></pre>"
      index = index + 1

    -- }}}
    -- {{{ a table, recognised by a row of pipes with a rule under it
    elseif line:match("^|") and lines[index + 1] and lines[index + 1]:match("^|%s*%-%-") then
      flush()
      local rows = {}
      local header = line
      index = index + 2
      while index <= #lines and lines[index]:match("^|") do
        rows[#rows + 1] = lines[index]
        index = index + 1
      end

      local function cells_of(row)
        local cells = {}
        -- The leading and trailing pipes are punctuation, not empty cells.
        row = row:gsub("^%s*|", ""):gsub("|%s*$", "")
        for cell in (row .. "|"):gmatch("(.-)|") do
          cells[#cells + 1] = inline((cell:gsub("^%s+", ""):gsub("%s+$", "")), link)
        end
        return cells
      end

      local piece = { "<table><thead><tr>" }
      for _, cell in ipairs(cells_of(header)) do
        piece[#piece + 1] = "<th>" .. cell .. "</th>"
      end
      piece[#piece + 1] = "</tr></thead><tbody>"
      for _, row in ipairs(rows) do
        piece[#piece + 1] = "<tr>"
        for _, cell in ipairs(cells_of(row)) do
          piece[#piece + 1] = "<td>" .. cell .. "</td>"
        end
        piece[#piece + 1] = "</tr>"
      end
      piece[#piece + 1] = "</tbody></table>"
      out[#out + 1] = table.concat(piece)

    -- }}}
    -- {{{ a heading, which is also a place that can be linked to
    elseif line:match("^#+%s") then
      flush()
      local hashes, text = line:match("^(#+)%s+(.*)$")
      local level = #hashes
      local rendered = inline(text, link)
      local id = slug(text)
      headings[#headings + 1] = { level = level, text = rendered, id = id }
      out[#out + 1] = "<h" .. level .. ' id="' .. id .. '">' ..
                      '<a class="anchor" href="#' .. id .. '">#</a>' ..
                      rendered .. "</h" .. level .. ">"
      index = index + 1

    -- }}}
    -- {{{ a rule
    elseif line:match("^%-%-%-+%s*$") or line:match("^___+%s*$") then
      flush()
      out[#out + 1] = "<hr>"
      index = index + 1

    -- }}}
    -- {{{ a quote
    elseif line:match("^>%s?") then
      flush()
      local body = {}
      while index <= #lines and lines[index]:match("^>%s?") do
        body[#body + 1] = lines[index]:gsub("^>%s?", "")
        index = index + 1
      end
      out[#out + 1] = "<blockquote>" ..
                      M.markdown(table.concat(body, "\n"), link) .. "</blockquote>"

    -- }}}
    -- {{{ a list, bulleted or numbered, one level of nesting
    elseif line:match("^%s*[%-%*]%s") or line:match("^%s*%d+%.%s") then
      flush()
      local numbered = line:match("^%s*%d+%.%s") ~= nil
      local tag = numbered and "ol" or "ul"
      local piece, open_nested = { "<" .. tag .. ">" }, false

      -- Nesting is measured against the FIRST item rather than against zero.
      -- A whole list can sit indented -- inside a comment block, or under a
      -- heading somebody indented by hand -- and read as though every item were
      -- nested, which opens an inner list that never had an outer item to sit
      -- in and leaves the page unbalanced.
      local base = #(line:match("^(%s*)") or "")

      while index <= #lines do
        local item = lines[index]
        local indent, body = item:match("^(%s*)[%-%*]%s+(.*)$")
        if not body then indent, body = item:match("^(%s*)%d+%.%s+(.*)$") end

        if body then
          -- A nested list belongs INSIDE the item above it, so opening one
          -- means reaching back and un-closing that item. Written the obvious
          -- way it lands between two items instead, which browsers tolerate and
          -- which indents nothing.
          local nested = #indent >= base + 2
          if nested and not open_nested then
            if piece[#piece] == "</li>" then piece[#piece] = nil end
            piece[#piece + 1] = "<ul>" ; open_nested = true
          elseif not nested and open_nested then
            piece[#piece + 1] = "</ul></li>" ; open_nested = false
          end
          piece[#piece + 1] = "<li>" .. inline(body, link)
          index = index + 1
          -- A continuation line is one that is indented and is not itself an
          -- item; it belongs to the item above rather than starting anything.
          while index <= #lines and lines[index]:match("^%s+%S")
                and not lines[index]:match("^%s*[%-%*]%s")
                and not lines[index]:match("^%s*%d+%.%s") do
            piece[#piece + 1] = " " .. inline((lines[index]:gsub("^%s+", "")), link)
            index = index + 1
          end
          piece[#piece + 1] = "</li>"
        elseif item:match("^%s*$") and lines[index + 1]
               and (lines[index + 1]:match("^%s*[%-%*]%s") or lines[index + 1]:match("^%s*%d+%.%s")) then
          -- A blank line between items is spacing, not the end of the list.
          index = index + 1
        else
          break
        end
      end
      if open_nested then piece[#piece + 1] = "</ul></li>" end
      piece[#piece + 1] = "</" .. tag .. ">"
      out[#out + 1] = table.concat(piece)

    -- }}}
    -- {{{ a blank line closes a paragraph; anything else extends one
    elseif line:match("^%s*$") then
      flush()
      index = index + 1
    else
      paragraph[#paragraph + 1] = line
      index = index + 1
    end
    -- }}}
  end

  flush()
  return table.concat(out, "\n"), headings
end
-- }}}

return M
