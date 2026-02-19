#!/usr/bin/env luajit

-- {{{ 001-html-structure-diff-analyzer.lua
-- A tool for comparing HTML page structures by stripping content and revealing patterns.
--
-- CONCEPTION:
-- When comparing two similar HTML files (e.g., similar/7378-01.html vs different/7378-01.html),
-- the raw diff is noisy because poem content differs. We want to see STRUCTURAL differences.
--
-- PROCESS:
-- 1. Read both files (first N lines)
-- 2. Strip content between structural markers (progress bars and nav boxes)
-- 3. Output stripped versions for diff comparison
-- 4. Progressively increase line count to watch patterns emerge
--
-- The structural markers in neocities-modernization HTML:
-- - Progress bar top: starts with <font color="...═══
-- - Navigation box top: starts with <font color="...┌
-- - Navigation box mid: contains "similar" and "different" links
-- - Navigation box bottom: starts with <font color="...╘ or ╚
-- - Section headers: === ... ===
-- - Poem headers: --- #N ... ---
--
-- Usage:
--   luajit 001-html-structure-diff-analyzer.lua <file1> <file2> [lines]
-- }}}

local DIR = "/home/ritz/programming/ai-stuff/lua-stories"

-- {{{ local function read_file
local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end
-- }}}

-- {{{ local function read_lines
local function read_lines(path, max_lines)
    local lines = {}
    local f = io.open(path, "r")
    if not f then return nil end

    local count = 0
    for line in f:lines() do
        count = count + 1
        if max_lines and count > max_lines then break end
        table.insert(lines, line)
    end
    f:close()
    return lines
end
-- }}}

-- {{{ local function is_structural_line
-- Returns true if line is a structural element (not poem content)
local function is_structural_line(line)
    -- HTML document structure
    if line:match("^<!DOCTYPE") then return true end
    if line:match("^<html") then return true end
    if line:match("^</html") then return true end
    if line:match("^<head") then return true end
    if line:match("^</head") then return true end
    if line:match("^<body") then return true end
    if line:match("^</body") then return true end
    if line:match("^<title") then return true end
    if line:match("^<table") then return true end
    if line:match("^</table") then return true end
    if line:match("^<tr") then return true end
    if line:match("^</tr") then return true end
    if line:match("^<td") then return true end
    if line:match("^</td") then return true end
    if line:match("^<pre") then return true end
    if line:match("^</pre") then return true end

    -- Progress bars (box-drawing characters with color)
    if line:match("^<font color=.*═") then return true end

    -- Navigation boxes
    if line:match("^<font color=.*┌") then return true end
    if line:match("^<font color=.*│.*similar.*│") then return true end
    if line:match("^<font color=.*╘") then return true end
    if line:match("^<font color=.*╚") then return true end
    if line:match("^<font color=.*╟") then return true end
    if line:match("^<font color=.*║") then return true end

    -- Section and poem headers
    if line:match("^=== .* ===$") then return true end
    if line:match("^--- #%d+ .* ---$") then return true end

    -- Media tags (structural, content is in alt text which we keep)
    if line:match("^%s*<img ") then return true end
    if line:match("^%s*<audio ") then return true end
    if line:match("^%s*<video ") then return true end
    if line:match("^%s*<source ") then return true end
    if line:match("^%s*</audio") then return true end
    if line:match("^%s*</video") then return true end

    -- File identifier lines
    if line:match("^ %-> file:") then return true end

    -- Image placeholders
    if line:match("^ %[Image:") then return true end

    return false
end
-- }}}

-- {{{ local function extract_structure
-- Extract only structural lines, replacing content with [CONTENT]
local function extract_structure(lines)
    local structure = {}
    local in_content = false
    local content_lines = 0

    for _, line in ipairs(lines) do
        if is_structural_line(line) then
            -- Flush content marker if we were in content
            if in_content and content_lines > 0 then
                table.insert(structure, string.format("[CONTENT: %d lines]", content_lines))
                content_lines = 0
                in_content = false
            end
            table.insert(structure, line)
        else
            -- We're in content
            in_content = true
            content_lines = content_lines + 1
        end
    end

    -- Flush final content marker
    if in_content and content_lines > 0 then
        table.insert(structure, string.format("[CONTENT: %d lines]", content_lines))
    end

    return structure
end
-- }}}

