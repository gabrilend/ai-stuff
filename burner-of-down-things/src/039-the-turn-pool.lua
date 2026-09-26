-- 039-the-turn-pool.lua
--
-- Running a set of independent turns at once and judging each (docs/005,
-- "many turns at once"). The whole case folder and the source are
-- snapshotted before the set starts and after it ends; the turns run in a
-- pool of worker threads, each starting one harness process at a time and
-- waiting for it; then every change is charged to the turn that may write
-- it, and each turn gets a verdict:
--
--   breach   something changed that no turn of the set may write (or the
--            source changed at all). Turns running together cannot be told
--            apart by what they wrote, so every turn of the set is a breach.
--   failed   the harness exited non-zero (124: it ran past its limit)
--   kept     neither
--
-- The turns/ folder, the ledger and the lock are left out of the snapshots:
-- the machine itself writes them while the set runs.

local ledger = require("016-ledger")
local fs = require("017-the-filesystem")
local instructions = require("035-instructions")
local snapshots = require("036-snapshots")
local harnesses = require("037-the-harness-table")

local pool = {}

-- {{{ local function worker
-- Runs inside a pool thread: takes shell lines from the channel until it is
-- empty, running each to completion. No upvalues.
local function worker(channel)
    while true do
        local line = channel:pop(0)
        if not line then
            return
        end
        os.execute(line)
    end
end
-- }}}

-- {{{ local function read_exit
local function read_exit(turn)
    local path = turn.folder .. "/exit"
    if not fs.exists(path) then
        return nil
    end
    return tonumber((fs.read(path):gsub("%s", "")))
end
-- }}}

-- {{{ local function last_lines
local function last_lines(path, n)
    if not fs.exists(path) then
        return ""
    end
    local lines = {}
    for line in fs.read(path):gmatch("[^\n]+") do
        lines[#lines + 1] = line
    end
    local from = math.max(1, #lines - n + 1)
    return table.concat(lines, " | ", from)
end
-- }}}

-- {{{ function pool.run_set
-- Runs prepared turns (from 034's make_turn) together. `options`:
--   harness     the harness name (default: the case's)
--   size        how many at once (default: the harness row's pool)
--   limit       seconds per turn (default: the row's limit)
--   center      the center's paragraph for the instructions (default "")
-- Returns an array, one per turn: { turn, verdict, exit, changes (array),
-- why (string) }, and a summary { breaches = array, source_touched = bool }.
function pool.run_set(project, record, turns, options)
    options = options or {}
    local row = harnesses.row(options.harness or record.harness)
    local size = math.max(1, math.min(options.size or row.pool, #turns))
    for _, turn in ipairs(turns) do
        instructions.write(turn, record, project.skills, options.center or "")
    end

    local cache_path = record.turns .. "/snapshot.tsv"
    local excluded = { record.turns, record.ledger, record.lock }
    local roots = { record.folder, record.source }
    local before = snapshots.take(project, roots, excluded, snapshots.load(cache_path))

    local effil = require("effil")
    local channel = effil.channel()
    for _, turn in ipairs(turns) do
        ledger.append(record.ledger, "turn-started", turn.id, turn.kind .. " " .. turn.about .. " by " .. row.name)
        channel:push(harnesses.shell_line(project, row, turn, options.limit))
    end
    local threads = {}
    for i = 1, size do
        threads[i] = effil.thread(worker)(channel)
    end
    for _, thread in ipairs(threads) do
        local status, err = thread:wait()
        if status ~= "completed" then
            error("turn pool: a worker thread stopped (" .. tostring(status) .. "): " .. tostring(err))
        end
    end

    local after = snapshots.take(project, roots, excluded, before)
    snapshots.save(cache_path, after)
    local changes = snapshots.compare(before, after)
    local charged = snapshots.charge(changes, turns)

    local source_prefix = record.source .. "/"
    local source_touched = false
    for _, change in ipairs(charged.breaches) do
        if change.path:sub(1, #source_prefix) == source_prefix then
            source_touched = true
        end
    end
    if #charged.breaches > 0 then
        local listed = {}
        for i, change in ipairs(charged.breaches) do
            listed[i] = change.how .. " " .. change.path
        end
        ledger.append(record.ledger, "breach", "set of " .. #turns,
            table.concat(listed, "; ") .. (source_touched and " (the source was touched)" or ""))
    end

    local results = {}
    for i, turn in ipairs(turns) do
        local exit = read_exit(turn)
        local verdict, why
        -- Each branch below is one verdict; breach outranks failure, since a
        -- breach means the turn's work cannot be trusted at all.
        if #charged.breaches > 0 then
            verdict = "breach"
            why = #charged.breaches .. " change(s) outside every writable path in this set"
        elseif exit == nil then
            verdict, why = "failed", "no exit status recorded"
        elseif exit == 124 or exit == 137 then
            verdict, why = "failed", "ran past its limit and was stopped"
        elseif exit ~= 0 then
            verdict, why = "failed", "exit " .. exit .. ": " .. last_lines(turn.folder .. "/stderr.txt", 3)
        else
            verdict, why = "kept", "exit 0"
        end
        local own = charged.by_turn[turn.id]
        fs.write(turn.folder .. "/verdict", verdict .. "\n" .. why .. "\n")
        ledger.append(record.ledger, "turn-ended", turn.id,
            verdict .. ": " .. why .. "; " .. #own .. " file(s) changed")
        results[i] = { turn = turn, verdict = verdict, exit = exit, changes = own, why = why }
    end
    return results, { breaches = charged.breaches, shared = charged.set, source_touched = source_touched }
end
-- }}}

return pool
