#!/usr/bin/env luajit
-- 063-measure-boards.lua
--
-- What the boards themselves can be measured for today: how long from power
-- to the machine finding its model, how long to the full memory report, and
-- how much of each board the engine and weights occupy. Issue 106's
-- board-side half; the native speed half is 051.
--
-- For a general: three emulated computers are switched on, and a stopwatch
-- runs until each one speaks. The numbers land in a data file as well as on
-- the screen, so a fourth board is a new row rather than a rewrite.
--
-- WHAT THESE TIMES ARE AND ARE NOT. An emulated machine is a board (see
-- phase 7), but its clock is not a real board's clock -- emulation speed is
-- one of the things the emulator lies about (705, when it exists). These
-- times say how the boot road FEELS in development and which board is
-- slowest relative to the others; a real board's numbers replace them the
-- day one is plugged in, in the same table.
--
-- usage:
--   luajit 063-measure-boards.lua [--dir ROOT] [--seconds N]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

local ffi = require("ffi")

ffi.cdef[[
  typedef long time_t;
  struct timespec { time_t tv_sec; long tv_nsec; };
  int clock_gettime(int clock, struct timespec *spec);
]]

-- {{{ local function now()
local spec = ffi.new("struct timespec[1]")
local function now()
  ffi.C.clock_gettime(1, spec)      -- the clock that only moves forward
  return tonumber(spec[0].tv_sec) + tonumber(spec[0].tv_nsec) / 1e9
end
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

-- {{{ local function find_board(name)
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
  error("063: no board named '" .. name .. "'")
end
-- }}}

-- {{{ main
local seconds = 120
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then
    index = index + 1 ; DIR = arg[index]
  elseif arg[index] == "--seconds" then
    index = index + 1 ; seconds = tonumber(arg[index]) or 120
  end
  index = index + 1
end

say("")
say("  from power to speech, per board")
say("  " .. string.rep("-", 66))
say("")

run_one("luajit " .. DIR .. "/src/019-build-payload.lua --dir " .. DIR
  .. " --payload blob-report > /dev/null")

local wording = dofile(DIR .. "/src/033-emit-blob-report.lua").WORDING

-- the boards measured, as data: adding one is adding a row.
local BOARDS = {
  { board = "qemu-uefi-x86-64",  arch = "x86_64"  },
  { board = "qemu-uefi-arm64",   arch = "aarch64" },
  { board = "qemu-uefi-riscv64", arch = "riscv64" },
}

local results = {}

for _, target in ipairs(BOARDS) do
  local description = find_board(target.board)
  local serial = DIR .. "/tmp/shared-memory/logs/" .. description.board_id .. "-serial.log"
  local payload = DIR .. "/tmp/shared-memory/payloads/blob-report-" .. target.arch .. ".efi"

  run_one("rm -f " .. serial)
  local started = now()
  run_one("luajit " .. DIR .. "/src/018-launch-board.lua " .. target.board
    .. " --payload " .. payload .. " --seconds " .. seconds
    .. " --dir " .. DIR .. " > /dev/null 2>&1 &")

  local found_at, report_at, spoken = nil, nil, nil
  for _ = 1, seconds * 2 do
    run_one("sleep 0.5")
    local text = read_file(serial)
    if text then
      if not found_at and text:find(wording.found, 1, true) then
        found_at = now() - started
      end
      if text:find(wording.rung, 1, true)
         and text:find("\n", text:find(wording.rung, 1, true), true) then
        report_at = now() - started
        spoken = text
        break
      end
    end
  end
  run_one("pkill -f " .. description.board_id .. "-serial.log")

  if not spoken then
    say(string.format("  %-9s said nothing within %d seconds", target.arch, seconds))
    results[#results + 1] = { arch = target.arch, board = description.board_id,
                              spoke = false }
  else
    local total = tonumber("0x" .. (spoken:match("total%s+(%x+)") or ""))
    local engine = tonumber("0x" .. (spoken:match("engine%s+(%x+)") or ""))
    local weights = tonumber("0x" .. (spoken:match("weights%s+(%x+)") or ""))
    local occupied = engine and weights and total and (engine + weights) / total

    say(string.format("  %-9s %5.1f s to find its model, %5.1f s to the full report",
                      target.arch, found_at or -1, report_at))
    if occupied then
      say(string.format("  %-9s engine and weights: %.2f%% of the memory the firmware reports",
                        "", occupied * 100))
    end
    say("")

    results[#results + 1] = {
      arch = target.arch, board = description.board_id, spoke = true,
      to_first_light = found_at, to_full_report = report_at,
      memory_total = total, engine_bytes = engine, weight_bytes = weights,
    }
  end
end

say("  these clocks are the emulator's, not a board's. They rank the roads")
say("  against each other and say what development costs; a real board's")
say("  numbers replace them in the same table the day one is plugged in.")
say("")

-- {{{ the results as data, so nothing has to be rewritten to add a board
run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/measurements")
local data = io.open(DIR .. "/tmp/shared-memory/measurements/boards.lua", "w")
if data then
  data:write("-- written by 063-measure-boards; read it back with dofile\n")
  data:write("return {\n")
  for _, row in ipairs(results) do
    data:write(string.format(
      "  { arch = %q, board = %q, spoke = %s, to_first_light = %s, "
      .. "to_full_report = %s, memory_total = %s, engine_bytes = %s, "
      .. "weight_bytes = %s },\n",
      row.arch, row.board, tostring(row.spoke),
      tostring(row.to_first_light), tostring(row.to_full_report),
      tostring(row.memory_total), tostring(row.engine_bytes),
      tostring(row.weight_bytes)))
  end
  data:write("}\n")
  data:close()
  say("  kept as data in tmp/shared-memory/measurements/boards.lua")
  say("")
end
-- }}}

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  local spoke = 0
  for _, row in ipairs(results) do if row.spoke then spoke = spoke + 1 end end
  goodbye:write("boards measured: " .. spoke .. " of " .. #results
                .. " spoke\ngoodbye\n")
  goodbye:close()
end
-- }}}
