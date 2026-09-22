#!/usr/bin/env lua
-- test_conversation-parser-timezone.lua
-- Validates issue #018's correction: a transcript is dated by the calendar
-- day the conversation happened on in LOCAL time, and its final timestamp is
-- the true instant of the last message.
--
-- Why this test exists. The session log records every message as an ISO
-- instant ending in "Z", which is UTC. The parser used to copy those date
-- characters into the filename verbatim and to build the mtime by handing
-- UTC fields to os.time, which reads what it is given as local. Both were
-- wrong by one UTC offset, and because they were wrong in the same direction
-- they agreed with each other, so nothing downstream ever contradicted them.
-- Only an absolute reference - a known epoch, or a second timezone - catches
-- it, which is exactly what this test supplies.
--
-- Timezone is pinned per case rather than inherited, so the expectations mean
-- the same thing on any machine, and so that one fixture can be run through
-- two zones to prove the parser follows the zone instead of hard-coding one.
--
-- Self-contained: writes fixture JSONL, drives the parser as a subprocess the
-- way the exporter does, and asserts on the signal lines it writes to stderr.
-- Run: `lua test_conversation-parser-timezone.lua`.

-- {{{ DIR + paths
-- Hard-coded default root, overridable by argument, so the test runs from any
-- directory (house convention).
local DIR = arg[1] or "/home/ritz/programming/ai-stuff/scripts"
local PARSER = DIR .. "/libs/conversation-parser.lua"
local TMP = os.getenv("TMPDIR") or "/tmp"
-- }}}

-- {{{ write_file(path, text)
local function write_file(path, text)
    local f = assert(io.open(path, "w"))
    f:write(text)
    f:close()
end
-- }}}

-- {{{ read_file(path)
local function read_file(path)
    local f = io.open(path, "r")
    if not f then return "" end
    local s = f:read("*all")
    f:close()
    return s
end
-- }}}

-- {{{ run_parser_signals(jsonl_text, tz) -> signals
-- The dates and the final timestamp do not appear in the markdown; the parser
-- reports them on stderr for the exporter to read, so that is what we capture.
local function run_parser_signals(jsonl_text, tz)
    local infile  = TMP .. "/tz_fixture_in.jsonl"
    local outfile = TMP .. "/tz_fixture_out.md"
    local errfile = TMP .. "/tz_fixture_err.txt"
    write_file(infile, jsonl_text)
    os.execute(string.format("TZ=%q lua %q %q %q >/dev/null 2>%q",
        tz, PARSER, infile, outfile, errfile))
    return read_file(errfile)
end
-- }}}

-- {{{ signal(signals, key) -> value
local function signal(signals, key)
    return signals:match(key .. ":([^\n]*)")
end
-- }}}

local failures = 0
-- {{{ check(condition, description)
local function check(condition, description)
    if condition then
        print("  ok   - " .. description)
    else
        print("  FAIL - " .. description)
        failures = failures + 1
    end
end
-- }}}

-- {{{ conversation(first_iso, last_iso) -> jsonl
-- The smallest log that still has a distinct first and last message, which is
-- all the date reducers read. Content is irrelevant here.
local function conversation(first_iso, last_iso)
    return table.concat({
        '{"type":"user","message":{"role":"user","content":"start"},"uuid":"u1","timestamp":"' .. first_iso .. '"}',
        '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"finish"}]},"uuid":"a1","timestamp":"' .. last_iso .. '"}',
    }, "\n") .. "\n"
end
-- }}}

-- An evening session on the American west coast. Both of its messages fall
-- after 5pm local, which is already the following day in UTC - the window
-- where the old code filed everything a day late.
local EVENING = conversation("2026-09-16T03:10:00.000Z", "2026-09-17T02:49:33.001Z")

print("An evening conversation is dated by the local day, not the UTC one:")
local la = run_parser_signals(EVENING, "America/Los_Angeles")
check(signal(la, "START_DATE") == "2026-09-15",
    "start date is the local evening (15th), not the UTC morning (16th)")
check(signal(la, "FINAL_DATE") == "2026-09-16",
    "end date is the local evening (16th), not the UTC morning (17th)")
check(signal(la, "FINAL_TIMESTAMP") == "1789613373",
    "final timestamp is the true instant of the last message")

print("The same log read in another zone follows that zone:")
local utc = run_parser_signals(EVENING, "UTC")
check(signal(utc, "START_DATE") == "2026-09-16",
    "under UTC the start date is the 16th")
check(signal(utc, "FINAL_DATE") == "2026-09-17",
    "under UTC the end date is the 17th")
check(signal(utc, "FINAL_TIMESTAMP") == "1789613373",
    "the instant itself does not move between zones")

print("A midday conversation is left where it is:")
local midday = run_parser_signals(
    conversation("2026-06-15T19:00:00.000Z", "2026-06-15T19:00:00.000Z"),
    "America/Los_Angeles")
check(signal(midday, "START_DATE") == "2026-06-15",
    "a session wholly inside one local day keeps that day")
check(signal(midday, "FINAL_TIMESTAMP") == "1781550000",
    "midday instant is exact")

-- Daylight saving is where a measured offset can go wrong in a way that is
-- invisible for half the year: a UTC breakdown reports no daylight saving, so
-- a conversion that trusts that field computes at the standard offset while
-- the rest of the summer runs an hour ahead of it.
print("Both daylight-saving boundaries land on the right instant:")
local spring_before = run_parser_signals(
    conversation("2026-03-08T09:30:00.000Z", "2026-03-08T09:30:00.000Z"),
    "America/Los_Angeles")
check(signal(spring_before, "FINAL_TIMESTAMP") == "1772962200",
    "the half hour before spring-forward is exact")

local spring_after = run_parser_signals(
    conversation("2026-03-08T10:30:00.000Z", "2026-03-08T10:30:00.000Z"),
    "America/Los_Angeles")
check(signal(spring_after, "FINAL_TIMESTAMP") == "1772965800",
    "the half hour after spring-forward is exact")

local autumn = run_parser_signals(
    conversation("2026-11-01T08:30:00.000Z", "2026-11-01T08:30:00.000Z"),
    "America/Los_Angeles")
check(signal(autumn, "FINAL_TIMESTAMP") == "1793521800",
    "the fall-back morning is exact")

print("")
if failures == 0 then
    print("All timezone checks passed.")
    os.exit(0)
else
    print(failures .. " check(s) failed.")
    os.exit(1)
end
