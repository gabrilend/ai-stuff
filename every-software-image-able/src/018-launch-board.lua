#!/usr/bin/env luajit
-- 018-launch-board.lua
--
-- Boots a described board in its emulator. The board description says what
-- the machine is; this script turns that into an emulator command and runs
-- it. Nobody writes a qemu command line by hand -- an emulated machine is a
-- board like any other, and the command is generated from its description
-- the same way the image builder will generate layouts from real ones.
--
-- For a general: point it at a board, give it something to boot, and it
-- starts that computer. The computer's serial wire lands in a log file in
-- RAM, or in your terminal if you ask -- and its screen appears in a window,
-- if you ask for that too.
--
-- usage:
--   luajit 018-launch-board.lua <board> [--payload FILE] [--disk FILE]
--                               [--memory small|plenty|SIZE] [--seconds N]
--                               [--stdio] [--gdb] [--accel] [--dry-run]
--                               [--watch [gtk|sdl|curses]] [--medium FILE]
--                               [--dir PROJECT_ROOT]
--
--   <board> is the short name from a src/*-board-<name>.lua file,
--   e.g. qemu-x86-64, qemu-arm64, qemu-riscv64 -- or a path to one.

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
  -- errors beat fallbacks: when something is wrong, stop and name it.
  io.stderr:write("018-launch-board: ", text, "\n")
  os.exit(1)
end
-- }}}

-- {{{ local function file_exists(path)
local function file_exists(path)
  local handle = io.open(path, "r")
  if handle then
    handle:close()
    return true
  end
  return false
end
-- }}}

-- {{{ local function run_one(command)
local function run_one(command)
  -- every shell command runs alone: one command, no chains, no pipes,
  -- so it can be understood where what is going when and why.
  local ok, _, code = os.execute(command)
  return ok == true or ok == 0, code
end
-- }}}

-- {{{ local function parse_arguments(argv)
local function parse_arguments(argv)
  local options = { board = nil, payload = nil, disk = nil, medium = nil,
                    memory = "small", seconds = nil,
                    screenshot = nil, capture_after = 3, monitor_port = 4444,
                    stdio = false, gdb = false, accel = false,
                    watch = nil, dry_run = false }
  -- one handler per flag: a dispatch table rather than an if-chain.
  local takes_value = {
    ["--payload"] = "payload", ["--disk"] = "disk",
    ["--memory"] = "memory", ["--seconds"] = "seconds", ["--cpu"] = "cpu",
    ["--screenshot"] = "screenshot", ["--capture-after"] = "capture_after",
    ["--medium"] = "medium",
    ["--dir"] = "dir",
  }
  local is_switch = {
    ["--stdio"] = "stdio", ["--gdb"] = "gdb",
    ["--accel"] = "accel", ["--dry-run"] = "dry_run",
  }
  -- --watch is the one option whose value is optional, so it sits in neither
  -- table: bare, it means "choose for me"; followed by a backend name, it
  -- means that one. Anything else after it is the next option, not a value.
  local WATCHABLE = { gtk = true, sdl = true, curses = true }
  local index = 1
  while index <= #argv do
    local word = argv[index]
    if word == "--watch" then
      local following = argv[index + 1]
      if following and WATCHABLE[following] then
        options.watch = following
        index = index + 1
      elseif following and following:sub(1, 2) ~= "--" and options.board ~= nil then
        -- a word that is not a backend and not another option, in the place a
        -- backend would go. Refusing beats guessing: "--watch vga" silently
        -- becoming a window is exactly the kind of quiet wrong answer this
        -- project keeps finding.
        die("--watch takes gtk, sdl or curses, not " .. following)
      else
        options.watch = "choose"
      end
    elseif takes_value[word] then
      index = index + 1
      if index > #argv then die("missing value after " .. word) end
      if word == "--dir" then
        DIR = argv[index]
      else
        options[takes_value[word]] = argv[index]
      end
    elseif is_switch[word] then
      options[is_switch[word]] = true
    elseif word:sub(1, 2) == "--" then
      die("unknown option: " .. word)
    elseif options.board == nil then
      options.board = word
    else
      die("more than one board named: " .. options.board .. " and " .. word)
    end
    index = index + 1
  end
  return options
end
-- }}}

-- {{{ local function read_input_defaults(options)
local function read_input_defaults(options)
  -- the first thing a program does is read the input/ files -- from there
  -- it knows exactly how to start up. Anything given on the command line
  -- wins over a default.
  local path = DIR .. "/input/launch-defaults.lua"
  if not file_exists(path) then return end
  local chunk = loadfile(path)
  if not chunk then die("input/launch-defaults.lua exists but does not load") end
  local defaults = chunk()
  if type(defaults) ~= "table" then return end
  for key, value in pairs(defaults) do
    if options[key] == nil then options[key] = value end
  end
end
-- }}}

-- {{{ local function ensure_ram_directories()
local function ensure_ram_directories()
  -- tmp/ points at the exec tier in /tmp; tmp/shared-memory points at the
  -- artifact tier in /dev/shm (guaranteed RAM). Run scripts ensure both
  -- exist before writing logs, because RAM directories vanish on reboot.
  run_one("mkdir -p /tmp/every-software-image-able")
  run_one("mkdir -p /dev/shm/every-software-image-able")
  run_one("ln -sfn /tmp/every-software-image-able " .. DIR .. "/tmp")
  run_one("ln -sfn /dev/shm/every-software-image-able /tmp/every-software-image-able/shared-memory")
  run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/logs")
end
-- }}}

-- {{{ local function find_board(name)
local function find_board(name)
  -- a board is named by the part after "-board-" in its filename, so
  -- adding a new board is adding a file and nothing else.
  if file_exists(name) then return dofile(name), name end
  local listing = io.popen("ls " .. DIR .. "/src")
  if not listing then die("cannot list " .. DIR .. "/src") end
  for entry in listing:lines() do
    local found = entry:match("^%d+%-board%-(.+)%.lua$")
    if found == name then
      listing:close()
      local path = DIR .. "/src/" .. entry
      return dofile(path), path
    end
  end
  listing:close()
  die("no board named '" .. name .. "' -- boards are src/*-board-<name>.lua files")
end
-- }}}

-- forward declaration: the payload attachers below reach for the storage
-- attachers, because a boot filesystem is a disk like any other and should
-- arrive on whatever controller the board says it has.
local attach_storage

-- {{{ local function attach_firmware(board, argv)
-- The board's own firmware, however that board carries it. Lifted out of the
-- payload attacher on 2026-08-21 because a second thing now needs it: booting
-- a MEDIUM this project built, rather than a directory the emulator pretends
-- is one. Both roads need firmware and only one of them needs a directory.
local function attach_firmware(board, argv)
  if board.payload.firmware_code then
    -- presented as flash chips, the way a real board carries firmware.
    argv[#argv + 1] = "-drive"
    argv[#argv + 1] = "if=pflash,format=raw,unit=0,readonly=on,file="
      .. board.payload.firmware_code

    if board.payload.firmware_vars then
      -- the variable store is written to, so each machine gets its own copy.
      -- Sharing one would let a run change what the next one sees.
      local vars = DIR .. "/tmp/vars-" .. board.board_id .. ".fd"
      run_one("cp -f " .. board.payload.firmware_vars .. " " .. vars)
      argv[#argv + 1] = "-drive"
      argv[#argv + 1] = "if=pflash,format=raw,unit=1,file=" .. vars
    end

  elseif board.payload.firmware then
    -- boards whose firmware is handed over whole rather than as flash.
    argv[#argv + 1] = "-bios"
    argv[#argv + 1] = board.payload.firmware
  end
end
-- }}}

-- {{{ attach_payload -- one attacher per way a firmware finds its payload
local attach_payload = {

  -- {{{ ["boot-sector"] = function(board, path, argv)
  ["boot-sector"] = function(board, path, argv)
    -- the BIOS road: sector zero to 0x7c00. Attached as a raw disk rather
    -- than -kernel because the point of the harness is to walk the road
    -- the hardware walks.
    argv[#argv + 1] = "-drive"
    argv[#argv + 1] = "file=" .. path .. ",format=raw,if=ide"
  end,
  -- }}}


-- {{{ ["uefi-esp"] = function(board, path, argv)
  ["uefi-esp"] = function(board, path, argv)
    -- The firmware road, and the only one that matches how a real computer
    -- starts. Firmware looks on a FAT filesystem for a file whose name says
    -- which architecture it is for, so the payload is placed there rather
    -- than dropped at an address.
    --
    -- The emulator can serve a directory as a FAT filesystem, which saves
    -- making a disk image for something that changes on every build.
    local root = DIR .. "/tmp/esp-" .. board.board_id

    attach_firmware(board, argv)

    local boot_directory = root .. "/" .. board.payload.boot_path:match("^(.*)/[^/]+$")
    run_one("rm -rf " .. root)
    run_one("mkdir -p " .. boot_directory)
    run_one("cp " .. path .. " " .. root .. "/" .. board.payload.boot_path)

    -- The boot filesystem arrives on the board's own storage controller
    -- rather than a fixed one, because not every machine has the same kind
    -- of disk -- an ARM board has no IDE at all. Using the board's controller
    -- also means the firmware exercises the same path a real disk would.
    local attacher = attach_storage[board.storage.controller]
    if not attacher then
      die("board declares storage controller '" .. board.storage.controller
          .. "', which nothing knows how to attach")
    end
    attacher(board, "fat:rw:" .. root, argv)
  end,
  -- }}}

  -- {{{ ["loader-device"] = function(board, path, argv)
  ["loader-device"] = function(board, path, argv)
    -- the generic loader places raw bytes at an address; a second entry
    -- points the processor there when the board's reset vector does not.
    if board.payload.bios then
      argv[#argv + 1] = "-bios"
      argv[#argv + 1] = board.payload.bios
    end
    local address = string.format("0x%x", board.payload.load_addr)
    argv[#argv + 1] = "-device"
    argv[#argv + 1] = "loader,file=" .. path .. ",addr=" .. address .. ",force-raw=on"
    if board.payload.set_pc then
      argv[#argv + 1] = "-device"
      argv[#argv + 1] = "loader,addr=" .. address .. ",cpu-num=0"
    end
  end,
  -- }}}
}
-- }}}

-- {{{ attach_storage -- one attacher per controller kind, so all three
--     kinds real boards use get exercised (and never the emulator's
--     convenient paravirtual one -- see issue 206).
attach_storage = {

  -- {{{ ahci = function(board, path, argv)
  ahci = function(board, path, argv)
    argv[#argv + 1] = "-drive"
    argv[#argv + 1] = "id=maindisk,file=" .. path .. ",format=raw,if=none"
    argv[#argv + 1] = "-device"
    argv[#argv + 1] = "ahci,id=ahci0"
    argv[#argv + 1] = "-device"
    argv[#argv + 1] = "ide-hd,drive=maindisk,bus=ahci0.0"
  end,
  -- }}}

  -- {{{ nvme = function(board, path, argv)
  nvme = function(board, path, argv)
    argv[#argv + 1] = "-drive"
    argv[#argv + 1] = "id=maindisk,file=" .. path .. ",format=raw,if=none"
    argv[#argv + 1] = "-device"
    argv[#argv + 1] = "nvme,drive=maindisk,serial=esia0001"
  end,
  -- }}}

  -- {{{ ["usb-storage"] = function(board, path, argv)
  ["usb-storage"] = function(board, path, argv)
    argv[#argv + 1] = "-drive"
    argv[#argv + 1] = "id=maindisk,file=" .. path .. ",format=raw,if=none"
    argv[#argv + 1] = "-device"
    argv[#argv + 1] = "qemu-xhci,id=xhci0"
    argv[#argv + 1] = "-device"
    argv[#argv + 1] = "usb-storage,drive=maindisk,bus=xhci0.0"
  end,
  -- }}}
}
-- }}}

-- {{{ local function host_architecture()
local function host_architecture()
  local pipe = io.popen("uname -m")
  if not pipe then return "unknown" end
  local name = pipe:read("*l")
  pipe:close()
  return name or "unknown"
end
-- }}}

-- {{{ local function resolve_watch(options)
-- Which display backend a --watch actually becomes, and what that costs the
-- serial line. Returns the backend name and, when something had to give way,
-- a sentence saying so -- because this file's habit is to decline out loud
-- rather than fall back quietly (see --accel below).
--
-- WHY "choose" IS NOT SIMPLY gtk. A window needs a display server, and a
-- machine reached over a connection with none is exactly where somebody most
-- wants to watch a boot. Asking the environment is one variable lookup and it
-- turns an obscure emulator failure into a picture in the terminal.
--
-- WHY curses AND --stdio CANNOT BOTH HAVE THE TERMINAL. The in-terminal
-- rendering draws the guest's screen over the whole terminal; serial-to-stdio
-- writes the machine's words to the same place. Together they overwrite each
-- other and neither is readable. The screen wins, because the person asked to
-- watch, and the words go to the log file where they are never lost.
local function attached_to_a_terminal()
  local ok, _, code = os.execute("test -t 1")
  return ok == true or ok == 0 or code == 0
end

local function resolve_watch(options)
  if not options.watch then return nil, nil end

  local backend = options.watch
  local note = nil
  if backend == "choose" then
    local windowed = os.getenv("DISPLAY") or os.getenv("WAYLAND_DISPLAY")
    if windowed and windowed ~= "" then
      backend = "gtk"
    else
      backend = "curses"
      note = "note: --watch found no display server, so the machine's screen "
          .. "is drawn in this terminal instead of a window"
    end
  end

  -- A window in a tiling window manager is whatever size the tile is, and a
  -- guest screen that ignores that is a small picture in the corner of a large
  -- window. Scaling to the window makes the emulated machine behave like a
  -- monitor somebody plugged in: it fills whatever it was given.
  if backend == "gtk" then backend = "gtk,zoom-to-fit=on" end

  -- The in-terminal rendering needs a real terminal to draw on. Without one
  -- the emulator refuses with four words about terminal output and stops, which
  -- reads like the machine failing rather than the option being wrong. Say
  -- which it is.
  if backend == "curses" and not attached_to_a_terminal() then
    die("--watch curses draws the machine's screen on a terminal, and this "
        .. "output is not one (redirected, or piped). Use --watch gtk for a "
        .. "window, or drop --watch and read the serial log")
  end

  if backend == "curses" and options.stdio then
    options.stdio = false
    note = "note: --watch curses draws over this terminal, so --stdio was "
        .. "declined; the serial line is in its log file"
  end

  return backend, note
end
-- }}}

-- {{{ local function build_command(board, options, serial_log)
local function build_command(board, options, serial_log)
  local argv = { board.emulator }

  argv[#argv + 1] = "-machine"
  argv[#argv + 1] = board.machine
  argv[#argv + 1] = "-cpu"
  -- The board names the processor it describes, and a caller may ask for a
  -- different one. That is not a convenience: the only way to test that a
  -- machine really detects what it is running on is to run it on more than
  -- one thing and require the answers to differ (issue 402).
  argv[#argv + 1] = options.cpu or board.cpu

  -- memory: a named size from the board, or a literal like 512M. Named
  -- sizes exist so the small board stays small -- the ratchet in issue
  -- 102 is only a test if some board forces the slower rungs.
  local memory = board.memory_sizes[options.memory] or options.memory
  argv[#argv + 1] = "-m"
  argv[#argv + 1] = memory

  -- No window by default, and that default is load-bearing: every test in this
  -- project boots machines unattended, and a window nobody asked for on a build
  -- machine is a hang rather than a picture. The framebuffer device still
  -- exists either way and can be inspected through the monitor afterwards;
  -- `none` only means nobody is watching live. --watch is how somebody does.
  local watching, watch_note = resolve_watch(options)
  if watch_note then say(watch_note) end
  argv[#argv + 1] = "-display"
  argv[#argv + 1] = watching or "none"
  if board.framebuffer and board.framebuffer.kind ~= "vga" then
    -- virt machines have no display until one is plugged in; the pc
    -- machine has its VGA already.
    argv[#argv + 1] = "-device"
    argv[#argv + 1] = board.framebuffer.kind
  end

  if options.stdio then
    argv[#argv + 1] = "-serial"
    argv[#argv + 1] = "mon:stdio"
  else
    argv[#argv + 1] = "-serial"
    argv[#argv + 1] = "file:" .. serial_log
  end

  -- {{{ a medium this project built, rather than one the emulator pretends into
  -- Added 2026-08-21, and it is the check that was missing for months. Every
  -- emulated boot until now took a payload FILE and let the emulator synthesise
  -- a filesystem around it, so the thing the image builder produces was never
  -- the thing under test -- and it turned out no firmware could open it.
  --
  -- This road hands the firmware a whole medium: partition table, filesystem,
  -- boot file and all, exactly the bytes that would go on a card. If the
  -- firmware finds it, the builder is right. If not, the builder is wrong, and
  -- that is a sentence somebody can act on rather than a boot that silently
  -- does nothing.
  if options.medium then
    attach_firmware(board, argv)
    local attacher = attach_storage[board.storage.controller]
    if not attacher then
      die("board declares storage controller '" .. board.storage.controller
          .. "', which nothing knows how to attach")
    end
    attacher(board, options.medium, argv)

  elseif options.payload then
    local attacher = attach_payload[board.payload.kind]
    if not attacher then die("board declares unknown payload kind: " .. board.payload.kind) end
    attacher(board, options.payload, argv)
  end

  if options.disk then
    local attacher = attach_storage[board.storage.controller]
    if not attacher then die("board declares unknown storage controller: " .. board.storage.controller) end
    attacher(board, options.disk, argv)
  end

  if options.gdb then
    -- frozen at the first instruction, waiting for a debugger on :1234.
    argv[#argv + 1] = "-S"
    argv[#argv + 1] = "-gdb"
    argv[#argv + 1] = "tcp::1234"
  end

  if options.screenshot then
    -- the emulator's monitor, so a picture of the screen can be taken from
    -- outside while the machine runs. The display device still draws with
    -- no window attached; -display none only means nobody is watching live.
    argv[#argv + 1] = "-monitor"
    argv[#argv + 1] = "tcp:127.0.0.1:" .. options.monitor_port .. ",server,nowait"
  end

  if options.accel then
    if host_architecture() == board.arch then
      argv[#argv + 1] = "-accel"
      argv[#argv + 1] = "kvm"
    else
      -- declining the option rather than falling back silently: the run
      -- still happens, but the user is told the speed they asked for is
      -- not available on this pairing.
      say("note: --accel needs guest and host to share an architecture ("
          .. board.arch .. " vs " .. host_architecture() .. "); running emulated")
    end
  end

  -- a runaway guest should not take the terminal with it; a wrong guest
  -- should not reboot forever either (an x86 triple fault reboots, and a
  -- rebooting boot sector is an endless loop nobody asked for).
  argv[#argv + 1] = "-no-reboot"

  local command = table.concat(argv, " ")
  if options.seconds then
    -- for tests: a machine that runs forever is correct behaviour, so the
    -- clock lives outside it.
    command = "timeout " .. options.seconds .. " " .. command
  end
  return command
end
-- }}}

-- {{{ local function write_goodbye(summary)
local function write_goodbye(summary)
  -- the last thing a program does is write to output/ -- specifically,
  -- goodbye.
  run_one("mkdir -p " .. DIR .. "/output")
  local handle = io.open(DIR .. "/output/goodbye", "w")
  if not handle then return end
  handle:write(summary, "\ngoodbye\n")
  handle:close()
end
-- }}}

-- {{{ main
local options = parse_arguments(arg)
if not options.board then
  die("no board named; try: luajit 018-launch-board.lua qemu-x86-64 --payload FILE")
end
read_input_defaults(options)
ensure_ram_directories()

local board, board_path = find_board(options.board)
local serial_log = DIR .. "/tmp/shared-memory/logs/" .. board.board_id .. "-serial.log"

if options.payload and not file_exists(options.payload) then
  die("payload does not exist: " .. options.payload)
end
if options.medium and not file_exists(options.medium) then
  die("medium does not exist: " .. options.medium)
end
if options.disk and not file_exists(options.disk) then
  die("disk does not exist: " .. options.disk)
end

local command = build_command(board, options, serial_log)

say("board:   " .. board.board_id .. "  (" .. board_path .. ")")
say("command: " .. command)
if not options.stdio then
  say("serial:  " .. serial_log)
end

if options.dry_run then
  write_goodbye("dry run for " .. board.board_id .. "; nothing was started")
  os.exit(0)
end

local started = os.time()
local ok, code

if options.screenshot then
  -- With a picture wanted, the machine runs in the background so this process
  -- is free to reach through the monitor and take one while it is still up.
  -- A screenshot after the machine has stopped would be a picture of nothing.
  if not options.seconds then
    die("--screenshot needs --seconds, so there is a moment to take it in")
  end
  run_one(command .. " &")
  run_one("sleep " .. options.capture_after)

  -- one command per line, so what is going where stays legible.
  local request = DIR .. "/tmp/screendump-request"
  local handle = io.open(request, "w")
  handle:write("screendump " .. options.screenshot .. "\n")
  handle:close()
  -- -c closes the connection when the request runs out, and -w gives up if
  -- the monitor never answers. The flags differ between netcat variants; these
  -- are GNU netcat's. A variant that rejects them will say so rather than hang,
  -- which is why the reply is kept.
  run_one("nc -c -w 2 127.0.0.1 " .. options.monitor_port .. " < " .. request
          .. " > " .. DIR .. "/tmp/shared-memory/logs/monitor-reply.log 2>&1")

  -- let the machine live out the rest of its allotted time, then take it down.
  local remaining = options.seconds - options.capture_after
  if remaining > 0 then run_one("sleep " .. remaining) end
  run_one("pkill -f 'monitor tcp:127.0.0.1:" .. options.monitor_port .. "'")

  ok = file_exists(options.screenshot)
  code = ok and 0 or 1
else
  ok, code = run_one(command)
end

local ran_for = os.time() - started

-- timeout's 124 means the allotted seconds elapsed -- for a test run that
-- is the machine surviving, not failing.
local outcome
if options.screenshot then
  outcome = ok and ("captured " .. options.screenshot)
                or "no picture was produced -- was anything drawing?"
elseif options.seconds and code == 124 then
  outcome = "ran its full " .. options.seconds .. "s"
elseif ok then
  outcome = "exited cleanly after " .. ran_for .. "s"
else
  outcome = "exited with code " .. tostring(code) .. " after " .. ran_for .. "s"
end
say("outcome: " .. outcome)

write_goodbye(board.board_id .. " " .. outcome .. "; serial at " .. serial_log)
-- }}}
