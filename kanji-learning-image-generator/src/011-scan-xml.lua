-- 011-scan-xml.lua
--
-- Walks an XML document from front to back, handing out tags as it meets them.
--
-- For a general: the two files this project reads are about thirty megabytes of
-- XML between them. The usual way to read XML is to build the whole document
-- into a tree of objects in memory and then ask it questions -- which for a
-- question as small as "what are this character's strokes" means constructing
-- several million objects to look at a few dozen of them.
--
-- This does the other thing. It reads forward once, calls a function every time
-- it passes a tag, and keeps nothing. The programs that use it build the small
-- structure they actually want as the tags go by.
--
-- It is not a general XML parser and does not want to be. It knows the parts of
-- the format these two archives use and errors on anything else, which is the
-- honest position: a parser that quietly accepts what it does not understand is
-- a parser that quietly loses data.

local M = {}

-- {{{ ENTITIES -- the named character references XML defines
--
-- Exactly five. Everything else named in a document has to be declared by that
-- document, and neither archive declares any it then uses in its content.
local ENTITIES = {
  lt = "<", gt = ">", amp = "&", quot = '"', apos = "'",
}
-- }}}

-- {{{ M.utf8(codepoint)
-- One character number, as the bytes that spell it.
--
-- Here rather than somewhere more obviously its home because numeric character
-- references need it and they are this file's business -- and because the
-- archive that draws the strokes identifies each character by its number rather
-- than by the character itself, so the reader needs the same conversion. Two
-- copies of this arithmetic would be two chances to get the continuation bytes
-- wrong.
function M.utf8(codepoint)
  if codepoint < 0x80 then
    return string.char(codepoint)
  elseif codepoint < 0x800 then
    return string.char(0xC0 + math.floor(codepoint / 0x40),
                       0x80 + (codepoint % 0x40))
  elseif codepoint < 0x10000 then
    return string.char(0xE0 + math.floor(codepoint / 0x1000),
                       0x80 + (math.floor(codepoint / 0x40) % 0x40),
                       0x80 + (codepoint % 0x40))
  end
  return string.char(0xF0 + math.floor(codepoint / 0x40000),
                     0x80 + (math.floor(codepoint / 0x1000) % 0x40),
                     0x80 + (math.floor(codepoint / 0x40) % 0x40),
                     0x80 + (codepoint % 0x40))
end
-- }}}

