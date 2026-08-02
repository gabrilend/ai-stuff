#!/usr/bin/env luajit
-- 097-show-the-payload.lua
--
-- What the machine carries, what it wakes up holding, and what the gap
-- between those costs. The phase 3 demo's numbers.
--
-- For a general: a demonstration that describes a payload is less useful
-- than one that says how many words are on the chip, how few of them the
-- machine holds when it starts, and how much room that leaves it to think
-- with. Those three numbers are the whole argument for the design.
--
-- usage:
--   luajit 097-show-the-payload.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

-- {{{ local function say(text)
local function say(text)
  io.write(text, "\n")
  io.flush()
end
-- }}}

-- {{{ main
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then index = index + 1 ; DIR = arg[index] end
  index = index + 1
end

local patterns = dofile(DIR .. "/src/083-the-patterns.lua")
local descriptions = dofile(DIR .. "/src/082-the-descriptions.lua")
local payload_module = dofile(DIR .. "/src/084-the-payload.lua")
local context_module = dofile(DIR .. "/src/052-atom-context.lua")

local handle = io.open(DIR .. "/assets/081-the-instruction.md", "rb")
local instruction = handle:read("*a")
handle:close()

local atoms = payload_module.build({
  instruction = instruction, patterns = patterns, descriptions = descriptions,
})

-- the budget a real machine would have. Taken from the smallest model shape
-- the project measures against, so the numbers below are a tight case rather
-- than a flattering one.
local BUDGET = 2048
local context = context_module.new({ budget = BUDGET })
local payload = payload_module.new({
  context = context, context_module = context_module, atoms = atoms,
})

say("")
say("  what the machine carries, and what it wakes up holding")
say("  " .. string.rep("-", 66))
say("")

-- {{{ the three numbers
local carried_tokens, held_tokens = 0, 0
local carried, held = 0, 0
for _, entry in ipairs(payload_module.index(payload)) do
  carried = carried + 1
  carried_tokens = carried_tokens + entry.tokens
  if entry.wakes_with then
    held = held + 1
    held_tokens = held_tokens + entry.tokens
  end
end

say(string.format("  carried on the chip     %3d pieces   %6d tokens",
                  carried, carried_tokens))
say(string.format("  held when it wakes      %3d pieces   %6d tokens   (%.0f%%)",
                  held, held_tokens, held_tokens / carried_tokens * 100))
say(string.format("  room it can think in    %s   %6d tokens",
                  string.rep(" ", 12), BUDGET))
say(string.format("  left over for thinking  %s   %6d tokens   (%.0f%%)",
                  string.rep(" ", 12), BUDGET - held_tokens,
                  (BUDGET - held_tokens) / BUDGET * 100))
say("")
say("  A machine that woke up holding everything it carries would need "
    .. string.format("%d", carried_tokens))
say("  tokens of room before it had a single thought of its own. It has "
    .. string.format("%d.", BUDGET))
say("")
-- }}}

-- {{{ what is held, and what is not
say("  held at boot:")
for _, entry in ipairs(payload_module.index(payload)) do
  if entry.wakes_with then
    say(string.format("    %-46s %5d", entry.topic, entry.tokens))
  end
end
say("")

local by_kind = {}
for _, entry in ipairs(payload_module.index(payload)) do
  if not entry.wakes_with then
    local kind = entry.topic:match("^([^:]+):") or "other"
    by_kind[kind] = by_kind[kind] or { count = 0, tokens = 0 }
    by_kind[kind].count = by_kind[kind].count + 1
    by_kind[kind].tokens = by_kind[kind].tokens + entry.tokens
  end
end

say("  reachable, and not held:")
local kinds = {}
for kind in pairs(by_kind) do kinds[#kinds + 1] = kind end
table.sort(kinds)
for _, kind in ipairs(kinds) do
  say(string.format("    %-46s %3d pieces, %5d tokens",
                    kind, by_kind[kind].count, by_kind[kind].tokens))
end
say("")
-- }}}

-- {{{ what fetching one costs, watched
local before = context_module.room_left(context)
payload_module.fetch(payload, "pattern: the-four-rungs")
local after = context_module.room_left(context)

say("  the machine asks for a pattern it was not given:")
say(string.format("    room before   %d", before))
say(string.format("    room after    %d   (that piece cost %d)",
                  after, before - after))
say("")
say("  It can see that number, which is what makes what it is thinking with")
say("  a decision it keeps making rather than a rule applied to it.")
say("")
-- }}}

local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write(string.format("payload: %d carried, %d held\ngoodbye\n",
                              carried, held))
  goodbye:close()
end
-- }}}
