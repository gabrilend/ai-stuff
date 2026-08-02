-- 066-the-reader.lua
--
-- Reading something too big to hold. A hand answers with a megabyte; a
-- megabyte cannot enter the thinking loop. This searches it in a scratch
-- context and lets only the useful part cross into the machine's own. Issue
-- 201a.
--
-- For a general: the machine reads a long document the way a person skims
-- one they cannot memorise -- a few pages at a time, holding the question in
-- mind, keeping the pages that answered it and letting the rest go. The main
-- context sees three or four valuable chunks and never has to know how large
-- the document was.
--
-- THE SIZING IS WHAT MAKES IT WORK. Chunks are about a tenth of a full
-- context each and seven to nine are resident at a time, so the scratch
-- context is filled without crowding out the asking, and a document of any
-- size is covered in a predictable number of passes: its length over about
-- eight tenths of a context.
--
-- THE SCRATCH CONTEXT IS A SECOND CONTEXT, filled, used and discarded,
-- never disturbing the machine's own. That was a requirement on 105 that did
-- not exist before this ticket, and the loop met it by keeping everything a
-- machine thinks with in one object -- so a second one is simply a second
-- object, not a mode.
--
-- WHAT IT DOES NOT SOLVE, said plainly rather than discovered: an answer
-- that needs the first chunk and the last one together. Each pass sees a
-- window, so a relationship spanning the whole document is invisible to
-- every pass. A widened search carries findings forward, which helps; some
-- questions will still come back wrong rather than unanswered.

local M = {}

