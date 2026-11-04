-- 040-director.lua — the director: a headless Claude Code session that
-- turns a person's prose into a score, and keeps talking with them until
-- the gif is right (issue 604d).
--
-- What this is, generally: the porch (601) was built to put prose to a
-- local model; the director is the same idea put to a Claude Code
-- session instead. It is given the prose, the whole score format, and
-- every word file's meaning, and asked to write one score into the run
-- folder. The studio's own wall then checks that score; if it refuses,
-- every refusal goes back to the same session, which tries again, a
-- bounded number of times. A score that passes is rendered by the
-- ordinary pipeline. After that, each message the person types goes to
-- the same session (by its id), which may change the score, the word
-- files, or the studio's code, and must write the score again.
--
-- Data-format notes worth knowing more than once:
--   * the session answers in JSON (--output-format json): we read its
--     session_id (to resume) and result (its reply text);
--   * the score always lives at <run>/score.lua and the picture at
--     <run>/now.gif; the gif is written to now.gif.partial and renamed,
--     so a viewer watching now.gif never reads half a file;
--   * the word files are reloaded before every reading, because the
--     director is allowed to change them.

local DKJSON_PATH = "/home/ritz/programming/ai-stuff/libs/lua/?.lua;"
package.path = DKJSON_PATH .. package.path
local json = require("dkjson")
local sessions = require("038-word-sessions")

local director = {}

local WALL_ROUNDS = 4

-- {{{ local function run_session()
-- One turn of the session: a prompt in, the reply and the session id
-- out. `resume` continues an existing session; nil starts one. Any
-- reply that is not the expected JSON is an error with the raw text.
local function run_session(dir, run_dir, prompt, resume)
    local extra = resume and ("--resume " .. sessions.shell_quote(resume)) or nil
    local out = run_dir .. "/director.out"
    local cmd = "env -C " .. sessions.shell_quote(dir) .. " "
        .. sessions.command(prompt, extra) .. " > " .. sessions.shell_quote(out) .. " 2>&1"
    os.execute(cmd)
    local text = sessions.slurp(out) or ""
    local reply = json.decode(text)
    if type(reply) ~= "table" or not reply.session_id then
        error("director: the session did not answer as expected:\n" .. text, 0)
    end
    if reply.is_error then
        error("director: the session reported an error: " .. tostring(reply.result), 0)
    end
    return tostring(reply.result or ""), reply.session_id
end
-- }}}

