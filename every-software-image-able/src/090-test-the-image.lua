#!/usr/bin/env luajit
-- 090-test-the-image.lua
--
-- Checks the recipe, the board description and the builder that turns them
-- into bytes. Issues 501 and 502.
--
-- The two checks that matter most are the ones about disagreement: that a
-- recipe naming a board is refused, since a recipe that names one has become
-- a recipe FOR it; and that the builder and the engine are held to the same
-- account of where things are, because that disagreement is what makes a
-- machine fail at the earliest possible moment with the least possible
-- information.
--
-- usage:
--   luajit 090-test-the-image.lua [--dir ROOT]

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

-- {{{ main
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then index = index + 1 ; DIR = arg[index] end
  index = index + 1
end

say("")
say("  a recipe, a board, and the bytes they make together")
say("  " .. string.rep("-", 58))
say("")

local describe = dofile(DIR .. "/src/088-the-recipe.lua")
local builder = dofile(DIR .. "/src/089-build-the-image.lua")
-- The thing that turns laid-out regions into a medium a firmware will open
-- (141). Handed in rather than reached for, so the builder stays a thing that
-- decides WHERE bytes go and not a thing that knows what a partition table is.
local medium_module = dofile(DIR .. "/src/141-a-bootable-medium.lua")
local sampler = dofile(DIR .. "/src/040-reference-sampler.lua")
local budget = dofile(DIR .. "/src/045-memory-budget.lua")

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

local recipe = dofile(DIR .. "/input/example-recipe.lua")

-- {{{ the recipe stands on its own
check("the example recipe is sound", describe.check_recipe(recipe) == true,
      select(2, describe.check_recipe(recipe)))

local incomplete = { recipe_id = "half", engines = {} }
local missing = select(2, describe.check_recipe(incomplete))
check("a recipe missing pieces says which",
      missing ~= nil and missing:find("model") ~= nil, missing)

-- the check that matters: a recipe naming a machine
local named = dofile(DIR .. "/input/example-recipe.lua")
named.model.name = "the model for the qemu board"
local tainted = select(2, describe.check_recipe(named))
check("a recipe that names a machine is refused",
      tainted ~= nil and tainted:find("recipe FOR that board") ~= nil, tainted)
-- }}}

-- {{{ the board descriptions already in the tree are board descriptions
-- They were written for the emulator harness before there was a builder to
-- read them. An emulated machine is a board, so they are the same kind of
-- thing and are held to the same rules.
local boards = {}
local listing = io.popen("ls " .. DIR .. "/src")
for entry in listing:lines() do
  local name = entry:match("^%d+%-board%-(.+)%.lua$")
  if name then boards[#boards + 1] = { name = name, path = DIR .. "/src/" .. entry } end
end
listing:close()

check("there is more than one board described", #boards >= 6,
      #boards .. " boards")

local all_sound, board_trouble = true, nil
for _, entry in ipairs(boards) do
  local board = dofile(entry.path)
  local ok, why = describe.check_board(board)
  if not ok then
    all_sound = false
    board_trouble = board_trouble or (entry.name .. ": " .. why)
  end
end
check("every board description says everything a builder needs",
      all_sound, board_trouble)

local nameless = { board_id = "vague", arch = "x86_64", console = {},
                   storage = {}, payload = { kind = "uefi-esp" },
                   verified_against = "nowhere" }
local no_place = select(2, describe.check_board(nameless))
check("a board that does not say where its firmware looks is refused",
      no_place ~= nil and no_place:find("looks for something to start") ~= nil,
      no_place)

-- but a scheme that carries the answer in itself is not made to repeat it: a
-- BIOS always reads sector zero, and saying so again would be a second copy
-- of a fact that cannot vary.
local bios = { board_id = "old-machine", arch = "x86_64", console = {},
               storage = {}, payload = { kind = "boot-sector" },
               verified_against = "invented" }
check("and one whose boot scheme answers it is not made to repeat it",
      describe.check_board(bios) == true,
      select(2, describe.check_board(bios)))

-- adding a board must require touching nothing else. Proved by building for
-- one that did not exist a moment ago.
local invented = {
  board_id = "invented-machine", arch = "x86_64",
  console = { kind = "com1-port", base = 0x3f8 },
  storage = { controller = "ahci" },
  payload = { kind = "uefi-esp", boot_path = "EFI/BOOT/BOOTX64.EFI" },
  verified_against = "invented for this check, and transcribed from nothing",
}
check("a board invented this second is a valid board",
      describe.check_board(invented) == true)
-- }}}

-- {{{ building
local model_bytes = string.rep("W", 4096)
local built, trouble = builder.build({
  recipe = recipe, board = invented, describe = describe, sampler = sampler,
  medium_module = medium_module,
  waking_bytes = string.rep("K", 300),
  engine_bytes_content = string.rep("E", 2000),
  model_bytes = model_bytes,
  text_bytes = string.rep("T", 700),
  components = { assembler = "073", tokenizer = "059" },
})
check("an image is built from a recipe and a board", built ~= nil, trouble)

check("and it emits a manifest as well as bytes",
      built.manifest:find("recipe: esia%-example") ~= nil
      and built.manifest:find("board: invented%-machine") ~= nil)

check("and an identity anyone can arrive at again",
      built.identity ~= nil and #built.identity == 8, built.identity)

check("and the manifest names the model that actually went in",
      built.manifest:find("model: the fixture model") ~= nil)

check("and says where the firmware will look",
      built.manifest:find("EFI/BOOT/BOOTX64.EFI", 1, true) ~= nil)

check("and the randomness is baked in, from the recorded seed",
      built.manifest:find("102400 bytes from seed 20260802", 1, true) ~= nil
      and #built.image > 102400)
-- }}}

-- {{{ reproducible in the plain sense
local again = builder.build({
  recipe = recipe, board = invented, describe = describe, sampler = sampler,
  medium_module = medium_module,
  waking_bytes = string.rep("K", 300),
  engine_bytes_content = string.rep("E", 2000),
  model_bytes = model_bytes,
  text_bytes = string.rep("T", 700),
  components = { assembler = "073", tokenizer = "059" },
})
check("the same inputs give the same bytes", again.image == built.image)
check("and the same identity", again.identity == built.identity)

-- and different inputs give a different identity, or the identity says
-- nothing at all
local different = builder.build({
  recipe = recipe, board = invented, describe = describe, sampler = sampler,
  medium_module = medium_module,
  waking_bytes = string.rep("K", 300),
  engine_bytes_content = string.rep("E", 2000),
  model_bytes = string.rep("X", 4096),
  text_bytes = string.rep("T", 700),
  components = { assembler = "073", tokenizer = "060" },
})
check("and different inputs give a different identity",
      different.identity ~= built.identity,
      built.identity .. " twice")
-- }}}

-- {{{ the seam with the engine
local agrees = builder.check_the_seam(built, {
  waking = { at = 0 },
  model = { after = "engine" },
  text = { after = "model" },
})
check("the builder and the engine agree about the image", agrees == true,
      select(2, builder.check_the_seam(built, { waking = { at = 0 } })))

local disagrees = select(2, builder.check_the_seam(built, {
  model = { at = 999999 },
}))
check("and a disagreement is refused by the build, not by first light",
      disagrees ~= nil and disagrees:find("earliest possible moment") ~= nil,
      disagrees)

local absent = select(2, builder.check_the_seam(built, { allocator = { at = 0 } }))
check("and something the engine expects and the builder never wrote",
      absent ~= nil and absent:find("nothing by that name") ~= nil, absent)
-- }}}

-- {{{ refusing what cannot work
local wrong_arch = { board_id = "another-kind", arch = "sparc64",
  console = {}, storage = {},
  payload = { kind = "uefi-esp", boot_path = "EFI/BOOT/BOOTSPARC.EFI" },
  verified_against = "invented" }
local no_engine = select(2, builder.build({
  recipe = recipe, board = wrong_arch, describe = describe, sampler = sampler,
  medium_module = medium_module,
}))
check("a board this recipe has no engine for is refused",
      no_engine ~= nil and no_engine:find("boots and stops") ~= nil, no_engine)

-- a model too large for the board, refused with the three numbers said
local too_large = select(2, builder.build({
  recipe = recipe, board = invented, describe = describe, sampler = sampler,
  medium_module = medium_module,
  model_bytes = string.rep("W", 64),
  shape = { layers = 32, hidden = 4096, heads = 32, head_width = 128,
            kv_heads = 8, feedforward = 14336, vocabulary = 128256,
            context = 8192 },
  budget = budget, board_memory = 64 * 1024 * 1024,
  medium_bytes = 8 * 1024 * 1024 * 1024,
  engine_bytes = 2 * 1024 * 1024,
}))
check("a model too large for the board is refused at build time",
      too_large ~= nil and too_large:find("no arrangement of it that runs") ~= nil,
      too_large)
check("and the three numbers are all said out loud",
      too_large ~= nil and too_large:find("the medium holds") ~= nil
      and too_large:find("the board's memory") ~= nil
      and too_large:find("thinking needs at least") ~= nil)
-- }}}

-- {{{ three files, never only the image
run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/images")
local to = DIR .. "/tmp/shared-memory/images/example.img"
builder.write(built, to)
local wrote_all = true
for _, suffix in ipairs({ "", ".manifest", ".identity" }) do
  local handle = io.open(to .. suffix, "rb")
  if handle then handle:close() else wrote_all = false end
end
check("three files are written, never only the image", wrote_all)
-- }}}

-- {{{ putting it on a card
-- The only operation here that cannot be undone by writing more software, so
-- everything about it is checked against pretend devices rather than real
-- ones -- a test that writes to real disks to prove it writes to real disks
-- is a test nobody should run twice.
local flasher = dofile(DIR .. "/src/091-put-it-on-a-card.lua")

local cards = {}
local function pretend_card(where, bytes, removable, read_only)
  cards[where] = { path = where, bytes = bytes, removable = removable,
                   read_only = read_only, contents = "" }
  return cards[where]
end
-- SIXTEEN MEGABYTES RATHER THAN ONE, since 2026-08-21. These were a megabyte
-- each, which was ample when an image was five regions laid end to end. An
-- image is now a MEDIUM -- a partition table, a filesystem, and the regions
-- inside a file in it -- and the smallest one the filesystem format permits is
-- about four megabytes, because a FAT16 filesystem is only FAT16 above roughly
-- four thousand clusters.
--
-- Worth keeping as a comment rather than a silent number: the floor came from
-- the format and not from anything this project chose, and a test whose pretend
-- hardware is smaller than the smallest real image tests nothing.
local PRETEND_CARD = 16 * 1024 * 1024
pretend_card("/pretend/card-one", PRETEND_CARD, true, false)
pretend_card("/pretend/card-two", PRETEND_CARD, true, false)
pretend_card("/pretend/finished", PRETEND_CARD, true, true)
pretend_card("/pretend/somebodys-computer", PRETEND_CARD, false, false)
pretend_card("/pretend/tiny", 64, true, false)

local function look(where) return cards[where] or { path = where } end

local image = built.image

-- a card whose size the operator got right
local right = flasher.check({ where = "/pretend/card-one", size = PRETEND_CARD },
                            #image, look("/pretend/card-one"))
check("a card the operator described correctly is accepted", right == true)

-- and one they did not
local mistaken = select(2, flasher.check(
  { where = "/pretend/card-one", size = 999 }, #image, look("/pretend/card-one")))
check("a card the operator described wrongly is refused",
      mistaken ~= nil and mistaken[1]:find("different device than you think")
        ~= nil, mistaken and mistaken[1])

local unwritable = select(2, flasher.check(
  { where = "/pretend/finished", size = PRETEND_CARD }, #image, look("/pretend/finished")))
check("a read-only medium is refused, and called the preferred kind",
      unwritable ~= nil and unwritable[1]:find("preferred kind") ~= nil,
      unwritable and unwritable[1])

local fixed = select(2, flasher.check(
  { where = "/pretend/somebodys-computer", size = PRETEND_CARD }, #image,
  look("/pretend/somebodys-computer")))
check("a disk that is not removable is objected to loudly",
      fixed ~= nil and fixed[1]:find("somebody is standing at") ~= nil,
      fixed and fixed[1])

local too_small = select(2, flasher.check(
  { where = "/pretend/tiny", size = 64 }, #image, look("/pretend/tiny")))
check("a card too small for the image is refused",
      too_small ~= nil, "an image larger than the card was allowed")

-- every objection at once, rather than one at a time
local several = select(2, flasher.check(
  { where = "/pretend/tiny", size = 999 }, #image, look("/pretend/tiny")))
check("and every objection is said at once",
      several ~= nil and #several >= 2,
      "an operator about to do something irreversible saw one reason at a time")

-- many cards in one run, since one image serves many machines
local results = flasher.run({
  image = image, identity = built.identity, look = look, dry_run = true,
  targets = {
    { where = "/pretend/card-one", size = PRETEND_CARD },
    { where = "/pretend/card-two", size = PRETEND_CARD },
    { where = "/pretend/finished", size = PRETEND_CARD },
  },
})
check("many cards are written in one run", #results == 3)
check("and the ones that could not be are named with their reasons",
      results[3].refused == true and results[3].why ~= nil)

local said = flasher.say_what_happened(results)
check("and what happened is reported per card",
      said:find("NOT WRITTEN") ~= nil and said:find("1 written") == nil
      and said:find("refused") ~= nil, said)

check("the confirmation asks for something only the right operator knows",
      flasher.WHAT_IT_ASKS:find("Type the size in bytes") ~= nil
      and flasher.WHAT_IT_ASKS:find("cannot") ~= nil)
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this does not cover:")
say("    - writing to a real card. The checks above run against pretend")
say("      devices, because a test that writes to real disks to prove it")
say("      writes to real disks is one nobody should run twice.")
say("    - whether an image built this way boots. That is 601, and it needs")
say("      the engine to exist for the board being built for.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("the image: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
