-- 002-narrator.lua
--
-- What the program says about itself.
--
-- Not to be confused with the herald, which is phase six and writes prose
-- about the game. This one writes about the program. Mixing the two is how
-- somebody listening to a story hears a stack trace.
--
-- Lines are sentences, not tagged fields. The reason is not taste: these logs
-- get read by somebody trying to find out why a turn came out wrong, possibly
-- through a screen reader, possibly weeks later, and a line that needs the
-- codebase to interpret is a line that gets skipped.
--
-- Everything lands in the RAM tier. Logs are ephemeral by nature and paying
-- disk for them buys nothing.

local narrator = {}

local log_handle = nil
local log_path = nil
local echo_to_terminal = true

-- {{{ local function timestamp()
local function timestamp()
   return os.date("%H:%M:%S")
end
-- }}}

-- {{{ function narrator.open()
-- Opens the log. `scratch` is the shared-memory directory, which the input
-- gate creates; `name` distinguishes one run's log from another's.
--
-- Append rather than truncate, and flush every line, so a run can be followed
-- with tail while it is happening. That costs a little speed and buys the
-- ability to watch a long survey move, which is what stops somebody killing it
-- because they assumed it had hung.
function narrator.open(scratch, name)
   log_path = scratch .. "/" .. (name or "interpreter") .. ".log"
   local handle, reason = io.open(log_path, "a")
   if not handle then
      -- Failing to open a log is worth stopping for. A program that cannot
      -- say what it is doing should not go on to do something irreversible.
      error("cannot open the log at " .. log_path .. ": " .. tostring(reason))
   end
   log_handle = handle
   return log_path
end
-- }}}

-- {{{ function narrator.quiet()
-- Stops echoing to the terminal. For tests, and for the conversation surface,
-- where program chatter must not interleave with what a person is reading.
function narrator.quiet(silent)
   echo_to_terminal = not silent
end
-- }}}

-- {{{ local function emit()
local function emit(marker, sentence)
   local line = string.format("%s %s %s", timestamp(), marker, sentence)
   if log_handle then
      log_handle:write(line, "\n")
      log_handle:flush()
   end
   if echo_to_terminal then
      io.stderr:write(line, "\n")
   end
end
-- }}}

-- {{{ function narrator.say()
-- What happened. The ordinary level.
function narrator.say(sentence)
   emit("--", sentence)
end
-- }}}

-- {{{ function narrator.worry()
-- What is worrying, and why - the reason is not optional, and passing nothing
-- for it is a programming error caught here rather than an empty string
-- written to a file somebody will read later and learn nothing from.
--
-- This level carries the house rule that makes it worth having: a fallback is
-- a warning and a warning is an error. Any path that substitutes a default for
-- something it could not read announces itself here, by name, every time. The
-- log is where that promise is kept or broken.
function narrator.worry(sentence, reason)
   if not reason or reason == "" then
      error("narrator.worry needs a reason: " .. tostring(sentence))
   end
   emit("??", sentence .. " - " .. reason)
end
-- }}}

-- {{{ function narrator.stop()
-- What stopped. Logs, then raises, because the two should never disagree
-- about what went wrong.
function narrator.stop(sentence)
   emit("!!", sentence)
   error(sentence, 2)
end
-- }}}

-- {{{ function narrator.timer()
-- Returns a function that returns elapsed seconds. Cheap now; the thing that
-- will be wanted most once three machines are involved and the question
-- becomes which of them is slow.
--
-- os.clock measures processor time, which is the wrong quantity the moment
-- anything waits on a socket, so wall clock it is - at one-second resolution,
-- which is enough for "did that take four seconds or four hundred".
function narrator.timer()
   local started = os.time()
   return function()
      return os.difftime(os.time(), started)
   end
end
-- }}}

-- {{{ function narrator.path()
function narrator.path()
   return log_path
end
-- }}}

-- {{{ function narrator.close()
function narrator.close()
   if log_handle then
      log_handle:close()
      log_handle = nil
   end
end
-- }}}

return narrator
