#!/usr/bin/env luajit
-- 125-test-quantised-kernels.lua
--
-- The quantised matrix product, on all three architectures, held to the
-- readable specification bit for bit. Issue 108.
--
-- For a general: weights stored at four bits each have to be unpacked before
-- they can be multiplied, and that unpacking happens in the innermost loop of
-- the machine. This checks that all three processors unpack them identically
-- and get identical answers -- not close answers.
--
-- ONE TEST, THREE MACHINES, ON PURPOSE. Every other piece of assembly in this
-- project was written for one architecture and ported later, and every time
-- that happened something went missing or drifted between them (`403` lists
-- what). This routine was written for all three in one sitting and is checked
-- in one place, so there is no interval during which two of them are
-- different and nothing says so.
--
-- WHAT IT IS HELD TO. Not the plain product -- that answer is different on
-- purpose, because quantising loses information. It is held to `123`, the
-- readable specification of this form, which is where the order of operations
-- is decided.
--
-- usage:
--   luajit 125-test-quantised-kernels.lua [--dir ROOT] [--seconds N]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

local ffi = require("ffi")

-- {{{ local function say(text)
local function say(text)
  io.write(text, "\n")
  io.flush()
end
-- }}}

-- {{{ local function run_one(command)
local function run_one(command)
  local ok, _, code = os.execute(command)
  return (ok == true or ok == 0), code
end
-- }}}

-- {{{ local function read_file(path)
local function read_file(path)
  local handle = io.open(path, "rb")
  if not handle then return nil end
  local text = handle:read("*a")
  handle:close()
  return text
end
-- }}}

