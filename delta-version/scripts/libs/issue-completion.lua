#!/usr/bin/env luajit
-- issue-completion.lua
--
-- The text work behind commit-completed-issue.sh: says which issue a file is
-- (its id, phase and title), and writes the one line that records it as done
-- into a progress file.
--
-- In general terms: the id and phase come from the shared issue-name reader
-- (scripts/libs/issue-names.lua), so this agrees with the progress dashboard
-- and validate-issues about which phase an issue is in. The record goes under
-- the progress file's first "Completed" heading -- "Completed", "Completed
-- Issues", "Recently Completed", ignoring case, emphasis and emoji -- at
-- the end of its list, or at the top for a "Recently ..." list, which the
-- house keeps newest first. A file with no such heading gets one at its end.
-- Nothing else in the file is touched.
--
-- Usage (from the wrapper; each prints tab-separated fields or lines):
--   issue-completion.lua locate <scripts-dir> <project-dir> <issue-file>
--       prints: id <TAB> phase (or "-") <TAB> title
--   issue-completion.lua record <progress-file> <id> <title> <date> [--dry-run]
--       writes the record (unless --dry-run) and prints each line it added

-- {{{ local function read_file
local function read_file(path)
    local f, err = io.open(path, "rb")
    if not f then return nil, err end
    local text = f:read("*a")
    f:close()
    return text
end
-- }}}

-- {{{ local function write_file
local function write_file(path, text)
    local f, err = io.open(path, "wb")
    if not f then return nil, err end
    f:write(text)
    f:close()
    return true
end
-- }}}

-- {{{ local function split_lines
-- Lines without their newlines; a final newline does not make an empty line.
local function split_lines(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    if text:sub(-1) == "\n" then lines[#lines] = nil end
    return lines
end
-- }}}

-- {{{ local function issue_title
-- The first "# " heading, without an "Issue 055:" or "055 -" prefix that only
-- repeats the id.
local function issue_title(path, id)
    local text = read_file(path) or ""
    for _, line in ipairs(split_lines(text)) do
        local title = line:match("^#%s+(.-)%s*$")
        if title then
            local escaped = id:gsub("%W", "%%%0")
            -- The em dash is three bytes, so it is its own alternative
            -- rather than a member of a character class.
            for _, prefix in ipairs({ "^[Ii]ssue%s+", "^" }) do
                for _, mark in ipairs({ "[:%-]", "—" }) do
                    title = title:gsub(prefix .. escaped .. "%s*" .. mark .. "%s*", "", 1)
                end
            end
            return title
        end
    end
    return path:match("([^/]+)%.md$") or path
end
-- }}}

-- {{{ local function locate
local function locate(scripts_dir, project_dir, issue_file)
    local issue_names = dofile(scripts_dir .. "/libs/issue-names.lua")
    local issues = issue_names.scan(project_dir)
    for _, issue in ipairs(issues) do
        if issue.path == issue_file then
            io.write(issue.id, "\t", issue.phase or "-", "\t",
                     issue_title(issue_file, issue.id), "\n")
            return true
        end
    end
    io.stderr:write("issue-completion: ", issue_file,
                    " is not an issue file the shared reader recognises\n")
    return false
end
-- }}}

-- {{{ local function completed_heading
-- The heading's level and whether its list runs newest first, when a line is
-- a "Completed" heading; nil otherwise. Emphasis, emoji and a trailing colon
-- are ignored: "### ✅ **Completed Issues**" counts.
local function completed_heading(line)
    local hashes, text = line:match("^(#+)%s+(.-)%s*$")
    if not hashes then return nil end
    local words = text:lower():gsub("[^%a ]", ""):gsub("%s+", " ")
    words = words:gsub("^ ", ""):gsub(" $", "")
    local recent = words:match("^recently ") ~= nil
    words = words:gsub("^recently ", "")
    if words == "completed" or words == "completed issues" then
        return #hashes, recent
    end
    return nil
end
-- }}}

-- {{{ local function is_item
local function is_item(line)
    return line:match("^[-*]%s") ~= nil
end
-- }}}

-- {{{ local function record
local function record(progress_file, id, title, date, dry_run)
    local text, err = read_file(progress_file)
    if not text then
        io.stderr:write("issue-completion: cannot read ", progress_file, ": ", tostring(err), "\n")
        return false
    end
    local lines = split_lines(text)

    -- Find the first "Completed" heading and where its section ends.
    local head, level, recent
    for i, line in ipairs(lines) do
        local l, r = completed_heading(line)
        if l then head, level, recent = i, l, r; break end
    end

    local added = {}
    local at -- insert the added lines after this line number
    if head then
        local stop = #lines
        for i = head + 1, #lines do
            local hashes = lines[i]:match("^(#+)%s")
            if hashes and #hashes <= level then stop = i - 1; break end
        end
        -- Match the list's own style for the first item it already has.
        local bold = false
        for i = head + 1, stop do
            if is_item(lines[i]) then
                bold = lines[i]:match("^[-*]%s+%*%*Issue ") ~= nil
                break
            end
        end
        if bold then
            added[1] = string.format("- **Issue %s**: %s (%s)", id, title, date)
        else
            added[1] = string.format("- %s %s — completed %s", id, title, date)
        end

        if recent then
            at = head
            -- Keep a blank line between heading and list if the file has one.
            if lines[head + 1] == "" then at = head + 1 end
        else
            -- After the last item of the section and its indented
            -- continuation lines.
            local last
            for i = head + 1, stop do
                if is_item(lines[i]) then
                    last = i
                elseif last and last == i - 1 and lines[i]:match("^%s+%S") then
                    last = i
                end
            end
            at = last or head
            -- A list whose items stand apart with blank lines gets one too.
            local last_item
            for i = at, head + 1, -1 do
                if is_item(lines[i]) then last_item = i; break end
            end
            if last_item and lines[last_item - 1] == "" and last_item - 1 > head then
                table.insert(added, 1, "")
            end
        end
    else
        added[1] = ""
        added[2] = "## Completed Issues"
        added[3] = string.format("- %s %s — completed %s", id, title, date)
        at = #lines
        if lines[#lines] == "" then
            table.remove(added, 1)
        end
    end

    for _, line in ipairs(added) do io.write(line, "\n") end
    if dry_run then return true end

    local out = {}
    for i = 1, at do out[#out + 1] = lines[i] end
    for _, line in ipairs(added) do out[#out + 1] = line end
    for i = at + 1, #lines do out[#out + 1] = lines[i] end
    -- A file that did not end in a newline still does not.
    local ending = (text == "" or text:sub(-1) == "\n") and "\n" or ""
    local ok, werr = write_file(progress_file, table.concat(out, "\n") .. ending)
    if not ok then
        io.stderr:write("issue-completion: cannot write ", progress_file, ": ", tostring(werr), "\n")
        return false
    end
    return true
end
-- }}}

-- {{{ local function main
local function main()
    local command = arg[1]
    if command == "locate" and arg[4] then
        return locate(arg[2], arg[3], arg[4])
    elseif command == "record" and arg[5] then
        return record(arg[2], arg[3], arg[4], arg[5], arg[6] == "--dry-run")
    end
    io.stderr:write("usage: issue-completion.lua locate <scripts-dir> <project-dir> <issue-file>\n",
                    "       issue-completion.lua record <progress-file> <id> <title> <date> [--dry-run]\n")
    return false
end
-- }}}

os.exit(main() and 0 or 1)
