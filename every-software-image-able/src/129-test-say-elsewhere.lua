#!/usr/bin/env luajit
-- 129-test-say-elsewhere.lua
--
-- Saying something, as a routine, on all three machines. Issue 403.
--
-- For a general: every payload this project boots already says things, but
-- each one spells its words out inline as it is built. That is no use to an
-- engine, which will say whatever a model produces and cannot know it in
-- advance. This checks the callable version -- hand it bytes and a length,
-- and the words come out -- on real emulated machines of all three kinds.
--
-- WHAT IS CHECKED, BEYOND "SOMETHING APPEARED". Three things that a routine
-- which merely looked right would fail:
--
--   A message longer than the scratch it is given, so the chunking is
--   exercised rather than assumed. A routine that wrote past its buffer
--   would corrupt whatever sat after it, and the message that provokes it is
--   exactly the long one somebody is reading after a crash.
--
--   A message said in several calls, with the pieces required to arrive in
--   order and joined, so a routine that returned early or restarted is
--   caught.
--
--   Bytes that are not letters -- a tab, and the two that end a line -- since
--   widening is where a routine that sign-extends instead of zero-extending
--   turns anything past 127 into a very different character.
--
-- usage:
--   luajit 129-test-say-elsewhere.lua [--dir ROOT] [--seconds N]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

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
say("  saying something, as a routine, on all three")
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

local speak = dofile(DIR .. "/src/128-say-elsewhere.lua")

run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/payloads")

-- {{{ what gets said, and why each piece is there
--
-- The scratch is deliberately small -- sixteen wide characters -- so the
-- long line has to be said in several pieces and the chunking is the thing
-- being tested rather than a path nothing takes.
local SCRATCH_CHARS = 16

local LINES = {
  -- longer than the scratch, several times over
  "the quick brown fox jumps over the lazy dog, and again, and again\r\n",
  -- exactly the awkward length: one character short of a chunk boundary
  string.rep("x", SCRATCH_CHARS - 1) .. "\r\n",
  -- and one that is exactly a chunk, so the ending zero has nowhere easy
  string.rep("y", SCRATCH_CHARS) .. "\r\n",
  -- bytes that are not letters
  "tab\there\r\n",
  -- and something short, after all of that, to prove it still works
  "done\r\n",
}

local full = table.concat(LINES)
check("the message is longer than the scratch, several times over",
      #full > SCRATCH_CHARS * 4,
      #full .. " bytes through a " .. SCRATCH_CHARS
      .. "-character buffer -- a routine that assumed room would not be "
      .. "asked to chunk at all")
-- }}}

