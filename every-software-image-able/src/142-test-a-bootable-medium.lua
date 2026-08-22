#!/usr/bin/env luajit
-- 142-test-a-bootable-medium.lua
--
-- Checks that what 141 builds is a medium a firmware will open, and checks it
-- the only way that means anything: by asking a firmware.
--
-- For a general: this project spent months producing images that were correct
-- in every way it knew how to check and that no computer on earth could start.
-- The checks it had compared the builder's arrangement against the engine's
-- expectations, and both were right. Nobody asked the component that has to
-- find the first byte. This asks it.
--
-- THREE KINDS OF WITNESS, ON PURPOSE. The structures here are checked by this
-- file, then by tools written by other people who have no stake in this being
-- right, then by a real firmware being handed the bytes. The first can be
-- fooled by a mistake shared between writer and reader -- which is exactly the
-- failure this project keeps meeting -- and the second cannot, and the third
-- is the thing that actually has to work.
--
-- usage:
--   luajit 142-test-a-bootable-medium.lua [--dir ROOT] [--quick]
--
--   --quick skips the boots, which take about twenty seconds each.

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

-- {{{ local function output_of(command)
local function output_of(command)
  local pipe = io.popen(command)
  if not pipe then return nil end
  local text = pipe:read("*a")
  pipe:close()
  return text
end
-- }}}

-- {{{ local function have(tool)
local function have(tool)
  return run_one("command -v " .. tool .. " >/dev/null 2>&1")
end
-- }}}

