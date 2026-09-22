#!/usr/bin/env lua
-- transcript-repair-plan.lua - Work out what every archived transcript
-- SHOULD be called and stamped, and say so. Decides nothing about carrying it
-- out; the shell driver does that. Generating the answer and acting on the
-- answer are kept apart on purpose, so a wrong answer can be read before it
-- becomes a wrong rename.
--
-- Input, one file per line on stdin:   <stored mtime epoch>\t<full path>
-- Output, one decision per line:       dir\tfile\ttier\tdest\ttrue_epoch\taction
--
-- Arguments:
--   --logs <file>     conversation ids whose session log still exists
--   --history <file>  sessionId\tfirst_epoch\tlast_epoch, from the prompt log
--
-- The three tiers, and why each is trusted only as far as it goes, are
-- described in issues/018-date-range-transcript-naming.md.

-- {{{ DIR + shared reasoning
-- Hard-coded default root, overridable by argument, so this runs from any
-- directory (house convention).
local DIR = os.getenv("REPAIR_DIR") or "/home/ritz/programming/ai-stuff/scripts"
local parser = dofile(DIR .. "/libs/conversation-parser.lua")
local utc_fields_to_epoch = parser.utc_fields_to_epoch
-- }}}

-- The header every real transcript opens with. Anything else in one of these
-- folders is derived output or a hand-written note, and is not ours to move.
local HEADER_PREFIX = "# Conversation Summary: "

-- How far a file's stamp may sit after a conversation's last prompt before we
-- stop believing it describes that conversation at all. A reply follows its
-- prompt by seconds or minutes; a whole day's distance means the stamp is
-- recording something else that happened to the file.
local STAMP_TRUST_WINDOW = 24 * 60 * 60