-- {{{ local function word_list()
-- Every word file, as the brief shows it: the word, its kind, its
-- meaning, and for a pattern its fields and example.
local function word_list(vocabulary)
    local names = {}
    for name in pairs(vocabulary.entries) do names[#names + 1] = name end
    table.sort(names)
    local lines = {}
    for _, name in ipairs(names) do
        local e = vocabulary.entries[name]
        lines[#lines + 1] = "- **" .. name .. "** (" .. e.kind .. "): " .. e.meaning
        if e.kind == "pattern" then
            local fields = {}
            for k, v in pairs(e.fields) do fields[#fields + 1] = k .. " = " .. v end
            table.sort(fields)
            lines[#lines + 1] = "  fields: " .. table.concat(fields, "; ")
            lines[#lines + 1] = "  example: `" .. e.example .. "`"
        end
    end
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ function director.brief()
-- The first brief, written into the run folder. Built from the format
-- document and the word files, never written twice.
function director.brief(dir, run_dir, prose, vocabulary)
    local path = run_dir .. "/director-brief.md"
    sessions.spit(path, table.concat({
        "# Brief: draw this as a gif",
        "",
        "A person typed this into the gif studio:",
        "",
        "> " .. prose:gsub("\n", "\n> "),
        "",
        "## Your job",
        "",
        "Write one score, in the studio's score language, to:",
        "",
        "    " .. run_dir .. "/score.lua",
        "",
        "Then reply with one or two sentences saying what you drew. The studio",
        "checks the score with its wall and renders it; if the wall refuses it,",
        "you will be sent every refusal and asked to write the score again.",
        "",
        "Use the words below wherever they fit: a pattern word is used with",
        "`pattern{ name = \"...\", ... }`; a plain word tells you how to express",
        "something with the ordinary vocabulary. Use `canvas{ size = 256,",
        "fps = 25, ... }` unless the prose asks otherwise.",
        "",
        "The person will talk to you afterwards. You may then change the score,",
        "the word files in `" .. dir .. "/words/`, or the studio's own code, as",
        "their messages ask; after every change, write the score again.",
        "",
        "## The words the studio knows",
        "",
        word_list(vocabulary),
        "",
        "## The score language",
        "",
        sessions.slurp(dir .. "/docs/score-format.md") or "",
        "",
    }, "\n"))
    return path
end
-- }}}

-- {{{ function director.read_and_compile()
-- Reads <run>/score.lua with freshly loaded word files and compiles it.
-- Returns compiled, or nil and the refusal text.
function director.read_and_compile(dir, run_dir)
    local score = require("022-score")
    local compile = require("024-compile")
    local loaded_ok, vocabulary = pcall(require("034-words").load_all, dir)
    if not loaded_ok then return nil, tostring(vocabulary) end
    local read_ok, raw = pcall(score.read, run_dir .. "/score.lua", vocabulary)
    if not read_ok then return nil, tostring(raw) end
    local ok, compiled = pcall(compile.score, raw)
    if not ok then return nil, tostring(compiled) end
    return compiled
end
-- }}}

-- {{{ function director.render()
-- Renders a compiled score to <run>/now.gif, by way of a partial file and
-- a rename, so a watching viewer only ever sees whole gifs.
function director.render(run_dir, compiled)
    local main = require("026-render-main")
    local bytes, facts = main.render_to_gif(compiled)
    sessions.spit(run_dir .. "/now.gif.partial", bytes)
    local ok, why = os.rename(run_dir .. "/now.gif.partial", run_dir .. "/now.gif")
    if not ok then error("director: could not place the gif: " .. tostring(why), 0) end
    return facts
end
-- }}}

-- {{{ local function settle()
-- After the session has written a score: compile; on refusal, send the
-- wall's words back and try again, up to WALL_ROUNDS times. Returns
-- facts (rendered) or nil and the last refusal; `say` is called with
-- each status line for the person to see.
local function settle(dir, run_dir, session_id, say)
    for round = 1, WALL_ROUNDS do
        local compiled, refusal = director.read_and_compile(dir, run_dir)
        if compiled then
            say("the wall accepted the score; rendering")
            return director.render(run_dir, compiled)
        end
        say("the wall refused the score (round " .. round .. " of " .. WALL_ROUNDS .. ")")
        if round == WALL_ROUNDS then return nil, refusal end
        run_session(dir, run_dir, "The studio's wall refused the score at "
            .. run_dir .. "/score.lua. Here is everything it said; fix the "
            .. "score (or the word files) and write it again:\n\n" .. refusal,
            session_id)
    end
end
-- }}}

-- {{{ function director.start()
-- The first draft. Returns a state table: session_id, reply (the
-- director's own words), facts (nil when the wall never accepted),
-- refusal (the last refusal, when it did not).
function director.start(dir, run_dir, prose, say)
    local vocabulary = require("034-words").load_all(dir)
    local brief = director.brief(dir, run_dir, prose, vocabulary)
    say("the director is drawing")
    local reply, session_id = run_session(dir, run_dir,
        "Read the brief at " .. brief .. " and do what it says.", nil)
    local facts, refusal = settle(dir, run_dir, session_id, say)
    return { session_id = session_id, reply = reply, facts = facts, refusal = refusal }
end
-- }}}

-- {{{ function director.message()
-- One chat turn: the person's words to the same session, then the wall
-- and render again. Returns the director's reply, and facts or refusal.
function director.message(dir, run_dir, state, text, say)
    local reply = run_session(dir, run_dir, text
        .. "\n\n(After any change, write the score again to " .. run_dir
        .. "/score.lua.)", state.session_id)
    local facts, refusal = settle(dir, run_dir, state.session_id, say)
    return reply, facts, refusal
end
-- }}}

return director
