#!/usr/bin/env luajit
-- 132-test-find-tensors.lua
--
-- Finding every tensor in a packed model, on all three machines, against
-- what the host works out from the same bytes. Issue 107.
--
-- For a general: before an engine can think it must be handed the address of
-- every table of weights. This checks that all three processors find the same
-- addresses in the same run of bytes -- and that each of them refuses a model
-- that does not match rather than handing back a number.
--
-- WHY THE ADDRESSES ARE COMPARED AS OFFSETS. The three machines load the
-- blob at three different places, so the addresses themselves cannot be
-- compared. What can is where each tensor sits RELATIVE to the start, which
-- is the thing the routine actually computes -- and comparing the difference
-- rather than the absolute is what makes one answer checkable against
-- another machine's at all.
--
-- WHAT IS CHECKED BEYOND "IT FOUND THEM". Two refusals, because both are
-- silent when they go wrong: a model holding fewer tensors than the engine
-- expects hands back an address that was never written, and a truncated one
-- hands back an address off the end of everything. Neither faults. Both are
-- refused here with distinct numbers, because to somebody reading a serial
-- port they mean different things -- the wrong model, or half of one.
--
-- usage:
--   luajit 132-test-find-tensors.lua [--dir ROOT] [--seconds N]

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
say("  finding the weights, on all three machines")
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

local finder = dofile(DIR .. "/src/131-find-tensors.lua")
local format = dofile(DIR .. "/src/024-blob-format.lua")
local shapes = dofile(DIR .. "/src/034-model-shapes.lua")

run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/payloads")
run_one("mkdir -p " .. DIR .. "/tmp/kernels")

