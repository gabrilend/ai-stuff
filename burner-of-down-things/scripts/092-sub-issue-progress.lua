#!/usr/bin/env luajit
-- 092-sub-issue-progress.lua
--
-- For every issue that has been split into lettered sub-issues (the
-- issue-lifecycle convention: 801a, 801b, ...), reports how many of its
-- pieces are built (moved to issues/completed/) against how many exist.
-- Reads nothing but the issues/ tree itself and writes nothing: split
-- another issue or finish another piece, and the next run already knows,
-- without this tool being told anything by hand.
--
-- Usage:
--   luajit scripts/092-sub-issue-progress.lua [project folder]
--   (the project folder defaults to DIR below)

local DIR = "/mnt/mtwo/programming/ai-stuff/burner-of-down-things"
local args = { ... }
if args[1] and args[1]:sub(1, 1) == "/" then
    DIR = args[1]
end

-- {{{ local function quote
local function quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function list
-- Sorted file names directly inside a folder (no recursion); an absent
-- folder lists as empty, not an error.
local function list(folder)
    local names = {}
    local pipe = io.popen("ls -1 " .. quote(folder) .. " 2>/dev/null")
    for name in pipe:lines() do
        names[#names + 1] = name
    end
    pipe:close()
    table.sort(names)
    return names
end
-- }}}

-- {{{ local function read_file
local function read_file(path)
    local file = io.open(path, "rb")
    if not file then
        return nil
    end
    local text = file:read("*a")
    file:close()
    return text
end
-- }}}

-- {{{ local function sub_issue_ids
-- The ids listed under a "## Sub-issues" section, in the order written.
local function sub_issue_ids(text)
    local section = text:match("## Sub%-issues\n(.-)\n##")
    if not section then
        return {}
    end
    local ids = {}
    for id in section:gmatch("%-%s+(%d+%a?)%s") do
        ids[#ids + 1] = id
    end
    return ids
end
-- }}}

-- {{{ local function title_of
local function title_of(text)
    return text:match("^# %d+%a?%s+%S+%s+(.-)\n") or "?"
end
-- }}}

local open_names = list(DIR .. "/issues")
local completed_names = list(DIR .. "/issues/completed")

-- {{{ local function built
local function built(id)
    for _, name in ipairs(completed_names) do
        if name:match("^" .. id .. "%-") then
            return true
        end
    end
    return false
end
-- }}}

-- {{{ local function collect
-- Parent issues (no letter right after the digits) from one folder's
-- listing that hold a "## Sub-issues" section.
local function collect(names, folder, rows)
    for _, name in ipairs(names) do
        if name:match("^%d+%-.*%.md$") then
            local text = read_file(folder .. "/" .. name)
            local ids = sub_issue_ids(text or "")
            if #ids > 0 then
                local done = 0
                local marks = {}
                for _, sub_id in ipairs(ids) do
                    local is_built = built(sub_id)
                    if is_built then
                        done = done + 1
                    end
                    marks[#marks + 1] = sub_id .. (is_built and "*" or " ")
                end
                rows[#rows + 1] = {
                    id = name:match("^(%d+)%-"),
                    title = title_of(text),
                    done = done,
                    total = #ids,
                    marks = table.concat(marks, " "),
                }
            end
        end
    end
end
-- }}}

local rows = {}
collect(open_names, DIR .. "/issues", rows)
collect(completed_names, DIR .. "/issues/completed", rows)
table.sort(rows, function(a, b) return tonumber(a.id) < tonumber(b.id) end)

local done_total, piece_total = 0, 0
print(string.format("%-6s %-40s %-5s  pieces (* built)", "id", "issue", "done"))
for _, row in ipairs(rows) do
    done_total = done_total + row.done
    piece_total = piece_total + row.total
    print(string.format("%-6s %-40s %d/%d    %s", row.id, row.title, row.done, row.total, row.marks))
end
print()
print(string.format("%d issues split, %d/%d pieces built", #rows, done_total, piece_total))
