-- 098-diagram-check.lua
--
-- Reads every drawing in every blueprint and fails if a dimension called out in
-- one names a symbol that does not exist.
--
-- For a general reader: a drawing is the part of a specification somebody
-- actually builds from, and it is the part most likely to be wrong, because a
-- drawing with a number written on it takes no part in any of the checking the
-- rest of the project does. The rule is that a drawing writes [L_cube], never
-- 60. This program is the only thing standing between the project and a drawing
-- that still says sixty after the cube has become sixty-four.
--
-- What it does not do, and cannot: say whether the drawing is *true*. Whether
-- the box is the right size next to the other box, whether the arrow points the
-- right way. Nothing short of turning pictures into geometry could, and
-- pretending otherwise would give false confidence. This checks that a drawing
-- refers to things that exist, and nothing at all about whether it depicts them
-- honestly.

local DIR = "/mnt/mtwo/programming/ai-stuff/six-sided-dice-layer-cake"
if arg and arg[1] then DIR = arg[1] end

local ledger = dofile(DIR .. "/src/094-ledger.lua")

local M = {}

-- A drawing may legitimately contain digits: a corner label like C011, a
-- multiplier like 2x, an axis mark. What it may not contain is a dimension
-- written as a number. The two cannot be told apart with certainty, so this is
-- a warning rather than an error, and a line carrying this marker is left
-- alone.
-- What a drawing's caption says when it is a diagram of relationships rather
-- than of sizes, and calls out no dimensions on purpose. Without a way to say
-- so, every schematic in the project would be reported as unfinished forever.
M.SUPPRESS = "[not-dimensioned]"

-- {{{ local function suspicious_numbers()
-- Digit runs that look like a dimension somebody typed instead of naming. A
-- bare integer under about four digits, not attached to a letter, not inside
-- brackets, and not one of the small counts a drawing legitimately uses.
local function suspicious_numbers(line)
  if line:find(M.SUPPRESS, 1, true) then return {} end
  local out = {}
  -- blank out anything already inside brackets: those are the correct form and
  -- may contain digits in a symbol name
  local scrubbed = line:gsub("%[[%w_]+%]", "")
  for pre, num, post in scrubbed:gmatch("()(%d+%.?%d*)()") do
    local before = scrubbed:sub(pre - 1, pre - 1)
    local after  = scrubbed:sub(post, post)
    local attached = before:match("[%w_]") or after:match("[%w_]")
    local n = tonumber(num)
    -- small whole numbers are counts and captions, not dimensions
    if not attached and n and (n > 8 or num:find("%.")) then
      out[#out + 1] = num
    end
  end
  return out
end
-- }}}

-- {{{ function M.run()
-- Check every drawing in the blueprint set against the symbols that exist.
--
-- A drawing calls its dimensions out in square brackets, and those brackets are
-- the only place in this project where a name is written outside a declaration
-- or an expression. So they are the one place a name can quietly stop meaning
-- anything, and this is what notices.
function M.run(dir)
  dir = dir or DIR
  local L = ledger.load(dir)
  local R = { ledger = L, unknown = {}, suspect = {}, dimensionless = {}, checked = 0 }

  for _, d in ipairs(L.drawings) do
    R.checked = R.checked + 1
    for _, r in ipairs(d.refs) do
      if not L.decl[r.name] then
        R.unknown[#R.unknown + 1] = {
          d = d, name = r.name, line = r.line,
        }
      end
    end
    -- A drawing with no dimensions on it is sometimes right -- a topology
    -- sketch, a labelled diagram of an argument -- and is often one somebody
    -- never finished. The two are told apart by the author saying so in the
    -- caption, and only the unmarked ones are reported.
    local deliberate = d.caption:find(M.SUPPRESS, 1, true)
    if #d.refs == 0 and not deliberate then
      R.dimensionless[#R.dimensionless + 1] = d
    end
    if not deliberate then
      local n = 0
      for ln in (d.body .. "\n"):gmatch("([^\n]*)\n") do
        n = n + 1
        for _, num in ipairs(suspicious_numbers(ln)) do
          R.suspect[#R.suspect + 1] = { d = d, num = num, line = d.line + n }
        end
      end
    end
  end

  return R
end
-- }}}

-- {{{ function M.report()
-- Every bracketed name that matches no symbol, and every drawing that calls out
-- no dimensions at all -- which is not an error, but is usually a drawing
-- somebody has not finished.
function M.report(R, out)
  out = out or io.stdout
  local function say(fmt, ...)
    out:write(select("#", ...) > 0 and fmt:format(...) or fmt, "\n")
  end

  say("  drawings: %d checked", R.checked)

  if #R.unknown > 0 then
    say("")
    say("  DRAWINGS NAMING SYMBOLS THAT DO NOT EXIST")
    for _, u in ipairs(R.unknown) do
      say("    %s:%d  [%s]  in \"%s\"", u.d.file, u.line, u.name, u.d.caption)
    end
  end

  if #R.suspect > 0 then
    say("")
    say("  WARNING -- a number in a drawing where a symbol name belongs")
    say("  (add %s to the line if it is genuinely not a dimension)", M.SUPPRESS)
    for _, s in ipairs(R.suspect) do
      say("    %s:~%d  %s  in \"%s\"", s.d.file, s.line, s.num, s.d.caption)
    end
  end

  if #R.dimensionless > 0 then
    say("")
    say("  drawings with no dimensions called out, which may be unfinished:")
    for _, d in ipairs(R.dimensionless) do
      say("    %s  \"%s\"", d.file, d.caption)
    end
  end

  say("")
  return (#R.unknown > 0) and 1 or 0
end
-- }}}

if arg and arg[0] and arg[0]:match("098%-diagram%-check%.lua$") then
  os.exit(M.report(M.run(DIR)))
end

return M
