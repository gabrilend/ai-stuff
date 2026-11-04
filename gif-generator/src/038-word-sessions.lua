-- 038-word-sessions.lua — every unrecognized word becomes an error
-- report and is solved at once (issue 604c).
--
-- What this is, generally: for each word the lexicon could not place, a
-- brief is written into RAM saying what the word is, the sentence it
-- came from, and the contract for a word file. Then one headless Claude
-- Code session per word is started, all at the same time, each told to
-- write exactly one file, words/<word>.lua. Because every word owns its
-- own file, no two sessions ever edit the same thing. When they have
-- all finished, each file is checked (not trusted), and every word that
-- passed is added to the tracker issue in a single write; a tracker that
-- had been moved to issues/completed/ is moved back and reopened first.
--
-- Data-format notes worth knowing more than once:
--   * the command is `claude` unless the SAY_CLAUDE environment variable
--     names a stand-in (tests use one; nothing else should);
--   * each session's printed output and exit status are kept beside its
--     brief in the run folder, for the person to read when one fails;
--   * a word counts as taught only if words.check() passes on its file.

local sessions = {}

-- {{{ local function shell_quote()
local function shell_quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function slurp()
local function slurp(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end
-- }}}

-- {{{ local function spit()
local function spit(path, text)
    local f, why = io.open(path, "w")
    if not f then error("word sessions: cannot write " .. path .. ": " .. tostring(why), 0) end
    f:write(text)
    f:close()
end
-- }}}

-- {{{ function sessions.command()
-- The headless session command for one prompt. Edits are allowed and
-- the only shell command it may run is luajit (to check its own file);
-- everything else it would need is reading and writing files. The
-- prompt comes straight after --print: --allowedTools takes every word
-- after it, and would swallow a prompt written later.
-- `extra` is more options (the director adds --resume); may be nil.
function sessions.command(prompt, extra)
    local claude = os.getenv("SAY_CLAUDE") or "claude"
    return shell_quote(claude) .. " --print " .. shell_quote(prompt)
        .. " --output-format json --permission-mode acceptEdits"
        .. (extra and (" " .. extra) or "")
        .. " --allowedTools Read Write Edit Glob Grep 'Bash(luajit *)'"
end
-- }}}

sessions.shell_quote = shell_quote
sessions.slurp = slurp
sessions.spit = spit

-- {{{ function sessions.brief()
-- The brief for one word: everything the session needs, so its prompt
-- can be one line. Built from the format document and the two shipped
-- examples, never written twice.
function sessions.brief(dir, run_dir, found)
    local format = slurp(dir .. "/docs/score-format.md") or ""
    local patterns_section = format:match("(## Patterns.-)\n## ") or ""
    local path = run_dir .. "/" .. found.word .. ".md"
    spit(path, table.concat({
        "# Brief: teach the studio the word \"" .. found.word .. "\"",
        "",
        "A person asked the gif studio for a picture and used the word **"
            .. found.word .. "**, which the studio does not know. The sentence was:",
        "",
        "> " .. found.sentence,
        "",
        "## Your one job",
        "",
        "Write exactly one file: `words/" .. found.word .. ".lua`, in the project folder",
        "`" .. dir .. "`. Do not create, edit or delete any other file: other",
        "sessions are teaching other words at this same moment, each in its own file.",
        "",
        "Decide what the word means in this sentence:",
        "",
        "- if it names something to draw (a shape, a motion, an effect), make a",
        "  **pattern**: an `expand` function that returns ordinary strokes",
        "  (`arc`, `line`, `point`, `fill`, with `at`, `lasts`, `color`, `fade`,",
        "  optional `ease` and `emit`), times in tenths of a second;",
        "- if it only says how something should be done or read (a manner, a",
        "  direction, a word for an existing thing), make a **plain** word whose",
        "  `meaning` says how to express it with the existing vocabulary.",
        "",
        "Put other forms of the word (plural, -ing) in `aliases`.",
        "",
        "Then check your file, and fix it until this prints `ok`:",
        "",
        "    luajit " .. dir .. "/src/034-words.lua --check " .. found.word .. " " .. dir,
        "",
        "If the word truly needs something the vocabulary cannot do at all (a",
        "new kind of shape), still write the closest pattern you can, and say",
        "what is missing in its `meaning`.",
        "",
        "## Two finished examples",
        "",
        "```lua",
        slurp(dir .. "/words/ring.lua") or "",
        "```",
        "",
        "```lua",
        slurp(dir .. "/words/slowly.lua") or "",
        "```",
        "",
        "## The contract and the vocabulary",
        "",
        patterns_section,
        "",
        "The whole score format is in `" .. dir .. "/docs/score-format.md`.",
        "",
    }, "\n"))
    return path
end
-- }}}

-- {{{ function sessions.run_all()
-- Starts one session per word, all at once, and waits for every one.
-- Returns a list of { word, sentence, brief, output, status } in the
-- order given.
function sessions.run_all(dir, run_dir, found_list)
    local jobs = {}
    local lines = { "#!/bin/bash" }
    for _, found in ipairs(found_list) do
        local brief = sessions.brief(dir, run_dir, found)
        local job = {
            word = found.word, sentence = found.sentence, brief = brief,
            output = run_dir .. "/" .. found.word .. ".out",
            status_path = run_dir .. "/" .. found.word .. ".status",
        }
        jobs[#jobs + 1] = job
        local prompt = "Read the brief at " .. brief .. " and do exactly what it says."
        lines[#lines + 1] = "( env -C " .. shell_quote(dir) .. " " .. sessions.command(prompt)
            .. " > " .. shell_quote(job.output)
            .. " 2>&1; echo $? > " .. shell_quote(job.status_path) .. " ) &"
    end
    lines[#lines + 1] = "wait"
    local script = run_dir .. "/word-sessions.sh"
    spit(script, table.concat(lines, "\n") .. "\n")
    os.execute("bash " .. shell_quote(script))
    for _, job in ipairs(jobs) do
        job.status = tonumber((slurp(job.status_path) or ""):match("%d+"))
    end
    return jobs
end
-- }}}

-- {{{ function sessions.judge()
-- Checks each job's word file. Adds ok (boolean), kind, problems.
function sessions.judge(dir, jobs)
    local words = require("034-words")
    for _, job in ipairs(jobs) do
        local ok, problems = words.check(dir, job.word)
        job.ok = ok and true or false
        job.problems = problems or {}
        if job.status ~= 0 then
            table.insert(job.problems, 1, "the session exited with status "
                .. tostring(job.status) .. " (see " .. job.output .. ")")
        end
        if job.ok then
            job.kind = words.load_one(dir, job.word).kind
        end
    end
    return jobs
end
-- }}}

-- {{{ local function find_tracker()
-- The tracker issue, wherever it is. Answers its path and whether it is
-- in completed/.
local function find_tracker(dir)
    for _, folder in ipairs({ "issues", "issues/completed" }) do
        local pipe = io.popen("ls -1 " .. shell_quote(dir .. "/" .. folder))
        for line in pipe:lines() do
            if line:match("^605%-.*%.md$") then
                pipe:close()
                return dir .. "/" .. folder .. "/" .. line, folder == "issues/completed"
            end
        end
        pipe:close()
    end
    error("word sessions: no tracker issue 605 in issues/ or issues/completed/", 0)
end
-- }}}

-- {{{ function sessions.update_tracker()
-- Adds every taught word to the tracker in one write. A tracker in
-- completed/ is moved back with git mv (so its history follows) and its
-- status set to open before the rows are added. Returns the tracker's
-- path and whether it was reopened.
function sessions.update_tracker(dir, jobs, date)
    local taught = {}
    for _, job in ipairs(jobs) do
        if job.ok then taught[#taught + 1] = job end
    end
    if #taught == 0 then return nil, false end

    local path, in_completed = find_tracker(dir)
    if in_completed then
        local name = path:match("[^/]+$")
        local target = dir .. "/issues/" .. name
        local ok = os.execute("git -C " .. shell_quote(dir) .. " mv "
            .. shell_quote(path) .. " " .. shell_quote(target))
        if ok ~= 0 and ok ~= true then
            error("word sessions: could not move the tracker back out of "
                  .. "completed/ with git mv: " .. path, 0)
        end
        path = target
    end

    local text = slurp(path)
    text = text:gsub("## Status: [%w%-]+", "## Status: open", 1)
    local rows = {}
    for _, job in ipairs(taught) do
        local sentence = job.sentence:gsub("|", "/")
        rows[#rows + 1] = "| " .. job.word .. " | " .. job.kind .. " | "
            .. sentence .. " | " .. date .. " |"
    end
    if not text:match("\n$") then text = text .. "\n" end
    spit(path, text .. table.concat(rows, "\n") .. "\n")
    return path, in_completed
end
-- }}}

return sessions
