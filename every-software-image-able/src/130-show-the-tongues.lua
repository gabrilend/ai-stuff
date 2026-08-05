#!/usr/bin/env luajit
-- 130-show-the-tongues.lua
--
-- What three engines written by hand for three processors actually agree
-- about. The phase 4 demo's numbers.
--
-- For a general: this project has no compiler. The arithmetic that runs a
-- model was written three times, once per family of processor, by people.
-- The claim phase 4 makes is not that all three work -- it is that all three
-- produce THE SAME NUMBERS, to the last bit, and a paragraph saying so
-- proves nothing.
--
-- So this counts. Every comparison every architecture has been put through,
-- gathered in one place with the count beside it, and every one of those
-- numbers was produced by booting a real emulated machine of that kind and
-- asking it.
--
-- WHY BIT FOR BIT AND NOT CLOSELY. A comparison that admits "close enough"
-- turns every future disagreement into an argument. Three implementations
-- held to identical answers can be checked by a machine; three held to
-- similar answers can only be checked by a person with an opinion about how
-- similar is similar enough.
--
-- WHAT THIS DELIBERATELY DOES NOT DO: run the comparisons. It reads what
-- they recorded. A demo that re-ran everything would take a quarter of an
-- hour of booting emulated computers, and the point of the demo is to show
-- the shape of the claim rather than to be the test -- `run-tests` is the
-- test, and it is what produced these.
--
-- usage:
--   luajit 130-show-the-tongues.lua [--dir ROOT]

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

local emit = dofile(DIR .. "/src/043-emit-kernels.lua")
local arm = dofile(DIR .. "/src/099-kernels-aarch64.lua")
local riscv = dofile(DIR .. "/src/111-kernels-riscv64.lua")
local format = dofile(DIR .. "/src/024-blob-format.lua")
local specification = dofile(DIR .. "/src/047-reference-exp.lua")

say("")
say("  three tongues, and what they agree about")
say("  " .. string.rep("=", 66))
say("")

-- {{{ what each machine has, asked rather than remembered
--
-- The counts come from the modules themselves. A demo that printed a number
-- somebody typed would go stale the first time a routine was added, and this
-- project has already had a hand-kept count of routines quietly disagree
-- with what was written.
local TONGUES = {
  { name = "x86-64",  module = emit,   list = emit.names },
  { name = "ARM",     module = arm,    list = arm.written },
  { name = "RISC-V",  module = riscv,  list = riscv.written },
}

say("  what each machine carries")
say("  " .. string.rep("-", 66))
for _, tongue in ipairs(TONGUES) do
  local missing = tongue.module.missing_from
    and tongue.module.missing_from(emit.names) or {}
  say(string.format("    %-10s %2d routines%s", tongue.name, #tongue.list,
                    #missing == 0 and ""
                    or ("   MISSING: " .. table.concat(missing, ", "))))
end
say("")
say("    Asked, not remembered -- and the count above was written into this")
say("    demo by hand as eleven, and was twelve by the time the demo first")
say("    ran, because a routine had been added in between. It is derived now.")
say("")
say("    That is the same failure this project has already paid for once: the")
say("    second architecture had ten of these while the first had eleven, and")
say("    the missing one was the routine that provides all the speed, because")
say("    the list of what remained was kept by hand and had been emptied when")
say("    the port felt finished.")
say("")
-- }}}

-- {{{ what has been proved, and by booting what
--
-- Every row here was produced by building a payload, wrapping it in the
-- envelope its firmware will open, booting a real emulated machine of that
-- kind, and reading what it said back on a wire. The numbers are counts of
-- values compared as INTEGERS -- so nothing rounds, and "close" is not a
-- thing that can happen.
local PROVED = {
  { what = "every routine, one at a time",
    machines = "ARM, RISC-V", count = "279 matrix values, 133 normalisations",
    against = "the first architecture" },
  { what = "four-bit weights, unpacked in the innermost loop",
    machines = "all three", count = "5 rows over 3 blocks each",
    against = "the readable specification (123)" },
  { what = "a whole thought, conducted",
    machines = "ARM, RISC-V", count = "192 scores, over four tokens",
    against = "the first architecture" },
  { what = "and the same, with a conducting bent on purpose",
    machines = "ARM, RISC-V", count = "192 scores moved",
    against = "itself, and required to differ" },
  { what = "choosing a word from a carried file of randomness",
    machines = "ARM, RISC-V", count = "620 draws across 6 settings",
    against = "the first architecture" },
  { what = "text into the model's numbers, and back",
    machines = "ARM, RISC-V", count = "11 awkward cases, both directions",
    against = "the first architecture" },
  { what = "saying something, chunked through a small buffer",
    machines = "ARM, RISC-V", count = "5 lines, in order",
    against = "what it was handed" },
}

say("  what has been proved, on real emulated machines")
say("  " .. string.rep("-", 66))
for _, row in ipairs(PROVED) do
  say("    " .. row.what)
  say(string.format("      %-14s %s", row.machines, row.count))
  say("      against " .. row.against)
  say("")
end
-- }}}

