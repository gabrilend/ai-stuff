#!/usr/bin/env luajit
-- claudemd-revise.lua - propose CLAUDE.md guidelines from repeated events,
-- and apply them only when you approve each one.
--
-- Issue 040, its smallest useful slice. Scripts and sessions record events
-- (a correction, a repeated instruction, a discovered convention). When the
-- same event has been seen often enough, `suggest` asks the local model to
-- word it as one guideline and files that as a proposal. Nothing reaches a
-- CLAUDE.md file until you run `approve` on a proposal and name the file.
-- Every approval backs the file up first and is written to an audit trail,
-- and `rollback` puts the file back as long as nobody has edited it since.
--
-- Usage:
--   claudemd-revise.lua event KIND TEXT       record an event
--                       (KIND: correction, instruction, convention)
--   claudemd-revise.lua events                list the recorded events, counted
--   claudemd-revise.lua suggest [--min=N]     word each event seen N times
--                                             (default 3) as a proposal, via the model
--   claudemd-revise.lua propose TEXT [--reason=WHY]   file a proposal directly
--   claudemd-revise.lua list [--all]          pending proposals (or all)
--   claudemd-revise.lua approve ID --target=FILE   add it to FILE (after a backup)
--   claudemd-revise.lua reject ID [--reason=WHY]
--   claudemd-revise.lua rollback ID --target=FILE  undo an approval, if FILE is
--                                             unchanged since
--   claudemd-revise.lua history [--id=ID] [--action=A] [--since=DATE]
--                                             the audit trail, or part of it
--   claudemd-revise.lua show ID               how a guideline came to be:
--                                             its events, proposal and timeline
--   claudemd-revise.lua diff ID               what its approval changed
--   claudemd-revise.lua report [--since=DATE] counts of events, proposals, actions
--   claudemd-revise.lua verify                check the audit trail and backups
--   claudemd-revise.lua prune [--keep=N] [--yes]   backup rotation: show which
--                                             backups beyond the newest N (default
--                                             100) would go; --yes removes them.
--                                             A backup a rollback needs is kept.
--
-- Options: --state=DIR  where events, proposals, backups and the audit trail
--          live (default ~/.local/share/claudemd-revisions, outside any
--          repository, since events can hold anything said in a session)
--
-- The model is reached through libs/llama-chat-client.lua (INFERENCE_CHAT_HOST
-- moves it). Only `suggest` uses it. Exit status: 0 done, 1 refused or nothing
-- to do, 2 usage error.

-- {{{ DIR Configuration
local SCRIPT_DIR = (arg[0]:match("(.*)/[^/]*$") or ".")
package.path = SCRIPT_DIR .. "/libs/?.lua;" .. package.path
local STATE = (os.getenv("XDG_DATA_HOME") or ((os.getenv("HOME") or ".") .. "/.local/share"))
    .. "/claudemd-revisions"
-- }}}

-- {{{ Configuration
local config = {
    kinds = { correction = true, instruction = true, convention = true },
    section = "## Learned conventions",
    max_guideline = 200,
    keep_backups = 100,   -- prune keeps this many of the newest backups
    system_prompt = table.concat({
        "Task: propose-guideline.",
        "You maintain a CLAUDE.md file of working guidelines for an AI coding assistant.",
        "The user message lists one event that keeps happening in sessions, with how often.",
        "Reply with exactly one line: a markdown bullet starting with \"- \" that states the",
        "guideline the event implies, in the imperative, under 200 characters. Nothing else.",
    }, "\n"),
}
-- }}}

