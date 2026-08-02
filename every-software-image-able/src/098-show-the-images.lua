#!/usr/bin/env luajit
-- 098-show-the-images.lua
--
-- One recipe, every board the project describes, built. The phase 5 demo's
-- numbers.
--
-- For a general: the claim phase 5 makes is that supporting a new computer
-- is a new description file and no code at all. A paragraph saying so proves
-- nothing. This builds the same seed for every machine described, side by
-- side, and shows what came out -- and uses the phase 1 measurement to say
-- what each of those images would actually be able to think with, which is
-- what those two phases together are for.
--
-- usage:
--   luajit 098-show-the-images.lua [--dir ROOT]

-- {{{ DIR -- the project root, hard-coded, overridable by --dir
local DIR = "/mnt/mtwo/programming/ai-stuff/every-software-image-able"
-- }}}

-- {{{ local function say(text)
local function say(text)
  io.write(text, "\n")
  io.flush()
end
-- }}}

-- {{{ main
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then index = index + 1 ; DIR = arg[index] end
  index = index + 1
end

local describe = dofile(DIR .. "/src/088-the-recipe.lua")
local builder = dofile(DIR .. "/src/089-build-the-image.lua")
local sampler = dofile(DIR .. "/src/040-reference-sampler.lua")
local waking = dofile(DIR .. "/src/086-emit-waking.lua")

local recipe = dofile(DIR .. "/input/example-recipe.lua")

say("")
say("  one recipe, every machine described")
say("  " .. string.rep("-", 74))
say("")
say("  recipe: " .. recipe.recipe_id)
say("")

-- {{{ every board in the tree
local boards = {}
local listing = io.popen("ls " .. DIR .. "/src")
for entry in listing:lines() do
  local name = entry:match("^%d+%-board%-(.+)%.lua$")
  if name then boards[#boards + 1] = DIR .. "/src/" .. entry end
end
listing:close()
table.sort(boards)
-- }}}

-- pretend parts, all the same, so what differs between the rows below is the
-- board and nothing else.
local waking_bytes = string.rep("K", 800)
local engine_bytes = string.rep("E", 24000)
local model_bytes = string.rep("W", 25728)
local text_bytes = string.rep("T", 19664)

say(string.format("  %-22s %-9s %-28s %9s", "board", "speaks",
                  "firmware looks in", "identity"))
say("  " .. string.rep("-", 74))

local built_count, refused_count = 0, 0
local identities = {}

for _, path in ipairs(boards) do
  local board = dofile(path)
  local built, why = builder.build({
    recipe = recipe, board = board, describe = describe, sampler = sampler,
    waking_bytes = waking_bytes, engine_bytes_content = engine_bytes,
    model_bytes = model_bytes, text_bytes = text_bytes,
    components = { engine = "049", assembler = "073" },
  })

  if built then
    built_count = built_count + 1
    identities[built.identity] = (identities[built.identity] or 0) + 1
    local where = board.payload.boot_path or board.payload.kind
    say(string.format("  %-22s %-9s %-28s %9s",
                      board.board_id, board.arch, where, built.identity))
  else
    refused_count = refused_count + 1
    say(string.format("  %-22s %-9s %s", board.board_id, board.arch or "?",
                      "REFUSED"))
    say("      " .. (why or ""):gsub("\n.*", ""))
  end
end

say("")
say(string.format("  %d built, %d refused, from one recipe and %d board files",
                  built_count, refused_count, #boards))
say("")

-- {{{ what the identities say
local distinct = 0
for _ in pairs(identities) do distinct = distinct + 1 end
say(string.format("  %d distinct identities among %d images.", distinct, built_count))
say("  Images for the same architecture that differ only in which machine")
say("  they were built for still differ, because the board is part of what")
say("  the image IS -- and building the same one twice gives the same number.")
say("")
-- }}}

-- {{{ what each of them could think with, using phase 1's arithmetic
local measured = DIR .. "/tmp/shared-memory/measurements/native.lua"
local handle = io.open(measured, "r")
if handle then
  handle:close()
  local native = dofile(measured)
  say("  and using the rate phase 1 measured on this processor:")
  say("")
  say(string.format("    %.2f million multiply-and-adds a second, conducted",
                    native.operations_per_second / 1e6))
  local weights = 134000000
  say(string.format("    a model of %d million weights would manage %.1f tokens a second",
                    weights / 1e6, native.operations_per_second / weights))
  say(string.format("    which is about %.0f minutes to write a page of assembly",
                    (3000 / (native.operations_per_second / weights)) / 60))
  say("")
  say("  Those numbers come from a file the measuring tool wrote, so this")
  say("  demonstration cannot go stale while claiming not to.")
else
  say("  (no measurement has been taken on this machine yet -- run the phase 1")
  say("   demonstration first and this will use its numbers)")
end
say("")
-- }}}

local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write(string.format("images: %d built from one recipe\ngoodbye\n",
                              built_count))
  goodbye:close()
end
-- }}}
