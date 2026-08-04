#!/usr/bin/env luajit
-- 119-test-sampler-aarch64.lua
--
-- Choosing what to say next, in the second tongue, on a real emulated ARM
-- machine -- held to the first architecture choice for choice. Issue 401.
--
-- For a general: a score off in its last bit stays off in its last bit. A
-- CHOICE that flips once joins the conversation, and every word after it is
-- said in a different conversation. So this does not ask whether the two
-- architectures are close. It asks whether, across many hundreds of draws
-- under every setting the sampler has, they picked the same word every time
-- and recorded the same chance for it.
--
-- WHY THE DRAWS ARE CHAINED. The carried stream advances with every draw --
-- its position, its state, how many have been taken from the current number,
-- and whether it has wrapped. Independent draws would check the arithmetic
-- and miss the bookkeeping; one long run means a single wrong step puts
-- every later draw somewhere else, which is the failure worth guarding.
--
-- usage:
--   luajit 119-test-sampler-aarch64.lua [--dir ROOT] [--seconds N]

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

-- {{{ local function host_architecture()
local function host_architecture()
  local pipe = io.popen("uname -m")
  local name = pipe and pipe:read("*l") or "unknown"
  if pipe then pipe:close() end
  return name
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
say("  choosing the same word, in the second tongue")
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

local host = host_architecture()
if host ~= "x86_64" then
  say("  this host is " .. host .. ", and the choices the second tongue is")
  say("  measured against have to come from the first one. Nothing was")
  say("  tested, which is not the same as nothing being wrong.")
  os.exit(1)
end

local emit = dofile(DIR .. "/src/043-emit-kernels.lua")
local arm = dofile(DIR .. "/src/099-kernels-aarch64.lua")
local sampler = dofile(DIR .. "/src/057-emit-sampler.lua")
local arm_sampler = dofile(DIR .. "/src/117-sampler-aarch64.lua")
local payload = dofile(DIR .. "/src/118-emit-sampler-check.lua")
local specification = dofile(DIR .. "/src/047-reference-exp.lua")
local float_bits = dofile(DIR .. "/src/107-float-bits.lua")

run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/kernels")
run_one("mkdir -p " .. DIR .. "/tmp/shared-memory/payloads")
run_one("mkdir -p " .. DIR .. "/tmp/kernels")

-- {{{ the first architecture, built and loaded
local source = DIR .. "/tmp/shared-memory/kernels/kernels-x86_64.s"
local sampler_source = DIR .. "/tmp/shared-memory/kernels/sampler-x86_64.s"
local library = DIR .. "/tmp/kernels/sampler-x86_64.so"

local handle = io.open(source, "w")
handle:write(emit.source("x86_64", specification))
handle:close()
handle = io.open(sampler_source, "w")
handle:write(sampler.x86_64())
handle:write('  .section .note.GNU-stack,"",@progbits\n')
handle:close()

if not run_one("clang -shared -o " .. library .. " " .. source
               .. " " .. sampler_source) then
  say("  the first tongue would not build; there is nothing to compare against")
  os.exit(1)
end

sampler.declare()
local kernels = ffi.load(library)
-- }}}

-- {{{ the scores, the carried numbers, and the settings
--
-- Scores shaped like a real distribution rather than uniform: a few clear
-- favourites, a long middle, and a tail -- so that cutting by chance and
-- cutting by count both actually cut something, and ties actually occur.
local COUNT = 48
local TIE_EVERY = 12
local scores = {}
for index = 1, COUNT do
  local value = ((index * 2654435761) % 100003) / 50000.0 - 1.0
  -- A deliberate tie group, so the rule that equal chances go to the lower
  -- token is exercised rather than assumed.
  --
  -- Every twelfth rather than every eighth, and the reason is worth keeping:
  -- at every eighth, six of forty-eight scores were identical and the
  -- payload's own guard against unvaried data refused to carry them. It was
  -- right to -- it cannot tell a deliberate tie from a generator handing
  -- back a stale value, and that guard exists because a machine was once
  -- very nearly recorded as a broken port after being given the same number
  -- two hundred and fifty-three times. So the ties were made fewer rather
  -- than the guard made weaker. Four tokens sharing one value is still a tie
  -- group, and the rule is still tested.
  if index % TIE_EVERY == 0 then value = 0.5 end
  scores[index] = value
end

local stream_numbers = {}
for index = 1, 64 do
  stream_numbers[index] = (index * 2654435761) % 4294967296
end

local PER_NUMBER = 8      -- small, so the stream reseeds and wraps during the run

-- Every setting the sampler has, and the draws are chained through all of
-- them from one carried file.
local SETTINGS = {
  { name = "ordinary",  temperature = 1.0,  top_p = 1.0,  top_k = COUNT, draws = 120 },
  { name = "sharpened", temperature = 0.25, top_p = 1.0,  top_k = COUNT, draws = 120 },
  { name = "flattened", temperature = 2.5,  top_p = 1.0,  top_k = COUNT, draws = 120 },
  { name = "tail cut",  temperature = 1.0,  top_p = 0.6,  top_k = COUNT, draws = 120 },
  { name = "few kept",  temperature = 1.0,  top_p = 1.0,  top_k = 5,     draws = 120 },
  { name = "frozen",    temperature = 0.0,  top_p = 1.0,  top_k = COUNT, draws = 20 },
}
-- }}}

-- {{{ what the first architecture chose, draw by draw, in one long run
local score_buffer = ffi.new("float[?]", COUNT)
for index = 1, COUNT do score_buffer[index - 1] = scores[index] end

local stream_holder = sampler.new_stream(stream_numbers)
stream_holder.stream.per_number = PER_NUMBER
stream_holder.stream.drawn = PER_NUMBER

-- The tie group is checked to exist rather than assumed, because it is the
-- thing that makes the two walks provably identical and a change to the
-- score generator could quietly remove it.
local tie_group = 0
for index = 1, COUNT do
  if scores[index] == 0.5 then tie_group = tie_group + 1 end
end
check("the scores really do contain a tie to break", tie_group > 1,
      tie_group .. " tokens share a score, and the rule that equal chances "
      .. "go to the lower token needs at least two")

local chance_out = ffi.new("float[1]")
local recorded = {}

for _, setting in ipairs(SETTINGS) do
  local holder = sampler.new_plan(kernels, COUNT, {
    temperature = setting.temperature,
    top_p = setting.top_p,
    top_k = setting.top_k,
  }, stream_holder)

  for _ = 1, setting.draws do
    local token = kernels.sampler_choose(holder.plan, score_buffer, COUNT,
                                         chance_out)
    local as_bits = ffi.cast("uint32_t *", chance_out)
    recorded[#recorded + 1] = {
      token = tonumber(token), chance = as_bits[0],
    }
  end
end

check("the first tongue drew, and drew something varied",
      #recorded > 0 and (function()
        local distinct = {}
        local seen = 0
        for _, entry in ipairs(recorded) do
          if not distinct[entry.token] then
            distinct[entry.token] = true ; seen = seen + 1
          end
        end
        return seen > 4
      end)(),
      "a run that always chooses the same word proves nothing about a port")

check("the carried file wrapped during the run",
      tonumber(stream_holder.stream.wrapped) == 1,
      "with " .. #recorded .. " draws at " .. PER_NUMBER
      .. " per number over " .. #stream_numbers .. " numbers, it should have")

local ended_at = tonumber(stream_holder.stream.position)
-- }}}

-- {{{ the payload that draws the same way on the other machine
local text = payload.aarch64({
  sampler = sampler,
  scores = scores,
  settings = SETTINGS,
  stream_numbers = stream_numbers,
  per_number = PER_NUMBER,
  recorded = recorded,
  kernels = arm.source({ "exp_one" }, specification, float_bits),
  sampler_source = arm_sampler.source(sampler),
  float_bits = float_bits,
})

local base = DIR .. "/tmp/shared-memory/payloads/sampler-check-aarch64"
handle = io.open(base .. ".s", "w")
handle:write(text)
handle:close()

if not run_one("clang --target=aarch64-unknown-none -c " .. base .. ".s -o "
               .. base .. ".o") then
  check("the second tongue's sampler assembles", false, "see " .. base .. ".s")
  say("")
  say("  " .. passed .. " of " .. (passed + failed + 1) .. " as expected")
  os.exit(1)
end
check("the second tongue's sampler assembles", true)

run_one("llvm-objcopy -O binary " .. base .. ".o " .. base .. ".raw")
run_one("luajit " .. DIR .. "/src/029-wrap-uefi.lua --from " .. base
        .. ".raw --to " .. base .. ".efi --arch aarch64 > /dev/null")
-- }}}

-- {{{ boot it and read what it said
local serial = DIR .. "/tmp/shared-memory/logs/qemu-uefi-arm64-serial.log"
run_one("rm -f " .. serial)
run_one("luajit " .. DIR .. "/src/018-launch-board.lua qemu-uefi-arm64"
  .. " --payload " .. base .. ".efi --seconds " .. seconds
  .. " --dir " .. DIR .. " > /dev/null 2>&1")

local spoken = read_file(serial) or ""

check("the other machine drew and reported",
      spoken:find("draws checked", 1, true) ~= nil,
      "nothing recognisable came back; see " .. serial)

-- only what the payload said, and only where a mark begins a line
local report = spoken:match("draws checked(.*)$") or ""
local function number_after(mark)
  return tonumber(report:match("[\r\n]%s*" .. mark .. "%s+(%x+)") or "", 16)
end

local chose, chose_total = number_after("chose"), number_after("of")
local chances, chances_total = number_after("chances"), number_after("cof")
local first_bad = number_after("firstbad")
local stream_at = number_after("streamat")

check("it chose the same word every time",
      chose ~= nil and chose_total ~= nil and chose == chose_total
      and chose_total > 0,
      tostring(chose) .. " of " .. tostring(chose_total)
      .. (first_bad and first_bad > 0
          and ("; the first that differed was draw " .. first_bad) or ""))

check("and recorded the same chance, bit for bit",
      chances ~= nil and chances_total ~= nil and chances == chances_total
      and chances_total > 0,
      tostring(chances) .. " of " .. tostring(chances_total))

check("as many draws were compared as were made",
      chose_total == #recorded,
      tostring(chose_total) .. " against " .. #recorded)

-- The stream's bookkeeping, which arithmetic alone would not catch: after
-- the same number of draws from the same carried file, both machines must be
-- looking at the same place in it.
check("and both ended at the same place in the carried file",
      stream_at == ended_at,
      "this machine ended at " .. tostring(stream_at) .. " and the first at "
      .. tostring(ended_at))
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this adds:")
say("    the second architecture can now turn scores into a word. Before")
say("    this it could think and never say anything -- an engine that")
say("    produces a score for every possible next word and no way to pick")
say("    one is not yet a machine that speaks.")
say("")
say("    " .. #recorded .. " draws across " .. #SETTINGS .. " settings, chained")
say("    through one carried file so that the reseeding and the wrap are")
say("    compared as well as the arithmetic. A flipped choice is not a small")
say("    error: it joins the conversation, and everything after it is said")
say("    in a different conversation.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("the second tongue chooses: " .. passed .. " of "
                .. (passed + failed) .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
