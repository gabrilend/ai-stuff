#!/usr/bin/env luajit
-- 134-test-lay-out.lua
--
-- Dividing a run of memory into everything a thought needs, on all three
-- machines, with no allocator. Issue 107.
--
-- For a general: this checks that three processors given the same model and
-- the same room put every working vector in the same place -- and that each
-- refuses, with a number, when the room is not enough.
--
-- THE PROPERTY THAT MATTERS MOST IS NOT AGREEMENT. It is that no two regions
-- overlap. Two that do would not fault: attention writes over the cache, the
-- cache reads back what attention left, and the machine thinks something
-- unrelated while reporting nothing. So the regions are checked against each
-- other directly, in addition to being checked against the host's answer.
--
-- usage:
--   luajit 134-test-lay-out.lua [--dir ROOT] [--seconds N]

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
say("  dividing the memory, on all three machines")
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

local layout = dofile(DIR .. "/src/133-lay-out-memory.lua")
local format = dofile(DIR .. "/src/024-blob-format.lua")

run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/payloads")
run_one("mkdir -p " .. DIR .. "/tmp/kernels")

-- {{{ a real model, and what the host says its layout should be
local blob_path = DIR .. "/tmp/shared-memory/fixture/fixture-model.blob"
local blob = read_file(blob_path)
if not blob then
  run_one("luajit " .. DIR .. "/src/036-make-fixture.lua --dir " .. DIR
          .. " > /dev/null")
  blob = read_file(blob_path)
end
if not blob then
  say("  no fixture model, and it would not build")
  os.exit(1)
end

local header_at = layout.header_offsets(format)
local function u32(at)
  local a, b, c, d = blob:byte(at + 1, at + 4)
  return a + b * 256 + c * 65536 + d * 16777216
end
local shape = {
  layers = u32(header_at.layers), hidden = u32(header_at.hidden),
  heads = u32(header_at.heads), head_width = u32(header_at.head_width),
  kv_heads = u32(header_at.kv_heads),
  feedforward = u32(header_at.feedforward),
  vocabulary = u32(header_at.vocabulary), context = u32(header_at.context),
}

local places, needed = layout.expected(shape)
check("the host works out a layout to be held to", needed > 0,
      needed .. " bytes for a model of " .. shape.layers .. " layers of "
      .. shape.hidden)

-- NO TWO REGIONS OVERLAP, and this is checked of the host's own answer
-- before it is used as the standard. A wrong expectation would otherwise be
-- what three machines are held to, and three machines agreeing about a wrong
-- layout is the worst outcome available here.
local ordered = {}
for _, region in ipairs(layout.REGIONS) do
  ordered[#ordered + 1] = {
    name = region.name, at = places[region.name],
    bytes = region.numbers(shape) * 4,
  }
end
table.sort(ordered, function(a, b) return a.at < b.at end)

local separate, overlap = true, nil
for place = 2, #ordered do
  local before = ordered[place - 1]
  if before.at + before.bytes > ordered[place].at then
    separate = false
    overlap = overlap or string.format(
      "%s runs to %d and %s begins at %d",
      before.name, before.at + before.bytes,
      ordered[place].name, ordered[place].at)
  end
end
check("and no two regions of it overlap", separate, overlap)

local aligned, misaligned = true, nil
for _, region in ipairs(ordered) do
  if region.at % 16 ~= 0 then
    aligned = false
    misaligned = misaligned or (region.name .. " begins at " .. region.at)
  end
end
check("and every one begins on a sixteen-byte boundary", aligned, misaligned)
-- }}}

