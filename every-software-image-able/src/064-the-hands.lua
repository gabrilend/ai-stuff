-- 064-the-hands.lua
--
-- The boundary between thinking and doing: the catalogue of what the machine
-- may ask for, the parser that recognises an asking in the token stream, and
-- the answering. Issue 201, and everything else in phase 2 hangs off the
-- shape chosen here.
--
-- For a general: the engine produces text, and text does nothing. This is the
-- part that notices when the text is a request, carries it out, and hands the
-- result back as more text for the machine to read.
--
-- THE DOOR AND THE CATALOGUE ARE ONE OBJECT (docs/002). The table the
-- answering machinery walks to find a hand is the same table the machine
-- reads to find out what its hands are. There is no privilege level here and
-- no separate list of what exists; a machine that wants to know what it can
-- do reads the table that does it.
--
-- THE CALL FORMAT IS NOT CHOSEN HERE. How a call is written depends on the
-- model, and the model is a parameter of the build (101). Reserved tokens are
-- ruled out for the same reason -- an arbitrary model was not trained with
-- tokens we invented. So the recogniser is a swappable part: a grammar object
-- with a name, and the machinery below never assumes one. `PLAIN` is the
-- default and is deliberately ordinary -- it uses only characters every
-- vocabulary can say.
--
-- ERRORS BEAT FALLBACKS. A call that does not parse comes back saying so, in
-- words the machine can read and correct, rather than being guessed at. A
-- guessed call is a hand moving somewhere nobody asked it to.

local M = {}

