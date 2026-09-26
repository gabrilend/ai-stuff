-- 027-the-language-table.lua
--
-- What a file is: its language, its role (code, doc, data, build, binary),
-- and which include scanner reads it. Decided from the file's name and its
-- first 8 KiB, never by a model. Adding a language is adding a row.
--
-- Order of decision (docs/004):
--   1. a whole-name row (Makefile, CMakeLists.txt)
--   2. an extension row
--   3. a NUL byte in the first 8 KiB -> binary
--   4. a #! line -> the interpreter's row
--   5. otherwise: language "other", role "data"

local languages = {}

-- Extension (lower-case, without the dot) -> row.
languages.BY_EXTENSION = {
    lua = { language = "lua", role = "code", scanner = "lua" },
    c = { language = "c", role = "code", scanner = "c" },
    h = { language = "c", role = "code", scanner = "c" },
    cpp = { language = "c++", role = "code", scanner = "c" },
    cc = { language = "c++", role = "code", scanner = "c" },
    cxx = { language = "c++", role = "code", scanner = "c" },
    hpp = { language = "c++", role = "code", scanner = "c" },
    hh = { language = "c++", role = "code", scanner = "c" },
    cmake = { language = "cmake", role = "build", scanner = nil },
    S = { language = "assembly", role = "code", scanner = "c" },
    s = { language = "assembly", role = "code", scanner = nil },
    sh = { language = "shell", role = "code", scanner = "shell" },
    bash = { language = "shell", role = "code", scanner = "shell" },
    py = { language = "python", role = "code", scanner = "python" },
    js = { language = "javascript", role = "code", scanner = "javascript" },
    mjs = { language = "javascript", role = "code", scanner = "javascript" },
    ts = { language = "javascript", role = "code", scanner = "javascript" },
    html = { language = "html", role = "code", scanner = nil },
    css = { language = "css", role = "code", scanner = nil },
    ld = { language = "linker-script", role = "build", scanner = nil },
    md = { language = "markdown", role = "doc", scanner = nil },
    txt = { language = "text", role = "doc", scanner = nil },
    json = { language = "data", role = "data", scanner = nil },
    tsv = { language = "data", role = "data", scanner = nil },
    csv = { language = "data", role = "data", scanner = nil },
    toml = { language = "data", role = "data", scanner = nil },
    yaml = { language = "data", role = "data", scanner = nil },
    yml = { language = "data", role = "data", scanner = nil },
    sql = { language = "sql", role = "code", scanner = nil },
    png = { language = "binary", role = "binary", scanner = nil },
    jpg = { language = "binary", role = "binary", scanner = nil },
    ttf = { language = "binary", role = "binary", scanner = nil },
}

-- Whole file names -> row.
languages.BY_NAME = {
    ["Makefile"] = { language = "make", role = "build", scanner = nil },
    ["makefile"] = { language = "make", role = "build", scanner = nil },
    ["CMakeLists.txt"] = { language = "cmake", role = "build", scanner = nil },
}

-- Interpreters named on a #! line -> row.
languages.BY_INTERPRETER = {
    lua = languages.BY_EXTENSION.lua,
    luajit = languages.BY_EXTENSION.lua,
    bash = languages.BY_EXTENSION.sh,
    sh = languages.BY_EXTENSION.sh,
    python = languages.BY_EXTENSION.py,
    python3 = languages.BY_EXTENSION.py,
    node = languages.BY_EXTENSION.js,
}

local BINARY = { language = "binary", role = "binary", scanner = nil }
local OTHER = { language = "other", role = "data", scanner = nil }

-- {{{ local function interpreter_of
-- "#!/usr/bin/env luajit" and "#!/bin/bash -e" both name their interpreter.
local function interpreter_of(first_line)
    local command = first_line:match("^#!%s*(%S+)")
    if not command then
        return nil
    end
    local name = command:match("([^/]+)$")
    if name == "env" then
        name = first_line:match("^#!%s*%S+%s+(%S+)")
    end
    return name
end
-- }}}

-- {{{ function languages.classify
-- `path` is the file's path (only its name matters); `head` is its first
-- 8 KiB. Returns a row: { language, role, scanner }.
function languages.classify(path, head)
    local name = path:match("([^/]+)$") or path
    local row = languages.BY_NAME[name]
    if row then
        return row
    end
    local extension = name:match("%.([^%.]+)$")
    -- Extensions are matched as written first (.S assembly differs from .s),
    -- then lower-cased.
    if extension then
        row = languages.BY_EXTENSION[extension] or languages.BY_EXTENSION[extension:lower()]
        if row then
            return row
        end
    end
    if head:find("%z") then
        return BINARY
    end
    local interpreter = interpreter_of(head:match("^[^\n]*") or "")
    if interpreter then
        row = languages.BY_INTERPRETER[interpreter]
        if row then
            return row
        end
    end
    return OTHER
end
-- }}}

return languages
