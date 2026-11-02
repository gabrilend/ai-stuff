-- 140-checking-ollama-confinement.lua
--
-- Checks issue 903d: whatever the model prints to standard output becomes
-- the turn's result.json `answer` field, written by the machine; the
-- model's standard error goes to stderr.txt and its exit status to `exit`;
-- nothing else on disk changes. A stand-in `ollama` program plays the
-- model, so no server or model is needed.

local kit = dofile(arg[1] .. "/tests/020-checking-kit.lua")
local fs = kit.fs
local harnesses = require("037-the-harness-table")
local sha = require("015-sha-256")

local scratch = kit.scratch("ollama-confinement")
local bin = scratch .. "/bin"
fs.make_folder(bin)

-- The model's answer, with everything JSON must escape: quotes, a
-- backslash, a tab, newlines, a control byte and a multi-byte character.
local ANSWER = 'shape: "circle"\nstation: chart\\png\t→ ok\1\n'
kit.write_file(scratch .. "/answer.txt", ANSWER)
kit.write_file(bin .. "/ollama", table.concat({
    "#!/bin/sh",
    "# A stand-in model: reads the prompt, prints a fixed answer, says",
    "# something on standard error, exits with the status it is given.",
    "[ \"$1\" = run ] || exit 9",
    "cat > /dev/null",
    "cat " .. fs.quote(scratch .. "/answer.txt"),
    "echo 'pulling manifest' >&2",
    "exit ${FAKE_STATUS:-0}",
}, "\n") .. "\n")
assert(fs.run("chmod +x " .. fs.quote(bin .. "/ollama")))

-- {{{ local function decode_answer
-- Reads {"answer":"..."} back, undoing JSON's string escapes, so the check
-- compares against the model's own bytes rather than our encoder's.
local function decode_answer(text)
    local body = text:match('^{"answer":"(.*)"}\n$')
    if not body then
        return nil
    end
    local simple = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
    local out, i = {}, 1
    while i <= #body do
        local c = body:sub(i, i)
        if c == "\\" then
            local e = body:sub(i + 1, i + 1)
            if e == "u" then
                out[#out + 1] = string.char(tonumber(body:sub(i + 2, i + 5), 16))
                i = i + 6
            else
                out[#out + 1] = simple[e]
                i = i + 2
            end
        elseif c == '"' or c:byte() < 32 then
            return nil
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
    return table.concat(out)
end
-- }}}

-- {{{ local function fingerprint
local function fingerprint(dir, skip, out)
    out = out or {}
    for _, name in ipairs(fs.list(dir)) do
        local path = dir .. "/" .. name
        if fs.is_folder(path) then
            out[#out + 1] = path .. "/"
            fingerprint(path, skip, out)
        elseif not skip[path] then
            out[#out + 1] = path .. " " .. sha.of_string(fs.read(path))
        end
    end
    table.sort(out)
    return table.concat(out, "\n")
end
-- }}}

-- {{{ local function run_turn
local function run_turn(label, status)
    local case = scratch .. "/" .. label
    local folder = case .. "/turns/0001-route"
    fs.make_folder(case .. "/turns")
    fs.make_folder(folder)
    kit.write_file(case .. "/station-table.lua", "return {}\n")
    kit.write_file(folder .. "/prompt.md", "Which station takes a circle?\n")
    local turn = { folder = folder, writes = { folder .. "/" }, reads = { case .. "/" }, model = "tiny:1b" }
    local made = { [folder .. "/result.json"] = true, [folder .. "/stderr.txt"] = true, [folder .. "/exit"] = true }
    local before = fingerprint(case, made)
    local row = harnesses.TABLE.ollama
    local line = harnesses.shell_line(kit.project, row, turn)
    fs.run("export PATH=" .. fs.quote(bin) .. ":\"$PATH\" FAKE_STATUS=" .. status .. "; " .. line)
    return {
        before = before, after = fingerprint(case, made),
        result = fs.read(folder .. "/result.json"), stderr = fs.read(folder .. "/stderr.txt"),
        exit = tonumber((fs.read(folder .. "/exit"):gsub("%s", ""))),
        made = fs.list(folder),
    }
end
-- }}}

local good = run_turn("good", 0)
kit.equal(decode_answer(good.result), ANSWER, "whatever the model printed is the result's answer field, byte for byte")
kit.check(good.result:find("pulling manifest", 1, true) == nil, "nothing on standard error reaches the answer")
kit.equal(good.stderr, "pulling manifest\n", "the model's standard error goes to stderr.txt")
kit.equal(good.exit, 0, "the turn's exit is the model's")
kit.equal(good.after, good.before, "nothing else on disk changes")
kit.equal(table.concat(good.made, " "), "exit prompt.md result.json stderr.txt", "the turn folder holds only the prompt and the machine's three files")

local failed = run_turn("failed", 3)
kit.equal(failed.exit, 3, "a model that fails passes its status on to the turn")
kit.equal(decode_answer(failed.result), ANSWER, "what it printed is still kept as the answer")
kit.equal(failed.after, failed.before, "a failing model changes nothing else either")

local one_answer = dofile(kit.DIR .. "/src/138-one-answer.lua")
kit.equal(one_answer.json(""), '{"answer":""}\n', "an empty answer is an empty string, not a missing field")

kit.finish()
