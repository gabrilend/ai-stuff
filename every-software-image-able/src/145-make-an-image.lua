#!/usr/bin/env luajit
-- 145-make-an-image.lua
--
-- The front door. Recipe, board and model in; an image you can put on a card
-- out, with the manifest saying what went into it and the number anyone can
-- arrive at again. Issue 502.
--
-- For a general: everything needed to make one of these existed and nothing
-- joined it up. The thing that builds a machine lived inside a test; the thing
-- that builds an image was a library nobody could run, whose own usage note
-- described a command line that did not exist. So there was no way to make a
-- seed. This is the way.
--
-- WHAT IT JOINS, IN ORDER:
--
--   144  writes out the machine -- the work area divided, the engine set up,
--        the tokenizer prepared, the driver's loop entered
--   clang and llvm-objcopy turn that text into instructions
--   089  lays out where everything goes and accounts for it
--   029  puts the code in the envelope a firmware will run
--   141  puts that file on a medium a firmware will open
--
-- Nothing here decides anything. Every decision belongs to one of those, and
-- this exists so that they meet.
--
-- usage:
--   luajit 145-make-an-image.lua --board NAME [--recipe FILE] [--model FILE]
--                                [--to FILE] [--dir ROOT]
--
--   --board   the short name from a src/*-board-<name>.lua file
--   --recipe  a recipe description; input/example-recipe.lua by default
--   --model   a packed model; the fixture is used if absent, and said so
--   --to      where the image goes; the RAM artifact tier by default

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

-- {{{ local function say(text)
local function say(text)
  io.write(text, "\n")
  io.flush()
end
-- }}}

-- {{{ local function die(text)
local function die(text)
  io.write("145-make-an-image: ", text, "\n")
  os.exit(1)
end
-- }}}

-- {{{ local function run_one(command)
-- One command, alone. No chains and no pipes, so what failed is what is named.
local function run_one(command)
  local ok, _, code = os.execute(command)
  return (ok == true or ok == 0), code
end
-- }}}

-- {{{ local function read_file(path)
local function read_file(path)
  local handle = io.open(path, "rb")
  if not handle then return nil end
  local content = handle:read("*a")
  handle:close()
  return content
end
-- }}}

-- {{{ main
local board_name, recipe_path, model_path, to_path = nil, nil, nil, nil
local index = 1
while index <= #arg do
  local word = arg[index]
  if word == "--board" then
    index = index + 1 ; board_name = arg[index] or die("missing value after --board")
  elseif word == "--recipe" then
    index = index + 1 ; recipe_path = arg[index] or die("missing value after --recipe")
  elseif word == "--model" then
    index = index + 1 ; model_path = arg[index] or die("missing value after --model")
  elseif word == "--to" then
    index = index + 1 ; to_path = arg[index] or die("missing value after --to")
  elseif word == "--dir" then
    index = index + 1 ; DIR = arg[index] or die("missing value after --dir")
  else
    die("unknown option: " .. word)
  end
  index = index + 1
end
if not board_name then
  die("no board named; try: luajit 145-make-an-image.lua --board qemu-uefi-x86-64")
end

recipe_path = recipe_path or (DIR .. "/input/example-recipe.lua")
to_path = to_path or (DIR .. "/tmp/shared-memory/images/" .. board_name .. ".img")

run_one("mkdir -p /tmp/every-software-image-able")
run_one("mkdir -p /dev/shm/every-software-image-able")
run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/images")
run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/payloads")

-- {{{ what is being built, and for what
local describe = dofile(DIR .. "/src/088-the-recipe.lua")
local builder  = dofile(DIR .. "/src/089-build-the-image.lua")
local machine  = dofile(DIR .. "/src/144-assemble-a-machine.lua")
local rides    = dofile(DIR .. "/src/143-what-rides-inside.lua")
local envelope = dofile(DIR .. "/src/029-wrap-uefi.lua")
local medium   = dofile(DIR .. "/src/141-a-bootable-medium.lua")
local sampler  = dofile(DIR .. "/src/040-reference-sampler.lua")

local recipe = dofile(recipe_path)
if type(recipe) ~= "table" then die("the recipe at " .. recipe_path .. " described nothing") end

local found = nil
local handle = io.popen("ls " .. DIR .. "/src/*-board-" .. board_name .. ".lua 2>/dev/null")
if handle then found = handle:read("*l") ; handle:close() end
if not found then die("no board description named '" .. board_name .. "'") end
local board = dofile(found)

say("")
say("  recipe:  " .. recipe_path)
say("  board:   " .. board_name .. "  (" .. board.arch .. ")")
-- }}}

-- {{{ the model
-- A parameter, always. Which model an image carries is the operator's choice
-- at build time and not a decision baked into this project (101). The fixture
-- stands in when nobody chose, and it says so, because an image quietly
-- carrying a toy is the kind of thing somebody finds out at first light.
if not model_path then
  model_path = DIR .. "/tmp/shared-memory/fixture/fixture-model.blob"
  say("  model:   the fixture, because none was named")
else
  say("  model:   " .. model_path)
end
local blob = read_file(model_path)
if not blob then
  die("no model at " .. model_path .. "; name one with --model, or make the "
      .. "fixture by running src/036-make-fixture.lua")
end
-- }}}

-- {{{ the randomness, made once and given to both halves
-- The machine's assembly refers to it and the image carries it, so it is made
-- here and handed to both rather than made twice. Same recipe and same seed
-- gives the same machine, exactly (104), which is the only kind of
-- reproducibility this project has.
local carried = {}
if recipe.randomness then
  carried = sampler.generate_file(recipe.randomness.seed,
                                  math.floor(recipe.randomness.bytes / 4))
end
-- }}}

-- {{{ the machine itself
local BOOT_TEXT = string.char(1, 2, 5, 3, 4, 7)
local made, why = machine.assemble({
  dir = DIR, blob = blob, text = BOOT_TEXT,
  max_tokens = 6, settings = { temperature = 1.0 }, randomness = carried,
})
if not made then die("the machine: " .. tostring(why)) end
say("  machine: " .. #made.assembly .. " characters of assembly, "
    .. made.work_bytes .. " bytes of work area")

local base = DIR .. "/tmp/shared-memory/payloads/image-" .. board_name
handle = io.open(base .. ".s", "w")
handle:write(made.assembly)
handle:close()

local target = { x86_64 = "x86_64-unknown-none", aarch64 = "aarch64-unknown-none",
                 riscv64 = "riscv64-unknown-none" }
if not target[board.arch] then die("nothing here assembles for " .. board.arch) end
if not run_one("clang --target=" .. target[board.arch] .. " -c "
               .. base .. ".s -o " .. base .. ".o") then
  die("the machine would not assemble; see " .. base .. ".s")
end
if not run_one("llvm-objcopy -O binary " .. base .. ".o " .. base .. ".raw") then
  die("the instructions would not come out of the object file")
end
local code = read_file(base .. ".raw") or die("nothing came out as raw bytes")
say("  code:    " .. #code .. " bytes")
-- }}}

-- {{{ the image
local built, trouble = builder.build({
  recipe = recipe, board = board, describe = describe, sampler = sampler,
  rides = rides, envelope = envelope, medium_module = medium,
  waking_bytes = code,
  model_bytes = blob,
  text_bytes = BOOT_TEXT,
  components = { machine = "144", envelope = "029", medium = "141" },
})
if not built then die(tostring(trouble)) end

local ok, complaint = builder.write(built, to_path)
if not ok then die(tostring(complaint)) end

say("")
say("  image:    " .. to_path .. "  (" .. #built.image .. " bytes)")
say("  manifest: " .. to_path .. ".manifest")
say("  identity: " .. built.identity)
say("")
say("  what is in it, measured from the code's first byte:")
for _, entry in ipairs(built.layout) do
  say(string.format("    %-11s at 0x%-8x %d bytes", entry.name, entry.at, entry.bytes))
end
say("")
say("  boot it with:")
say("    luajit src/018-launch-board.lua " .. board_name
    .. " --medium " .. to_path .. " --memory plenty --seconds 120")
say("")
-- }}}
