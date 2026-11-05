#!/usr/bin/env luajit
-- 055-turn.lua - one voice's turn: the canvas kuvalu sent, edited by the
-- voice's model until it fits, written for the runner to send back.
--
-- In plain terms: the turn runner (038) runs one turn by running the program
-- its `turn` setting names. In phase 3 that was the stand-in; this is the
-- real one (issue 405), the seven steps of docs/datapath-voice-turn.md:
--
--   1. read the canvas kuvalu sent (to-voices, 006);
--   2. the project clone: this voice's clone of the project the canvas
--      names, brought to its commit, in RAM if it fits (501, 058);
--   3. the endpoint: this voice's own line in the canvas (402), its key read
--      on this machine;
--   4. the opening conversation (403), with last turn's advisory note;
--   5-6. ask until the reply fits (404);
--   7. write the voice's canvas (from-voice, base: the version read), read
--      back with the canvas reader before it is written, so the voice never
--      sends a canvas the blitter would refuse for its form.
--
-- The runner keeps the turn number (output/turn-counter-<voice>) and sends
-- what this writes. This keeps last turn's advisory note beside it, in
-- output/turn-note-<voice>: written when a turn's changes were over the
-- recommendation, removed when they were not.
--
-- A newer canvas arriving while the model is still being asked: by the
-- owner's word the turn keeps going (input/turn: newer-canvas = "keep-going").
-- With "give-way" it looks before each new ask, and when a newer canvas is
-- waiting it stops, writes nothing and exits 3; the runner counts that as a
-- turn that gave way and takes the newer canvas next.
--
-- Each turn is one run of its own: its log is tmp/shared-memory/turn-<voice>
-- .log and its receipt output/goodbye-turn-<voice> (the last turn's; the one
-- before is .previous). Both name the endpoint the turn used, so a canvas's
-- history can be traced to the models that wrote it (402). The log's last
-- line for a turn that fitted reads
--   turn 7 on version 12 fits: endpoint kuvalu-chat (http://...), asks 3,
--   tries 2, problems: too-wide 1, look calls 0, tokens 1200 + 300, 4.21
--   seconds, 3 words and 0 sentences changed (12 and 1 recommended)
-- and the receipt counts the same: asks, tries, problems-<kind>, look-calls,
-- looks-<focus>, tokens-prompt, tokens-completion, model-milliseconds,
-- words-changed, sentences-changed, over-recommended, endpoint-<name>.
--
--   scripts/turn --dir ROOT --voice fg-sora-1 --turn 7 --canvas FILE --out FILE
--   local turn = dofile(DIR .. "/src/055-turn.lua")
--   local outcome = turn.run({ root, voice, turn, canvas, out })  -- "sent"|"gave-way"
-- LuaJIT-compatible.

-- {{{ local DIR
local SOURCE = debug.getinfo(1, "S").source
local DIR = string.match(SOURCE, "^@(.+)/src/[^/]*$")
    or (string.match(SOURCE, "^@src/[^/]*$") and ".")
    or "/mnt/mtwo/programming/ai-stuff/guide-feature"
-- }}}

local settings = dofile(DIR .. "/src/001-settings.lua")
local goodbye = dofile(DIR .. "/src/002-goodbye.lua")
local canvas = dofile(DIR .. "/src/006-canvas-text.lua")
local runner = dofile(DIR .. "/src/038-turn-runner.lua")
local caller = dofile(DIR .. "/src/046-model-caller.lua")
local prompt = dofile(DIR .. "/src/049-turn-prompt.lua")
local ask = dofile(DIR .. "/src/051-ask-until-it-fits.lua")
local clone = dofile(DIR .. "/src/058-project-clone.lua")

local M = {}

-- {{{ M.GAVE_WAY
-- The exit status of a turn that gave way to a newer canvas (038 reads it).
M.GAVE_WAY = 3
-- }}}

-- {{{ small helpers
local function slurp(path)
    local handle = io.open(path, "rb")
    if not handle then return nil end
    local text = handle:read("*a")
    handle:close()
    return text
end

-- Written under another name, then renamed into place.
local function put(path, text)
    local handle = io.open(path .. ".part", "wb")
    if not handle then error("cannot write " .. path, 0) end
    handle:write(text)
    handle:close()
    local moved, why = os.rename(path .. ".part", path)
    if not moved then
        os.remove(path .. ".part")
        error("cannot write " .. path .. ": " .. tostring(why), 0)
    end
end
-- }}}

-- {{{ function M.note_path()
function M.note_path(root, voice) return root .. "/output/turn-note-" .. voice end
-- }}}

-- {{{ function M.project()
-- Step 2: the clone keeper (501) brings this voice's clone of the project to
-- the commit the canvas names. The log says where the clone is, RAM or disk,
-- and why; the receipt counts clone-ram or clone-disk, clone-made,
-- clone-fetched, clone-moved and clone-milliseconds. A clone that cannot be
-- made is logged and counted (clone-failed), and the turn goes on with the
-- canvas alone: the canvas is the work, the clone only what a look sees.
-- Returns the kept clone, or nil and why. opts.clone passes the keeper's
-- seams (memory, filesystem_of, free_space) through, for tests.
function M.project(opts, record, run, where)
    local seams = opts.clone or {}
    local ok, kept = pcall(clone.keep, { root = opts.root, voice = opts.voice,
        project = record.headers.project, memory = seams.memory,
        filesystem_of = seams.filesystem_of, free_space = seams.free_space })
    if not ok then
        run:count("clone-failed")
        run:log(where .. ": no clone of the project: " .. tostring(kept))
        return nil, tostring(kept)
    end
    run:count("clone-" .. kept.place)
    if kept.made then run:count("clone-made") end
    if kept.fetched then run:count("clone-fetched") end
    if kept.moved then run:count("clone-moved") end
    run:count("clone-milliseconds", math.floor(kept.seconds * 1000 + 0.5))
    run:log(where .. ": " .. clone.describe(kept))
    return kept
end
-- }}}

-- {{{ function M.voice_canvas()
-- Step 7: the from-voice text of the rows that fit, read back with the canvas
-- reader and checked against what was meant before anything is written.
function M.voice_canvas(record, rows, voice, turn, written)
    local mine = {
        set = "from-voice", width = record.width, height = record.height,
        rows = rows, marks = {},
        headers = { voice = voice, turn = turn, base = record.headers.canvas,
                    written = written or os.date("!%Y-%m-%dT%H:%M:%SZ") },
    }
    local text = canvas.write(mine, "from-voice")
    local back = canvas.read(text, "from-voice", "the turn's canvas")
    local h = back.headers
    if h.voice ~= voice or h.turn ~= turn or h.base ~= record.headers.canvas
        or back.width ~= record.width or back.height ~= record.height then
        error("the turn's canvas does not read back as written", 0)
    end
    for index = 1, record.height do
        if back.rows[index] ~= mine.rows[index] then
            error("the turn's canvas does not read back as written: row " .. index, 0)
        end
    end
    return text
end
-- }}}

-- {{{ function M.summary()
-- The log line of a turn's numbers.
function M.summary(opts, endpoint, counts, changes, recommended)
    local kinds = {}
    for kind, n in pairs(counts.problems) do kinds[#kinds + 1] = kind .. " " .. n end
    table.sort(kinds)
    local looks = {}
    for focus, n in pairs(counts.looks) do looks[#looks + 1] = focus .. " " .. n end
    table.sort(looks)
    local line = string.format("endpoint %s (%s), asks %d, tries %d, problems: %s, look calls %d%s, "
        .. "tokens %d + %d, %.2f seconds", endpoint.name, endpoint.url, counts.asks, counts.tries,
        #kinds > 0 and table.concat(kinds, ", ") or "none", counts.look_calls,
        #looks > 0 and (" (" .. table.concat(looks, ", ") .. ")") or "",
        counts.tokens.prompt, counts.tokens.completion, counts.seconds)
    if changes then
        line = line .. string.format(", %d words and %d sentences changed (%d and %d recommended)",
            changes.words_changed, changes.sentences_rewritten, recommended.words,
            recommended.sentences)
    end
    return line
end
-- }}}

-- {{{ local function count_all()
local function count_all(run, endpoint, counts, changes, note)
    run:count("endpoint-" .. endpoint.name)
    run:count("asks", counts.asks)
    run:count("tries", counts.tries)
    run:count("look-calls", counts.look_calls)
    for kind, n in pairs(counts.problems) do run:count("problems-" .. kind, n) end
    for focus, n in pairs(counts.looks) do run:count("looks-" .. focus, n) end
    run:count("tokens-prompt", counts.tokens.prompt)
    run:count("tokens-completion", counts.tokens.completion)
    run:count("model-milliseconds", math.floor(counts.seconds * 1000 + 0.5))
    if changes then
        run:count("words-changed", changes.words_changed)
        run:count("sentences-changed", changes.sentences_rewritten)
        run:count("over-recommended", note and 1 or 0)
    end
end
-- }}}

-- {{{ function M.run()
-- One turn. opts: root, voice, turn (its number), canvas (the file kuvalu's
-- canvas was taken to), out (where the voice's canvas goes); goodbye and
-- clock for tests. Returns "sent" or "gave-way". Errors (the canvas, the
-- endpoint, its key, the model) are logged, end the run with its receipt,
-- and are raised again for the program to report.
function M.run(opts)
    local root, voice, number = opts.root, opts.voice, opts.turn
    local values = settings.read("turn", ask.SETTINGS, { root = root })
    local recommended = { words = values["recommended-words"],
                          sentences = values["recommended-sentences"] }
    local run = (opts.goodbye or goodbye).start("turn-" .. voice, { root = root, clock = opts.clock })
    local outcome
    local ok, problem = pcall(function()
        -- 1. the canvas
        local text = slurp(opts.canvas)
        if not text then error("cannot read the canvas " .. opts.canvas, 0) end
        local record = canvas.read(text, "to-voices", "the canvas")
        local version = record.headers.canvas
        local where = string.format("turn %d on version %d", number, version)
        run:log(where .. ": started")
        -- 2. the project clone
        M.project(opts, record, run, where)
        -- 3. the endpoint
        local endpoint = caller.from_canvas(record, voice, root)
        run:log(where .. ": endpoint " .. caller.describe(endpoint)
            .. (endpoint.key and ", with its key" or ""))
        -- 4. the conversation
        local note = slurp(M.note_path(root, voice))
        local conversation = prompt.build({
            instructions = prompt.read_instructions(root), canvas = record, voice = voice,
            turn = number, recommended = recommended, look_limit = values["look-limit"],
            note = note and note:gsub("%s+$", "") or nil,
        })
        if note then run:log(where .. ": last turn's note is in the prompt") end
        -- 5-6. ask until it fits
        local waiting = runner.folder(root, voice) .. "/waiting"
        local give_way = nil
        if values["newer-canvas"] == "give-way" then
            give_way = function()
                local handle = io.open(waiting, "rb")
                if not handle then return nil end
                handle:close()
                return "a newer canvas is waiting"
            end
        end
        local result = ask.until_fits({
            call = function(turns) return caller.chat(endpoint, turns) end,
            conversation = conversation, base = record, recommended = recommended,
            look_limit = values["look-limit"],
            log = function(line) run:log(where .. ", " .. line) end,
            give_way = give_way,
        })
        if result.gave_way then
            count_all(run, endpoint, result.counts, nil, nil)
            run:count("gave-way")
            run:log(where .. " gave way: " .. result.gave_way .. "; "
                .. M.summary(opts, endpoint, result.counts, nil, recommended))
            outcome = "gave-way"
            return
        end
        -- 7. the voice's canvas, and next turn's note
        put(opts.out, M.voice_canvas(record, result.rows, voice, number))
        if result.note then
            put(M.note_path(root, voice), result.note .. "\n")
        else
            os.remove(M.note_path(root, voice))
        end
        count_all(run, endpoint, result.counts, result.changes, result.note)
        run:log(where .. " fits: " .. M.summary(opts, endpoint, result.counts, result.changes,
            recommended))
        outcome = "sent"
    end)
    if not ok then
        run:count("failed")
        run:log("turn " .. tostring(number) .. " failed: " .. tostring(problem))
        run:finish()
        error(problem, 0)
    end
    run:finish()
    return outcome
end
-- }}}

-- {{{ run as a program
if arg and arg[0] and string.match(arg[0], "055%-turn%.lua$") then
    local opts = { root = DIR }
    local index = 1
    local usage = "usage: turn [--dir ROOT] --voice NAME --turn N --canvas FILE --out FILE\n"
    while index <= #arg do
        local key = string.match(arg[index], "^%-%-(%a+)$")
        if not key or arg[index + 1] == nil then
            io.stderr:write(usage)
            os.exit(2)
        end
        opts[key == "dir" and "root" or key] = arg[index + 1]
        index = index + 2
    end
    opts.turn = tonumber(opts.turn)
    if not (opts.voice and opts.turn and opts.canvas and opts.out) then
        io.stderr:write(usage)
        os.exit(2)
    end
    local ok, outcome = pcall(M.run, opts)
    if not ok then
        io.stderr:write(tostring(outcome), "\n")
        os.exit(1)
    end
    os.exit(outcome == "gave-way" and M.GAVE_WAY or 0)
end
-- }}}

return M