-- {{{ M.chunk(text, size)
-- Cuts on something meaningful where the content allows it, rather than on
-- a byte count that saws words in half.
--
-- The boundaries in order of preference: a blank line, a line ending, a
-- space. Each is looked for in the last quarter of the chunk, so a cut is
-- never dragged far from where it was wanted. Content with none of them --
-- a single enormous line of data -- is cut at the byte, which is correct
-- rather than a fallback: there is no meaningful boundary to find.
function M.chunk(text, size)
  local chunks = {}
  local at = 1

  while at <= #text do
    local upto = math.min(at + size - 1, #text)
    if upto < #text then
      local window_start = upto - math.floor(size / 4)
      if window_start < at then window_start = at end
      local window = text:sub(window_start, upto)

      -- last blank line, else last line ending, else last space
      local cut = nil
      for _, pattern in ipairs({ "\n%s*\n", "\n", " " }) do
        local last = nil
        local search = 1
        while true do
          local from, to = window:find(pattern, search)
          if not from then break end
          last = to
          search = from + 1
        end
        if last then
          cut = window_start + last - 1
          break
        end
      end
      if cut and cut > at then upto = cut end
    end

    chunks[#chunks + 1] = text:sub(at, upto)
    at = upto + 1
  end

  return chunks
end
-- }}}

-- {{{ M.new(options)
--
-- options:
--   context      how many characters the machine can hold at once
--   ask          a function: (question, pages) -> { found = boolean,
--                widen = boolean, note = string }. The machine's own
--                judgement, handed in, because the reader must not decide
--                what counts as an answer.
--   summarise    a function: (question, pages) -> text, used only when the
--                answer spans several chunks
--   resident     how many chunks are held at once (default eight)
function M.new(options)
  options = options or {}
  local context = options.context or 8192
  return {
    context = context,
    -- a tenth of a context per chunk, eight resident: that fills the
    -- scratch context and leaves room for the question and the answer.
    chunk_size = options.chunk_size or math.max(math.floor(context / 10), 64),
    resident = options.resident or 8,
    ask = options.ask,
    summarise = options.summarise,
    passes = 0,
  }
end
-- }}}

-- {{{ M.read(reader, whole, question)
-- Walks the whole thing, a window at a time, and returns what answered.
--
-- Returns { text, from_chunks, of_chunks, passes, summarised, widened } or
-- nil and a reason. The reason matters: a reader that comes back empty must
-- say whether the document was searched and did not contain it, or whether
-- the search itself failed.
function M.read(reader, whole, question)
  if type(reader.ask) ~= "function" then
    return nil, "nothing was given to judge the pages with"
  end

  local chunks = M.chunk(whole, reader.chunk_size)
  local kept, kept_numbers = {}, {}
  local widened = false
  local passes = 0
  local at = 1

  while at <= #chunks do
    local window = {}
    local window_numbers = {}
    for offset = 0, reader.resident - 1 do
      local which = at + offset
      if which > #chunks then break end
      window[#window + 1] = chunks[which]
      window_numbers[#window_numbers + 1] = which
    end

    passes = passes + 1
    reader.passes = reader.passes + 1

    -- A question with a shape that can be answered cheaply: is what is
    -- wanted in here, and if not, should the search widen. A scan that
    -- produces prose about every chunk costs more than reading the whole
    -- document would have.
    local verdict = reader.ask(question, window, window_numbers)
    if type(verdict) ~= "table" then
      return nil, "judging a window gave back something that is not an answer"
    end

    if verdict.found then
      for index, page in ipairs(window) do
        -- keep only the pages named, or all of them when none were named
        if verdict.pages == nil or verdict.pages[index] then
          kept[#kept + 1] = page
          kept_numbers[#kept_numbers + 1] = window_numbers[index]
        end
      end
    end

    if verdict.widen then
      -- a widened search carries what has been found so far forward, which
      -- is the only mitigation there is for an answer spanning the document.
      widened = true
      question = verdict.question or question
    end

    at = at + reader.resident
  end

  if #kept == 0 then
    return nil, "the whole of it was read, in " .. passes
      .. " passes, and none of it answered the question"
  end

  -- {{{ several chunks into one
  -- Summarising is said out loud. A summary presented as a quotation is a
  -- lie the machine told itself, and the difference matters most exactly
  -- when the machine goes back to check.
  local text, summarised
  if #kept == 1 then
    text = kept[1]
    summarised = false
  elseif reader.summarise then
    text = reader.summarise(question, kept)
    summarised = true
  else
    text = table.concat(kept, "\n")
    summarised = false
  end
  -- }}}

  return {
    text = text,
    from_chunks = kept_numbers,
    of_chunks = #chunks,
    passes = passes,
    summarised = summarised,
    widened = widened,
  }
end
-- }}}

-- {{{ M.as_atom(found, source)
-- What crosses into the machine's own context: an atom naming where the text
-- came from, so the machine can tell later and go back for more (docs/013).
function M.as_atom(found, source)
  local heading
  if found.summarised then
    heading = "summarised from " .. #found.from_chunks .. " of "
      .. found.of_chunks .. " pieces of " .. source
      .. " -- this is a summary, not a quotation"
  else
    heading = "piece " .. table.concat(found.from_chunks, ", ")
      .. " of " .. found.of_chunks .. " of " .. source
  end

  return {
    topic = "read from " .. source,
    content = heading .. "\n" .. found.text,
    origin = "read out of something too big to hold",
    derived_from = { source },
  }
end
-- }}}

-- {{{ M.for_hands(reader, source_name)
-- The shape 064 wants for its `reader`: given a whole answer and the call
-- that produced it, hand back the short version.
--
-- The question is built from the call itself -- the specific request, plus
-- what is needed to understand the item being looked at -- since that is all
-- the reader knows about why the machine asked.
function M.for_hands(reader, source_name)
  return function(whole, call)
    local question = "what '" .. call.name .. "'"
      .. (#call.arguments > 0 and (" " .. table.concat(call.arguments, " ")) or "")
      .. " was asked for"
    local found, why = M.read(reader, whole, question)
    if not found then return nil, why end

    local source = source_name or call.name
    local atom = M.as_atom(found, source)
    return atom.content
  end
end
-- }}}

return M