-- {{{ local function write_file
local function write_file(path, content)
    local f = io.open(path, "w")
    if not f then return false end
    f:write(content)
    f:close()
    return true
end
-- }}}

-- {{{ local function main
local function main()
    local file1 = arg[1]
    local file2 = arg[2]
    local max_lines = tonumber(arg[3]) or 1000

    if not file1 or not file2 then
        print("Usage: luajit 001-html-structure-diff-analyzer.lua <file1> <file2> [lines]")
        print("")
        print("Compares structural elements of two HTML files, stripping poem content.")
        print("")
        print("Example:")
        print("  luajit 001-html-structure-diff-analyzer.lua similar/7378-01.html different/7378-01.html 500")
        os.exit(1)
    end

    print(string.format("=== Analyzing first %d lines ===", max_lines))
    print(string.format("File 1: %s", file1))
    print(string.format("File 2: %s", file2))
    print("")

    -- Read lines
    local lines1 = read_lines(file1, max_lines)
    local lines2 = read_lines(file2, max_lines)

    if not lines1 then
        print("ERROR: Could not read " .. file1)
        os.exit(1)
    end
    if not lines2 then
        print("ERROR: Could not read " .. file2)
        os.exit(1)
    end

    print(string.format("Read %d lines from file 1", #lines1))
    print(string.format("Read %d lines from file 2", #lines2))
    print("")

    -- Extract structure
    local struct1 = extract_structure(lines1)
    local struct2 = extract_structure(lines2)

    print(string.format("Structural lines in file 1: %d", #struct1))
    print(string.format("Structural lines in file 2: %d", #struct2))
    print("")

    -- Write to temp files for diff
    local tmp1 = "/tmp/struct1.txt"
    local tmp2 = "/tmp/struct2.txt"

    write_file(tmp1, table.concat(struct1, "\n") .. "\n")
    write_file(tmp2, table.concat(struct2, "\n") .. "\n")

    print("Wrote structural extracts to:")
    print("  " .. tmp1)
    print("  " .. tmp2)
    print("")
    print("=== DIFF OUTPUT ===")
    print("")

    -- Run diff
    os.execute(string.format("diff -u %s %s | head -100", tmp1, tmp2))
end
-- }}}

-- {{{ FINDINGS LOG
--[[
    DATE: 2026-02-10
    COMPARISON: similar/7378-01.html vs different/7378-01.html

    PATTERN DISCOVERED:
    ==================
    The two page types use DIFFERENT image rendering strategies:

    | Metric              | Similar Page | Different Page |
    |---------------------|--------------|----------------|
    | <img src=...> tags  | 8            | 26             |
    | [Image: ...] text   | 146          | 13             |
    | </pre> breaks       | 3            | 16             |

    STRUCTURAL ANALYSIS:
    - Both have identical wrapper: <table align="center"><tr><td><pre>
    - Both have balanced <pre>/</pre> tags
    - Both close properly: </pre></td></tr></table></body></html>

    KEY DIFFERENCE:
    The "different" page poems happen to have more ACTUAL image attachments
    (from fediverse posts) that render as <img> tags, while "similar" page
    poems have more [Image: ...] text placeholders (from messages category).

    When <img> tags render, they break out of <pre> with </pre>...<pre>,
    and the image uses: style="display:block; max-width:min(100%,800px)"

    MISSING: margin:0 auto on images - this causes left-alignment within <td>

    HYPOTHESIS:
    The centering difference may be caused by:
    1. Images being left-aligned within the centered table cell
    2. Browser rendering differences when many </pre><pre> breaks occur
    3. Content width differences affecting table centering behavior

    NEXT STEP: Confirm which page appears left-justified (likely different)
               and add margin:0 auto to image styles in render_attachment_images()
]]--
-- }}}

main()
