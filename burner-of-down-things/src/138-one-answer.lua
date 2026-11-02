#!/usr/bin/env luajit
-- 138-one-answer.lua
--
-- The single-answer turn wrapper (docs/068, issue 903d), for a harness
-- whose model has no file tools of its own (ollama's). Runs the model
-- command given as arguments, the prompt passing through on standard input;
-- keeps only what the model prints on standard output; and prints it, as
-- one JSON object {"answer": "..."}, for the turn's shell line to write
-- into result.json. The machine writes the answer, not the model, and this
-- wrapper writes nothing at all to disk. The model's standard error passes
-- through to the turn's stderr.txt, and its exit status is this wrapper's.
--
-- Usage (from 037's ollama row):
--   luajit 138-one-answer.lua <program> <arguments...> < prompt.md

local SRC = (arg[0]:match("^(.*)/[^/]*$")) or "."
package.path = SRC .. "/?.lua;" .. package.path

local fs = require("017-the-filesystem")
local harnesses = require("037-the-harness-table")

local one_answer = {}

-- {{{ function one_answer.json
-- The answer as the turn's result: exactly what the model printed, no
-- trimming, as one JSON object and a newline.
function one_answer.json(printed)
    return '{"answer":' .. harnesses.json_string(printed) .. "}\n"
end
-- }}}

-- {{{ function one_answer.run
-- Runs the command (an array of words, each quoted for the shell) and
-- returns what it printed on standard output and its exit status.
function one_answer.run(words)
    local quoted = {}
    for i, word in ipairs(words) do
        quoted[i] = fs.quote(word)
    end
    local printed, _, code = fs.capture(table.concat(quoted, " "))
    return printed, code or 1
end
-- }}}

-- {{{ local function main
local function main(words)
    if #words == 0 then
        io.stderr:write("one-answer: usage: 138-one-answer.lua <program> <arguments...> < prompt\n")
        os.exit(2)
    end
    local printed, code = one_answer.run(words)
    io.stdout:write(one_answer.json(printed))
    io.stdout:flush()
    os.exit(code)
end
-- }}}

if arg and arg[0] and arg[0]:match("138%-one%-answer%.lua$") then
    main({ ... })
end

return one_answer
