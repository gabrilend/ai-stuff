#!/usr/bin/env luajit
-- 070-test-say.lua
--
-- Checks that a machine with no operating system can be heard: the font
-- derives correctly from its pictures, and a real board draws the right
-- pixels in the right places -- compared against what the font says they
-- should be, pixel for pixel, rather than against "some green appeared".
--
-- For a general: the machine is switched on, told to write a sentence on the
-- screen, photographed, and the photograph is compared with the letters the
-- font holds. Anything less than that passes when the letters are wrong.
--
-- usage:
--   luajit 070-test-say.lua [--dir ROOT] [--seconds N]

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
local seconds = 30
local index = 1
while index <= #arg do
  if arg[index] == "--dir" then
    index = index + 1 ; DIR = arg[index]
  elseif arg[index] == "--seconds" then
    index = index + 1 ; seconds = tonumber(arg[index]) or 30
  end
  index = index + 1
end

say("")
say("  saying something with nothing underneath")
say("  " .. string.rep("-", 58))
say("")

local font = dofile(DIR .. "/src/068-bitmap-font.lua")

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

-- {{{ the font derives from its pictures
local every_glyph_sound = true
local trouble = nil
for character in pairs(font.PICTURES) do
  local ok, result = pcall(font.rows, character)
  if not ok then
    every_glyph_sound = false
    trouble = trouble or tostring(result)
  elseif #result ~= font.HEIGHT then
    every_glyph_sound = false
    trouble = trouble or ("'" .. character .. "' came back in " .. #result .. " rows")
  end
end
check("every picture in the font is well formed", every_glyph_sound, trouble)

-- the derivation is checked by going back the other way: bytes to picture,
-- which must be the picture that produced them.
local round_trips = true
local drifted = nil
for character, picture in pairs(font.PICTURES) do
  local shown = font.show(character)
  local flattened = picture:gsub(",", "\n")
  if shown ~= flattened then
    round_trips = false
    drifted = drifted or character
  end
end
check("and the bytes give the picture back exactly", round_trips,
      drifted and ("'" .. drifted .. "' drew differently than it was written"))

local glyphs, missing = font.contiguous_table()
check("the carried table covers every code in its range",
      #glyphs == (font.LAST - font.FIRST + 1) * font.HEIGHT,
      #glyphs .. " bytes for " .. (font.LAST - font.FIRST + 1) .. " codes")

-- a character with no picture carries the box, and the box is not a blank:
-- a blank would say the machine printed a space it never printed.
local box = font.rows_of_picture(font.MISSING, "the box")
local box_is_visible = false
for _, byte in ipairs(box) do if byte ~= 0 then box_is_visible = true end end
check("a character with no picture carries a visible box", box_is_visible
      and missing > 0, missing .. " codes have no picture")
-- }}}

-- {{{ the machine's own voice, as hands
-- The engine narrating itself is one thing; the model being able to speak is
-- another, and it is what makes 202 a phase 2 ticket rather than a phase 1
-- one.
local hands = dofile(DIR .. "/src/064-the-hands.lua")

local heard = { screen = {}, wire = {} }
local catalogue = hands.new()
hands.offer_the_catalogue(catalogue)
hands.offer_speaking(catalogue, {
  { name = "screen", note = "the framebuffer the firmware handed over",
    write = function(text) heard.screen[#heard.screen + 1] = text return true end },
  { name = "wire", note = "the serial port, unbuffered",
    write = function(text) heard.wire[#heard.wire + 1] = text return true end },
})

local said = hands.answer(catalogue, hands.find(catalogue, "<call say hello>"))
check("the machine can ask to be heard",
      said.ok and heard.screen[1] == "hello" and heard.wire[1] == "hello",
      said.text)

local one_voice = hands.answer(catalogue,
  hands.find(catalogue, "<call say_on wire quietly>"))
check("and can choose one voice over another",
      one_voice.ok and heard.wire[2] == "quietly" and #heard.screen == 1,
      one_voice.text)

local nowhere = hands.answer(catalogue,
  hands.find(catalogue, "<call say_on trumpet anything>"))
check("a voice this machine does not have is refused, by name",
      not nowhere.ok and nowhere.text:find("no voice called") ~= nil,
      nowhere.text)

local listed = hands.answer(catalogue, hands.find(catalogue, "<call voices>"))
check("and it can ask what it can be heard on",
      listed.ok and listed.text:find("screen") and listed.text:find("wire"))

-- every voice failing is a refusal rather than a quiet nothing
local mute = hands.new()
hands.offer_speaking(mute, {
  { name = "broken", write = function() return nil, "the wire is cut" end },
})
local unheard = hands.answer(mute, hands.find(mute, "<call say anything>"))
check("a machine that speaks and is not heard says so",
      not unheard.ok and unheard.text:find("nothing carried it") ~= nil,
      unheard.text)

local silent_ok = pcall(hands.offer_speaking, hands.new(), {})
check("a machine with no voice at all is refused at build time", not silent_ok)
-- }}}

-- {{{ the board draws it
local text = "first light, drawn from the firmware's own framebuffer"
local picture_path = DIR .. "/tmp/shared-memory/said.ppm"
local serial = DIR .. "/tmp/shared-memory/logs/qemu-uefi-x86-64-serial.log"

run_one("luajit " .. DIR .. "/src/019-build-payload.lua --dir " .. DIR
  .. " --payload draw-on-firmware --arch x86_64 > /dev/null")
run_one("rm -f " .. picture_path)
run_one("rm -f " .. serial)

local payload = DIR .. "/tmp/shared-memory/payloads/draw-on-firmware-x86_64.efi"
run_one("luajit " .. DIR .. "/src/018-launch-board.lua qemu-uefi-x86-64"
  .. " --payload " .. payload .. " --seconds " .. seconds
  .. " --screenshot " .. picture_path .. " --capture-after " .. (seconds - 7)
  .. " --dir " .. DIR .. " > /dev/null 2>&1")

local spoken = read_file(serial) or ""
check("the machine says it on the wire too",
      spoken:find(text, 1, true) ~= nil and spoken:find("drawn", 1, true) ~= nil,
      "nothing recognisable arrived on the serial port")

local photograph = read_file(picture_path)
if not photograph then
  check("the screen was photographed", false, "no picture was produced")
else
  -- {{{ read the photograph
  -- The header is walked by hand: comments may sit between any two fields.
  local at, numbers = 3, {}
  while #numbers < 3 do
    local from, to, value = photograph:find("^%s*(%d+)", at)
    if from then numbers[#numbers + 1] = tonumber(value) ; at = to + 1
    else at = at + 1 end
  end
  local width = numbers[1]
  local pixels = at + 1

  local function lit(row, column)
    local offset = pixels + (row * width + column) * 3
    local _, green = photograph:byte(offset, offset + 2)
    return green ~= nil and green > 60
  end
  -- }}}

  -- {{{ compare against what the font says
  -- Every pixel of every letter, in both directions: a set bit must be lit
  -- and a clear bit must be dark. Checking only the set bits would pass a
  -- machine that filled the whole line solid.
  local wrong_on, wrong_off, checked = 0, 0, 0
  local first_wrong = nil
  for position = 1, #text do
    local character = text:sub(position, position)
    local rows = font.rows(character)
    if rows then
      for row = 0, font.HEIGHT - 1 do
        for column = 0, font.WIDTH - 1 do
          local wanted = math.floor(rows[row + 1] / 2 ^ (font.WIDTH - 1 - column)) % 2 == 1
          local found = lit(row, (position - 1) * font.WIDTH + column)
          checked = checked + 1
          if wanted and not found then
            wrong_off = wrong_off + 1
            first_wrong = first_wrong or ("'" .. character .. "' at " .. position
              .. ", row " .. row .. ", column " .. column .. " should be lit")
          elseif found and not wanted then
            wrong_on = wrong_on + 1
            first_wrong = first_wrong or ("'" .. character .. "' at " .. position
              .. ", row " .. row .. ", column " .. column .. " should be dark")
          end
        end
      end
    end
  end

  check("every pixel of every letter is where the font says",
        wrong_on == 0 and wrong_off == 0 and checked > 2000,
        first_wrong and (first_wrong .. "  (" .. wrong_off .. " missing, "
          .. wrong_on .. " extra, of " .. checked .. ")"))
  -- }}}

  -- and the line below the text is untouched, so nothing overran
  local overran = false
  for column = 0, #text * font.WIDTH - 1 do
    if lit(font.HEIGHT + 1, column) then overran = true end
  end
  check("and nothing was drawn below the line", not overran)
end
-- }}}

say("")
say("  " .. string.rep("-", 58))
say("  " .. passed .. " of " .. (passed + failed) .. " as expected")
say("")
say("  what this does not cover:")
say("    - the other two architectures. The drawing is written in x86-64's")
say("      instructions only; 401 is where the rest are.")
say("    - a board with no display at all. The payload says so and stops,")
say("      which is checked by reading, not by running -- there is no")
say("      emulated UEFI board here that lacks a framebuffer.")
say("")

run_one("mkdir -p " .. DIR .. "/output")
local goodbye = io.open(DIR .. "/output/goodbye", "w")
if goodbye then
  goodbye:write("saying something: " .. passed .. " of " .. (passed + failed)
                .. " as expected\ngoodbye\n")
  goodbye:close()
end

os.exit(failed == 0 and 0 or 1)
-- }}}
