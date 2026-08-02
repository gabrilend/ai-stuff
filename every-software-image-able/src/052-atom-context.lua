-- 052-atom-context.lua
--
-- What the machine is thinking with, and how it decides. Issue 105 and the
-- mechanism described in docs/013.
--
-- For a general: a machine's working memory is not one long scroll that fills
-- up and spills. It is a list of separately named pieces, each about one
-- subject, and the machine chooses which ones it is currently holding. Running
-- low is then something it can see and act on rather than a wall it hits.
--
-- THE RULE: the context is a concatenation of atomic artifacts and nothing
-- else. No preamble, no hidden frame, nothing outside the list. Everything the
-- machine is thinking with can be enumerated, named and pointed at -- including
-- the instruction it woke up holding.
--
-- WHAT IS NOT HERE. Writing an atom out to storage and recalling it, because
-- storage does not exist during this phase. The seam is marked; issue 304
-- completes it.

local M = {}

-- {{{ M.new(options)
-- A fresh context. `budget` is how many tokens may be resident at once, which
-- comes from the model's shape rather than from a preference.
function M.new(options)
  return {
    budget = options.budget,
    atoms = {},          -- every atom this context knows of, by number
    order = {},          -- the resident ones, in the order they concatenate
    next_number = 1,
    dropped = 0,         -- how many were let go for want of room
    written = 0,         -- how many were put away rather than dropped
  }
end
-- }}}

-- {{{ M.add(context, atom)
-- Puts a new atom in, resident. Returns its number.
--
-- An atom carries where it came from, because the first time a carried
-- description turns out to be wrong, the difference between "somebody handed
-- me this" and "I worked this out" is the whole of the diagnosis.
function M.add(context, atom)
  local number = context.next_number
  context.next_number = number + 1

  context.atoms[number] = {
    number = number,
    topic = atom.topic or "untitled",
    content = atom.content or "",
    tokens = atom.tokens or 0,
    origin = atom.origin or "written by the machine",
    derived_from = atom.derived_from or {},
    resident = true,
    stored = false,
    changed_at = atom.changed_at or 0,
  }
  context.order[#context.order + 1] = number
  return number
end
-- }}}

-- {{{ M.resident_tokens(context)
function M.resident_tokens(context)
  local total = 0
  for _, number in ipairs(context.order) do
    total = total + context.atoms[number].tokens
  end
  return total
end
-- }}}

-- {{{ M.room_left(context)
-- What the machine can see about its own situation. Running low is a condition
-- rather than an event, which is the whole point of the arrangement.
function M.room_left(context)
  return context.budget - M.resident_tokens(context)
end
-- }}}

-- {{{ M.drop(context, number)
-- Stop carrying an atom. It is gone unless it was stored.
function M.drop(context, number)
  local atom = context.atoms[number]
  if not atom or not atom.resident then return false end
  atom.resident = false
  for index, held in ipairs(context.order) do
    if held == number then
      table.remove(context.order, index)
      break
    end
  end
  context.dropped = context.dropped + 1
  return true
end
-- }}}

-- {{{ M.carry_forward(context, number)
-- Bring a known atom back into the resident set, if it is not already.
function M.carry_forward(context, number)
  local atom = context.atoms[number]
  if not atom then return false end
  if atom.resident then return true end
  atom.resident = true
  context.order[#context.order + 1] = number
  return true
end
-- }}}

-- {{{ M.merge(context, first, second, topic)
-- Two atoms become one. Both originals stop being resident; the new one
-- records what it came from.
--
-- The identities of the originals are kept rather than reused, because
-- anything that referred to them by number would otherwise be pointing at
-- something that is no longer what it was. That is question four in docs/013
-- and this is the answer it takes: a merged-away atom stays known and stops
-- being resident, and its number never means anything else.
function M.merge(context, first, second, topic)
  local a, b = context.atoms[first], context.atoms[second]
  if not a or not b then return nil end

  local number = M.add(context, {
    topic = topic or (a.topic .. " and " .. b.topic),
    content = a.content .. "\n" .. b.content,
    tokens = a.tokens + b.tokens,
    origin = "written by the machine",
    derived_from = { first, second },
  })

  M.drop(context, first)
  M.drop(context, second)
  return number
end
-- }}}

-- {{{ M.replace(context, number, changes)
-- Atoms are mutable. Editing one in place keeps its number, because whatever
-- referred to it meant the subject rather than the wording.
function M.replace(context, number, changes)
  local atom = context.atoms[number]
  if not atom then return false end
  if changes.content then atom.content = changes.content end
  if changes.tokens then atom.tokens = changes.tokens end
  if changes.topic then atom.topic = changes.topic end
  atom.changed_at = (changes.changed_at or atom.changed_at + 1)
  return true
end
-- }}}

-- {{{ M.concatenate(context)
-- What the machine is actually thinking with, in order. This is the whole of
-- it -- there is nothing else anywhere.
function M.concatenate(context)
  local parts = {}
  for _, number in ipairs(context.order) do
    parts[#parts + 1] = context.atoms[number].content
  end
  return table.concat(parts, "\n")
end
-- }}}

-- {{{ M.enumerate(context)
-- A list of what is resident, so the machine can ask what it is holding rather
-- than having to remember.
function M.enumerate(context)
  local out = {}
  for _, number in ipairs(context.order) do
    local atom = context.atoms[number]
    out[#out + 1] = {
      number = number, topic = atom.topic, tokens = atom.tokens,
      origin = atom.origin, derived_from = atom.derived_from,
    }
  end
  return out
end
-- }}}

-- {{{ M.find(context, topic)
-- The index: what is known that bears on a subject, resident or not. An atom
-- that cannot be found again is an atom that was dropped, whatever else was
-- done with it.
function M.find(context, topic)
  local found = {}
  local needle = topic:lower()
  for number = 1, context.next_number - 1 do
    local atom = context.atoms[number]
    if atom and atom.topic:lower():find(needle, 1, true) then
      found[#found + 1] = number
    end
  end
  return found
end
-- }}}

-- {{{ M.make_room(context, wanted)
-- When there is not enough room, say so and let something go -- oldest first,
-- and never the atoms marked as carried on the chip, because those include the
-- instruction and the explanation of this mechanism itself.
--
-- Dropping for want of room is a FALLBACK. It is what happens when the machine
-- did not choose in time, and it is announced rather than done quietly.
function M.make_room(context, wanted)
  local freed = {}
  while M.room_left(context) < wanted and #context.order > 0 do
    local victim = nil
    for _, number in ipairs(context.order) do
      if context.atoms[number].origin ~= "carried on the chip" then
        victim = number
        break
      end
    end
    if not victim then break end     -- everything left is undroppable
    freed[#freed + 1] = victim
    M.drop(context, victim)
  end
  return freed
end
-- }}}

-- {{{ M.boot(context, initialising)
-- The default initialising context: the atoms a machine wakes up holding.
--
-- It is a list, and it is mutable, which means a machine can change what it
-- wakes up believing -- including the two prohibitions, which are atoms like
-- everything else. That follows from everything about the machine being
-- mutable and is written down rather than quietly prevented (docs/013).
function M.boot(context, initialising)
  for _, atom in ipairs(initialising) do
    M.add(context, atom)
  end
  return context
end
-- }}}

return M