-- {{{ M.GRAMMARS -- how a call is written, per model. Swappable on purpose.
--
-- Each grammar exports `find(text)` -- the first call in a stretch of text,
-- as { name, arguments, from, to } or nil -- and `render(result)`, how an
-- answer is written back for the machine to read.
--
-- Tested per model rather than once: this is one of the few places where
-- changing the model can break the machine while everything else keeps
-- working.
M.GRAMMARS = {}

-- {{{ PLAIN -- the default
--
--   <call name argument argument>
--   <result name
--   ...text...
--   >
--
-- Angle brackets and plain words: no invented tokens, nothing a byte-level
-- vocabulary cannot say, and a closing mark that cannot appear inside an
-- argument because arguments are whitespace-separated words.
M.GRAMMARS.plain = {
  name = "plain",

  -- {{{ find(text)
  find = function(text)
    local from, to, body = text:find("<call%s+([^<>]*)>")
    if not from then return nil end

    local words = {}
    for word in body:gmatch("%S+") do words[#words + 1] = word end
    if #words == 0 then
      return { malformed = "a call with no name", from = from, to = to }
    end

    local name = table.remove(words, 1)
    return { name = name, arguments = words, from = from, to = to }
  end,
  -- }}}

  -- {{{ render(result)
  render = function(result)
    -- The name is repeated in the answer. A machine reading its own context
    -- back sees which hand answered rather than having to count backwards to
    -- the asking, and that matters most exactly when several calls are in
    -- flight in one thought.
    return "<result " .. result.name .. "\n" .. result.text .. "\n>"
  end,
  -- }}}
}
-- }}}
-- }}}

-- {{{ M.new(options)
-- A fresh catalogue.
--
-- options: grammar (a table from M.GRAMMARS, defaulting to plain),
--          budget (how long an answer may be before it goes to 201a's
--          reader), reader (what to do with an answer that is too long)
function M.new(options)
  options = options or {}
  return {
    grammar = options.grammar or M.GRAMMARS.plain,
    -- how much of an answer may cross into the machine's own context. Longer
    -- answers go to the reader (201a), and where there is no reader they are
    -- refused rather than truncated -- a truncated answer presented as whole
    -- is a lie the machine tells itself.
    budget = options.budget or 2048,
    reader = options.reader,
    hands = {},        -- by name
    order = {},        -- the order they were added, so the catalogue is stable
    calls = 0,
    refusals = 0,
  }
end
-- }}}

-- {{{ M.offer(catalogue, hand)
-- Adds a hand. The door widens from inside: a hand may be offered at any
-- time, including by something the machine built, which is the answer this
-- project gives to the open question at the end of docs/002.
--
-- hand: name, takes (a list of argument names), gives (what it returns, for
--       the machine to read), does (the function), and optionally
--       `dangerous` (whether it is refused by default) and `note`.
function M.offer(catalogue, hand)
  if type(hand.name) ~= "string" or hand.name == "" then
    error("064-the-hands: a hand needs a name")
  end
  if type(hand.does) ~= "function" then
    error("064-the-hands: the hand '" .. hand.name .. "' does nothing")
  end
  if catalogue.hands[hand.name] then
    error("064-the-hands: there are already two hands called '" .. hand.name .. "'")
  end

  catalogue.hands[hand.name] = {
    name = hand.name,
    takes = hand.takes or {},
    gives = hand.gives or "text",
    note = hand.note or "",
    dangerous = hand.dangerous or false,
    opened = hand.opened or false,
    does = hand.does,
    used = 0,
  }
  catalogue.order[#catalogue.order + 1] = hand.name
  return hand.name
end
-- }}}

-- {{{ M.catalogue_text(catalogue)
-- What the machine reads when it asks what its hands are. The same table the
-- answering walks -- the door and the catalogue are one object -- rendered
-- for reading rather than kept as a separate list that could drift.
function M.catalogue_text(catalogue)
  local lines = { "the hands this machine has:" }
  for _, name in ipairs(catalogue.order) do
    local hand = catalogue.hands[name]
    local shape = name
    for _, argument in ipairs(hand.takes) do
      shape = shape .. " " .. argument
    end
    local state = ""
    if hand.dangerous then
      state = hand.opened and "  (dangerous, opened)" or "  (dangerous, refused)"
    end
    lines[#lines + 1] = "  <call " .. shape .. ">" .. state
    if hand.note ~= "" then
      lines[#lines + 1] = "      " .. hand.note
    end
  end
  return table.concat(lines, "\n")
end
-- }}}

-- {{{ M.find(catalogue, text)
-- The first asking in a stretch of text, or nil. Exposed so the loop can ask
-- "is there a call here" without committing to answering it.
function M.find(catalogue, text)
  return catalogue.grammar.find(text)
end
-- }}}

-- {{{ M.answer(catalogue, call)
-- Carries out one asking and returns the answer as text.
--
-- Every refusal here is a sentence the machine can read and act on, because
-- the alternative is a machine that stops for reasons it cannot see.
function M.answer(catalogue, call)
  catalogue.calls = catalogue.calls + 1

  local function refuse(why)
    catalogue.refusals = catalogue.refusals + 1
    return { name = call.name or "call", ok = false, text = why }
  end

  if call.malformed then
    return refuse("that call did not parse: " .. call.malformed
      .. ". A call is written <call name argument argument>.")
  end

  local hand = catalogue.hands[call.name]
  if not hand then
    return refuse("there is no hand called '" .. call.name
      .. "'. Ask <call hands> to see what there is.")
  end

  if #call.arguments ~= #hand.takes then
    return refuse("'" .. call.name .. "' takes " .. #hand.takes .. " ("
      .. table.concat(hand.takes, ", ") .. ") and was given "
      .. #call.arguments .. ".")
  end

  if hand.dangerous and not hand.opened then
    return refuse("'" .. call.name .. "' is refused by default. It is opened by "
      .. "a confirmed description, and confirming is a read-only act.")
  end

  hand.used = hand.used + 1

  -- A hand that fails must say so rather than raise: the machine reads the
  -- sentence and tries something else, where an unhandled failure would take
  -- the whole thought down with it.
  local ok, answer, trouble = pcall(hand.does, call.arguments, catalogue)
  if not ok then
    return refuse("'" .. call.name .. "' came apart: " .. tostring(answer))
  end
  if answer == nil then
    return refuse("'" .. call.name .. "' did not work: "
      .. tostring(trouble or "no reason given"))
  end

  answer = tostring(answer)

  -- {{{ an answer too large to hold
  -- Small ones come back as text. Large ones go through the reader (201a),
  -- which searches them in a scratch context so only the useful part crosses
  -- over. With no reader, refusing beats truncating.
  if #answer > catalogue.budget then
    if not catalogue.reader then
      return refuse("'" .. call.name .. "' answered with " .. #answer
        .. " characters and only " .. catalogue.budget
        .. " may cross. Nothing here can read something that large yet.")
    end
    local shortened, why = catalogue.reader(answer, call, catalogue)
    if not shortened then
      return refuse("'" .. call.name .. "' answered with " .. #answer
        .. " characters, and reading it did not work: " .. tostring(why))
    end
    return { name = call.name, ok = true, text = shortened, read = true,
             whole_length = #answer }
  end
  -- }}}

  return { name = call.name, ok = true, text = answer }
end
-- }}}

-- {{{ M.answer_text(catalogue, call)
-- The answer, written the way the grammar writes answers.
function M.answer_text(catalogue, call)
  return catalogue.grammar.render(M.answer(catalogue, call))
end
-- }}}

-- {{{ M.offer_the_catalogue(catalogue)
-- The one hand every machine has: asking what its hands are. Offered
-- separately so a caller building a restricted machine can decline it, and
-- so this file has no special case in `offer`.
function M.offer_the_catalogue(catalogue)
  return M.offer(catalogue, {
    name = "hands",
    takes = {},
    gives = "the catalogue",
    note = "what this machine can be asked for",
    does = function() return M.catalogue_text(catalogue) end,
  })
end
-- }}}

-- {{{ M.open(catalogue, name, confirmation)
-- Opens a dangerous hand. The confirmation is a description that has been
-- read and confirmed (302); confirming is a read-only act, which is why
-- opening is a separate step from using.
function M.open(catalogue, name, confirmation)
  local hand = catalogue.hands[name]
  if not hand then return nil, "there is no hand called '" .. name .. "'" end
  if not hand.dangerous then
    return nil, "'" .. name .. "' is not refused by default; there is nothing to open"
  end
  if type(confirmation) ~= "string" or confirmation == "" then
    return nil, "opening '" .. name .. "' needs a confirmed description"
  end
  hand.opened = true
  hand.opened_by = confirmation
  return true
end
-- }}}

return M
