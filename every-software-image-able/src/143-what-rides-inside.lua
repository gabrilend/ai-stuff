#!/usr/bin/env luajit
-- 143-what-rides-inside.lua
--
-- Where the model, the text and the carried randomness sit inside the one file
-- a firmware opens. Written down once, here, because it was written down twice
-- and the two did not agree. Issue 502.
--
-- For a general: the machine and everything it thinks with travel as a single
-- file, because a firmware loads that file whole before the first instruction
-- runs -- so anything inside it is simply in memory when the machine wakes,
-- with nothing to read and no driver needed to read it. This says what goes
-- where inside that file.
--
-- WHY THIS FILE EXISTS, WHICH IS THE INTERESTING PART. Three arrangements of
-- the same five things existed in this project and only two were ever read:
--
--   * 029 puts an appended blob a fixed distance past the code, and the machine
--     finds it by measuring from where it is standing. This is real and it is
--     what boots.
--   * 140 divided that blob into model, text and randomness -- inside a TEST,
--     where nothing else could reach it. Also real, also what boots.
--   * 089 laid five regions down at block boundaries, in a different order,
--     with different alignment, and checked them against expectations written
--     out again by hand in its own test. Nothing has ever read that
--     arrangement. It was correct and it described a machine nobody built.
--
-- So the layout that is real lived in a test and the layout that was documented
-- lived in a builder. This is the first one, moved somewhere both can reach.
--
-- WHAT THIS DELIBERATELY DOES NOT KNOW. Where the blob itself goes -- that is
-- 029's business, and it is a fixed distance past the code so that a payload
-- which outgrew the distance is refused rather than having its own instructions
-- read as weights. Splitting the two means neither has to know the other's
-- number.

local M = {}

-- {{{ M.ALIGNMENT -- what each part inside the blob starts on
-- Sixteen bytes. Not a hardware requirement -- nothing here is loaded by a
-- processor that cares -- but the arrangement 140 has been booting with since
-- the driver first spoke, and changing it would change where a working machine
-- looks for its own weights.
M.ALIGNMENT = 16
-- }}}

-- {{{ M.ORDER -- the parts, in the order they sit
-- The model first because it is the largest and because a machine that finds
-- nothing else can still count its own weights; then what it is told; then the
-- randomness it draws with.
M.ORDER = { "model", "text", "randomness" }
-- }}}

-- {{{ M.plan(parts)
--
-- parts: a table of name -> bytes, holding some or all of M.ORDER.
--
-- Returns { at = { name -> offset }, bytes = the blob, size = #bytes }.
--
-- Every offset is measured from the start of the blob, which is itself a fixed
-- distance past the code (029). A part that is absent takes no room and is
-- given no offset, so a caller can ask what a machine with no carried
-- randomness would look like without inventing an empty one.
function M.plan(parts)
  local at, cursor = {}, 0
  for _, name in ipairs(M.ORDER) do
    local content = parts[name]
    if content and #content > 0 then
      at[name] = cursor
      cursor = cursor + #content
      local over = cursor % M.ALIGNMENT
      if over ~= 0 then cursor = cursor + (M.ALIGNMENT - over) end
    end
  end

  local pieces, written = {}, 0
  for _, name in ipairs(M.ORDER) do
    local content = parts[name]
    if content and #content > 0 then
      if at[name] > written then
        pieces[#pieces + 1] = string.rep("\0", at[name] - written)
        written = at[name]
      end
      pieces[#pieces + 1] = content
      written = written + #content
    end
  end

  return { at = at, bytes = table.concat(pieces), size = written }
end
-- }}}

-- {{{ M.expectations(plan)
-- The same thing said the way a seam check wants to hear it: what the machine
-- believes about where its pieces are.
--
-- THIS IS THE POINT OF THE FILE. 089's check compared the builder's layout
-- against expectations typed out again in a test, so it compared two copies of
-- a belief rather than a belief against a fact -- which is why it passed for
-- months while describing an arrangement nothing implemented. Derived from the
-- plan, the two cannot drift, because there is only one of them.
function M.expectations(plan)
  local out = {}
  for name, offset in pairs(plan.at) do
    out[name] = { at = offset }
  end
  return out
end
-- }}}

return M
