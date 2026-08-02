-- 083-the-patterns.lua
--
-- The build patterns carried on the chip. Issue 303.
--
-- For a general: shapes that have worked before, offered to the machine as
-- suggestions it may take or leave. Not code -- code would decide how the
-- machine gets built, and that decision is not the seed's to make.
--
-- EVERY PATTERN HAS FOUR PARTS, AND THE FOURTH IS THE ONE THAT MATTERS. What
-- it is, where it has worked, what it costs, and WHERE IT STOPS WORKING. A
-- shape recommended without its failure mode is a trap with a good
-- reputation.
--
-- THESE ARE SUGGESTIONS AND SAY SO. Most of them are written elsewhere in
-- this project as though they were how the machine works. They are not; they
-- are how some machines have worked. A machine that organises itself
-- completely differently and ignores all of these has done nothing wrong.
--
-- The one exception is the calling convention, which is not a suggestion but
-- an agreement -- everything the machine writes has to agree with everything
-- else it wrote, and that agreement has to start somewhere.

local M = {}

-- {{{ M.PATTERNS
M.PATTERNS = {}

local function pattern(entry) M.PATTERNS[entry.name] = entry ; return entry end

-- {{{ ask, do not schedule -- the pattern about patterns
pattern({
  name = "ask-do-not-schedule",
  about = "how to read every other pattern here",
  what = "Say what is wanted and leave the method alone. Somebody handed a "
      .. "goal can find a way you did not think of; somebody handed a "
      .. "schedule can only follow it or fail.",
  worked = "Every place in this design where a document describes what the "
        .. "machine does rather than what it must do. The patterns below are "
        .. "written as suggestions for this reason.",
  costs = "You cannot predict what will be built, or when, or in what order. "
       .. "If you need that prediction, this pattern is the wrong one.",
  stops = "Where the order genuinely cannot be rearranged, and where a "
       .. "mistake cannot be undone. This machine has exactly two of those: "
       .. "the startup order, and the two prohibitions. Everything else is "
       .. "yours.",
})
-- }}}

-- {{{ the calling convention -- an agreement rather than a suggestion
pattern({
  name = "the-calling-convention",
  about = "how everything you write can call everything else you write",
  what = "Arguments arrive in registers, in order. On this architecture: the "
      .. "first four in di, si, d, c. What comes back comes back in a. A "
      .. "function may use those and must give back anything else it touched, "
      .. "including the processor's flags.",
  worked = "The assembler you have, the arithmetic underneath it, and every "
        .. "kernel the engine runs. They all agree already.",
  costs = "Nothing, so long as it is followed from the beginning.",
  stops = "It does not stop working. This is the one thing here that is an "
       .. "agreement rather than a suggestion: agreement has to start "
       .. "somewhere, and changing it later means changing everything that "
       .. "was written before.",
  learned = "A watch that changes what it watches is not a watch. Something "
         .. "that borrows the processor's flags and does not give them back "
         .. "will break a loop that was correct, and the machine will hang "
         .. "rather than fail.",
})
-- }}}

-- {{{ dispatch tables
pattern({
  name = "dispatch-tables",
  about = "choosing what to do",
  what = "When several things could happen depending on a number, put the "
      .. "things in a table indexed by that number rather than asking a chain "
      .. "of questions. Looking something up is one step whatever the table "
      .. "holds; asking questions is one step per question.",
  worked = "The instruction encoders in your assembler; the emitters that "
        .. "build payloads per architecture; the attachers that know how each "
        .. "kind of storage is wired.",
  costs = "A table has to be dense, or it is a table with holes in it, and "
       .. "the holes are as large as the range.",
  stops = "When the conditions are not a number -- when the choice depends on "
       .. "several things at once, or on a range rather than a value. Forcing "
       .. "those into a table produces a table nobody can read.",
})
-- }}}

-- {{{ the interpreter and its operation table
pattern({
  name = "the-interpreter",
  about = "running things that are not machine code",
  what = "A loop that fetches a number, looks it up in a table of operations, "
      .. "and does what it says. The table IS the list of things a program may "
      .. "ask for -- so the door and the catalogue of what exists are one "
      .. "object, and a program can read the same table the loop reads.",
  worked = "Your own hands work this way. So does every small language that "
        .. "was ever built inside another one.",
  costs = "Slower than machine code by whatever the loop costs per operation. "
       .. "Usually a large factor.",
  stops = "In the hottest loops, where the interpretation costs more than the "
       .. "work. The usual answer is to keep the interpreter and write the few "
       .. "hot things in machine code, rather than abandoning it.",
})
-- }}}

-- {{{ the four rungs
pattern({
  name = "the-four-rungs",
  about = "what to do when you cannot hold everything at once",
  what = "Four places knowledge can be, from cheapest to dearest: what you "
      .. "are holding right now; what you can fetch quickly; what you would "
      .. "have to search for; and what you would have to work out again. Move "
      .. "things between them deliberately rather than letting the top one "
      .. "overflow.",
  worked = "Reading something too big to hold works this way; so does the "
        .. "atom context you are thinking with.",
  costs = "Bookkeeping, and the risk of putting something on a lower rung and "
       .. "never fetching it again.",
  stops = "When what you need is a relationship between two things on "
       .. "different rungs. Neither one alone contains it, and no amount of "
       .. "fetching one at a time will find it.",
})
-- }}}

-- {{{ condensing
pattern({
  name = "condensing",
  about = "making things smaller without making them worse",
  what = "When space runs short, make what you have terser rather than "
      .. "throwing pieces of it away. Deleting costs capability; condensing "
      .. "costs only the ease of reading it.",
  worked = "Summarising several pieces of a long document into one, and "
        .. "saying that the summary is a summary.",
  costs = "Readability, and the risk of condensing away the thing that "
       .. "mattered. Say when you have condensed, always -- a summary "
       .. "presented as a quotation is a lie you told yourself.",
  stops = "When the thing is already terse. Past that point condensing is "
       .. "deleting with extra steps.",
})
-- }}}

-- {{{ the status triple
pattern({
  name = "the-status-triple",
  about = "saying how you are on hardware that cannot spell",
  what = "Three numbers: where this came from, what it is about, and how far "
      .. "from ordinary. Show the first as a colour AND a shape, so the "
      .. "reading survives a failed lamp or a person who does not distinguish "
      .. "the colours.",
  worked = "Your own emission works this way, and the same reading is what "
        .. "the assembler pushes on at the bottom of every loop -- so a "
        .. "program running away and a machine worrying appear on one dial.",
  costs = "Two digits each is all that fits on lamps, so the vocabulary is "
       .. "small and you have to write down what your own codes mean.",
  stops = "Between machines. Two of these emitting seventeen mean unrelated "
       .. "things. There is no shared vocabulary and there is not meant to be "
       .. "one.",
})
-- }}}

-- {{{ keep only what could not be recomputed
pattern({
  name = "keep-only-the-underivable",
  about = "what is worth writing down",
  what = "Write down what you could not work out again: what arrived from "
      .. "outside, what a piece of hardware actually did when you touched it, "
      .. "which of your guesses were wrong. Do not write down what you could "
      .. "recompute from those.",
  worked = "The randomness you draw from is a seed and a position rather than "
        .. "a record of every number drawn -- the same determinism for far "
        .. "less machinery.",
  costs = "Recomputing takes time, and something you decided was derivable "
       .. "may stop being so when the thing it derived from changes.",
  stops = "When recomputing is more expensive than the storage would have "
       .. "been, which is most of the time for small things and almost never "
       .. "for large ones.",
})
-- }}}

-- {{{ walking backward from a saturating reading
pattern({
  name = "walk-backward-from-the-edge",
  about = "finding what went wrong",
  what = "When a reading is stuck at its limit, walk backwards through what "
      .. "happened until you find where it was ordinary. The last ordinary "
      .. "moment is the thing to look at, not the first stuck one.",
  worked = "A whole thought disagreeing at the second token and not the "
        .. "first: the first matching exactly was the diagnosis, because it "
        .. "cleared everything that acts at every position.",
  costs = "You have to be keeping enough history to walk back through.",
  stops = "When the cause and the symptom are far apart, or when the thing "
       .. "that went wrong is what stopped the history being kept.",
})
-- }}}

-- {{{ thread pools
pattern({
  name = "thread-pools",
  about = "doing many things at once",
  what = "A pile of work and several workers taking from it, rather than one "
      .. "worker per piece of work. Workers that finish take the next thing; "
      .. "nothing is scheduled in advance.",
  worked = "Anywhere the work is many similar independent pieces.",
  costs = "The pile has to be shared safely, which is the whole difficulty.",
  stops = "When the pieces are not independent -- when one needs another's "
       .. "answer. Then it is not a pile, it is an order, and pretending "
       .. "otherwise deadlocks.",
})
-- }}}

-- {{{ looping iterators
pattern({
  name = "looping-iterators",
  about = "walking over something without knowing its shape",
  what = "Ask the thing for its next piece rather than knowing how it is "
      .. "arranged. The walker works on anything that can answer, and the "
      .. "arrangement stays the arrangement's business.",
  worked = "Walking the firmware's memory map, whose stride the firmware "
        .. "chooses rather than the reader.",
  costs = "One indirection per piece.",
  stops = "When you need to jump to the middle. An iterator that only goes "
       .. "forward makes seeking cost the whole walk.",
})
-- }}}
-- }}}