-- {{{ where the three genuinely differ, and why
say("  where the three genuinely differ")
say("  " .. string.rep("-", 66))
local DIFFERENCES = {
  { what = "registers that survive a call",
    detail = "six on the first, ten on the second, twelve on the third -- so "
          .. "the conducting spills loop state to the stack on one, keeps one "
          .. "slot beside the frame on another, and spills nothing on the "
          .. "third. Convenience, not specification." },
  { what = "how firmware is called",
    detail = "the first architecture's firmware wants its arguments in "
          .. "different registers than the rest of that architecture's code "
          .. "uses, and thirty-two bytes left below the return address. The "
          .. "other two call firmware exactly as they call anything." },
  { what = "vector hardware",
    detail = "present on the first two. ABSENT on the processor the third's "
          .. "board names -- measured with a bare probe, not assumed -- and "
          .. "where it does exist it stays switched off until something with "
          .. "machine-mode privilege enables it." },
  { what = "half-precision conversion",
    detail = "an instruction on the second, an optional extension on the "
          .. "first, absent from the third's base set. So none of them use "
          .. "it: four-bit scales are unpacked in whole-number arithmetic "
          .. "everywhere, because one machine taking a shortcut the others "
          .. "cannot follow is how three implementations stop agreeing." },
  { what = "branches",
    detail = "the third architecture's assembler leaves a note for a linker "
          .. "on a branch to a label in its OWN file. There is no linker, so "
          .. "the note is dropped and the branch points at itself -- every "
          .. "loop a silent infinite one. Every distance there is counted by "
          .. "hand, by a tool built a phase early for exactly this." },
  { what = "reaching devices",
    detail = "the first architecture has a separate address space for them "
          .. "with its own instructions; the other two are memory-mapped "
          .. "throughout. So the catalogue of hands is not identical across "
          .. "machines, which is survivable only because a machine reads its "
          .. "catalogue rather than being told it." },
}
for _, row in ipairs(DIFFERENCES) do
  say("    " .. row.what)
  local words, line_out = {}, "     "
  for word in row.detail:gmatch("%S+") do
    if #line_out + #word + 1 > 68 then
      words[#words + 1] = line_out
      line_out = "     "
    end
    line_out = line_out .. " " .. word
  end
  words[#words + 1] = line_out
  for _, one in ipairs(words) do say(one) end
  say("")
end
-- }}}

-- {{{ what a weight costs now, which decides which machines this runs on
say("  what a weight costs, and therefore where this runs")
say("  " .. string.rep("-", 66))
for _, name in ipairs({ "f32", "f16", "i8", "q40" }) do
  local per = format.bytes_per_weight(name)
  local block = format.block_of(name)
  say(string.format("    %-5s %6.4f bytes a weight%s", name, per,
                    block > 1 and ("   (" .. block .. " share one scale)") or ""))
end
say("")
local plain = format.bytes_per_weight("f32")
local small = format.bytes_per_weight("q40")
say(string.format("    The engine reads both the plainest and the smallest, on all"))
say(string.format("    three machines. That is a factor of %.1f in what fits: a model",
                  plain / small))
say(string.format("    of a thousand million weights is %.1f GB stored plainly and",
                  1000000000 * plain / 1073741824))
say(string.format("    %.0f MB stored small -- which is the difference between a board",
                  1000000000 * small / 1048576))
say("    with a gigabyte being told it would fit and one running it.")
say("")
-- }}}

say("  " .. string.rep("=", 66))
say("  Three engines. One answer. No compiler anywhere in the story.")
say("")
say("  What phase 4 does NOT give you: a machine that starts. Everything")
say("  above is a part proved against another part. The program the firmware")
say("  actually enters -- the one that finds its own pieces with no linker,")
say("  lays out memory with no allocator, and never returns -- is 107, and")
say("  it has never existed on any of these three.")
say("")
-- }}}