-- {{{ read_lookup_table(path, columns) -> table
-- Both lookup files are plain tab-separated text with the key first. One
-- column asked for yields a set; more yields a row per key.
local function read_lookup_table(path, columns)
    local out = {}
    local fh = io.open(path, "r")
    if not fh then return out end
    for line in fh:lines() do
        if line ~= "" then
            local fields = {}
            for field in line:gmatch("[^\t]+") do fields[#fields + 1] = field end
            if columns == 1 then
                out[fields[1]] = true
            elseif fields[2] then
                out[fields[1]] = { first = tonumber(fields[2]), last = tonumber(fields[3]) }
            end
        end
    end
    fh:close()
    return out
end
-- }}}

-- {{{ true_epoch_from_stamp(stored) -> epoch
-- Undo the fault on one stored modification time.
--
-- The stamp was made by taking a UTC clock reading and building an instant
-- from it as though the reading were local. Rendering the stamp back in local
-- time therefore returns that original UTC reading, field for field; reading
-- those fields AS UTC gives the instant the last message really happened at.
-- The error cancels exactly, daylight saving included, because each half
-- consults the rules in force on its own date.
local function true_epoch_from_stamp(stored)
    return utc_fields_to_epoch(os.date("*t", stored))
end
-- }}}

-- {{{ date_token(epoch) -> "mon-d-yy"
-- The compact calendar token the filenames are built from. Month names are
-- spelled out here rather than taken from os.date("%b") so the answer does
-- not change under a different locale.
local MONTH_NAMES = { "jan", "feb", "mar", "apr", "may", "jun",
                      "jul", "aug", "sep", "oct", "nov", "dec" }
local function date_token(epoch)
    local t = os.date("*t", epoch)
    return string.format("%s-%d-%02d", MONTH_NAMES[t.month], t.day, t.year % 100)
end
-- }}}

-- {{{ span_basename(start_epoch, end_epoch) -> base
-- One day collapses to a single token; a real span reads start-through-end.
-- The endpoints are put in order first: every source here is an independent
-- witness, and two witnesses can contradict each other, but a filename that
-- runs backwards helps nobody read the folder.
local function span_basename(start_epoch, end_epoch)
    if start_epoch > end_epoch then
        start_epoch, end_epoch = end_epoch, start_epoch
    end
    local first, last = date_token(start_epoch), date_token(end_epoch)
    if first == last then return first end
    return first .. "-through-" .. last
end
-- }}}

-- {{{ strip_suffix(filename) -> base
-- Reduce a transcript filename to its span base by shedding the trailing
-- collision marker and the extension.
local function strip_suffix(filename)
    local base = filename:gsub("%.md$", "")
    base = base:gsub("_agent%-%d+$", "")
    return base
end
-- }}}

-- {{{ read_header_id(path) -> conversation id or nil
-- Identity lives in the first line, not the name, which is what makes a bulk
-- rename safe in the first place.
local function read_header_id(path)
    local fh = io.open(path, "r")
    if not fh then return nil end
    local first = fh:read("*l")
    fh:close()
    if not first then return nil end
    if first:sub(1, #HEADER_PREFIX) ~= HEADER_PREFIX then return nil end
    return (first:sub(#HEADER_PREFIX + 1):gsub("%s+$", ""))
end
-- }}}

-- {{{ split_path(path) -> dir, file
local function split_path(path)
    local dir, file = path:match("^(.*)/([^/]+)$")
    return dir, file
end
-- }}}

-- {{{ parse_arguments(argv) -> options
local function parse_arguments(argv)
    local options = { logs = nil, history = nil }
    local index = 1
    while index <= #argv do
        local flag = argv[index]
        if flag == "--logs" then
            index = index + 1; options.logs = argv[index]
        elseif flag == "--history" then
            index = index + 1; options.history = argv[index]
        end
        index = index + 1
    end
    return options
end
-- }}}

-- {{{ collect_input() -> records
-- Read the stamp-and-path list, keep only the real transcripts, and note the
-- identity and stamp of each. Grouped by folder, because naming decisions are
-- only ever made against the other files sharing a folder.
local function collect_input()
    local by_directory, order = {}, {}
    for line in io.lines() do
        local stamp, path = line:match("^(%d+)\t(.+)$")
        if stamp and path then
            local conversation_id = read_header_id(path)
            if conversation_id then
                local dir, file = split_path(path)
                if not by_directory[dir] then
                    by_directory[dir] = {}
                    order[#order + 1] = dir
                end
                table.insert(by_directory[dir], {
                    file = file,
                    id = conversation_id,
                    stored = tonumber(stamp),
                })
            end
        end
    end
    return by_directory, order
end
-- }}}

-- {{{ find_flattened_stamps(entries, history) -> set of stamps
-- Decide which stamps in a folder are not describing their own file.
--
-- A bulk copy, a restore or a checkout rewrites every file's modification
-- time to the moment of that operation, and the archive has folders where
-- hundreds of files carry one identical second. Counting files per stamp does
-- not by itself catch it, because a conversation and its sidechains honestly
-- do share a last message - a hundred files on one stamp can be perfectly
-- truthful.
--
-- What separates the two is a second witness. Where a file's own session is
-- in the prompt history, we already know roughly when it ended; if the stamp
-- sits a day or more past that, the stamp is recording something that
-- happened to the file rather than something that happened in it. One such
-- disproof condemns the stamp for every file sharing it, because they were
-- all written by the same event.
local function find_flattened_stamps(entries, history)
    local flattened = {}
    for _, entry in ipairs(entries) do
        local span = history[entry.id]
        if span then
            local true_end = true_epoch_from_stamp(entry.stored)
            if true_end - span.last > STAMP_TRUST_WINDOW then
                flattened[entry.stored] = true
            end
        end
    end
    return flattened
end
-- }}}

-- {{{ decide_dates(entry, logs, history, flattened) -> tier, start, finish
-- Choose the best pair of instants for one transcript, and name the grounds.
-- Ordered from strongest evidence to weakest; a tier is only reached when
-- every stronger one has nothing to say about this file.
local function decide_dates(entry, logs, history, flattened)
    if logs[entry.id] then
        -- The session log survives. The exporter will rebuild this file from
        -- it, which recovers both ends properly, so nothing is decided here.
        return "rebuild", nil, nil
    end

    local span = history[entry.id]
    local stamp_is_sound = not flattened[entry.stored]

    if span then
        -- Both ends from the prompt history, and the file's own timestamp
        -- ignored entirely even when it looks sound.
        --
        -- The end is strictly the last PROMPT, not the last word: the
        -- assistant's closing reply lands after it and is recorded nowhere
        -- here. Measured over the whole archive, that distinction moves the
        -- calendar day for one file in sixty-eight, and it was judged not
        -- worth having - because what it buys is worth a great deal more.
        --
        -- The prompt history counts in milliseconds since the epoch, which
        -- names an instant outright rather than describing a clock reading.
        -- Nothing about it depends on the current state of the file, so
        -- deciding this transcript twice gives the same answer twice. Every
        -- other route to a date here runs through the timestamp, and undoing
        -- the fault in a timestamp cannot tell whether it has already been
        -- done. These files are therefore safe to reconsider at any time,
        -- with or without the note that guards the rest.
        return "history", span.first, span.last
    end

    if stamp_is_sound then
        -- Nothing but the stamp, which is sound. It records the last message,
        -- so the end is recoverable and the start is not - and these files
        -- carry a single-day name, whose whole content is that end date.
        --
        -- This is the one route that cannot be walked twice. Inverting a
        -- timestamp that has already been inverted simply subtracts the
        -- offset again, and nothing in the file says which it is, so these
        -- files are the reason the repair leaves a note behind.
        local true_end = true_epoch_from_stamp(entry.stored)
        return "stamp", true_end, true_end
    end

    -- Every witness has failed: the stamp was disproved by its neighbours and
    -- this conversation left no prompt history. Inventing a date here is
    -- exactly the sort of quiet fallback that makes an archive untrustworthy,
    -- so the file is left alone and reported instead.
    return "no-evidence", nil, nil
end
-- }}}

-- {{{ sidechain_last(entries) -> sorted copy
-- Plan the main conversations before their sidechains, which is the order the
-- exporter hands out the bare name and the numbered slots behind it. Within
-- each group the current name orders them, so a re-run decides the same way.
local function sidechain_last(entries)
    local sorted = {}
    for index, entry in ipairs(entries) do sorted[index] = entry end
    table.sort(sorted, function(left, right)
        local left_side = left.id:sub(1, 6) == "agent-"
        local right_side = right.id:sub(1, 6) == "agent-"
        if left_side ~= right_side then return right_side end
        return left.file < right.file
    end)
    return sorted
end
-- }}}

-- {{{ pick_slot(dir, base, claimed, own_name, vacating) -> filename
-- The first claimant of a span gets the bare name and later ones fall into
-- numbered slots.
--
-- Three things can make a name unavailable, and only one of them is what a
-- single rename would check. A name already handed out earlier in this same
-- plan is taken even though nothing has moved yet. A name sitting on disk is
-- taken - unless the file holding it is itself leaving, which is the case a
-- bulk shift creates constantly: when every file slides back a day, the name
-- each one wants is usually held by its neighbour, who is sliding too. Left
-- unaccounted for, that turned ordinary conversations into "_agent-1", a
-- suffix that means a sidechain to every reader of this archive.
local function pick_slot(dir, base, claimed, own_name, vacating)
    local number = 0
    while true do
        local candidate
        if number == 0 then
            candidate = base .. ".md"
        else
            candidate = string.format("%s_agent-%d.md", base, number)
        end
        if candidate == own_name then return candidate end
        if not claimed[candidate] then
            if vacating[candidate] then return candidate end
            local existing = io.open(dir .. "/" .. candidate, "r")
            if not existing then return candidate end
            existing:close()
        end
        number = number + 1
    end
end
-- }}}

-- {{{ plan_directory(dir, entries, logs, history)
-- Decide every file in one folder together.
--
-- Done in two passes rather than one. The first works out what each file
-- deserves to be called and, from that, which of the folder's current names
-- are about to be given up. Only then can the second pass hand out names
-- knowing that a neighbour's name may be free by the time anyone needs it.
-- One pass cannot know this, because the answer for the first file depends
-- on a decision not yet made about the last.
local function plan_directory(dir, entries, logs, history)
    local flattened = find_flattened_stamps(entries, history)
    local ordered = sidechain_last(entries)

    -- First pass: the verdict and the wanted span for every file, and the
    -- set of names their owners are leaving behind.
    local decided, vacating = {}, {}
    for index, entry in ipairs(ordered) do
        local tier, start_epoch, end_epoch =
            decide_dates(entry, logs, history, flattened)
        local wanted = nil
        if tier ~= "rebuild" and tier ~= "no-evidence" then
            wanted = span_basename(start_epoch, end_epoch)
            if wanted ~= strip_suffix(entry.file) then
                vacating[entry.file] = true
            end
        end
        decided[index] = { tier = tier, wanted = wanted, finish = end_epoch }
    end

    -- Second pass: hand out the names.
    local claimed = {}
    for index, entry in ipairs(ordered) do
        local verdict = decided[index]

        if verdict.wanted == nil then
            io.write(string.format("%s\t%s\t%s\t%s\t0\tskip\n",
                dir, entry.file, verdict.tier, entry.file))
        elseif verdict.wanted == strip_suffix(entry.file) then
            claimed[entry.file] = true
            io.write(string.format("%s\t%s\t%s\t%s\t%d\tstamp-only\n",
                dir, entry.file, verdict.tier, entry.file, verdict.finish))
        else
            local dest = pick_slot(dir, verdict.wanted, claimed, entry.file, vacating)
            claimed[dest] = true
            -- Once taken, the name is no longer one that anybody is leaving.
            vacating[dest] = nil
            io.write(string.format("%s\t%s\t%s\t%s\t%d\trename\n",
                dir, entry.file, verdict.tier, dest, verdict.finish))
        end
    end
end
-- }}}

-- {{{ main()
local function main()
    local options = parse_arguments(arg)
    local logs = read_lookup_table(options.logs or "", 1)
    local history = read_lookup_table(options.history or "", 3)

    local by_directory, order = collect_input()
    for _, dir in ipairs(order) do
        plan_directory(dir, by_directory[dir], logs, history)
    end
    return 0
end
-- }}}

os.exit(main())