-- {{{ M.as_text(name)
function M.as_text(name)
  local entry = M.PATTERNS[name]
  if not entry then return nil end
  local lines = {
    entry.name,
    "  " .. entry.about,
    "",
    "what it is:",
    "  " .. entry.what,
    "",
    "where it has worked:",
    "  " .. entry.worked,
    "",
    "what it costs:",
    "  " .. entry.costs,
    "",
    "where it stops working:",
    "  " .. entry.stops,
  }
  if entry.learned then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "learned the hard way:"
    lines[#lines + 1] = "  " .. entry.learned
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "This is a suggestion. A machine that does something "
    .. "else entirely has done nothing wrong."
  return table.concat(lines, "\n")
end
-- }}}

-- {{{ M.names()
function M.names()
  local out = {}
  for name in pairs(M.PATTERNS) do out[#out + 1] = name end
  table.sort(out)
  return out
end
-- }}}

-- {{{ M.offer(catalogue, hands)
function M.offer(catalogue, hands)
  hands.offer(catalogue, {
    name = "patterns", takes = {}, gives = "shapes that have worked before",
    does = function()
      local lines = { "shapes carried on this chip. All suggestions except "
        .. "the calling convention, which is an agreement:" }
      for _, name in ipairs(M.names()) do
        lines[#lines + 1] = "  " .. name .. "  -- " .. M.PATTERNS[name].about
      end
      lines[#lines + 1] = ""
      lines[#lines + 1] = "Ask <call pattern NAME> for one. Each says where it "
        .. "stops working, which is the part worth reading."
      return table.concat(lines, "\n")
    end,
  })

  hands.offer(catalogue, {
    name = "pattern", takes = { "name" }, gives = "the whole of one",
    does = function(arguments)
      local text = M.as_text(arguments[1])
      if not text then
        return nil, "there is no pattern called '" .. tostring(arguments[1])
          .. "'. Ask <call patterns> for the list."
      end
      return text
    end,
  })
end
-- }}}

return M
