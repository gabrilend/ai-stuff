-- kit.lua — the small checking kit the words-pdf tests share, and the
-- loader that brings compile-pdf-ai.lua's functions in without making a
-- PDF.  No framework: a check is a named function that passes by running
-- through and fails by raising; finish() prints "counts <passed> <failed>"
-- for tests/run-tests to read.

local kit = { passed = 0, failed = 0 }

-- {{{ function kit.check
function kit.check(name, fn)
    local ok, problem = pcall(fn)
    -- Path: ran through — a pass.  Raised — a failure, with why.
    if ok then
        kit.passed = kit.passed + 1
        print("    PASS " .. name)
    else
        kit.failed = kit.failed + 1
        print("    FAIL " .. name .. ": " .. tostring(problem))
    end
end
-- }}}

-- {{{ function kit.same
function kit.same(got, want, what)
    if got ~= want then
        error((what or "value") .. ": got " .. tostring(got) .. ", want " .. tostring(want), 2)
    end
end
-- }}}

-- {{{ function kit.near
-- Numbers equal within a small tolerance (floating point).
function kit.near(got, want, what)
    if type(got) ~= "number" or math.abs(got - want) > 1e-9 then
        error((what or "value") .. ": got " .. tostring(got) .. ", want " .. tostring(want), 2)
    end
end
-- }}}

-- {{{ function kit.lines
-- Two lists of strings equal, line for line.
function kit.lines(got, want, what)
    what = what or "lines"
    if #got ~= #want then
        error(what .. ": got " .. #got .. " lines {" .. table.concat(got, " | ")
            .. "}, want " .. #want .. " {" .. table.concat(want, " | ") .. "}", 2)
    end
    for i = 1, #want do
        if got[i] ~= want[i] then
            error(what .. ": line " .. i .. " is '" .. tostring(got[i])
                .. "', want '" .. want[i] .. "'", 2)
        end
    end
end
-- }}}

-- {{{ function kit.truthy
function kit.truthy(value, what)
    if not value then error((what or "condition") .. " does not hold", 2) end
end
-- }}}

-- {{{ function kit.finish
function kit.finish()
    print("counts " .. kit.passed .. " " .. kit.failed)
    os.exit(kit.failed == 0 and 0 or 1)
end
-- }}}

-- {{{ function kit.load_compiler
-- Loads compile-pdf-ai.lua for its functions: the libharu binding is
-- replaced by a stand-in that accepts any call (no test draws), and
-- WORDS_PDF_NO_MAIN stops it from generating a book.  input_file becomes
-- the script's FILE global, which load_file reads.
function kit.load_compiler(dir, input_file)
    package.preload["hpdf"] = function()
        return setmetatable({}, { __index = function() return function() end end })
    end
    WORDS_PDF_NO_MAIN = true
    local saved_arg = arg
    arg = { [0] = dir .. "/compile-pdf-ai.lua", dir, input_file or "" }
    dofile(dir .. "/compile-pdf-ai.lua")
    arg = saved_arg
end
-- }}}

-- {{{ function kit.extract_function
-- Pulls one top-level function's source out of a Lua file, from its
-- "function NAME(" line to the first line that is exactly "end" or starts
-- with "end --", and returns it as a chunk that defines NAME as a global.
-- Used to run a script's local copy of a function without running the
-- script.
function kit.extract_function(path, name)
    local f = assert(io.open(path, "r"))
    local text = f:read("*a")
    f:close()
    local out, inside = {}, false
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        if not inside and (line:match("^local function " .. name .. "%(")
                           or line:match("^function " .. name .. "%(")) then
            inside = true
            line = line:gsub("^local ", "")
        end
        if inside then
            table.insert(out, line)
            if line == "end" or line:match("^end %-%-") then break end
        end
    end
    if #out == 0 then error("no function " .. name .. " in " .. path, 2) end
    return table.concat(out, "\n")
end
-- }}}

-- {{{ function kit.sandbox
-- Runs chunks in a fresh environment (globals from _G readable, writes
-- kept apart) and returns that environment, so two copies of the same
-- function name can live side by side.
function kit.sandbox(chunks)
    local env = setmetatable({}, { __index = _G })
    for _, chunk in ipairs(chunks) do
        local fn
        if setfenv then  -- LuaJIT / Lua 5.1
            fn = assert(loadstring(chunk))
            setfenv(fn, env)
        else
            fn = assert(load(chunk, "extracted", "t", env))
        end
        fn()
    end
    return env
end
-- }}}

return kit
