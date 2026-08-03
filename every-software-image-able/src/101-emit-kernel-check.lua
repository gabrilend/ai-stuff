-- 101-emit-kernel-check.lua
--
-- A payload that runs the second tongue's kernels on a bare machine and
-- says how many of their answers matched what the first tongue produced.
-- The other half of issue 401's test.
--
-- For a general: the kernels for this architecture cannot be tested on the
-- machine that wrote them, because that machine does not speak this
-- language. So the test is carried to a machine that does: the inputs, the
-- kernels, and the answers the first architecture gave, all baked into one
-- program that boots, computes, compares, and reports two numbers.
--
-- WHY THE ANSWERS ARE CARRIED RATHER THAN RECOMPUTED. A payload that
-- computed the expected answers on the same machine would be comparing an
-- implementation against itself, which passes whatever it does. The bit
-- patterns here came off the first architecture, and they are compared as
-- INTEGERS -- not as numbers, so nothing rounds during the comparison and
-- "close" is not a thing that can happen.

local M = {}

-- {{{ M.aarch64(options)
--
-- options: cases, recorded, norms, recorded_norm, kernels (the assembly
-- text), number_at (the same deterministic numbers the host used)
function M.aarch64(options)
  local out = {}
  local function line(text) out[#out + 1] = text end

  -- {{{ the numbers, as the exact bit patterns the host had
  -- Not as decimal text: a decimal that has to be parsed back into a float
  -- is a rounding this test would then be measuring.
  --
  -- Through 107 rather than done here. The version that lived in this file
  -- wrote a float and read it back through a pointer of another shape, which
  -- is correct until the loop goes hot and the compiler decides the second
  -- read cannot have changed. It emitted 256 numbers of which 3 were
  -- distinct, and the machine that ran them was very nearly recorded as a
  -- broken port.
  local bits = dofile((options.dir or ".") .. "/src/107-float-bits.lua")
  local function bits_of(value) return bits.of(value) end
  -- }}}

  -- THE FIRST INSTRUCTION MUST BE OURS. Firmware enters at offset zero of
  -- the code, so whatever is emitted first is what runs. Putting the kernels
  -- first meant the machine entered `matrix_vector_plain` with the
  -- firmware's arguments in its registers, which happened to mean "no rows",
  -- so it returned immediately -- and the firmware, handed control back,
  -- carried on booting to its own shell. Nothing failed and nothing was
  -- reported; the payload simply never ran.
  line("  .text")
  line("  .globl _start")
  line("_start:")
  line("  b start_here")

  -- THE KERNELS' NAMES ARE STRIPPED OF THEIR EXPORT, and that is the third
  -- appearance of this project's oldest trap. A call to an EXPORTED symbol
  -- is a note for a linker even on an assembler that resolves local
  -- references itself. There is no linker here, so extracting the raw bytes
  -- drops the note and leaves the branch offset as zero -- and a call whose
  -- offset is zero is a call to ITSELF. Every kernel call became an infinite
  -- loop, with no fault and nothing said: the machine printed its first mark
  -- and then span forever.
  --
  -- The kernels keep their exports in their own file, because the hosted
  -- build genuinely needs them to load the library. It is only here, where
  -- nothing links, that a name must be local.
  line(options.kernels:gsub("%s*%.section%s+%.note%.GNU%-stack[^\n]*\n", "\n")
                      :gsub("^%s*%.text%s*\n", "")
                      :gsub("%s*%.globl%s+[%w_]+%s*\n", "\n")
                      :gsub("%s*%.type%s+[%w_]+%s*,%s*@function%s*\n", "\n"))

  line("start_here:")
  line("here:")
  line("  sub sp, sp, #4096")
  line("  mov x19, x1")                    -- the firmware's table
  line("  ldr x20, [x19, #64]")            -- its console
  line("  mov x21, xzr")                   -- matched
  line("  mov x22, xzr")                   -- total
  line("  mov x23, xzr")                   -- normalisations matched
  line("  mov x24, xzr")                   -- normalisations total
  -- The first disagreement, kept whole. Counting how many differ says
  -- nothing about WHETHER the port is subtly rounding differently or plainly
  -- wrong, and those want opposite responses -- one is accepted, the other
  -- is a defect that the fast kernel would inherit. So the first pair is
  -- carried back intact and the host works out the distance, rather than
  -- floating-point arithmetic being done here to answer a question about
  -- floating-point arithmetic.
  line("  mov x25, xzr")                   -- what this machine got
  line("  mov x26, xzr")                   -- what the first tongue said
  line("  mov x27, xzr")                   -- whether one has been captured

  -- {{{ saying things
  local said = 0
  local function say_text(text)
    said = said + 1
    local skip, label = "cskip" .. said, "ctext" .. said
    line("  b " .. skip)
    line(label .. ":")
    for index = 1, #text do line("  .short " .. text:byte(index)) end
    line("  .short 0")
    line("  .balign 4")
    line(skip .. ":")
    line("  adr x1, " .. label)
    line("  mov x0, x20")
    line("  ldr x8, [x20, #8]")
    line("  blr x8")
  end

  local converted = 0
  local function say_hex(register)
    converted = converted + 1
    local loop, digit, done = "chex" .. converted, "cdig" .. converted,
                              "cdone" .. converted
    line("  mov x9, " .. register)
    line("  add x10, sp, #64")
    line("  mov w11, #16")
    line(loop .. ":")
    line("  lsr x12, x9, #60")
    line("  lsl x9, x9, #4")
    line("  cmp w12, #10")
    line("  b.lt " .. digit)
    line("  add w12, w12, #87")
    line("  b " .. done)
    line(digit .. ":")
    line("  add w12, w12, #48")
    line(done .. ":")
    line("  strh w12, [x10], #2")
    line("  subs w11, w11, #1")
    line("  b.ne " .. loop)
    line("  strh wzr, [x10]")
    line("  add x1, sp, #64")
    line("  mov x0, x20")
    line("  ldr x8, [x20, #8]")
    line("  blr x8")
  end
  -- }}}

  say_text("\r\nchecking the second tongue against the first\r\n")

  -- {{{ the data, laid inline
  -- Each case gets its matrix, its input, and the answers the first tongue
  -- gave. All as raw words, so nothing is parsed and nothing rounds.
  local data_labels = {}
  line("  b data_done")
  for case_index, case in ipairs(options.cases) do
    local entry = options.recorded[case_index]

    data_labels[case_index] = {
      matrix = "matrix" .. case_index,
      input = "input" .. case_index,
      want = "want" .. case_index,
    }

    line("  .balign 16")
    line(data_labels[case_index].matrix .. ":")
    for index = 0, case.rows * case.columns - 1 do
      line(string.format("  .word 0x%08x",
                         bits_of(options.number_at(index + case_index * 100))))
    end

    line("  .balign 16")
    line(data_labels[case_index].input .. ":")
    for index = 0, case.columns - 1 do
      line(string.format("  .word 0x%08x",
                         bits_of(options.number_at(index + case_index * 7000))))
    end

    line("  .balign 16")
    line(data_labels[case_index].want .. ":")
    for _, answer in ipairs(entry.answers) do
      line(string.format("  .word 0x%08x", answer))
    end
  end

  local norm_labels = {}
  for case_index, size in ipairs(options.norms) do
    local entry = options.recorded_norm[case_index]
    norm_labels[case_index] = {
      input = "ninput" .. case_index,
      weight = "nweight" .. case_index,
      want = "nwant" .. case_index,
    }
    line("  .balign 16")
    line(norm_labels[case_index].input .. ":")
    for index = 0, size - 1 do
      line(string.format("  .word 0x%08x",
                         bits_of(options.number_at(index + case_index * 300))))
    end
    line("  .balign 16")
    line(norm_labels[case_index].weight .. ":")
    for index = 0, size - 1 do
      line(string.format("  .word 0x%08x",
                         bits_of(options.number_at(index + case_index * 900))))
    end
    line("  .balign 16")
    line(norm_labels[case_index].want .. ":")
    for _, answer in ipairs(entry.answers) do
      line(string.format("  .word 0x%08x", answer))
    end
  end

  -- Nowhere to put results INSIDE the payload: firmware that honours
  -- section rights maps the code read-only, so a buffer in .text is a
  -- crash on some machines and not others. The stack is writable
  -- everywhere, which is why 033 puts its map buffer there too. This one
  -- announced itself by speaking its greeting and then going silent.
  line("data_done:")
  -- }}}

  -- {{{ every case, run both ways and compared
  for case_index, case in ipairs(options.cases) do
    local labels = data_labels[case_index]

    -- A mark per case, said before the case runs. Everything else this
    -- payload says comes at the end, so a machine that stops partway says
    -- nothing at all and the last mark is the only thing that narrows it --
    -- the same reason a hazard probe speaks before it acts (019).
    say_text(".")

    for _, which in ipairs({ "matrix_vector_plain", "matrix_vector_wide" }) do
      line("  add x0, sp, #512")
      line("  adr x1, " .. labels.matrix)
      line("  adr x2, " .. labels.input)
      line("  mov w3, #" .. case.rows)
      line("  mov w4, #" .. case.columns)
      line("  bl " .. which)

      -- compare as integers. Nothing rounds, and "close" cannot happen.
      line("  add x5, sp, #512")
      line("  adr x6, " .. labels.want)
      line("  mov w7, #" .. case.rows)
      local loop = "cmp" .. case_index .. which:gsub("_", "")
      line(loop .. ":")
      line("  ldr w8, [x5], #4")           -- what this machine got
      line("  ldr w9, [x6], #4")           -- what the first tongue said
      line("  add x22, x22, #1")
      line("  cmp w8, w9")
      line("  b.eq " .. loop .. "same")
      -- the first disagreement is kept whole, and only the first
      line("  cbnz x27, " .. loop .. "no")
      line("  mov x25, x8")
      line("  mov x26, x9")
      line("  mov x27, #1")
      line("  b " .. loop .. "no")
      line(loop .. "same:")
      line("  add x21, x21, #1")
      line(loop .. "no:")
      line("  subs w7, w7, #1")
      line("  b.ne " .. loop)
    end
  end
  -- }}}

  -- {{{ the normalisations
  for case_index, size in ipairs(options.norms) do
    local labels = norm_labels[case_index]
    line("  add x0, sp, #512")
    line("  adr x1, " .. labels.input)
    line("  adr x2, " .. labels.weight)
    line("  mov w3, #" .. size)
    -- the small constant, as the exact pattern the host used
    line(string.format("  mov w9, #0x%x", bits_of(1e-5) % 0x10000))
    line(string.format("  movk w9, #0x%x, lsl #16",
                       math.floor(bits_of(1e-5) / 0x10000)))
    line("  fmov s0, w9")
    line("  bl rms_normalise")

    line("  add x5, sp, #512")
    line("  adr x6, " .. labels.want)
    line("  mov w7, #" .. size)
    local loop = "ncmp" .. case_index
    line(loop .. ":")
    line("  ldr w8, [x5], #4")
    line("  ldr w9, [x6], #4")
    line("  add x24, x24, #1")
    line("  cmp w8, w9")
    line("  b.ne " .. loop .. "no")
    line("  add x23, x23, #1")
    line(loop .. "no:")
    line("  subs w7, w7, #1")
    line("  b.ne " .. loop)
  end
  -- }}}

  say_text("kernels checked\r\n  matched ")
  say_hex("x21")
  say_text("\r\n  of ")
  say_hex("x22")
  say_text("\r\n  norms ")
  say_hex("x23")
  say_text("\r\n  nof ")
  say_hex("x24")
  say_text("\r\n  got ")
  say_hex("x25")
  say_text("\r\n  want ")
  say_hex("x26")
  say_text("\r\n")

  line("chalt:")
  line("  wfi")
  line("  b chalt")
  line("")

  return table.concat(out, "\n")
end
-- }}}

return M