-- {{{ main
local seconds = 90
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then
    index = index + 1 ; DIR = arg[index]
  elseif arg[index] == "--seconds" then
    index = index + 1 ; seconds = tonumber(arg[index]) or 90
  end
  index = index + 1
end

say("")
say("  four-bit weights, on all three machines")
say("  " .. string.rep("-", 58))
say("")

local passed, failed = 0, 0
local function check(what, ok, detail)
  if ok then
    passed = passed + 1
    say(string.format("  %-50s ok", what))
  else
    failed = failed + 1
    say(string.format("  %-50s WRONG", what))
    if detail then say("      " .. detail) end
  end
end

local emit = dofile(DIR .. "/src/043-emit-kernels.lua")
local arm = dofile(DIR .. "/src/099-kernels-aarch64.lua")
local riscv = dofile(DIR .. "/src/111-kernels-riscv64.lua")
local format = dofile(DIR .. "/src/024-blob-format.lua")
local quantised = dofile(DIR .. "/src/123-reference-quantised.lua")
local specification = dofile(DIR .. "/src/047-reference-exp.lua")
local float_bits = dofile(DIR .. "/src/107-float-bits.lua")

run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/kernels")
run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/payloads")
run_one("mkdir -p " .. DIR .. "/tmp/kernels")

-- {{{ the case, and what the specification says about it
--
-- Three blocks to a row, so a row spans more than one scale and a routine
-- that read one scale for the whole row would be caught. Five rows, so the
-- row stride is exercised rather than assumed.
local BLOCK = format.block_of("q40")
local ROWS, COLUMNS = 5, BLOCK * 3

local matrix = ffi.new("float[?]", ROWS * COLUMNS)
local input = ffi.new("float[?]", COLUMNS)
for place = 0, ROWS * COLUMNS - 1 do
  matrix[place] = ((place * 2654435761) % 1000003) / 500000.0 - 1.0
end
for place = 0, COLUMNS - 1 do
  input[place] = ((place * 40503) % 1000003) / 500000.0 - 1.0
end

-- One block made of tiny values, so its scale comes out subnormal and the
-- branch that resolves subnormals is actually taken. Without this the
-- unpacking would be checked only on its easy path -- and the easy path is
-- the one every implementation gets right.
-- A hundred thousandth, not a ten millionth. The smaller factor drove the
-- whole block's scale to exactly zero, which is a different case entirely --
-- an all-but-zero block, exact and uninteresting -- rather than the
-- subnormal one. The check below is what caught that, which is the reason it
-- asks whether the case it is about to rely on actually occurs.
for place = BLOCK, BLOCK * 2 - 1 do
  matrix[place] = matrix[place] * 1e-5
end

local packed = quantised.quantise(matrix, ROWS * COLUMNS, format)
local expected = ffi.new("float[?]", ROWS)
quantised.matrix_vector_quantised(expected, packed, input, ROWS, COLUMNS,
                                  format)

local scales_seen = {}
for at = 1, #packed, format.block_bytes("q40") do
  local low, high = packed:byte(at), packed:byte(at + 1)
  scales_seen[low + high * 256] = true
end
local distinct_scales = 0
for _ in pairs(scales_seen) do distinct_scales = distinct_scales + 1 end
check("the case has more than one scale in it",
      distinct_scales > 1,
      distinct_scales .. " distinct scales -- a routine reading one scale for "
      .. "a whole row would pass a case that had only one")

-- the subnormal path is taken, checked rather than assumed
local subnormal_present = false
for pattern in pairs(scales_seen) do
  if pattern > 0 and pattern < 1024 then subnormal_present = true end
end
check("and a scale small enough to be subnormal", subnormal_present,
      "the branch that resolves subnormals would otherwise never be taken, "
      .. "and it is the half of the unpacking that is easy to get wrong")

local as_bits = ffi.cast("uint32_t *", expected)
local want = {}
for row = 0, ROWS - 1 do want[row + 1] = as_bits[row] end
-- }}}

-- {{{ the first architecture, in this process
local source = DIR .. "/tmp/shared-memory/kernels/kernels-x86_64.s"
local library = DIR .. "/tmp/kernels/kernels-quantised-x86_64.so"
local handle = io.open(source, "w")
handle:write(emit.source("x86_64", specification))
handle:close()

if not run_one("clang -shared -o " .. library .. " " .. source) then
  say("  the first tongue would not build")
  os.exit(1)
end

ffi.cdef[[
  void matrix_vector_quantised(float *out, const unsigned char *matrix,
                               const float *input, int rows, int columns);
]]
local kernels = ffi.load(library)

local packed_bytes = ffi.new("unsigned char[?]", #packed)
ffi.copy(packed_bytes, packed, #packed)
local got = ffi.new("float[?]", ROWS)
kernels.matrix_vector_quantised(got, packed_bytes, input, ROWS, COLUMNS)

local first_same, first_where = true, nil
local got_bits = ffi.cast("uint32_t *", got)
for row = 0, ROWS - 1 do
  if got_bits[row] ~= want[row + 1] then
    first_same = false
    first_where = first_where or string.format(
      "row %d: %.9g against %.9g", row, got[row], expected[row])
  end
end
check("the first architecture agrees with the specification",
      first_same, first_where)
-- }}}

-- {{{ what the other two need carried, as words
--
-- The packed matrix is bytes, and the payloads lay down words, so it is
-- packed four bytes to a word with the earliest byte in the lowest position
-- -- which is the order both of these machines read memory in, so the bytes
-- land in memory in the order they were written.
local function as_words(bytes)
  local out = {}
  for at = 1, #bytes, 4 do
    local word = 0
    for step = 0, 3 do
      local byte = bytes:byte(at + step) or 0
      word = word + byte * (256 ^ step)
    end
    out[#out + 1] = word
  end
  return out
end

local matrix_words = as_words(packed)
local input_words = {}
for place = 0, COLUMNS - 1 do
  input_words[#input_words + 1] = float_bits.of(input[place])
end
-- }}}

-- {{{ the second architecture, on a real ARM machine
local function aarch64_payload()
  local out = {}
  local function line(text) out[#out + 1] = text end

  line("  .text")
  line("  .globl _start")
  line("_start:")
  line("  b start_here")

  line((arm.matrix_vector_quantised
        :gsub("%s*%.globl%s+[%w_]+%s*\n", "\n")
        :gsub("%s*%.type%s+[%w_]+%s*,%s*@function%s*\n", "\n")))

  line("start_here:")
  line("  sub sp, sp, #4096")
  line("  mov x19, x1")
  line("  ldr x20, [x19, #64]")
  line("  mov x21, xzr")                     -- matched
  line("  mov x22, xzr")                     -- compared

  local said = 0
  local function say_text(text)
    said = said + 1
    local skip, label = "qskip" .. said, "qtext" .. said
    line("  b " .. skip)
    line(label .. ":")
    for at = 1, #text do line("  .short " .. text:byte(at)) end
    line("  .short 0")
    line("  .balign 4")
    line(skip .. ":")
    line("  adr x1, " .. label)
    line("  mov x0, x20")
    line("  ldr x8, [x20, #8]")
    line("  blr x8")
  end

  local function say_hex(register)
    said = said + 1
    local loop, digit, done = "qh" .. said, "qd" .. said, "qe" .. said
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

  say_text("\r\nfour-bit weights, second tongue\r\n")

  line("  b qdata_done")
  local function lay(label, words)
    line("  .balign 16")
    line(label .. ":")
    local row = {}
    for at, word in ipairs(words) do
      row[#row + 1] = string.format("0x%08x", word)
      if #row == 8 or at == #words then
        line("  .word " .. table.concat(row, ", "))
        row = {}
      end
    end
  end
  lay("qmatrix", matrix_words)
  lay("qinput", input_words)
  lay("qwant", want)
  line("qdata_done:")

  line("  add x0, sp, #512")
  line("  adr x1, qmatrix")
  line("  adr x2, qinput")
  line("  mov w3, #" .. ROWS)
  line("  mov w4, #" .. COLUMNS)
  line("  bl matrix_vector_quantised")

  line("  add x5, sp, #512")
  line("  adr x6, qwant")
  line("  mov w7, #" .. ROWS)
  line("qcmp:")
  line("  ldr w8, [x5], #4")
  line("  ldr w9, [x6], #4")
  line("  add x22, x22, #1")
  line("  cmp w8, w9")
  line("  b.ne qcmpno")
  line("  add x21, x21, #1")
  line("qcmpno:")
  line("  subs w7, w7, #1")
  line("  b.ne qcmp")

  say_text("quantised checked\r\n  matched ")
  say_hex("x21")
  say_text("\r\n  of ")
  say_hex("x22")
  say_text("\r\n")

  line("qhalt:")
  line("  wfi")
  line("  b qhalt")
  return table.concat(out, "\n")
end

local base = DIR .. "/tmp/shared-memory/payloads/quantised-aarch64"
handle = io.open(base .. ".s", "w")
handle:write(aarch64_payload())
handle:close()

if not run_one("clang --target=aarch64-unknown-none -c " .. base .. ".s -o "
               .. base .. ".o") then
  check("the second architecture's routine assembles", false,
        "see " .. base .. ".s")
else
  check("the second architecture's routine assembles", true)
  run_one("llvm-objcopy -O binary " .. base .. ".o " .. base .. ".raw")
  run_one("luajit " .. DIR .. "/src/029-wrap-uefi.lua --from " .. base
          .. ".raw --to " .. base .. ".efi --arch aarch64 > /dev/null")

  local serial = DIR .. "/tmp/shared-memory/logs/qemu-uefi-arm64-serial.log"
  run_one("rm -f " .. serial)
  run_one("luajit " .. DIR .. "/src/018-launch-board.lua qemu-uefi-arm64"
    .. " --payload " .. base .. ".efi --seconds " .. seconds
    .. " --dir " .. DIR .. " > /dev/null 2>&1")

  local spoken = read_file(serial) or ""
  local report = spoken:match("quantised checked(.*)$") or ""
  local matched = tonumber(report:match("[\r\n]%s*matched%s+(%x+)") or "", 16)
  local total = tonumber(report:match("[\r\n]%s*of%s+(%x+)") or "", 16)

  check("and agrees with the specification on a real ARM machine",
        matched ~= nil and total ~= nil and matched == total and total > 0,
        tostring(matched) .. " of " .. tostring(total)
        .. "; see " .. serial)
end
-- }}}

-- {{{ the third architecture, on a real RISC-V machine
local function riscv64_payload()
  local words = dofile(DIR .. "/src/054-riscv-words.lua")
  local p = words.new()

  local strings, string_order = {}, {}
  local function pooled(text)
    if not strings[text] then
      strings[text] = "qstring" .. (#string_order + 1)
      string_order[#string_order + 1] = text
    end
    return strings[text]
  end

  local function say_text(text)
    p:address("a1", pooled(text), "s1")
    p:op("mv a0, s4")
    p:op("ld t1, 8(s4)")
    p:op("jalr ra, 0(t1)")
  end

  local converted = 0
  local function say_hex(register)
    converted = converted + 1
    local loop = "qhex" .. converted
    p:op("mv t0, " .. register)
    p:op("addi t1, sp, 64")
    p:op("addi t2, zero, 16")
    p:op("addi a6, zero, 39")
    p:label(loop)
    p:op("srli t3, t0, 60")
    p:op("slli t0, t0, 4")
    p:op("sltiu t4, t3, 10")
    p:op("xori t4, t4, 1")
    p:op("mul t4, t4, a6")
    p:op("addi t5, t3, 48")
    p:op("add t5, t5, t4")
    p:op("sh t5, 0(t1)")
    p:op("addi t1, t1, 2")
    p:op("addi t2, t2, -1")
    p:branch("bne", "t2", "zero", loop)
    p:op("sh zero, 0(t1)")
    p:op("addi a1, sp, 64")
    p:op("mv a0, s4")
    p:op("ld t1, 8(s4)")
    p:op("jalr ra, 0(t1)")
  end

  p:op("auipc s1, 0")
  p:op("mv s3, a1")
  p:op("ld s4, 64(s3)")
  p:load_constant("t0", 4096)
  p:op("sub sp, sp, t0")
  p:op("mv s5, zero")                        -- matched
  p:op("mv s6, zero")                        -- compared

  say_text("\r\nfour-bit weights, third tongue\r\n")

  p:op("addi a0, sp, 512")
  p:address("a1", "qmatrix", "s1")
  p:address("a2", "qinput", "s1")
  p:load_constant("a3", ROWS)
  p:load_constant("a4", COLUMNS)
  p:call("matrix_vector_quantised")

  p:op("addi t0, sp, 512")
  p:address("t1", "qwant", "s1")
  p:load_constant("t2", ROWS)
  p:label("qcmp")
  p:op("lwu t3, 0(t0)")
  p:op("lwu t4, 0(t1)")
  p:op("addi s6, s6, 1")
  p:branch("bne", "t3", "t4", "qcmpno")
  p:op("addi s5, s5, 1")
  p:label("qcmpno")
  p:op("addi t0, t0, 4")
  p:op("addi t1, t1, 4")
  p:op("addi t2, t2, -1")
  p:branch("bne", "t2", "zero", "qcmp")

  say_text("quantised checked\r\n  matched ")
  say_hex("s5")
  say_text("\r\n  of ")
  say_hex("s6")
  say_text("\r\n")

  p:label("qhalt")
  p:op("wfi")
  p:jump("qhalt")

  riscv.emit(p, { "matrix_vector_quantised" }, {
    specification = specification, float_bits = float_bits,
  })

  for _, pair in ipairs({ { "qmatrix", matrix_words }, { "qinput", input_words },
                          { "qwant", want } }) do
    p:align(16)
    p:label(pair[1])
    for _, word in ipairs(pair[2]) do p:word(word) end
  end
  for _, text in ipairs(string_order) do
    p:align(4)
    p:label(strings[text])
    p:shorts(text)
  end

  local text = p:resolve()
  return text
end

local rv_base = DIR .. "/tmp/shared-memory/payloads/quantised-riscv64"
handle = io.open(rv_base .. ".s", "w")
handle:write(riscv64_payload())
handle:close()

if not run_one("clang --target=riscv64-unknown-none -march=rv64imafd -c "
               .. rv_base .. ".s -o " .. rv_base .. ".o") then
  check("the third architecture's routine assembles", false,
        "see " .. rv_base .. ".s")
else
  check("the third architecture's routine assembles", true)

  local relocations = io.popen("llvm-readelf -r " .. rv_base .. ".o 2>&1")
  local relocation_text = relocations and relocations:read("*a") or ""
  if relocations then relocations:close() end
  check("and nothing in it is waiting on a linker",
        relocation_text:find("There are no relocations", 1, true) ~= nil,
        "a relocation left behind becomes a branch to itself, silently")

  run_one("llvm-objcopy -O binary " .. rv_base .. ".o " .. rv_base .. ".raw")
  run_one("luajit " .. DIR .. "/src/029-wrap-uefi.lua --from " .. rv_base
          .. ".raw --to " .. rv_base .. ".efi --arch riscv64 > /dev/null")

  local serial = DIR .. "/tmp/shared-memory/logs/qemu-uefi-riscv64-serial.log"
  run_one("rm -f " .. serial)
  run_one("luajit " .. DIR .. "/src/018-launch-board.lua qemu-uefi-riscv64"
    .. " --payload " .. rv_base .. ".efi --seconds " .. seconds
    .. " --dir " .. DIR .. " > /dev/null 2>&1")

  local spoken = read_file(serial) or ""
  local report = spoken:match("quantised checked(.*)$") or ""
  local matched = tonumber(report:match("[\r\n]%s*matched%s+(%x+)") or "", 16)
  local total = tonumber(report:match("[\r\n]%s*of%s+(%x+)") or "", 16)

  check("and agrees with the specification on a real RISC-V machine",
        matched ~= nil and total ~= nil and matched == total and total > 0,
        tostring(matched) .. " of " .. tostring(total)
        .. "; see " .. serial)
end
-- }}}

-- {{{ every architecture has it, worked out rather than remembered
local missing_arm = arm.missing_from(emit.names)
local missing_riscv = riscv.missing_from(emit.names)
check("all three carry the same routines",
      #missing_arm == 0 and #missing_riscv == 0,
      "second is missing " .. table.concat(missing_arm, ", ")
      .. "; third is missing " .. table.concat(missing_riscv, ", "))
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this makes possible:")
say(string.format("    weights at %.4f bytes each instead of four -- the same",
                  format.bytes_per_weight("q40")))
say("    model in about a seventh of the room, on all three machines,")
say("    agreeing to the last bit. A board with a gigabyte can now hold a")
say("    model it could only previously be told it would fit.")
say("")
say("  what it does not say:")
say("    whether a model quantised this way still thinks well. That is a")
say("    question about models rather than arithmetic, and the only honest")
say("    answer comes from running one.")
say("")

os.exit(failed == 0 and 0 or 1)
-- }}}