-- {{{ the first architecture, in this process
local source = DIR .. "/tmp/shared-memory/payloads/layout-x86_64.s"
local library = DIR .. "/tmp/kernels/layout-x86_64.so"
local handle = io.open(source, "w")
handle:write(layout.x86_64(format))
handle:write('  .section .note.GNU-stack,"",@progbits\n')
handle:close()

if not run_one("clang -shared -o " .. library .. " " .. source) then
  say("  the first architecture's routine would not build")
  os.exit(1)
end

ffi.cdef[[
  int64_t lay_out(const uint8_t *blob, void *room, int64_t bytes, void **out);
]]
local laid = ffi.load(library)

local blob_bytes = ffi.new("uint8_t[?]", #blob)
ffi.copy(blob_bytes, blob, #blob)
local room = ffi.new("uint8_t[?]", needed + 4096)
local addresses = ffi.new("void *[?]", #layout.REGIONS)

local used = tonumber(laid.lay_out(blob_bytes, room, needed + 4096, addresses))
check("the first architecture used what the host expected",
      used == needed, tostring(used) .. " against " .. needed)

local base = ffi.cast("uintptr_t", room)
local same, where = true, nil
for place, region in ipairs(layout.REGIONS) do
  local offset = tonumber(ffi.cast("uintptr_t", addresses[place - 1]) - base)
  if offset ~= places[region.name] then
    same = false
    where = where or string.format("%s at %d, and the host says %d",
                                   region.name, offset, places[region.name])
  end
end
check("and put every region where the host put it", same, where)

-- THE REFUSAL, and the number it comes back with. A machine that cannot fit
-- its own model is exactly the case where the size of the shortfall is the
-- whole of the diagnosis.
local short_by = 4096
local refused = tonumber(laid.lay_out(blob_bytes, room, needed - short_by,
                                      addresses))
check("and refuses room that is not enough, with the shortfall",
      refused == -short_by,
      tostring(refused) .. " where minus " .. short_by .. " was expected")

check("and accepts room that is exactly enough",
      tonumber(laid.lay_out(blob_bytes, room, needed, addresses)) == needed,
      "an off-by-one at the boundary would refuse a machine that fits")
-- }}}

-- {{{ what the other two are given
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
for _, region in ipairs(layout.REGIONS) do
  local at = places[region.name]
  want_words[#want_words + 1] = at % 4294967296
  want_words[#want_words + 1] = math.floor(at / 4294967296)
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
  line((layout.aarch64(format)
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
    local skip, label = "loskip" .. said, "lotext" .. said
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
    local loop, digit, done = "loh" .. said, "lod" .. said, "loe" .. said
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

  say_text("\r\ndividing the memory, second tongue\r\n")

  line("  b lodata_done")
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
  lay("loblob", blob_words)
  lay("lowant", want_words)
  line("lodata_done:")

  -- a made-up run of memory: somewhere in the payload's own stack, far
  -- enough down that nothing else is using it
  line("  adr x0, loblob")
  line("  add x1, x21, #4096")              -- the room
  line("  movz x2, #" .. (needed + 4096))
  line("  add x3, x21, #1024")              -- where the addresses go
  line("  bl lay_out")
  line("  mov x24, x0")                     -- how much it used

  line("  movz x9, #" .. needed)
  line("  add x23, x23, #1")
  line("  cmp x24, x9")
  line("  b.ne lousedno")
  line("  add x22, x22, #1")
  line("lousedno:")

  -- each address, turned back into an offset from the room's start
  line("  add x25, x21, #4096")
  line("  add x5, x21, #1024")
  line("  adr x6, lowant")
  line("  movz x7, #" .. #layout.REGIONS)
  line("locmp:")
  line("  ldr x8, [x5], #8")
  line("  sub x8, x8, x25")
  line("  ldr x9, [x6], #8")
  line("  add x23, x23, #1")
  line("  cmp x8, x9")
  line("  b.ne locmpno")
  line("  add x22, x22, #1")
  line("locmpno:")
  line("  subs x7, x7, #1")
  line("  b.ne locmp")

  -- and the refusal
  line("  adr x0, loblob")
  line("  add x1, x21, #4096")
  line("  movz x2, #" .. (needed - 4096))
  line("  add x3, x21, #1024")
  line("  bl lay_out")
  line("  mov x26, x0")

  say_text("memory divided\r\n  matched ")
  say_hex("x22")
  say_text("\r\n  of ")
  say_hex("x23")
  say_text("\r\n  shortfall ")
  say_hex("x26")
  say_text("\r\n")

  line("lohalt:")
  line("  wfi")
  line("  b lohalt")
  return table.concat(out, "\n")
end

local arm_base = DIR .. "/tmp/shared-memory/payloads/layout-aarch64"
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
  local report = spoken:match("memory divided(.*)$") or ""
  local function after(mark)
    return tonumber(report:match("[\r\n]%s*" .. mark .. "%s+(%x+)") or "", 16)
  end
  local matched, of, shortfall = after("matched"), after("of"), after("shortfall")

  check("and divides it exactly as the host did",
        matched ~= nil and of ~= nil and matched == of and of > 0,
        tostring(matched) .. " of " .. tostring(of) .. "; see " .. serial)
  check("and refuses room that is short, by the right amount",
        shortfall == (0x10000000000000000 - 4096),
        "it said " .. (shortfall and string.format("%x", shortfall) or "nothing")
        .. " where minus four thousand and ninety-six was expected")
end
-- }}}

-- {{{ the third architecture
local function riscv64_payload()
  local words = dofile(DIR .. "/src/054-riscv-words.lua")
  local p = words.new()

  local strings, string_order = {}, {}
  local function pooled(text)
    if not strings[text] then
      strings[text] = "lostring" .. (#string_order + 1)
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
    local loop = "lohex" .. converted
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
  p:op("mv s5, zero")
  p:op("mv s6, zero")

  say_text("\r\ndividing the memory, third tongue\r\n")

  p:address("a0", "loblob", "s1")
  p:load_constant("a1", 4096)
  p:op("add a1, s2, a1")
  p:load_constant("a2", needed + 4096)
  p:load_constant("a3", 1024)
  p:op("add a3, s2, a3")
  p:call("lay_out")
  p:op("mv s7, a0")

  p:load_constant("t0", needed)
  p:op("addi s6, s6, 1")
  p:branch("bne", "s7", "t0", "lousedno")
  p:op("addi s5, s5, 1")
  p:label("lousedno")

  p:load_constant("s8", 4096)
  p:op("add s8, s2, s8")                    -- where the room begins
  p:load_constant("t0", 1024)
  p:op("add t0, s2, t0")
  p:address("t1", "lowant", "s1")
  p:load_constant("t2", #layout.REGIONS)
  p:label("locmp")
  p:op("ld t3, 0(t0)")
  p:op("sub t3, t3, s8")
  p:op("ld t4, 0(t1)")
  p:op("addi s6, s6, 1")
  p:branch("bne", "t3", "t4", "locmpno")
  p:op("addi s5, s5, 1")
  p:label("locmpno")
  p:op("addi t0, t0, 8")
  p:op("addi t1, t1, 8")
  p:op("addi t2, t2, -1")
  p:branch("bne", "t2", "zero", "locmp")

  p:address("a0", "loblob", "s1")
  p:load_constant("a1", 4096)
  p:op("add a1, s2, a1")
  p:load_constant("a2", needed - 4096)
  p:load_constant("a3", 1024)
  p:op("add a3, s2, a3")
  p:call("lay_out")
  p:op("mv s9, a0")

  say_text("memory divided\r\n  matched ")
  say_hex("s5")
  say_text("\r\n  of ")
  say_hex("s6")
  say_text("\r\n  shortfall ")
  say_hex("s9")
  say_text("\r\n")

  p:label("lohalt")
  p:op("wfi")
  p:jump("lohalt")

  layout.riscv64(p, format)

  for _, pair in ipairs({ { "loblob", blob_words }, { "lowant", want_words } }) do
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

local rv_base = DIR .. "/tmp/shared-memory/payloads/layout-riscv64"
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
  local report = spoken:match("memory divided(.*)$") or ""
  local function after(mark)
    return tonumber(report:match("[\r\n]%s*" .. mark .. "%s+(%x+)") or "", 16)
  end
  local matched, of, shortfall = after("matched"), after("of"), after("shortfall")

  check("and divides it exactly as the host did",
        matched ~= nil and of ~= nil and matched == of and of > 0,
        tostring(matched) .. " of " .. tostring(of) .. "; see " .. serial)
  check("and refuses room that is short, by the right amount",
        shortfall == (0x10000000000000000 - 4096),
        "it said " .. (shortfall and string.format("%x", shortfall) or "nothing")
        .. " where minus four thousand and ninety-six was expected")
end
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this is the second piece of:")
say("    the driver. With the first, a machine can now find its own weights")
say("    and work out where everything a thought needs will sit -- both with")
say("    nothing underneath them. What remains is filling the plan the")
say("    conducting reads, and the loop itself.")
say("")

os.exit(failed == 0 and 0 or 1)
-- }}}