-- {{{ main
local QUICK = false
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then index = index + 1 ; DIR = arg[index] end
  if arg[index] == "--quick" then QUICK = true end
  index = index + 1
end

say("")
say("  a medium a firmware will open")
say("  " .. string.rep("-", 58))
say("")

local medium = dofile(DIR .. "/src/141-a-bootable-medium.lua")

local passed, failed, inconclusive = 0, 0, 0
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
-- A check that could not be made is not a check that passed. This project has
-- already been caught reporting a clean run from a harness connected to
-- nothing, so an absent tool is counted separately and shown at the end rather
-- than quietly skipped.
local function unable(what, why)
  inconclusive = inconclusive + 1
  say(string.format("  %-50s INCONCLUSIVE", what))
  say("      " .. why)
end

local WORK = DIR .. "/tmp/shared-memory/media"
run_one("mkdir -p " .. WORK)

-- {{{ the checksum, against a number somebody else published
-- The partition table checks itself and a header that fails its own check is
-- ignored in silence -- the firmware simply finds no partitions. So this is
-- the one piece of arithmetic here with a published right answer, and it is
-- checked first because everything else rests on it.
check("the checksum agrees with the published answer",
      string.format("%08x", medium.crc32("123456789")) == "cbf43926",
      string.format("%08x", medium.crc32("123456789")))
-- }}}

-- {{{ the filesystem stays the format its own boot sector claims
-- Which of the three FATs a filesystem IS depends on how many clusters it has,
-- not on what it says. A cluster count outside the FAT16 range with a boot
-- sector saying FAT16 is read differently by different systems, which is worse
-- than being either.
local all_sound = true
local sizes_tried = 0
for _, megabytes in ipairs({4, 8, 16, 64, 256, 512, 1024}) do
  local shape = medium.geometry(megabytes * 1024 * 1024 / 512)
  sizes_tried = sizes_tried + 1
  if not shape or shape.clusters < 4085 or shape.clusters > 65524 then
    all_sound = false
  end
end
check("every medium size lands inside the FAT16 range", all_sound,
      sizes_tried .. " sizes tried")

check("a medium too small to be FAT16 at all is refused",
      medium.geometry(64) == nil)
-- }}}

-- {{{ a name that does not fit gets the long-name treatment
-- The third architecture's boot path is eleven characters, which does not fit
-- the eight-and-three naming FAT has always had. An earlier version of 141
-- refused it and said in a comment that no firmware path needed long names.
-- That claim was made by looking at one machine.
local long = medium.medium({
  bytes = string.rep("R", 900),
  path = "EFI/BOOT/BOOTRISCV64.EFI",
  identity = "long-name",
})
check("an eleven-character boot path is built, not refused", long ~= nil,
      long == nil and select(2, medium.medium({
        bytes = "x", path = "EFI/BOOT/BOOTRISCV64.EFI", identity = "x" })) or nil)
-- }}}

-- {{{ what other people's tools make of it
local sample = medium.medium({
  bytes = string.rep("Z", 3000),
  path = "EFI/BOOT/BOOTX64.EFI",
  identity = "witness",
  label = "SEED",
})
local sample_path = WORK .. "/witness.img"
local handle = io.open(sample_path, "wb")
handle:write(sample.image)
handle:close()

if have("sgdisk") then
  local told = output_of("sgdisk -p " .. sample_path .. " 2>&1") or ""
  check("a partition tool reads the table and finds one partition",
        told:find("EF00") ~= nil, told:sub(1, 200))
  local verified = output_of("sgdisk -v " .. sample_path .. " 2>&1") or ""
  check("and finds no problems with it",
        verified:find("No problems found") ~= nil, verified:sub(1, 200))
else
  unable("a partition tool reads the table", "sgdisk is not installed")
  unable("and finds no problems with it", "sgdisk is not installed")
end

if have("mdir") then
  local at = sample.partition_at * medium.SECTOR
  local listed = output_of("mdir -i " .. sample_path .. "@@" .. at
                           .. " ::/EFI/BOOT 2>&1") or ""
  check("another filesystem reader finds the file where firmware will look",
        listed:find("BOOTX64") ~= nil, listed:sub(1, 200))

  local back = output_of("mtype -i " .. sample_path .. "@@" .. at
                         .. " ::/EFI/BOOT/BOOTX64.EFI 2>/dev/null") or ""
  check("and hands back the bytes that were put in",
        #back == 3000 and back == string.rep("Z", 3000),
        #back .. " bytes came back")
else
  unable("another filesystem reader finds the file", "mtools is not installed")
  unable("and hands back the bytes that were put in", "mtools is not installed")
end
-- }}}

-- {{{ and the only witness that counts
-- Build a payload that speaks through the firmware's own console, wrap it in a
-- medium, hand the medium to a real firmware, and see whether the machine says
-- anything. Every other check in this file can be satisfied by a mistake
-- shared between a writer and a reader. This one cannot.
if QUICK then
  say("")
  say("  (the boots were skipped; --quick)")
else
  local boards = {
    { arch = "x86_64",  board = "qemu-uefi-x86-64",   path = "EFI/BOOT/BOOTX64.EFI" },
    { arch = "aarch64", board = "qemu-uefi-arm64",    path = "EFI/BOOT/BOOTAA64.EFI" },
    { arch = "riscv64", board = "qemu-uefi-riscv64",  path = "EFI/BOOT/BOOTRISCV64.EFI" },
  }
  for _, target in ipairs(boards) do
    local built_ok = run_one("luajit " .. DIR .. "/src/019-build-payload.lua --payload uefi-hello --arch "
                             .. target.arch .. " --dir " .. DIR .. " >/dev/null 2>&1")
    if not built_ok then
      unable("a firmware opens what was built (" .. target.arch .. ")",
             "the payload for this architecture would not build")
    else
      local source = io.open(DIR .. "/tmp/shared-memory/payloads/uefi-hello-"
                             .. target.arch .. ".efi", "rb")
      local payload = source:read("*a")
      source:close()

      local made, why = medium.medium({
        bytes = payload, path = target.path,
        identity = "boot-" .. target.arch, label = "SEED",
      })
      if not made then
        check("a firmware opens what was built (" .. target.arch .. ")", false, why)
      else
        local where = WORK .. "/boot-" .. target.arch .. ".img"
        local out = io.open(where, "wb")
        out:write(made.image)
        out:close()

        run_one("luajit " .. DIR .. "/src/018-launch-board.lua " .. target.board
                .. " --medium " .. where .. " --seconds 25 --dir " .. DIR
                .. " >/dev/null 2>&1")

        local log = io.open(DIR .. "/tmp/shared-memory/logs/" .. target.board
                            .. "-serial.log", "r")
        local said = log and log:read("*a") or ""
        if log then log:close() end
        check("a firmware opens what was built (" .. target.arch .. ")",
              said:find("first light through firmware") ~= nil,
              "nothing recognisable came out of the machine")
      end
    end
  end
end
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected"
    .. (inconclusive > 0 and ("; " .. inconclusive .. " could not be checked") or ""))
say("")
say("  what this does not cover:")
say("    a real card. Every medium here was handed to an emulator, which")
say("    reads a file where a board reads silicon. The firmware is real and")
say("    the reading is real; the thing being read is not.")
say("")
say("    and whether the file INSIDE the medium is a machine. This checks")
say("    that a firmware finds it and runs it, which is a different claim")
say("    from it being the seed -- 502 hands the engine's real bytes to the")
say("    builder, and that seam is still checked against a placeholder.")
say("")
os.exit((failed == 0 and inconclusive == 0) and 0 or 1)
-- }}}