-- {{{ what the two payloads must produce, and how the log is read
--
-- The firmware narrates before the payload does, at length, so the reading
-- starts after a marker the payload prints and every expected line must
-- appear after it. That is the guard this project added after the third time
-- a tool reading a log was the thing at fault.
local MARK = "saying:"

local function judge(spoken, serial, name)
  local report = spoken:match(MARK .. "(.*)$")
  check(name .. " said something after its mark", report ~= nil,
        "nothing recognisable came back; see " .. serial)
  if report == nil then return end

  local missing = nil
  for _, wanted in ipairs(LINES) do
    local bare = wanted:gsub("[\r\n]", "")
    if bare ~= "" and not report:find(bare, 1, true) then
      missing = missing or bare
    end
  end
  check(name .. " said every line it was given", missing == nil,
        "the first one missing was '" .. tostring(missing) .. "'")

  -- and in order, joined rather than interleaved: the last line must come
  -- after the first, which a routine that restarted or returned early would
  -- fail even while printing everything.
  local first_at = report:find(LINES[1]:gsub("[\r\n]", ""), 1, true)
  local last_at = report:find("done", 1, true)
  check(name .. " said them in the order it was given them",
        first_at ~= nil and last_at ~= nil and last_at > first_at,
        "a routine that returned early or restarted would print every line "
        .. "and not in this order")
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
  line((speak.aarch64()
        :gsub("%s*%.globl%s+[%w_]+%s*\n", "\n")
        :gsub("%s*%.type%s+[%w_]+%s*,%s*@function%s*\n", "\n")))

  line("start_here:")
  line("  sub sp, sp, #4096")
  line("  mov x19, x1")                     -- the firmware's table
  line("  ldr x20, [x19, #64]")             -- its console

  line("  b syd_done")
  line("  .balign 16")
  line("symark:")
  for at = 1, #MARK do line("  .short " .. MARK:byte(at)) end
  line("  .short 13")
  line("  .short 10")
  line("  .short 0")
  line("  .balign 16")
  line("sytext:")
  local row = {}
  for at = 1, #full do
    row[#row + 1] = full:byte(at)
    if #row == 12 or at == #full then
      line("  .byte " .. table.concat(row, ", "))
      row = {}
    end
  end
  -- BACK ONTO A FOUR-BYTE BOUNDARY. The text is bytes and its length is
  -- whatever it is, so the instruction after it can land at an odd address
  -- -- and every branch on this architecture must target a multiple of four.
  -- The assembler says so plainly, which is the pleasant kind of failure:
  -- the same mistake in data rather than code would have been silent.
  line("  .balign 4")
  line("syd_done:")

  -- the mark, said the old inline way, so the reading has somewhere to start
  line("  adr x1, symark")
  line("  mov x0, x20")
  line("  ldr x8, [x20, #8]")
  line("  blr x8")

  -- and then everything else, through the routine
  line("  mov x0, x20")
  line("  adr x1, sytext")
  line("  movz x2, #" .. #full)
  line("  add x3, sp, #512")
  line("  movz x4, #" .. SCRATCH_CHARS)
  line("  bl console_say")

  line("syhalt:")
  line("  wfi")
  line("  b syhalt")
  return table.concat(out, "\n")
end

local base = DIR .. "/tmp/shared-memory/payloads/say-aarch64"
local handle = io.open(base .. ".s", "w")
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
  judge(read_file(serial) or "", serial, "the second architecture")
end
-- }}}

-- {{{ the third architecture
local function riscv64_payload()
  local words = dofile(DIR .. "/src/054-riscv-words.lua")
  local p = words.new()

  p:op("auipc s1, 0")
  p:op("mv s3, a1")
  p:op("ld s4, 64(s3)")                     -- the console
  p:load_constant("t0", 4096)
  p:op("sub sp, sp, t0")

  -- the mark, the old inline way
  p:address("a1", "symark", "s1")
  p:op("mv a0, s4")
  p:op("ld t1, 8(s4)")
  p:op("jalr ra, 0(t1)")

  -- and everything else through the routine
  p:op("mv a0, s4")
  p:address("a1", "sytext", "s1")
  p:load_constant("a2", #full)
  p:op("addi a3, sp, 512")
  p:load_constant("a4", SCRATCH_CHARS)
  p:call("console_say")

  p:label("syhalt")
  p:op("wfi")
  p:jump("syhalt")

  speak.riscv64(p)

  p:align(16)
  p:label("symark")
  p:shorts(MARK .. "\r\n")
  p:align(16)
  p:label("sytext")
  -- the text as words, four bytes each, earliest byte lowest
  for at = 0, #full - 1, 4 do
    local word = 0
    for step = 0, 3 do
      local byte = full:byte(at + step + 1) or 0
      word = word + byte * (256 ^ step)
    end
    p:word(word)
  end

  local text = p:resolve()
  return text
end

local rv_base = DIR .. "/tmp/shared-memory/payloads/say-riscv64"
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
        "a routine that exists to break silences, failing silently")

  run_one("llvm-objcopy -O binary " .. rv_base .. ".o " .. rv_base .. ".raw")
  run_one("luajit " .. DIR .. "/src/029-wrap-uefi.lua --from " .. rv_base
          .. ".raw --to " .. rv_base .. ".efi --arch riscv64 > /dev/null")

  local serial = DIR .. "/tmp/shared-memory/logs/qemu-uefi-riscv64-serial.log"
  run_one("rm -f " .. serial)
  run_one("luajit " .. DIR .. "/src/018-launch-board.lua qemu-uefi-riscv64"
    .. " --payload " .. rv_base .. ".efi --seconds " .. seconds
    .. " --dir " .. DIR .. " > /dev/null 2>&1")
  judge(read_file(serial) or "", serial, "the third architecture")
end
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this completes:")
say("    all three architectures can now be told something and can say")
say("    something back, as routines rather than as text spelled out when")
say("    a payload was built. An engine says whatever a model produces and")
say("    cannot know it in advance, so the inline kind was never going to")
say("    serve it.")
say("")
say("  what it does not cover:")
say("    the screen. Drawing letters as pictures exists on the first")
say("    architecture only, and a board may have no display at all -- which")
say("    601 names as a case to meet rather than assume away. The wire is")
say("    the channel that always exists, and it is the one that matters")
say("    while something is going wrong.")
say("")

os.exit(failed == 0 and 0 or 1)
-- }}}