-- {{{ a real packed model, and where its tensors actually are
local blob_path = DIR .. "/tmp/shared-memory/fixture/fixture-model.blob"
local blob = read_file(blob_path)
if not blob then
  say("  building the fixture model first")
  run_one("luajit " .. DIR .. "/src/036-make-fixture.lua --dir " .. DIR
          .. " > /dev/null")
  blob = read_file(blob_path)
end
if not blob then
  say("  no fixture model, and it would not build")
  os.exit(1)
end

-- The blob read here rather than through a module, deliberately. What is
-- being checked is whether three assembly routines agree with the FORMAT, so
-- the answer they are held to is worked out from the format directly -- a
-- second reading of the same description, not a shared one. A helper both
-- sides called would hide exactly the disagreement worth catching.
local header_at, entry_at, entry_size = finder.offsets(format)

local function u32(at)
  local a, b, c, d = blob:byte(at + 1, at + 4)
  return a + b * 256 + c * 65536 + d * 16777216
end
local function u64(at)
  return u32(at) + u32(at + 4) * 4294967296
end

local tensor_count = u32(header_at.tensor_count)
local tensor_table = u64(header_at.tensor_table)

local want_offsets, want_names = {}, {}
for place = 0, tensor_count - 1 do
  local entry = tensor_table + place * entry_size
  want_offsets[#want_offsets + 1] = u64(entry + entry_at.offset)
  want_names[#want_names + 1] =
    blob:sub(entry + 1, entry + format.NAME_BYTES):gsub("%z.*", "")
end

-- the model's own shape, for the order check below
local shape = {
  layers = u32(header_at.layers), hidden = u32(header_at.hidden),
  heads = u32(header_at.heads), head_width = u32(header_at.head_width),
  kv_heads = u32(header_at.kv_heads),
  feedforward = u32(header_at.feedforward),
  vocabulary = u32(header_at.vocabulary), context = u32(header_at.context),
}

check("the model holds tensors to find", #want_offsets > 10,
      #want_offsets .. " of them")

-- THE DEPENDENCY THIS WHOLE ROUTINE RESTS ON, checked rather than trusted.
-- The routines walk by index and never read a name. That only works because
-- the packer writes them in the order `034` decides, so the order is
-- compared against the names here -- which is the one place names are read.
local expected = finder.expected_order(shape, shapes)
local order_holds, order_trouble = true, nil
if #expected ~= #want_names then
  order_holds = false
  order_trouble = #expected .. " expected against " .. #want_names
else
  for place, name in ipairs(expected) do
    if want_names[place] ~= name then
      order_holds = false
      order_trouble = order_trouble or string.format(
        "at %d the model has '%s' where the order says '%s'",
        place - 1, want_names[place], name)
    end
  end
end
check("the packing order is what walking by index assumes",
      order_holds, order_trouble)
-- }}}

-- {{{ the first architecture, in this process
local source = DIR .. "/tmp/shared-memory/payloads/find-x86_64.s"
local library = DIR .. "/tmp/kernels/find-x86_64.so"
local handle = io.open(source, "w")
handle:write(finder.x86_64(format))
handle:write('  .section .note.GNU-stack,"",@progbits\n')
handle:close()

if not run_one("clang -shared -o " .. library .. " " .. source) then
  say("  the first architecture's routine would not build")
  os.exit(1)
end

ffi.cdef[[
  int64_t find_tensors(const uint8_t *blob, const void **out, int64_t wanted);
]]
local found = ffi.load(library)

local blob_bytes = ffi.new("uint8_t[?]", #blob)
ffi.copy(blob_bytes, blob, #blob)
local addresses = ffi.new("const void *[?]", #want_offsets)
local answer = tonumber(found.find_tensors(blob_bytes, addresses,
                                           #want_offsets))

check("the first architecture found them all",
      answer == #want_offsets,
      tostring(answer) .. " of " .. #want_offsets)

local base = ffi.cast("uintptr_t", blob_bytes)
local first_same, first_where = true, nil
for place = 0, #want_offsets - 1 do
  local offset = tonumber(ffi.cast("uintptr_t", addresses[place]) - base)
  if offset ~= want_offsets[place + 1] then
    first_same = false
    first_where = first_where or string.format(
      "tensor %d at %d, and the model says %d",
      place, offset, want_offsets[place + 1])
  end
end
check("and each one where the model says it is", first_same, first_where)

-- the two refusals, which are the whole reason this is a routine rather than
-- three lines at a call site
check("asking for more tensors than the model holds is refused",
      tonumber(found.find_tensors(blob_bytes, addresses,
                                  #want_offsets + 1)) == -1,
      "it handed back an address that was never written")

-- a truncated model: the size in the header says more than the bytes carry,
-- which is what a write cut off midway produces
local truncated = ffi.new("uint8_t[?]", #blob)
ffi.copy(truncated, blob, #blob)
local as_words = ffi.cast("uint64_t *", truncated + 76)
as_words[0] = 128                          -- claim the blob is tiny
check("and a model whose tensors run past its end is refused",
      tonumber(found.find_tensors(truncated, addresses, #want_offsets)) == -2,
      "it handed back an address off the end of everything")
-- }}}

-- {{{ what the other two have to reproduce
--
-- Offsets rather than addresses, because the three machines load the bytes at
-- three different places -- so what is carried is the difference, which is
-- what the routine computes anyway.
local function as_words_of(bytes)
  local out = {}
  for at = 1, #bytes, 4 do
    local word = 0
    for step = 0, 3 do
      word = word + (bytes:byte(at + step) or 0) * (256 ^ step)
    end
    out[#out + 1] = word
  end
  return out
end

local blob_words = as_words_of(blob)
local want_words = {}
for _, offset in ipairs(want_offsets) do
  want_words[#want_words + 1] = offset % 4294967296
  want_words[#want_words + 1] = math.floor(offset / 4294967296)
end
-- }}}

-- {{{ the second architecture
local function aarch64_payload()
  local out = {}
  local function line(text) out[#out + 1] = text end

  line("  .text")
  line("  .globl _start")
  line("_start:")
  line("  b start_here")
  line((finder.aarch64(format)
        :gsub("%s*%.globl%s+[%w_]+%s*\n", "\n")
        :gsub("%s*%.type%s+[%w_]+%s*,%s*@function%s*\n", "\n")))

  line("start_here:")
  line("  movz x9, #0x8000")
  line("  sub sp, sp, x9")
  line("  mov x19, x1")
  line("  ldr x20, [x19, #64]")
  line("  mov x21, sp")
  line("  mov x22, xzr")                    -- offsets matched
  line("  mov x23, xzr")                    -- offsets compared

  local said = 0
  local function say_text(text)
    said = said + 1
    local skip, label = "ftskip" .. said, "fttext" .. said
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
    local loop, digit, done = "fth" .. said, "ftd" .. said, "fte" .. said
    line("  mov x9, " .. register)
    line("  add x10, x21, #64")
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
    line("  add x1, x21, #64")
    line("  mov x0, x20")
    line("  ldr x8, [x20, #8]")
    line("  blr x8")
  end

  say_text("\r\nfinding the weights, second tongue\r\n")

  line("  b ftdata_done")
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
  lay("ftblob", blob_words)
  lay("ftwant", want_words)
  line("ftdata_done:")

  -- find them
  line("  adr x0, ftblob")
  line("  add x1, x21, #1024")
  line("  movz x2, #" .. #want_offsets)
  line("  bl find_tensors")
  line("  mov x24, x0")                     -- how many it said

  line("  movz x9, #" .. #want_offsets)
  line("  add x23, x23, #1")
  line("  cmp x24, x9")
  line("  b.ne ftcount")
  line("  add x22, x22, #1")
  line("ftcount:")

  -- each address, turned back into an offset before comparing
  line("  adr x25, ftblob")
  line("  add x5, x21, #1024")
  line("  adr x6, ftwant")
  line("  movz x7, #" .. #want_offsets)
  line("ftcmp:")
  line("  ldr x8, [x5], #8")
  line("  sub x8, x8, x25")                 -- where it sits, from the start
  line("  ldr x9, [x6], #8")
  line("  add x23, x23, #1")
  line("  cmp x8, x9")
  line("  b.ne ftcmpno")
  line("  add x22, x22, #1")
  line("ftcmpno:")
  line("  subs x7, x7, #1")
  line("  b.ne ftcmp")

  -- and the refusal, which must be the same number
  line("  adr x0, ftblob")
  line("  add x1, x21, #1024")
  line("  movz x2, #" .. (#want_offsets + 1))
  line("  bl find_tensors")
  line("  mov x26, x0")

  say_text("weights found\r\n  matched ")
  say_hex("x22")
  say_text("\r\n  of ")
  say_hex("x23")
  say_text("\r\n  refusal ")
  say_hex("x26")
  say_text("\r\n")

  line("fthalt:")
  line("  wfi")
  line("  b fthalt")
  return table.concat(out, "\n")
end

local arm_base = DIR .. "/tmp/shared-memory/payloads/find-aarch64"
handle = io.open(arm_base .. ".s", "w")
handle:write(aarch64_payload())
handle:close()

if not run_one("clang --target=aarch64-unknown-none -c " .. arm_base
               .. ".s -o " .. arm_base .. ".o") then
  check("the second architecture's routine assembles", false,
        "see " .. arm_base .. ".s")
else
  check("the second architecture's routine assembles", true)
  run_one("llvm-objcopy -O binary " .. arm_base .. ".o " .. arm_base .. ".raw")
  run_one("luajit " .. DIR .. "/src/029-wrap-uefi.lua --from " .. arm_base
          .. ".raw --to " .. arm_base .. ".efi --arch aarch64 > /dev/null")

  local serial = DIR .. "/tmp/shared-memory/logs/qemu-uefi-arm64-serial.log"
  run_one("rm -f " .. serial)
  run_one("luajit " .. DIR .. "/src/018-launch-board.lua qemu-uefi-arm64"
    .. " --payload " .. arm_base .. ".efi --seconds " .. seconds
    .. " --dir " .. DIR .. " > /dev/null 2>&1")

  local spoken = read_file(serial) or ""
  local report = spoken:match("weights found(.*)$") or ""
  local function after(mark)
    return tonumber(report:match("[\r\n]%s*" .. mark .. "%s+(%x+)") or "", 16)
  end
  local matched, of, refusal = after("matched"), after("of"), after("refusal")

  check("and finds every tensor where the model says",
        matched ~= nil and of ~= nil and matched == of and of > 0,
        tostring(matched) .. " of " .. tostring(of) .. "; see " .. serial)
  -- minus one, as sixty-four bits
  check("and refuses a model that holds too few",
        refusal == 0xffffffffffffffff,
        "it said " .. tostring(refusal) .. " rather than minus one")
end
-- }}}

-- {{{ the third architecture
local function riscv64_payload()
  local words = dofile(DIR .. "/src/054-riscv-words.lua")
  local p = words.new()

  local strings, string_order = {}, {}
  local function pooled(text)
    if not strings[text] then
      strings[text] = "ftstring" .. (#string_order + 1)
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
    local loop = "fthex" .. converted
    p:op("mv t0, " .. register)
    p:op("addi t1, s2, 64")
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
    p:op("addi a1, s2, 64")
    p:op("mv a0, s4")
    p:op("ld t1, 8(s4)")
    p:op("jalr ra, 0(t1)")
  end

  p:op("auipc s1, 0")
  p:op("mv s3, a1")
  p:op("ld s4, 64(s3)")
  p:load_constant("t0", 32768)
  p:op("sub sp, sp, t0")
  p:op("mv s2, sp")
  p:op("mv s5, zero")                       -- offsets matched
  p:op("mv s6, zero")                       -- offsets compared

  say_text("\r\nfinding the weights, third tongue\r\n")

  p:address("a0", "ftblob", "s1")
  p:load_constant("a1", 1024)
  p:op("add a1, s2, a1")
  p:load_constant("a2", #want_offsets)
  p:call("find_tensors")
  p:op("mv s7, a0")                         -- how many it said

  p:load_constant("t0", #want_offsets)
  p:op("addi s6, s6, 1")
  p:branch("bne", "s7", "t0", "ftcount")
  p:op("addi s5, s5, 1")
  p:label("ftcount")

  p:address("s8", "ftblob", "s1")           -- where the bytes begin
  p:load_constant("t0", 1024)
  p:op("add t0, s2, t0")
  p:address("t1", "ftwant", "s1")
  p:load_constant("t2", #want_offsets)
  p:label("ftcmp")
  p:op("ld t3, 0(t0)")
  p:op("sub t3, t3, s8")                    -- where it sits, from the start
  p:op("ld t4, 0(t1)")
  p:op("addi s6, s6, 1")
  p:branch("bne", "t3", "t4", "ftcmpno")
  p:op("addi s5, s5, 1")
  p:label("ftcmpno")
  p:op("addi t0, t0, 8")
  p:op("addi t1, t1, 8")
  p:op("addi t2, t2, -1")
  p:branch("bne", "t2", "zero", "ftcmp")

  -- and the refusal
  p:address("a0", "ftblob", "s1")
  p:load_constant("a1", 1024)
  p:op("add a1, s2, a1")
  p:load_constant("a2", #want_offsets + 1)
  p:call("find_tensors")
  p:op("mv s9, a0")

  say_text("weights found\r\n  matched ")
  say_hex("s5")
  say_text("\r\n  of ")
  say_hex("s6")
  say_text("\r\n  refusal ")
  say_hex("s9")
  say_text("\r\n")

  p:label("fthalt")
  p:op("wfi")
  p:jump("fthalt")

  finder.riscv64(p, format)

  for _, pair in ipairs({ { "ftblob", blob_words }, { "ftwant", want_words } }) do
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

local rv_base = DIR .. "/tmp/shared-memory/payloads/find-riscv64"
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
  local report = spoken:match("weights found(.*)$") or ""
  local function after(mark)
    return tonumber(report:match("[\r\n]%s*" .. mark .. "%s+(%x+)") or "", 16)
  end
  local matched, of, refusal = after("matched"), after("of"), after("refusal")

  check("and finds every tensor where the model says",
        matched ~= nil and of ~= nil and matched == of and of > 0,
        tostring(matched) .. " of " .. tostring(of) .. "; see " .. serial)
  check("and refuses a model that holds too few",
        refusal == 0xffffffffffffffff,
        "it said " .. tostring(refusal) .. " rather than minus one")
end
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this is the first piece of:")
say("    the driver -- the program the firmware enters and never leaves.")
say("    Before anything can think, something has to find the weights with")
say("    no operating system, no file and no map: a run of bytes somewhere")
say("    in memory, walked.")
say("")
say("    it is the piece written first because its failure is silence. An")
say("    address computed slightly wrong is not an error; it is a number,")
say("    which the arithmetic multiplies happily while the machine thinks")
say("    about nothing.")
say("")

os.exit(failed == 0 and 0 or 1)
-- }}}
