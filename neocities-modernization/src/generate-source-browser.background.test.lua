#!/usr/bin/env luajit

-- Guards issue 11-009: every source-browser page renders on pure black.
--
-- Why this test exists. The source browser is the one page family that set no
-- background at all -- a bare <body> -- so a reader following a link from a
-- pure-black poem page into it got the browser's default white.  Its stylesheet
-- also painted near-black panels under a glow and a grain overlay, each a lit
-- pixel on an OLED screen and a second "black" beside the poem pages.
--
-- It builds the source browser the way run.sh does (into DIR/output/source,
-- which is a build product and ignored by git) and then reads every page and
-- the shared stylesheet.  The page check is the issue's own audit:
--   find output/source -name '*.html' | xargs grep -L 'bgcolor="#000000"'
-- must print nothing.
--
-- Run directly:  luajit src/generate-source-browser.background.test.lua [project-dir]

-- {{{ local function project_dir()
local function project_dir()
    if arg and arg[1] then return (arg[1]:gsub("/$", "")) end
    local this = debug.getinfo(1, "S").source:sub(2)
    local src_dir = this:match("(.*)/") or "."
    local root = src_dir:gsub("/?src$", "")
    if root == "" then root = "." end
    return root
end
-- }}}

local DIR = project_dir()

local passed, failed = 0, 0

-- {{{ local function check()
local function check(name, condition, detail)
    if condition then
        passed = passed + 1
        print("  ok   " .. name)
    else
        failed = failed + 1
        print("  FAIL " .. name .. (detail and ("  -- " .. detail) or ""))
    end
end
-- }}}

-- {{{ local function read_file()
local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end
-- }}}

-- {{{ local function shell_quote()
local function shell_quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end
-- }}}

local q = shell_quote(DIR)
local built = os.execute("luajit " .. q .. "/src/generate-source-browser.lua " .. q .. " >/dev/null 2>&1")
check("the source browser builds", built == 0 or built == true)

local out = DIR .. "/output/source"

-- Every generated page: the black body tag and the dark declaration.  The raw
-- copies of the archived word clouds are the site's own pages, so they are held
-- to the same rule.
local pages, missing_bg, missing_scheme = 0, {}, {}
local list = io.popen("find " .. shell_quote(out) .. " -name '*.html'")
for path in list:lines() do
    pages = pages + 1
    local html = read_file(path) or ""
    if not html:find('bgcolor="#000000"', 1, true) then
        missing_bg[#missing_bg + 1] = path:sub(#out + 2)
    end
    -- Only pages this generator writes carry the shell's head; the archived
    -- word clouds are byte-for-byte copies and keep the head they shipped with.
    if html:find('id="wrap"', 1, true) and not html:find('name="color-scheme" content="dark"', 1, true) then
        missing_scheme[#missing_scheme + 1] = path:sub(#out + 2)
    end
end
list:close()

check("pages were written", pages > 0, "found " .. pages)
check("every page sets a pure-black background (11-009 audit)", #missing_bg == 0,
    #missing_bg .. " without it, e.g. " .. tostring(missing_bg[1]))
check("every generated page declares itself dark", #missing_scheme == 0,
    #missing_scheme .. " without it, e.g. " .. tostring(missing_scheme[1]))

local index = read_file(out .. "/index.html") or ""
check("the index no longer opens with a bare <body>", not index:find("<body>", 1, true))

-- The stylesheet: every panel colour is the site's black, and nothing paints
-- light over it.
local css = read_file(out .. "/_style.css") or ""
check("the stylesheet was written", css ~= "")
check("the page ink is pure black", css:find("--ink:#000000;", 1, true) ~= nil)
check("the second panel colour is pure black", css:find("--ink-2:#000000;", 1, true) ~= nil)
check("the side panel colour is pure black", css:find("--panel:#000000;", 1, true) ~= nil)
check("no placeholder is left in the stylesheet", not css:find("__PAGE_BG__", 1, true))
for _, old in ipairs({ "#0b0c10", "#13151f", "#0e1018" }) do
    check("the old near-black " .. old .. " is gone", not css:find(old, 1, true))
end
check("no glow is painted over the background", not css:find("radial-gradient", 1, true))
check("no grain overlay is painted over the background", not css:find("feTurbulence", 1, true))

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
