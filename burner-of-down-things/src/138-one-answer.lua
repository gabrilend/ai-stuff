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

-- This file's own folder, whether run as a script or loaded with dofile.
local SRC = (debug.getinfo(1, "S").source:match("^@(.*)/[^/]*$")) or "."
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

-- {{{ local function utf8_char
local function utf8_char(code)
    if code < 0x80 then
        return string.char(code)
    elseif code < 0x800 then
        return string.char(0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40)
    end
    return string.char(0xE0 + math.floor(code / 0x1000), 0x80 + math.floor(code / 0x40) % 0x40, 0x80 + code % 0x40)
end
-- }}}

-- {{{ function one_answer.decode
-- The answer back out of a result.json this wrapper wrote: the text, or
-- nil when the file is not one `{"answer": "..."}` object. Undoes JSON's
-- string escapes; a \u escape of a surrogate half is refused rather than
-- written as a broken character.
function one_answer.decode(text)
    local body = type(text) == "string" and text:match('^%s*{%s*"answer"%s*:%s*"(.*)"%s*}%s*$')
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
                local code = tonumber(body:sub(i + 2, i + 5), 16)
                if not code or #body:sub(i + 2, i + 5) ~= 4 or (code >= 0xD800 and code <= 0xDFFF) then
                    return nil
                end
                out[#out + 1] = utf8_char(code)
                i = i + 6
            elseif simple[e] then
                out[#out + 1] = simple[e]
                i = i + 2
            else
                return nil
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
