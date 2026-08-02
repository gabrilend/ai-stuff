#!/usr/bin/env luajit
-- 055-test-blob-report.lua
--
-- Boots the blob-report payload on all three UEFI boards and holds what each
-- machine says against what the host works out from the same blob. Issue 102
-- proven whole: the weights found with no filesystem, the memory map read,
-- the image verified outside every usable range, and the ratchet computed by
-- two implementations that must agree.
--
-- For a general: a bare machine and a development machine are both asked the
-- same questions about the same model -- how big, how much room, which
-- arrangement can be afforded. If any answer differs, one of the two is
-- wrong, and it does not matter which: the seam between the builder's
-- arithmetic and the engine's is exactly where a machine fails at first
-- light with the least possible information, so it is checked here instead.
--
-- The machines run in the background and are stopped the moment they finish
-- speaking, so the test costs boot time rather than a fixed allowance.
--
-- usage:
--   luajit 055-test-blob-report.lua [--dir ROOT] [--seconds N]

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

-- {{{ local function ask(command)
-- one line from a helper that prints an answer.
local function ask(command)
  local pipe = io.popen(command)
  if not pipe then return nil end
  local answer = pipe:read("*l")
  pipe:close()
  return answer
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

-- {{{ reading the blob's header, from the same layout description the
-- packer, the reader and the payload all measure from
local function read_u32(blob, at)
  local a, b, c, d = blob:byte(at + 1, at + 4)
  return a + b * 256 + c * 65536 + d * 16777216
end

local function read_header(blob, format)
  local header, at = {}, 0
  for _, field in ipairs(format.HEADER) do
    if field.kind == "u32" then
      header[field.name] = read_u32(blob, at)
    elseif field.kind == "u64" then
      header[field.name] = read_u32(blob, at) + read_u32(blob, at + 4) * 4294967296
    end
    at = at + field.size
  end
  return header
end
-- }}}

-- {{{ local function memory_bytes(named)
-- "256M" as a number of bytes.
local function memory_bytes(named)
  local amount, unit = named:match("^(%d+)([MG])$")
  if not amount then
    error("055: cannot read a memory size of '" .. tostring(named) .. "'")
  end
  return tonumber(amount) * (unit == "G" and 2 ^ 30 or 2 ^ 20)
end
-- }}}

-- {{{ local function find_board(name)
-- the same rule 018 uses: a board is named by the part after "-board-" in
-- its filename.
local function find_board(name)
  local listing = io.popen("ls " .. DIR .. "/src")
  for entry in listing:lines() do
    local found = entry:match("^%d+%-board%-(.+)%.lua$")
    if found == name then
      listing:close()
      return dofile(DIR .. "/src/" .. entry)
    end
  end
  listing:close()
  error("055: no board named '" .. name .. "'")
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
say("  the machine's own arithmetic, against the host's")
say("  " .. string.rep("-", 58))
say("")

-- build the payloads first, so a build failure is not mistaken for a
-- machine misbehaving. This also packs the small model if it is missing.
local built = run_one("luajit " .. DIR .. "/src/019-build-payload.lua --dir " .. DIR
  .. " --payload blob-report > /dev/null")
if not built then
  say("  could not build the payloads at all")
  os.exit(1)
end

local format = dofile(DIR .. "/src/024-blob-format.lua")
local budget = dofile(DIR .. "/src/045-memory-budget.lua")
local wording = dofile(DIR .. "/src/033-emit-blob-report.lua").WORDING

local blob = read_file(DIR .. "/tmp/shared-memory/blob-test/small-model.blob")
if not blob then
  say("  the small model is nowhere to be found")
  os.exit(1)
end
local header = read_header(blob, format)
local shape = {
  layers = header.layers, hidden = header.hidden, heads = header.heads,
  head_width = header.head_width, kv_heads = header.kv_heads,
  feedforward = header.feedforward, vocabulary = header.vocabulary,
  context = header.context,
}

-- how the wrapper lays an image out, asked rather than copied.
local blob_offset = tonumber(ask("luajit " .. DIR .. "/src/029-wrap-uefi.lua --blob-offset"))
local text_rva = tonumber(ask("luajit " .. DIR .. "/src/029-wrap-uefi.lua --text-rva"))
if not blob_offset or not text_rva then
  say("  the wrapper would not describe its own layout")
  os.exit(1)
end
local engine_expected = text_rva + blob_offset

local BOARDS = {
  { board = "qemu-uefi-x86-64",  arch = "x86_64"  },
  { board = "qemu-uefi-arm64",   arch = "aarch64" },
  { board = "qemu-uefi-riscv64", arch = "riscv64" },
}

local passed, failed = 0, 0
local function check(name, ok)
  if ok then passed = passed + 1 else failed = failed + 1 end
  say(string.format("  %-51s %s", name, ok and "ok" or "WRONG"))
end

for _, target in ipairs(BOARDS) do
  local description = find_board(target.board)
  local serial = DIR .. "/tmp/shared-memory/logs/" .. description.board_id .. "-serial.log"
  local payload = DIR .. "/tmp/shared-memory/payloads/blob-report-" .. target.arch .. ".efi"
  local launch_log = DIR .. "/tmp/shared-memory/logs/055-launch-" .. target.arch .. ".log"

  say("  " .. target.arch)

  run_one("rm -f " .. serial)
  run_one("luajit " .. DIR .. "/src/018-launch-board.lua " .. target.board
    .. " --payload " .. payload .. " --seconds " .. seconds
    .. " --dir " .. DIR .. " > " .. launch_log .. " 2>&1 &")

  -- wait for the machine to finish speaking rather than for a fixed
  -- allowance: the last thing the payload prints is the rung line.
  local spoken = nil
  for _ = 1, seconds do
    run_one("sleep 1")
    local text = read_file(serial)
    if text and (text:find(wording.rung, 1, true) and text:find("\n", text:find(wording.rung, 1, true), true)
                 or text:find(wording.map_failed, 1, true)) then
      spoken = text
      break
    end
  end
  -- the serial log path is unique to this board, so it names the emulator
  -- without naming every emulator the user may be running.
  run_one("pkill -f " .. description.board_id .. "-serial.log")

  if not spoken then
    check("the machine spoke at all", false)
    say("        nothing readable arrived; launch details in " .. launch_log)
    say("")
  else
    -- {{{ what the machine said
    local heard = {}
    for _, name in ipairs({ "total", "engine", "weights", "free", "cache", "working" }) do
      local value = spoken:match(name .. "%s+(%x+)\r?\n")
      heard[name] = value and tonumber("0x" .. value) or nil
    end
    local rung = spoken:match("rung:%s+([^\r\n]+)")
    local outside = spoken:match("outside every usable range:%s+(%a+)")

    local fields_spoken = true
    for _, entry in ipairs({
      { "magic",      "41495345" },
      { "layers",     string.format("%08x", header.layers) },
      { "hidden",     string.format("%08x", header.hidden) },
      { "heads",      string.format("%08x", header.heads) },
      { "vocabulary", string.format("%08x", header.vocabulary) },
      { "context",    string.format("%08x", header.context) },
      { "tensors",    string.format("%08x", header.tensor_count) },
      { "bytes",      string.format("%08x", header.blob_bytes) },
    }) do
      if not spoken:find(entry[1] .. "%s+" .. entry[2]) then fields_spoken = false end
    end
    -- }}}

    -- {{{ held against the host's arithmetic
    check("finds the model and reads its header correctly", fields_spoken)
    check("knows its own size", heard.engine == engine_expected)
    check("knows the weight of what it carries", heard.weights == header.blob_bytes)
    check("its accounts balance",
          heard.total ~= nil and heard.free ~= nil
          and heard.total == heard.free + heard.engine + heard.weights)
    check("the free memory is a believable amount",
          heard.free ~= nil and heard.free > 0
          and heard.free < memory_bytes(description.memory_sizes.small))
    check("its body sits outside every usable range", outside == wording.outside_ok)
    check("the cache cost matches the host's",
          heard.cache == budget.cache(shape, header.context, 4))
    check("the working cost matches the host's",
          heard.working == budget.working(shape, 4))

    local host_rung = budget.strategy({
      shape = shape,
      weights_bytes = header.blob_bytes,
      engine_bytes = heard.engine or 0,
      context = header.context,
    }, (heard.free or 0) + (heard.engine or 0))
    check("both implementations choose the same rung",
          rung ~= nil and rung == host_rung)
    -- }}}
    say("")
  end
end

say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this does not prove:")
say("    - that the strategy chosen is the right one for a real model.")
say("      The small blob fits everywhere, so only the first rung is")
say("      exercised on these boards; the other rungs are held to the")
say("      host arithmetic by 046, and to nothing else yet.")
say("    - anything about what the machine does with the answer. Nothing")
say("      is copied or read in place yet; the ratchet is computed and")
say("      spoken, not acted on.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local handle = io.open(DIR .. "/output/goodbye", "w")
if handle then
  handle:write("blob report: " .. passed .. " of " .. (passed + failed)
               .. " as expected\ngoodbye\n")
  handle:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