-- {{{ M.characters(text)
-- One UTF-8 string, as an array of its characters.
--
-- The inverse of M.utf8, and here for the same reason: a person naming which
-- characters they want types them as one word, and every part of this project
-- that accepts such a list has to break it apart. A byte with its top two bits
-- set to one-zero is a continuation of the character before it; every other
-- byte starts a new one, which is the whole of what UTF-8 needs to be walked
-- forwards.
function M.characters(text)
  local out = {}
  local index = 1
  local length = #text
  while index <= length do
    local byte = text:byte(index)
    local width = 1
    if byte >= 0xF0 then width = 4
    elseif byte >= 0xE0 then width = 3
    elseif byte >= 0xC0 then width = 2 end
    out[#out + 1] = text:sub(index, index + width - 1)
    index = index + width
  end
  return out
end
-- }}}

-- {{{ M.decode(text)
-- Character references turned back into characters.
--
-- Kept separate from the scan and called by the reader rather than by the
-- scanner, because most text in these archives contains no references at all
-- and checking every string for one costs more than the few that need it.
function M.decode(text)
  if not text:find("&", 1, true) then return text end
  return (text:gsub("&(#?[%w]+);", function(body)
    if body:sub(1, 1) == "#" then
      local number
      if body:sub(2, 2) == "x" or body:sub(2, 2) == "X" then
        number = tonumber(body:sub(3), 16)
      else
        number = tonumber(body:sub(2))
      end
      if not number then return nil end
      return M.utf8(number)
    end
    local named = ENTITIES[body]
    -- An undeclared entity is a document this scanner does not understand, and
    -- passing it through unchanged would put a literal &something; in the data.
    if not named then
      error("unknown entity &" .. body .. "; in the document")
    end
    return named
  end))
end
-- }}}

-- {{{ M.attributes(text)
-- One tag's attribute text, as a table.
--
-- Called by the reader, not by the scanner. Most tags in these archives have
-- attributes nobody wants -- KANJIDIC2 alone has hundreds of thousands of them
-- -- and building a table for every one would be most of the running time spent
-- on data that is then discarded.
--
-- Names with a colon in them are kept whole. `kvg:element` is an attribute
-- whose name contains a colon, and that is all this project needs it to be;
-- resolving namespace prefixes would be work in service of nothing.
function M.attributes(text)
  local out = {}
  if not text or text == "" then return out end
  for name, quoted in text:gmatch('([%w_:%-%.]+)%s*=%s*(%b"")') do
    out[name] = M.decode(quoted:sub(2, -2))
  end
  -- single quotes are equally legal and neither archive uses them, so this
  -- second pass costs one failed search per tag and removes a whole class of
  -- "it worked until upstream reformatted"
  for name, quoted in text:gmatch("([%w_:%-%.]+)%s*=%s*(%b'')") do
    if out[name] == nil then out[name] = M.decode(quoted:sub(2, -2)) end
  end
  return out
end
-- }}}

-- {{{ tag_end(text, from)
-- The position of the > that closes a tag, ignoring any inside quotes.
--
-- WHY NOT JUST FIND THE NEXT >. An attribute value is allowed to contain one.
-- Neither of these archives happens to do it today, and the day one does, a
-- naive scan would cut a tag in half and every character after it would be
-- wrong in a way that looks like a corrupted download.
local function tag_end(text, from)
  local index = from
  local length = #text
  local quote = nil
  while index <= length do
    local char = text:sub(index, index)
    if quote then
      if char == quote then quote = nil end
    elseif char == '"' or char == "'" then
      quote = char
    elseif char == ">" then
      return index
    end
    index = index + 1
  end
  return nil
end
-- }}}

-- {{{ M.scan(text, handlers)
-- Walk the document, calling handlers as tags go past.
--
-- handlers.open(name, attribute_text, self_closing)
-- handlers.close(name)
-- handlers.text(raw)
--
-- All three are optional. A scan with only an open handler is the normal case
-- and is the fastest thing this file does.
--
-- The attribute text is handed over raw, for M.attributes to make sense of if
-- the handler wants it. A self-closing tag calls open with the third argument
-- true and does not call close -- a handler that keeps a stack has to account
-- for that itself, which is the one piece of bookkeeping this file pushes
-- outward rather than doing.
function M.scan(text, handlers)
  local on_open = handlers.open
  local on_close = handlers.close
  local on_text = handlers.text

  local position = 1
  local length = #text
  local find = string.find
  local sub = string.sub

  while position <= length do
    local open_at = find(text, "<", position, true)
    if not open_at then
      if on_text and position <= length then on_text(sub(text, position)) end
      break
    end

    if on_text and open_at > position then
      on_text(sub(text, position, open_at - 1))
    end

    local marker = sub(text, open_at + 1, open_at + 1)

    if marker == "?" then
      -- <?xml ... ?> -- a processing instruction; nothing here reads one
      local close_at = find(text, "?>", open_at + 2, true)
      if not close_at then error("a processing instruction is never closed") end
      position = close_at + 2

    elseif marker == "!" then
      local three = sub(text, open_at + 2, open_at + 3)
      if three == "--" then
        local close_at = find(text, "-->", open_at + 4, true)
        if not close_at then error("a comment is never closed") end
        position = close_at + 3
      elseif sub(text, open_at + 2, open_at + 8) == "[CDATA[" then
        local close_at = find(text, "]]>", open_at + 9, true)
        if not close_at then error("a CDATA section is never closed") end
        if on_text then on_text(sub(text, open_at + 9, close_at - 1)) end
        position = close_at + 3
      else
        -- <!DOCTYPE ...>, and KANJIDIC2's runs to several hundred lines with an
        -- internal subset in brackets. Those brackets contain > characters, so
        -- a scan for the next > lands in the middle of an entity declaration
        -- and the rest of the document is read as garbage. Find the bracket
        -- first; if there is one, the declaration ends at its match.
        local bracket_at = find(text, "[", open_at, true)
        local shallow_end = tag_end(text, open_at + 1)
        if bracket_at and shallow_end and bracket_at < shallow_end then
          local close_bracket = find(text, "]", bracket_at + 1, true)
          if not close_bracket then error("a doctype subset is never closed") end
          local after = find(text, ">", close_bracket, true)
          if not after then error("a doctype is never closed") end
          position = after + 1
        else
          if not shallow_end then error("a declaration is never closed") end
          position = shallow_end + 1
        end
      end

    elseif marker == "/" then
      local close_at = tag_end(text, open_at + 2)
      if not close_at then error("a closing tag is never closed") end
      if on_close then
        on_close(sub(text, open_at + 2, close_at - 1):match("^%s*([^%s]*)"))
      end
      position = close_at + 1

    else
      local close_at = tag_end(text, open_at + 1)
      if not close_at then error("a tag is never closed") end
      local body = sub(text, open_at + 1, close_at - 1)
      local self_closing = sub(body, -1) == "/"
      if self_closing then body = sub(body, 1, -2) end
      local name, rest = body:match("^([^%s/>]+)%s*(.*)$")
      if not name then
        error("a tag with no name at byte " .. open_at)
      end
      if on_open then on_open(name, rest, self_closing) end
      position = close_at + 1
    end
  end
end
-- }}}

return M