-- {{{ Utility Functions
-- {{{ local function fail()
local function fail(message, code)
    io.stderr:write("claudemd-revise: " .. message .. "\n")
    os.exit(code or 2)
end
-- }}}

-- {{{ local function shell_quote()
local function shell_quote(text)
    return "'" .. text:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function read_file()
local function read_file(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local text = file:read("*a")
    file:close()
    return text
end
-- }}}

-- {{{ local function write_file()
local function write_file(path, text)
    local file = io.open(path, "w")
    if not file then return false end
    file:write(text)
    file:close()
    return true
end
-- }}}

-- {{{ local function append_row()
local function append_row(path, fields)
    local file = io.open(path, "a")
    if not file then fail("cannot write " .. path, 1) end
    file:write(table.concat(fields, "\t") .. "\n")
    file:close()
end
-- }}}

-- {{{ local function read_rows()
local function read_rows(path, columns)
    local rows = {}
    local text = read_file(path) or ""
    for line in text:gmatch("[^\n]+") do
        local fields, row = {}, {}
        for field in (line .. "\t"):gmatch("([^\t]*)\t") do fields[#fields + 1] = field end
        for index, column in ipairs(columns) do row[column] = fields[index] or "" end
        rows[#rows + 1] = row
    end
    return rows
end
-- }}}

-- {{{ local function one_line()
-- Text made safe for one TSV field: no tabs or line breaks, trimmed.
local function one_line(text)
    return (text:gsub("[\t\r\n]+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end
-- }}}

-- {{{ local function normalise()
local function normalise(text)
    return one_line(text):lower():gsub("%s+", " "):gsub("[%.!]+$", "")
end
-- }}}

-- {{{ local function checksum()
local function checksum(path)
    local handle = io.popen("sha256sum " .. shell_quote(path) .. " 2>/dev/null")
    local line = handle and handle:read("*l")
    if handle then handle:close() end
    return line and line:match("^(%x+)") or nil
end
-- }}}
-- }}}

-- {{{ State
local EVENT_COLUMNS = { "date", "kind", "text" }
local PROPOSAL_COLUMNS = { "id", "date", "status", "guideline", "reason", "source" }
local AUDIT_COLUMNS = { "date", "action", "id", "target", "detail" }

-- {{{ local function state_path()
local function state_path(name)
    return STATE .. "/" .. name
end
-- }}}

-- {{{ local function ensure_state()
local function ensure_state()
    os.execute("mkdir -p " .. shell_quote(STATE .. "/backups"))
end
-- }}}

-- {{{ local function proposals()
local function proposals()
    return read_rows(state_path("proposals.tsv"), PROPOSAL_COLUMNS)
end
-- }}}

-- {{{ local function save_proposals()
local function save_proposals(rows)
    local lines = {}
    for _, row in ipairs(rows) do
        local fields = {}
        for index, column in ipairs(PROPOSAL_COLUMNS) do fields[index] = row[column] or "" end
        lines[#lines + 1] = table.concat(fields, "\t")
    end
    write_file(state_path("proposals.tsv"), #lines > 0 and table.concat(lines, "\n") .. "\n" or "")
end
-- }}}

-- {{{ local function find_proposal()
local function find_proposal(rows, id)
    for _, row in ipairs(rows) do
        if row.id == id then return row end
    end
    fail("no proposal " .. tostring(id) .. " (see list --all)", 1)
end
-- }}}

-- {{{ local function add_proposal()
local function add_proposal(guideline, reason, source)
    local rows = proposals()
    local id = string.format("P%03d", #rows + 1)
    rows[#rows + 1] = { id = id, date = os.date("%Y-%m-%d"), status = "pending",
                        guideline = one_line(guideline), reason = one_line(reason),
                        source = source or "" }
    save_proposals(rows)
    append_row(state_path("audit.tsv"), { os.date("%Y-%m-%d %H:%M:%S"), "proposed", id, "-",
        one_line(reason) })
    return id
end
-- }}}
-- }}}

-- {{{ Commands
local commands = {}

-- {{{ commands.event
function commands.event(words)
    local kind, text = words[1], table.concat(words, " ", 2)
    if not kind or not config.kinds[kind] then
        fail("event takes a kind (correction, instruction or convention) and the text")
    end
    if one_line(text) == "" then fail("event needs its text") end
    append_row(state_path("events.tsv"), { os.date("%Y-%m-%d %H:%M:%S"), kind, one_line(text) })
    return 0
end
-- }}}

-- {{{ local function grouped_events()
-- Events grouped by kind and wording: { key, kind, text, count }, most first.
local function grouped_events()
    local groups, order = {}, {}
    for _, row in ipairs(read_rows(state_path("events.tsv"), EVENT_COLUMNS)) do
        local key = row.kind .. ":" .. normalise(row.text)
        if not groups[key] then
            groups[key] = { key = key, kind = row.kind, text = row.text, count = 0 }
            order[#order + 1] = groups[key]
        end
        groups[key].count = groups[key].count + 1
    end
    table.sort(order, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.key < b.key
    end)
    return order
end
-- }}}

-- {{{ commands.events
function commands.events()
    local groups = grouped_events()
    if #groups == 0 then print("No events recorded.") return 0 end
    for _, group in ipairs(groups) do
        print(string.format("%4d  %-11s %s", group.count, group.kind, group.text))
    end
    return 0
end
-- }}}

-- {{{ commands.suggest
function commands.suggest(_, options)
    local minimum = tonumber(options.min or "3")
    if not minimum or minimum < 1 then fail("--min takes a whole number of times") end
    local proposed = {}
    for _, row in ipairs(proposals()) do proposed[row.source] = true end

    local client = require("llama-chat-client")
    local filed, failed = 0, 0
    for _, group in ipairs(grouped_events()) do
        if group.count >= minimum and not proposed[group.key] then
            local answer, why = client.complete(config.system_prompt,
                string.format("%d x %s (%s)", group.count, group.text, group.kind))
            local guideline = answer and answer:match("^%s*%-%s+([^\n]+)")
            if not guideline then
                failed = failed + 1
                print(string.format("could not word \"%s\": %s", group.text,
                    why or "the model's reply was not one \"- \" line"))
            elseif #guideline > config.max_guideline then
                failed = failed + 1
                print(string.format("could not word \"%s\": the guideline was over %d characters",
                    group.text, config.max_guideline))
            else
                local id = add_proposal(guideline, string.format("seen %d %s as %s %s: %s",
                    group.count, group.count == 1 and "time" or "times",
                    group.kind == "instruction" and "an" or "a", group.kind, group.text), group.key)
                filed = filed + 1
                print(string.format("%s  - %s", id, one_line(guideline)))
            end
        end
    end
    print(string.format("\n%d proposal(s) filed, %d could not be worded; approve with: approve ID --target=FILE",
        filed, failed))
    return (filed > 0 and failed == 0) and 0 or 1
end
-- }}}

-- {{{ commands.propose
function commands.propose(words, options)
    local text = one_line(table.concat(words, " "):gsub("^%-%s+", ""))
    if text == "" then fail("propose needs the guideline's text") end
    if #text > config.max_guideline then fail("a guideline is one line under 200 characters") end
    print(add_proposal(text, options.reason or "proposed directly", "direct:" .. normalise(text)))
    return 0
end
-- }}}

-- {{{ commands.list
function commands.list(_, options)
    local shown = 0
    for _, row in ipairs(proposals()) do
        if options.all or row.status == "pending" then
            shown = shown + 1
            print(string.format("%s  %-11s %s  - %s\n      why: %s", row.id, row.status, row.date,
                row.guideline, row.reason))
        end
    end
    if shown == 0 then print(options.all and "No proposals." or "No pending proposals.") end
    return 0
end
-- }}}

-- {{{ local function with_guideline()
-- The target's text with the guideline added under the learned section.
local function with_guideline(text, guideline)
    local bullet = "- " .. guideline
    local start = text:find("\n" .. config.section .. "\n", 1, true)
        or (text:sub(1, #config.section + 1) == config.section .. "\n" and 0)
    if not start then
        local gap = text == "" and "" or (text:match("\n\n$") and "" or (text:match("\n$") and "\n" or "\n\n"))
        return text .. gap .. config.section .. "\n\n" .. bullet .. "\n"
    end
    -- After the section heading: the end of its bullets (next heading or end).
    local after = start + #config.section + 2
    local next_heading = text:find("\n#", after, true)
    local insert_at = next_heading or (#text + 1)
    local before = text:sub(1, insert_at - 1)
    if not before:match("\n$") then before = before .. "\n" end
    return before .. bullet .. "\n" .. text:sub(insert_at)
end
-- }}}

-- {{{ commands.approve
function commands.approve(words, options)
    local rows = proposals()
    local row = find_proposal(rows, words[1])
    local target = options.target or fail("approve needs --target=FILE: the CLAUDE.md to change")
    if row.status ~= "pending" then fail(row.id .. " is " .. row.status .. ", not pending", 1) end
    local text = read_file(target)
    if not text then fail("cannot read " .. target .. " (create it first if it is new)", 1) end
    for line in text:gmatch("[^\n]+") do
        if normalise(line:gsub("^%-%s+", "")) == normalise(row.guideline) then
            fail(target .. " already says this: " .. line, 1)
        end
    end
    local backup = state_path(string.format("backups/%s-%s.md", row.id, os.date("%Y%m%d-%H%M%S")))
    if not write_file(backup, text) then fail("cannot write the backup " .. backup, 1) end
    if not write_file(target, with_guideline(text, row.guideline)) then
        fail("cannot write " .. target .. "; it is unchanged, the backup is " .. backup, 1)
    end
    row.status = "approved"
    save_proposals(rows)
    append_row(state_path("audit.tsv"), { os.date("%Y-%m-%d %H:%M:%S"), "approved", row.id, target,
        "backup " .. backup .. " after " .. (checksum(target) or "-") })
    print(string.format("%s added to %s (backup: %s)", row.id, target, backup))
    return 0
end
-- }}}

-- {{{ commands.reject
function commands.reject(words, options)
    local rows = proposals()
    local row = find_proposal(rows, words[1])
    if row.status ~= "pending" then fail(row.id .. " is " .. row.status .. ", not pending", 1) end
    row.status = "rejected"
    save_proposals(rows)
    append_row(state_path("audit.tsv"), { os.date("%Y-%m-%d %H:%M:%S"), "rejected", row.id, "-",
        one_line(options.reason or "") })
    print(row.id .. " rejected")
    return 0
end
-- }}}

-- {{{ commands.rollback
function commands.rollback(words, options)
    local rows = proposals()
    local row = find_proposal(rows, words[1])
    local target = options.target or fail("rollback needs --target=FILE")
    if row.status ~= "approved" then fail(row.id .. " is " .. row.status .. ", not approved", 1) end
    local approval
    for _, entry in ipairs(read_rows(state_path("audit.tsv"), AUDIT_COLUMNS)) do
        if entry.action == "approved" and entry.id == row.id and entry.target == target then
            approval = entry
        end
    end
    if not approval then fail(row.id .. " was not approved into " .. target, 1) end
    local backup, after = approval.detail:match("^backup (.-) after (%x+)$")
    if not backup then fail("the audit trail has no backup for " .. row.id, 1) end
    if checksum(target) ~= after then
        fail(target .. " has changed since " .. row.id .. " was approved; not rolled back. "
            .. "The file before the approval is " .. backup, 1)
    end
    local saved = read_file(backup)
    if not saved or not write_file(target, saved) then fail("cannot restore " .. target, 1) end
    row.status = "rolled-back"
    save_proposals(rows)
    append_row(state_path("audit.tsv"), { os.date("%Y-%m-%d %H:%M:%S"), "rolled-back", row.id, target,
        "restored " .. backup })
    print(string.format("%s rolled back; %s restored from %s", row.id, target, backup))
    return 0
end
-- }}}

-- {{{ local function check_date()
local function check_date(text, name)
    if text and not text:match("^%d%d%d%d%-%d%d%-%d%d$") then fail("--" .. name .. " takes a date, YYYY-MM-DD") end
    return text
end
-- }}}

-- {{{ commands.history
-- The audit trail, optionally only one proposal's rows, one action's, or
-- those on or after a date.
function commands.history(_, options)
    local since = check_date(options.since, "since")
    local shown = 0
    for _, row in ipairs(read_rows(state_path("audit.tsv"), AUDIT_COLUMNS)) do
        if (not options.id or row.id == options.id) and (not options.action or row.action == options.action)
            and (not since or row.date:sub(1, 10) >= since) then
            shown = shown + 1
            print(string.format("%s  %-11s %s  %s  %s", row.date, row.action, row.id, row.target, row.detail))
        end
    end
    if shown == 0 then print("No history" .. ((options.id or options.action or since) and " matches." or " yet.")) end
    return 0
end
-- }}}

-- {{{ local function events_behind()
-- The recorded events a proposal was worded from (none for a direct one).
local function events_behind(row)
    local found = {}
    for _, event in ipairs(read_rows(state_path("events.tsv"), EVENT_COLUMNS)) do
        if event.kind .. ":" .. normalise(event.text) == row.source then found[#found + 1] = event end
    end
    return found
end
-- }}}

-- {{{ commands.show
-- How one guideline came to be: the events behind it, the proposal, and
-- every audit row about it, in order.
function commands.show(words)
    local row = find_proposal(proposals(), words[1])
    print(string.format("%s  %s\n  - %s\n  why: %s", row.id, row.status, row.guideline, row.reason))
    local events = events_behind(row)
    if row.source:match("^direct:") then
        print("\nfiled directly (propose), not from events")
    else
        print(string.format("\nevents behind it (%d):", #events))
        for _, event in ipairs(events) do print(string.format("  %s  %-11s %s", event.date, event.kind, event.text)) end
    end
    print("\ntimeline:")
    for _, entry in ipairs(read_rows(state_path("audit.tsv"), AUDIT_COLUMNS)) do
        if entry.id == row.id then
            print(string.format("  %s  %-11s %s  %s", entry.date, entry.action, entry.target, entry.detail))
        end
    end
    return 0
end
-- }}}

-- {{{ local function last_approval()
local function last_approval(id)
    local approval
    for _, entry in ipairs(read_rows(state_path("audit.tsv"), AUDIT_COLUMNS)) do
        if entry.action == "approved" and entry.id == id then approval = entry end
    end
    return approval
end
-- }}}

-- {{{ local function base_name()
local function base_name(path)
    return path:match("([^/]*)$")
end
-- }}}

-- {{{ local function pruned_backups()
-- The backups prune has removed: file name -> the audit row that says so.
local function pruned_backups()
    local pruned = {}
    for _, entry in ipairs(read_rows(state_path("audit.tsv"), AUDIT_COLUMNS)) do
        local path = entry.action == "pruned" and entry.detail:match("^backup (.+)$")
        if path then pruned[base_name(path)] = entry end
    end
    return pruned
end
-- }}}

-- {{{ commands.diff
-- What an approval changed: the file before it (the backup) against the
-- file it wrote, rebuilt from the backup and checked against the checksum
-- recorded at the time.
function commands.diff(words)
    local row = find_proposal(proposals(), words[1])
    local approval = last_approval(row.id) or fail(row.id .. " was never approved", 1)
    local backup, after = approval.detail:match("^backup (.-) after (%x+)$")
    if not backup then fail("the audit trail has no backup for " .. row.id, 1) end
    local before = read_file(backup)
    if not before then
        local pruned = pruned_backups()[base_name(backup)]
        if pruned then
            fail("the backup " .. backup .. " was pruned on " .. pruned.date:sub(1, 10)
                .. ", so this change can no longer be shown", 1)
        end
        fail("the backup " .. backup .. " is missing", 1)
    end
    local rebuilt = state_path("backups/.diff-" .. row.id .. ".md")
    write_file(rebuilt, with_guideline(before, row.guideline))
    local matches = checksum(rebuilt) == after
    local handle = io.popen("diff -u --label " .. shell_quote(approval.target .. " before " .. row.id)
        .. " --label " .. shell_quote(approval.target .. " after " .. row.id) .. " "
        .. shell_quote(backup) .. " " .. shell_quote(rebuilt))
    io.write(handle:read("*a"))
    handle:close()
    os.remove(rebuilt)
    if not matches then
        print("note: this rebuilds the change from the backup, and it does not match the checksum "
            .. "recorded at approval; the approval may have been made by another version of this tool")
        return 1
    end
    return 0
end
-- }}}

-- {{{ commands.report
-- Counts of events, proposals and audit actions, on or after a date.
function commands.report(_, options)
    local since = check_date(options.since, "since")
    local function counted(rows, field, date_field)
        local counts, order, total = {}, {}, 0
        for _, row in ipairs(rows) do
            if not since or row[date_field]:sub(1, 10) >= since then
                if not counts[row[field]] then order[#order + 1] = row[field] end
                counts[row[field]] = (counts[row[field]] or 0) + 1
                total = total + 1
            end
        end
        table.sort(order)
        local parts = {}
        for _, name in ipairs(order) do parts[#parts + 1] = name .. " " .. counts[name] end
        return total, #parts > 0 and (" (" .. table.concat(parts, ", ") .. ")") or ""
    end
    print("Activity" .. (since and (" since " .. since) or ", all time") .. ":")
    print(string.format("  events     %d%s", counted(read_rows(state_path("events.tsv"), EVENT_COLUMNS), "kind", "date")))
    print(string.format("  proposals  %d%s, by status now",
        counted(proposals(), "status", "date")))
    print(string.format("  actions    %d%s", counted(read_rows(state_path("audit.tsv"), AUDIT_COLUMNS), "action", "date")))
    return 0
end
-- }}}

-- {{{ commands.verify
-- The integrity checks: every audit row is whole and in date order, names
-- a proposal and agrees with it; every approval's backup is there. Changes
-- made to a target since its last approval are reported, not counted as
-- problems.
function commands.verify()
    local problems, notes = {}, {}
    local by_id = {}
    for _, row in ipairs(proposals()) do by_id[row.id] = { row = row, actions = {} } end
    local status_after = { proposed = "pending", approved = "approved", rejected = "rejected",
                           ["rolled-back"] = "rolled-back" }
    local pruned = pruned_backups()
    local previous = ""
    for number, entry in ipairs(read_rows(state_path("audit.tsv"), AUDIT_COLUMNS)) do
        local where = "audit.tsv line " .. number
        if not entry.date:match("^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d$") or entry.detail == nil
            or entry.target == "" then
            problems[#problems + 1] = where .. ": not a whole row"
        else
            if entry.date < previous then problems[#problems + 1] = where .. ": dated before the line above it" end
            previous = entry.date
            local known = by_id[entry.id]
            if not known then
                problems[#problems + 1] = where .. ": names " .. entry.id .. ", which is not a proposal"
            else
                -- Only the rows that set a status are its timeline; a
                -- "pruned" row records a backup removed by rotation.
                if status_after[entry.action] then known.actions[#known.actions + 1] = entry end
                if entry.action == "approved" then
                    local backup = entry.detail:match("^backup (.-) after %x+$")
                    if not backup then
                        problems[#problems + 1] = where .. ": an approval with no backup recorded"
                    elseif not read_file(backup) and not pruned[base_name(backup)] then
                        problems[#problems + 1] = where .. ": the backup " .. backup .. " is missing"
                    end
                end
            end
        end
    end
    local ids = {}
    for id in pairs(by_id) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local known = by_id[id]
        local first, last = known.actions[1], known.actions[#known.actions]
        if not first or first.action ~= "proposed" then
            problems[#problems + 1] = id .. ": the audit trail does not start with its proposal"
        end
        if last and status_after[last.action] and status_after[last.action] ~= known.row.status then
            problems[#problems + 1] = string.format("%s: its status is %s, but its last action was %s",
                id, known.row.status, last.action)
        end
        if known.row.status == "approved" and last and last.action == "approved" then
            local after = last.detail:match(" after (%x+)$")
            local now = checksum(last.target)
            if not now then
                notes[#notes + 1] = string.format("%s: %s is gone", id, last.target)
            elseif now ~= after then
                notes[#notes + 1] = string.format("%s: %s has been edited since it was approved", id, last.target)
            end
        end
    end
    for _, line in ipairs(problems) do print("problem: " .. line) end
    for _, line in ipairs(notes) do print("note: " .. line) end
    print(string.format("%d problem%s, %d note%s", #problems, #problems == 1 and "" or "s",
        #notes, #notes == 1 and "" or "s"))
    return #problems > 0 and 1 or 0
end
-- }}}
-- }}}

-- {{{ commands.prune
-- Backup rotation (040d). Every approval leaves a backup, so they would grow
-- without end. This keeps the newest --keep (default 100) and, whatever their
-- age, the backups a rollback still needs: the last approval of each
-- proposal that is approved now. Without --yes it only shows what it would
-- remove. Each removal is written to the audit trail, so diff and verify
-- can tell a pruned backup from a lost one.
function commands.prune(_, options)
    local keep = tonumber(options.keep or config.keep_backups)
    if not keep or keep < 0 or keep % 1 ~= 0 then fail("--keep takes a whole number, 0 or more") end

    local status = {}
    for _, row in ipairs(proposals()) do status[row.id] = row.status end
    local last = {}
    for _, entry in ipairs(read_rows(state_path("audit.tsv"), AUDIT_COLUMNS)) do
        local path = entry.action == "approved" and entry.detail:match("^backup (.-) after %x+$")
        if path then last[entry.id] = base_name(path) end
    end
    local needed = {}
    for id, name in pairs(last) do
        if status[id] == "approved" then needed[name] = id end
    end

    -- The backups on disk, newest first by the date in their names.
    local files = {}
    local handle = io.popen("find " .. shell_quote(state_path("backups")) .. " -maxdepth 1 -type f"
        .. " -name '*.md' ! -name '.*' 2>/dev/null")
    for path in handle:lines() do
        -- Only files named as approve names its backups (ID-DATE-TIME.md).
        local name = base_name(path)
        local id, stamp = name:match("^(.-)%-(%d+%-%d+)%.md$")
        if id then files[#files + 1] = { path = path, name = name, id = id, stamp = stamp } end
    end
    handle:close()
    table.sort(files, function(a, b)
        if a.stamp ~= b.stamp then return a.stamp > b.stamp end
        return a.name > b.name
    end)

    local remove, protected = {}, 0
    for index, file in ipairs(files) do
        if index > keep then
            if needed[file.name] then protected = protected + 1
            else remove[#remove + 1] = file end
        end
    end
    local kept_note = string.format("newest %d kept%s", math.min(keep, #files),
        protected > 0 and string.format(", %d older kept for rollback", protected) or "")
    if #remove == 0 then
        print(string.format("Nothing to prune: %d backup%s (%s).", #files, #files == 1 and "" or "s", kept_note))
        return 0
    end
    for _, file in ipairs(remove) do
        if options.yes then
            if os.remove(file.path) then
                append_row(state_path("audit.tsv"), { os.date("%Y-%m-%d %H:%M:%S"), "pruned", file.id, "-",
                    "backup " .. file.path })
                print("removed  " .. file.name)
            else
                print("could not remove " .. file.name)
            end
        else
            print("would remove  " .. file.name)
        end
    end
    print(string.format("%d backup%s %s (%s)%s", #remove, #remove == 1 and "" or "s",
        options.yes and "removed" or "would be removed", kept_note,
        options.yes and "." or "; run again with --yes to remove them."))
    return 0
end
-- }}}

-- {{{ local function show_help()
local function show_help()
    local file = io.open(arg[0], "r")
    if not file then return end
    for line in file:lines() do
        if line:match("^%-%- {{{") then break end
        if line:match("^%-%-") then print((line:gsub("^%-%- ?", ""))) end
    end
    file:close()
end
-- }}}

-- {{{ main
local function main(argv)
    local words, options = {}, {}
    for _, argument in ipairs(argv) do
        local key, value = argument:match("^%-%-([%w%-]+)=(.*)$")
        if key then options[key] = value
        elseif argument == "--all" then options.all = true
        elseif argument == "--yes" then options.yes = true
        elseif argument == "-h" or argument == "--help" then show_help() return 0
        else words[#words + 1] = argument end
    end
    if options.state then STATE = options.state end
    local name = table.remove(words, 1)
    if not name or not commands[name] then
        fail("say what to do: event, events, suggest, propose, list, approve, reject, rollback, "
            .. "history, show, diff, report, verify or prune")
    end
    for key in pairs(options) do
        if not ({ state = true, min = true, reason = true, target = true, all = true, id = true,
                  action = true, since = true, keep = true, yes = true })[key] then
            fail("unknown option --" .. key)
        end
    end
    ensure_state()
    return commands[name](words, options)
end
-- }}}

os.exit(main(arg))
