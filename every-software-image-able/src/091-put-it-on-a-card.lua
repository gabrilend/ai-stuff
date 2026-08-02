#!/usr/bin/env luajit
-- 091-put-it-on-a-card.lua
--
-- The image reaches a physical medium. Issue 503, and the only operation in
-- this project that cannot be undone by writing more software.
--
-- For a general: everything else here can be fixed by building it again.
-- This one writes over whatever was on somebody's disk, and if it is the
-- wrong disk that data is gone. So the confirmation is uncomfortable on
-- purpose, and the discomfort is a feature rather than an oversight.
--
-- THE OPERATOR NAMES THE DEVICE AND SOMETHING ABOUT IT. Not just the path --
-- device paths move between one boot and the next, and the disk that was the
-- second one yesterday may be somebody's photographs today. Naming the size
-- or the serial as well means a mistake has to be made twice, identically,
-- to get through.
--
-- WRITTEN, THEN READ BACK, THEN COMPARED. Against the identity the builder
-- produced (502), and the comparison is REPORTED rather than assumed. A
-- flasher that says "done" without reading anything back has told you that
-- it finished, which is a different fact from the card being right.
--
-- READ-ONLY MEDIA ARE PREFERRED, and this says so where an operator will see
-- it. A seed nothing can write to can be carried from machine to machine
-- indefinitely, plants the same thing every time, and cannot be damaged by a
-- computer dying halfway through being started (docs/003).
--
-- usage:
--   luajit 091-put-it-on-a-card.lua --image FILE --to DEVICE --size BYTES
--                                   [--to DEVICE --size BYTES ...]
--                                   [--i-know] [--dry-run]

local M = {}

-- {{{ M.WHAT_IT_ASKS -- the confirmation, and why it is shaped like this
M.WHAT_IT_ASKS =
  "This writes over everything on that device. Every other mistake in this\n"
  .. "project can be repaired by building something again. This one cannot.\n"
  .. "\n"
  .. "Type the size in bytes of the device you named, exactly, to go ahead."
-- }}}

-- {{{ M.look(where)
-- What is actually at a path, so the operator's claim can be checked against
-- the machine's own account rather than trusted.
function M.look(where, run)
  run = run or function(command)
    local pipe = io.popen(command .. " 2>/dev/null")
    if not pipe then return "" end
    local text = pipe:read("*a")
    pipe:close()
    return text
  end

  local found = { path = where }

  -- size in bytes, from the kernel's own account of the block device
  local name = where:match("([^/]+)$")
  local size = run("cat /sys/class/block/" .. tostring(name) .. "/size")
  local blocks = tonumber((size or ""):match("%d+"))
  if blocks then found.bytes = blocks * 512 end

  local removable = run("cat /sys/class/block/" .. tostring(name) .. "/removable")
  found.removable = (removable or ""):match("1") ~= nil

  local read_only = run("cat /sys/class/block/" .. tostring(name) .. "/ro")
  found.read_only = (read_only or ""):match("1") ~= nil

  local model = run("cat /sys/class/block/" .. tostring(name) .. "/device/model")
  found.model = (model or ""):gsub("%s+$", "")

  return found
end
-- }}}

