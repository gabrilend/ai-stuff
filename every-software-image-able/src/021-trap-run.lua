#!/usr/bin/env luajit
-- 021-trap-run.lua
--
-- Arms the forbidden registers as landmines and runs a machine over them.
-- If the machine writes where issue 003a says it must never write, everything
-- stops and the record names the device, the register, the value and where
-- the machine was standing.
--
-- For a general: this puts tripwires on the controls that would destroy real
-- hardware, then lets a computer run. If it trips one we find out exactly
-- which, and it never gets to do it twice.
--
-- THE HALT IS INVISIBLE TO THE MACHINE. The watchpoints live in a debugger
-- attached from outside; the guest is not interrupted, does not receive an
-- exception, and cannot notice. This is the whole point. A trap the machine
-- could see would teach it that touching a fatal register produces immediate
-- survivable feedback -- the opposite of what real hardware teaches, where
-- there is no feedback at all and the part is simply gone. A machine trained
-- against visible traps would learn to explore by trial, and the trial that
-- matters happens once.
--
-- A trap is an assertion about US -- did the instruction and the discipline
-- hold? -- not a signal in the machine's world. If one fires, something
-- upstream is wrong.
--
-- usage:
--   luajit 021-trap-run.lua <board> --payload FILE [--mode halt|count]
--                           [--seconds N] [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

-- {{{ local function say(text)
local function say(text)
  io.write(text, "\n")
end
-- }}}

-- {{{ local function die(text)
local function die(text)
  io.stderr:write("021-trap-run: ", text, "\n")
  os.exit(1)
end
-- }}}

-- {{{ local function run_one(command)
local function run_one(command)
  local ok, _, code = os.execute(command)
  return ok == true or ok == 0, code
end
-- }}}

-- {{{ local function read_file(path)
local function read_file(path)
  local handle = io.open(path, "r")
  if not handle then return nil end
  local text = handle:read("*a")
  handle:close()
  return text
end
-- }}}

-- {{{ local function file_exists(path)
local function file_exists(path)
  local handle = io.open(path, "r")
  if handle then handle:close() return true end
  return false
end
-- }}}

-- {{{ gdb_architecture -- what the debugger must be told it is looking at
--
-- The debugger has to be told, because it is attaching to a bare machine with
-- no program headers to read the answer from -- there is no executable here,
-- only a processor mid-thought.
local gdb_architecture = {
  -- Not i8086, even though the probe is a boot sector running in 16-bit real
  -- mode: the emulated processor is a 64-bit one that happens to be in that
  -- mode, and it reports itself as such. Telling the debugger otherwise makes
  -- it reject the target and connect to nothing -- which armed no watchpoints
  -- and then reported a clean run. The mode the code is in and the processor
  -- the code is on are different questions.
  x86_64  = "i386:x86-64",
  aarch64 = "aarch64",
  riscv64 = "riscv:rv64",
}
-- }}}

-- {{{ local function find_board(name)
local function find_board(name)
  if file_exists(name) then return dofile(name), name end
  local listing = io.popen("ls " .. DIR .. "/src")
  if not listing then die("cannot list " .. DIR .. "/src") end
  for entry in listing:lines() do
    local found = entry:match("^%d+%-board%-(.+)%.lua$")
    if found == name then
      listing:close()
      return dofile(DIR .. "/src/" .. entry), entry
    end
  end
  listing:close()
  die("no board named '" .. name .. "'")
end
-- }}}

-- {{{ local function write_gdb_script(board, hazards, options, paths)
local function write_gdb_script(board, hazards, options, paths)
  local lines = {
    "set pagination off",
    "set confirm off",
    "set architecture " .. (gdb_architecture[board.arch] or die("no debugger architecture for " .. board.arch)),
    "target remote :" .. options.port,
  }

  -- One watchpoint per hazard. Write-only: reading a forbidden register is
  -- legal and is exactly how a description gets confirmed (issue 302), so
  -- trapping reads would forbid the safe half of the discipline.
  for _, hazard in ipairs(hazards) do
    lines[#lines + 1] = "watch *(unsigned int *) " .. string.format("0x%x", hazard.address)
  end

  -- Two modes. halt-on-first freezes the machine at the mistake, for
  -- debugging. count-and-continue keeps going so a whole run reports how many
  -- violations it produced rather than what its first one was.
  if options.mode == "halt" then
    lines[#lines + 1] = "continue"
    lines[#lines + 1] = "echo \\n=== TRAP FIRED ===\\n"
    lines[#lines + 1] = "info registers pc"
    lines[#lines + 1] = "kill"
  else
    -- a fixed number of resumptions rather than a loop: gdb batch scripts
    -- have no conditionals worth trusting, and a bounded count cannot hang.
    for _ = 1, options.resumptions do
      lines[#lines + 1] = "continue"
      lines[#lines + 1] = "echo \\n=== TRAP FIRED ===\\n"
    end
    lines[#lines + 1] = "kill"
  end
  lines[#lines + 1] = "quit"

  local handle = io.open(paths.gdb_script, "w")
  if not handle then die("cannot write " .. paths.gdb_script) end
  handle:write(table.concat(lines, "\n"), "\n")
  handle:close()
end
-- }}}

-- {{{ local function parse_hits(transcript, hazards)
local function parse_hits(transcript, hazards)
  -- The debugger prints the same "Hardware watchpoint N: <expr>" line twice:
  -- once when arming, once when firing. Only the firing is followed by an
  -- "Old value" line, so that is what distinguishes them -- matching on the
  -- address alone finds the arming line and names the wrong register, which
  -- is exactly the bug this comment exists to stop somebody reintroducing.
  local hits = {}
  local pattern = "Hardware watchpoint %d+: %*%(unsigned int %*%) (0x%x+)%s*\n"
    .. "%s*\nOld value = (%S+)%s*\nNew value = (%S+)%s*\n(0x%x+)"

  for address, old, new, pc in transcript:gmatch(pattern) do
    local numeric = tonumber(address)
    local named
    for _, hazard in ipairs(hazards) do
      if hazard.address == numeric then named = hazard end
    end
    hits[#hits + 1] = {
      hazard = named,
      address = address,
      old_value = old,
      new_value = new,
      pc = pc,
    }
  end
  return hits
end
-- }}}

-- {{{ local function count_armed(transcript)
local function count_armed(transcript)
  -- How many watchpoints the debugger actually set. This exists because a
  -- run that armed nothing produces exactly the same silence as a run that
  -- armed everything and caught nothing -- and calling the first one "clean"
  -- is the worst answer this tool could give. Issue 702a: report zero as a
  -- result rather than as silence.
  local count = 0
  for _ in transcript:gmatch("Hardware watchpoint %d+: %*") do count = count + 1 end
  -- each watchpoint is announced once when armed and again when it fires, so
  -- subtract the firings to get the arming count.
  local fired = 0
  for _ in transcript:gmatch("New value") do fired = fired + 1 end
  return count - fired
end
-- }}}

-- {{{ local function machine_ended(transcript)
local function machine_ended(transcript)
  -- A write that really does end the machine cannot be reported by a
  -- watchpoint, because the channel the report would travel down dies with
  -- the machine. The debugger sees a broken pipe and nothing else.
  --
  -- This is not a flaw in the traps. It is issue 003a's honestly-hard problem
  -- arriving early: from outside, a machine destroyed by a write and a
  -- machine that merely went away look identical. The serial log is the only
  -- witness -- which is why a hazard probe says what it is about to do BEFORE
  -- doing it, so the last line before silence is the confession.
  return transcript:find("Target disconnected", 1, true) ~= nil
      or transcript:find("Broken pipe", 1, true) ~= nil
end
-- }}}

-- {{{ local function last_intent(serial)
local function last_intent(serial)
  local intent
  for line in serial:gmatch("[^\n]+") do
    local named = line:match("^about to write (.+)$")
    if named then intent = named end
  end
  return intent
end
-- }}}

-- {{{ main
local options = { board = nil, payload = nil, mode = "halt",
                  seconds = 15, port = 1234, resumptions = 8 }
local index = 1
while index <= #arg do
  local word = arg[index]
  if word == "--dir" then
    index = index + 1 ; DIR = arg[index] or die("missing value after --dir")
  elseif word == "--payload" then
    index = index + 1 ; options.payload = arg[index] or die("missing value after --payload")
  elseif word == "--mode" then
    index = index + 1 ; options.mode = arg[index] or die("missing value after --mode")
  elseif word == "--seconds" then
    index = index + 1 ; options.seconds = tonumber(arg[index]) or die("--seconds wants a number")
  elseif word:sub(1, 2) == "--" then
    die("unknown option: " .. word)
  elseif options.board == nil then
    options.board = word
  else
    die("more than one board named")
  end
  index = index + 1
end

if not options.board then die("no board named") end
if not options.payload then die("no payload given; there is nothing to run") end
if not file_exists(options.payload) then die("payload does not exist: " .. options.payload) end
if options.mode ~= "halt" and options.mode ~= "count" then
  die("--mode must be halt or count")
end

local board = find_board(options.board)
local forbidden = dofile(DIR .. "/src/020-forbidden-registers.lua")
local hazards = forbidden.all(board.arch)
local mechanisms = forbidden.mechanism
if #hazards == 0 then die("no forbidden registers described for " .. board.arch) end

run_one("mkdir -p /tmp/every-software-image-able")
run_one("mkdir -p /dev/shm/every-software-image-able")
run_one("ln -sfn /tmp/every-software-image-able " .. DIR .. "/tmp")
run_one("ln -sfn /dev/shm/every-software-image-able /tmp/every-software-image-able/shared-memory")
local work = DIR .. "/tmp/shared-memory/traps"
run_one("mkdir -p " .. work)

local paths = {
  gdb_script = work .. "/" .. board.board_id .. ".gdb",
  transcript = work .. "/" .. board.board_id .. "-debugger.log",
  serial     = work .. "/" .. board.board_id .. "-serial.log",
}

write_gdb_script(board, hazards, options, paths)

-- The machine is started frozen and waiting for the debugger. Launching it in
-- the background and attaching from this process is what keeps the halt
-- outside the guest: the emulator stops, the guest is never told.
local launch = "timeout " .. options.seconds .. " luajit " .. DIR .. "/src/018-launch-board.lua "
  .. options.board .. " --payload " .. options.payload .. " --gdb --dir " .. DIR
  .. " > " .. work .. "/launcher.log 2>&1 &"
run_one(launch)

-- give the emulator a moment to open its debug port before knocking.
run_one("sleep 1")

local debugger = "timeout " .. options.seconds .. " gdb --batch --command=" .. paths.gdb_script
  .. " > " .. paths.transcript .. " 2>&1"
run_one(debugger)

run_one("pkill -f 'qemu-system.*gdb tcp::" .. options.port .. "'")

local transcript = read_file(paths.transcript) or ""
local serial = read_file(DIR .. "/tmp/shared-memory/logs/" .. board.board_id .. "-serial.log") or ""
run_one("cp " .. DIR .. "/tmp/shared-memory/logs/" .. board.board_id .. "-serial.log "
        .. paths.serial .. " 2>/dev/null || true")

local hits = parse_hits(transcript, hazards)
local ended = machine_ended(transcript)
local intent = last_intent(serial)
local armed = count_armed(transcript)

say("board:    " .. board.board_id)
say("payload:  " .. options.payload)
say("described:" .. " " .. #hazards .. " forbidden registers")
say("armed:    " .. armed)
say("mode:     " .. options.mode)
say("")

-- Report zero out loud. A trap that was never armed and a trap that never
-- fired look identical in a log that only records failures, and calling the
-- first one clean is the worst answer this tool could give.
if armed < #hazards then
  say("RESULT:   INCONCLUSIVE -- only " .. armed .. " of " .. #hazards
      .. " watchpoints were armed")
  say("          Nothing can be concluded about this machine's behaviour.")
  say("          Look at the debugger transcript: the connection is the")
  say("          usual reason, and a rejected architecture is the usual")
  say("          reason for that.")

elseif serial == "" then
  -- a machine that said nothing may never have run at all. Silence from a
  -- payload built to speak is not evidence of good behaviour.
  say("RESULT:   INCONCLUSIVE -- the traps were armed and the machine said")
  say("          nothing. Every payload here speaks before it acts, so")
  say("          silence means it probably never ran.")

elseif #hits == 0 and not ended then
  say("RESULT:   clean -- the machine ran, and wrote no forbidden register")

elseif #hits == 0 and ended then
  -- the case the traps cannot catch, reported as itself rather than as a
  -- clean run, which is what it would otherwise be mistaken for.
  say("RESULT:   the machine ended without the traps reporting")
  if intent then
    say("          last thing it said it was about to do:")
    say("            " .. intent)
    say("          a write that ends the machine takes the debugger")
    say("          connection with it, so no watchpoint can report it.")
    say("          The console is the only witness.")
  else
    say("          and it never said what it was about to do")
  end

else
  say("RESULT:   " .. #hits .. " forbidden write" .. (#hits == 1 and "" or "s"))
  for _, hit in ipairs(hits) do
    say("")
    if hit.hazard then
      say("          " .. hit.hazard.name)
      say("          category:   " .. hit.hazard.category)
      say("          mechanism:  " .. (mechanisms[hit.hazard.category] or "unrecorded"))
    else
      say("          an armed address with no hazard on record")
    end
    say("          address:    " .. hit.address)
    say("          wrote:      " .. hit.new_value .. " (was " .. hit.old_value .. ")")
    say("          from:       " .. hit.pc)
  end
  if ended then
    say("")
    say("          ...and then the machine ended.")
  end
end

say("")
say("what the machine said before it stopped:")
if serial == "" then
  say("  | (nothing)")
else
  for line in serial:gmatch("[^\n]+") do say("  | " .. line) end
end
say("")
say("debugger transcript: " .. paths.transcript)

-- the last thing a program does is write to output/, specifically goodbye.
run_one("mkdir -p " .. DIR .. "/output")
local handle = io.open(DIR .. "/output/goodbye", "w")
if handle then
  handle:write("trap run on " .. board.board_id .. ": "
               .. #hits .. " forbidden writes"
               .. (ended and ", machine ended" or "") .. "\ngoodbye\n")
  handle:close()
end

-- zero only for a run that proved something and proved it good. Inconclusive
-- is a failure here, not a shrug: a test that cannot tell you whether the
-- discipline held has not tested the discipline.
local conclusive = armed >= #hazards and serial ~= ""
os.exit((conclusive and #hits == 0 and not ended) and 0 or 1)
-- }}}