-- {{{ M.check(target, image_bytes, found)
-- Everything that must be true before anything is written. Returns true, or
-- nil and every reason -- all of them, because an operator about to do
-- something irreversible should see the whole objection rather than fix one
-- thing at a time and try again.
function M.check(target, image_bytes, found)
  local wrong = {}

  if not found.bytes then
    wrong[#wrong + 1] = "nothing at '" .. target.where .. "' looks like a "
      .. "device this machine knows the size of"
  elseif target.size ~= found.bytes then
    wrong[#wrong + 1] = string.format(
      "you said '%s' is %d bytes and it is %d. One of those is a different "
      .. "device than you think.", target.where, target.size, found.bytes)
  end

  if found.read_only then
    wrong[#wrong + 1] = "'" .. target.where .. "' cannot be written to. That "
      .. "is the preferred kind of medium for a seed, and it means this "
      .. "particular card is already finished or is not the one to write."
  end

  if found.bytes and image_bytes > found.bytes then
    wrong[#wrong + 1] = string.format(
      "the image is %d bytes and '%s' holds %d",
      image_bytes, target.where, found.bytes)
  end

  if found.removable == false then
    -- Not refused, because a fixed disk is sometimes genuinely the target.
    -- Said loudly, because it is usually somebody's computer.
    wrong[#wrong + 1] = "'" .. target.where .. "' is not removable. Fixed "
      .. "disks are usually the machine somebody is standing at. Pass "
      .. "--i-know if you mean it."
  end

  if #wrong > 0 then return nil, wrong end
  return true
end
-- }}}

-- {{{ M.write(target, image, options)
-- Write, read back, compare, report.
function M.write(target, image, options)
  options = options or {}
  local report = { where = target.where, bytes = #image }

  if options.dry_run then
    report.wrote = false
    report.note = "nothing was written; this was a dry run"
    return report
  end

  local handle = io.open(target.where, "wb")
  if not handle then
    return nil, "cannot open '" .. target.where .. "' to write to it"
  end
  handle:write(image)
  handle:close()

  -- Read back rather than trust. A flasher that says "done" without reading
  -- anything back has told you it finished, which is a different fact from
  -- the card being right.
  handle = io.open(target.where, "rb")
  if not handle then
    return nil, "wrote it and then could not read '" .. target.where
      .. "' back, so what is on it is unknown"
  end
  local back = handle:read(#image)
  handle:close()

  report.wrote = true
  report.read_back = back ~= nil and #back or 0
  report.matches = (back == image)

  if not report.matches then
    -- where they first differ, because "it did not match" is a question and
    -- "it differs at byte 4096" is an answer.
    local at = nil
    for index = 1, math.min(#image, #(back or "")) do
      if image:sub(index, index) ~= back:sub(index, index) then at = index break end
    end
    report.differs_at = at
  end

  return report
end
-- }}}

-- {{{ M.run(options)
-- The whole thing, over however many cards were named. One image is meant to
-- serve many machines, and doing them one at a time is where mistakes come
-- from.
function M.run(options)
  local image = options.image
  local results = {}

  for _, target in ipairs(options.targets) do
    local found = options.look(target.where)
    local ok, objections = M.check(target, #image, found)

    if not ok and not (options.i_know and #objections == 1
                       and objections[1]:find("not removable")) then
      results[#results + 1] = { where = target.where, refused = true,
                                why = objections }
    else
      local report, why = M.write(target, image, options)
      if not report then
        results[#results + 1] = { where = target.where, refused = true,
                                  why = { why } }
      else
        report.identity = options.identity
        results[#results + 1] = report
      end
    end
  end

  return results
end
-- }}}

-- {{{ M.say_what_happened(results)
function M.say_what_happened(results)
  local lines = {}
  local written, refused = 0, 0
  for _, result in ipairs(results) do
    if result.refused then
      refused = refused + 1
      lines[#lines + 1] = "  " .. result.where .. "  NOT WRITTEN"
      for _, why in ipairs(result.why) do
        lines[#lines + 1] = "      " .. why
      end
    elseif not result.wrote then
      lines[#lines + 1] = "  " .. result.where .. "  " .. (result.note or "")
    elseif result.matches then
      written = written + 1
      lines[#lines + 1] = string.format("  %s  written and read back, %d bytes, "
        .. "matching%s", result.where, result.bytes,
        result.identity and (" -- " .. result.identity) or "")
    else
      lines[#lines + 1] = string.format("  %s  WRITTEN BUT WRONG: what came "
        .. "back differs at byte %s. Do not use this card.",
        result.where, tostring(result.differs_at))
    end
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  " .. written .. " written, " .. refused .. " refused"
  return table.concat(lines, "\n")
end
-- }}}

return M
