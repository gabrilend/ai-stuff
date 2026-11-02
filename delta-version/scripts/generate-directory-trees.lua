#!/usr/bin/env luajit
-- generate-directory-trees.lua - Draws a map of every project's folders and
-- files, collects the maps into one master file, and gives each project its
-- own copy as DIRECTORY_STRUCTURE.txt, with the monorepo's shared scripts
-- listed underneath so a newcomer -- person or agent -- sees what is there
-- and what they can already use without walking the folders by hand.
--
-- In general terms: a project's files are the ones git would keep (tracked,
-- plus new files git does not ignore), so build output, scratch space and
-- other ignored things never appear. Those paths are folded into a tree,
-- directories first, each folder's own files capped so a folder of four
-- hundred transcripts reads as a count rather than a page of names. Every
-- project's tree is written into the master file under a marker line,
--
--     ][ project-name ][
--
-- and the per-project files are then cut out of the master file by those
-- markers, so the master file is the one source and a section can be pulled
-- out of it with any tool. A project's file is only rewritten when its map
-- changed: the "Generated" date alone never makes a new version to commit.
--
-- Usage:
--   generate-directory-trees.lua [options]
--
-- Options (a value may follow "=" or come as the next argument):
--   --dir=PATH          the delta-version folder; the monorepo is its parent
--                       (default /mnt/mtwo/programming/ai-stuff/delta-version)
--   --project=NAME      only this project (may be repeated)
--   --no-files          folders only
--   --max-depth=N       folder levels listed below the project (default 5);
--                       a folder one level deeper is shown with a count of
--                       the files under it
--   --max-entries=N     files shown per folder before the rest are counted
--                       (default 25; 0 shows them all)
--   --no-gitignore      list every file on disk, ignored ones included
--   --dry-run           write the master file only; distribute nothing
--   --master=PATH       where the master file goes
--                       (default <dir>/assets/master-directory-structure.txt)
--   -h, --help          this text
--
-- Exit 0 when everything was written, 1 on an error, 2 for bad arguments.

-- {{{ DIR Configuration
local DIR = "/mnt/mtwo/programming/ai-stuff/delta-version"
-- }}}

local OUTPUT_NAME = "DIRECTORY_STRUCTURE.txt"
local MARKER_PATTERN = "^%]%[ (.-) %]%[$"
local SHARED_SECTION = "shared-monorepo-utilities"

-- {{{ local options
local options = {
    projects = {},
    files = true,
    max_depth = 5,
    max_entries = 25,
    gitignore = true,
    dry_run = false,
    master = nil,
}
-- }}}

-- {{{ local function shell_quote
local function shell_quote(word)
    return "'" .. tostring(word):gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ local function read_command
-- Everything a shell command prints, and whether it succeeded.
local function read_command(command)
    local pipe = io.popen(command .. " 2>/dev/null; echo \"__status=$?\"")
    local out = pipe:read("*a")
    pipe:close()
    local body, status = out:match("^(.-)__status=(%d+)\n?$")
    return body or "", tonumber(status) == 0
end
-- }}}

-- {{{ local function read_file
local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
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

-- {{{ local function show_help
local function show_help()
    local text = read_file(arg[0]) or ""
    local out = {}
    for line in text:gmatch("[^\n]*\n") do
        if line:match("^%-%- {{{") then break end
        if not line:match("^#!") then
            out[#out + 1] = (line:gsub("^%-%- ?", ""))
        end
    end
    io.write(table.concat(out))
end
-- }}}

-- {{{ local function parse_args
local function parse_args()
    local i = 1
    -- A value option takes "--name=value" or "--name value".
    local function value(name)
        local a = arg[i]
        local escaped = name:gsub("%W", "%%%0")
        local v = a:match("^%-%-" .. escaped .. "=(.*)$")
        if v then i = i + 1; return v end
        if a == "--" .. name then
            v = arg[i + 1]
            i = i + 2
            return v
        end
        return nil
    end
    local function number(name, v)
        local n = tonumber(v)
        if not n or n < 0 or n ~= math.floor(n) then
            io.stderr:write("generate-directory-trees: --", name, " needs a whole number\n")
            os.exit(2)
        end
        return n
    end
    while arg[i] do
        local a = arg[i]
        local v
        if a == "-h" or a == "--help" then
            show_help(); os.exit(0)
        elseif a == "--no-files" then
            options.files = false; i = i + 1
        elseif a == "--no-gitignore" then
            options.gitignore = false; i = i + 1
        elseif a == "--dry-run" then
            options.dry_run = true; i = i + 1
        else
            v = value("dir")
            if v then DIR = v
            else
                v = value("project")
                if v then options.projects[#options.projects + 1] = v
                else
                    v = value("max-depth")
                    if v then options.max_depth = number("max-depth", v)
                    else
                        v = value("max-entries")
                        if v then options.max_entries = number("max-entries", v)
                        else
                            v = value("master")
                            if v then options.master = v
                            else
                                io.stderr:write("generate-directory-trees: unknown argument ", a, " (see --help)\n")
                                os.exit(2)
                            end
                        end
                    end
                end
            end
        end
    end
    DIR = DIR:gsub("/+$", "")
    options.master = options.master or (DIR .. "/assets/master-directory-structure.txt")
end
-- }}}

-- {{{ local function monorepo_root
local function monorepo_root()
    return DIR:match("^(.*)/[^/]+$") or "."
end
-- }}}

-- {{{ local function list_projects
-- Project folders under the monorepo, by delta-version's own project lister
-- (issue 023), external project folders left out: they are not in this
-- repository. Returns a sorted list of { name, path }.
local function list_projects()
    local root = monorepo_root()
    local out, ok = read_command(shell_quote(DIR .. "/scripts/list-projects.sh")
        .. " --exclude-external --names " .. shell_quote(root))
    if not ok then
        io.stderr:write("generate-directory-trees: list-projects.sh failed\n")
        os.exit(1)
    end
    local wanted = nil
    if #options.projects > 0 then
        wanted = {}
        for _, name in ipairs(options.projects) do wanted[name] = true end
    end
    local projects, seen = {}, {}
    for name in out:gmatch("[^\n]+") do
        if (not wanted or wanted[name]) and not seen[name] then
            seen[name] = true
            projects[#projects + 1] = { name = name, path = root .. "/" .. name }
        end
    end
    if wanted then
        for _, name in ipairs(options.projects) do
            if not seen[name] and name ~= DIR:match("([^/]+)$") then
                io.stderr:write("generate-directory-trees: no project named ", name, " in ", root, "\n")
                os.exit(1)
            end
        end
    end
    -- The lister leaves delta-version out (it is the tooling, not a
    -- project), but its folders are worth a map like any other's.
    local self_name = DIR:match("([^/]+)$")
    if (not wanted or wanted[self_name]) and not seen[self_name] then
        projects[#projects + 1] = { name = self_name, path = DIR }
    end
    table.sort(projects, function(a, b) return a.name < b.name end)
    return projects
end
-- }}}

-- {{{ local function split_nul
local function split_nul(text)
    local list = {}
    for item in text:gmatch("([^%z]+)%z") do list[#list + 1] = item end
    return list
end
-- }}}

-- {{{ local function project_files
-- The project's files as paths relative to it, and how they were found.
local function project_files(path)
    local q = shell_quote(path)
    local _, in_git = read_command("git -C " .. q .. " rev-parse --is-inside-work-tree")
    local files = {}
    local source
    if options.gitignore and in_git then
        -- Tracked files and new ones git does not ignore, less tracked files
        -- already deleted from disk.
        local listed = read_command("git -C " .. q .. " ls-files -z --cached --others --exclude-standard")
        local deleted = read_command("git -C " .. q .. " ls-files -z --deleted")
        local gone = {}
        for _, p in ipairs(split_nul(deleted)) do gone[p] = true end
        local seen = {}
        for _, p in ipairs(split_nul(listed)) do
            if not gone[p] and not seen[p] then
                seen[p] = true
                files[#files + 1] = p
            end
        end
        source = "git ls-files (respects .gitignore)"
    else
        local listed = read_command("cd " .. q .. " && find . -name .git -prune -o \\( -type f -o -type l \\) -print0")
        for _, p in ipairs(split_nul(listed)) do
            files[#files + 1] = p:gsub("^%./", "")
        end
        source = in_git and "every file on disk (--no-gitignore)"
            or "every file on disk (not in a git repository)"
    end
    -- The map does not list itself.
    local kept = {}
    for _, p in ipairs(files) do
        if p ~= OUTPUT_NAME then kept[#kept + 1] = p end
    end
    return kept, source
end
-- }}}

-- {{{ local function build_tree
-- Folds a list of relative paths into nested folders:
-- { dirs = { name = node }, files = { name, ... }, count = files below }
local function build_tree(paths)
    local root = { dirs = {}, files = {}, count = 0 }
    for _, p in ipairs(paths) do
        local node = root
        node.count = node.count + 1
        local parts = {}
        for part in p:gmatch("[^/]+") do parts[#parts + 1] = part end
        for k = 1, #parts - 1 do
            local name = parts[k]
            node.dirs[name] = node.dirs[name] or { dirs = {}, files = {}, count = 0 }
            node = node.dirs[name]
            node.count = node.count + 1
        end
        node.files[#node.files + 1] = parts[#parts]
    end
    return root
end
-- }}}

-- {{{ local function plural
local function plural(n, word)
    return n .. " " .. word .. (n == 1 and "" or "s")
end
-- }}}

-- {{{ local function render_tree
-- Lines of the drawn tree under one node: folders first, then files, each in
-- name order; folders past the depth limit and files past the per-folder cap
-- are counted rather than named.
local function render_tree(node, prefix, depth, lines)
    local dir_names = {}
    for name in pairs(node.dirs) do dir_names[#dir_names + 1] = name end
    table.sort(dir_names)
    local file_names = {}
    if options.files then
        for _, name in ipairs(node.files) do file_names[#file_names + 1] = name end
        table.sort(file_names)
    end

    local entries = {}
    for _, name in ipairs(dir_names) do entries[#entries + 1] = { dir = true, name = name } end
    local shown = #file_names
    if options.max_entries > 0 and shown > options.max_entries then
        shown = options.max_entries
    end
    for k = 1, shown do entries[#entries + 1] = { name = file_names[k] } end
    if shown < #file_names then
        entries[#entries + 1] = { more = #file_names - shown }
    end

    for k, entry in ipairs(entries) do
        local last = (k == #entries)
        local branch = last and "└── " or "├── "
        local child_prefix = prefix .. (last and "    " or "│   ")
        if entry.more then
            lines[#lines + 1] = prefix .. branch .. "… and " .. plural(entry.more, "more file")
        elseif entry.dir then
            local child = node.dirs[entry.name]
            if depth > options.max_depth then
                lines[#lines + 1] = prefix .. branch .. entry.name .. "/  (" .. plural(child.count, "file") .. ")"
            else
                lines[#lines + 1] = prefix .. branch .. entry.name .. "/"
                render_tree(child, child_prefix, depth + 1, lines)
            end
        else
            lines[#lines + 1] = prefix .. branch .. entry.name
        end
    end
    return lines
end
-- }}}

-- {{{ local function project_tree
-- The drawn tree of one project, as text, and how its files were found.
local function project_tree(project)
    local paths, source = project_files(project.path)
    local lines = { project.name .. "/" }
    render_tree(build_tree(paths), "", 1, lines)
    if #paths == 0 then lines[#lines + 1] = "    (no files)" end
    return table.concat(lines, "\n"), source
end
-- }}}

-- {{{ local function script_description
-- One line saying what a script does, from its opening comment: the first
-- comment paragraph that is more than the script's own name, with a leading
-- "name - " taken off, joined across its wrapped lines and cut at its first
-- sentence or at 72 characters.
local function script_description(path, name)
    local f = io.open(path, "rb")
    if not f then return "" end
    local stem = name:gsub("%.[^.]+$", "")
    local words = {}
    for _ = 1, 40 do
        local line = f:read("*l")
        if not line then break end
        if not line:match("^#!") then
            local text = line:match("^%s*%-%-+%s?(.*)$") or line:match("^%s*#+%s?(.*)$")
            if not text then
                -- the first line of code ends the opening comment
                if line:match("%S") then break end
                if #words > 0 then break end
            else
                text = text:gsub("^%s+", ""):gsub("%s+$", "")
                local skip = text == name or text == stem or text:match("{{{")
                    or text:match("^%-+$") or text:match("^=+$")
                if text == "" or skip then
                    if #words > 0 then break end
                else
                    if #words == 0 then
                        for _, n in ipairs({ name, stem }) do
                            local escaped = n:gsub("%W", "%%%0")
                            for _, sep in ipairs({ "%s+%-%s+", "%s+—%s+", ":%s+" }) do
                                text = text:gsub("^" .. escaped .. sep, "", 1)
                            end
                        end
                    end
                    words[#words + 1] = text
                    -- a sentence that ends on this line is enough
                    if text:match("[.!?]$") then break end
                end
            end
        end
    end
    f:close()
    local found = table.concat(words, " ")
    found = found:match("^(.-[.!?])%s") or found
    if #found > 72 then
        -- cut on a character boundary, never inside a UTF-8 sequence
        found = found:sub(1, 71):gsub("[\192-\255][\128-\191]*$", "") .. "…"
    end
    return found
end
-- }}}

-- {{{ local function scripts_listing
-- The runnable scripts directly in a folder (not tests), each with what it
-- does, as aligned lines.
local function scripts_listing(folder)
    -- -L: a link to a runnable file counts, a link to a folder does not.
    local out = read_command("find -L " .. shell_quote(folder)
        .. " -maxdepth 1 -type f -perm -u+x -printf '%f\\n'")
    local names = {}
    for name in out:gmatch("[^\n]+") do
        if not name:match("^test[-_]") and not name:match("%.md$") then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    local width = 0
    for _, name in ipairs(names) do width = math.max(width, #name) end
    local lines = {}
    for k, name in ipairs(names) do
        local branch = (k == #names) and "└── " or "├── "
        local description = script_description(folder .. "/" .. name, name)
        if description ~= "" then
            lines[#lines + 1] = string.format("%s%-" .. width .. "s  - %s", branch, name, description)
        else
            lines[#lines + 1] = branch .. name
        end
    end
    if #lines == 0 then lines[1] = "(none)" end
    return table.concat(lines, "\n")
end
-- }}}

-- {{{ local function shared_section
local function shared_section()
    local root = monorepo_root()
    return table.concat({
        "## Shared Monorepo Utilities",
        "",
        "Available in " .. root .. "/scripts/:",
        scripts_listing(root .. "/scripts"),
        "",
        "Available in " .. DIR .. "/scripts/:",
        scripts_listing(DIR .. "/scripts"),
    }, "\n")
end
-- }}}

-- {{{ local function build_master
-- The master file's text: a header, then each project's section and the
-- shared section, each opened by its marker line. A project section holds
-- its tree and one line saying how its files were found.
local function build_master(projects, today)
    local parts = {
        "# Monorepo Directory Structure",
        "",
        "Generated: " .. today,
        "Generated by: delta-version/scripts/generate-directory-trees.lua",
        "Sections open with a marker line: ][ name ][",
    }
    for _, project in ipairs(projects) do
        local tree, source = project_tree(project)
        parts[#parts + 1] = ""
        parts[#parts + 1] = "][ " .. project.name .. " ]["
        parts[#parts + 1] = ""
        parts[#parts + 1] = tree
        parts[#parts + 1] = ""
        parts[#parts + 1] = "Listed from: " .. source
    end
    parts[#parts + 1] = ""
    parts[#parts + 1] = "][ " .. SHARED_SECTION .. " ]["
    parts[#parts + 1] = ""
    parts[#parts + 1] = shared_section()
    return table.concat(parts, "\n") .. "\n"
end
-- }}}

-- {{{ local function split_master
-- The master file's sections by name, each without its marker and without
-- blank lines at either end.
local function split_master(text)
    local sections, order = {}, {}
    local current
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local name = line:match(MARKER_PATTERN)
        if name then
            current = { }
            sections[name] = current
            order[#order + 1] = name
        elseif current then
            current[#current + 1] = line
        end
    end
    for name, lines in pairs(sections) do
        local body = table.concat(lines, "\n")
        sections[name] = body:gsub("^\n+", ""):gsub("\n+$", "")
    end
    return sections, order
end
-- }}}

-- {{{ local function project_file_text
local function project_file_text(project, section, shared, today)
    local tree, source = section:match("^(.-)\n\nListed from: (.-)$")
    tree = tree or section
    source = source or "unknown"
    return table.concat({
        "# " .. project.name .. " Directory Structure",
        "",
        "Generated: " .. today,
        "Auto-generated by: delta-version/scripts/generate-directory-trees.lua",
        "",
        "## Project Structure",
        "",
        tree,
        "",
        shared,
        "",
        "## Configuration",
        "",
        "- Main repository: " .. monorepo_root(),
        "- Project path: " .. project.path,
        "- Listed from: " .. source,
        "",
        "---",
        "To regenerate: " .. DIR .. "/scripts/generate-directory-trees.lua --project=" .. project.name,
    }, "\n") .. "\n"
end
-- }}}

-- {{{ local function without_date
local function without_date(text)
    return (text:gsub("\nGenerated: [^\n]*\n", "\n", 1))
end
-- }}}

-- {{{ local function distribute
-- Writes each project's file from the master file's sections; a file whose
-- map is unchanged (only the date would differ) is left alone. Returns the
-- counts written and unchanged.
local function distribute(projects, master_text, today)
    local sections = split_master(master_text)
    local shared = sections[SHARED_SECTION] or ""
    local written, unchanged = 0, 0
    for _, project in ipairs(projects) do
        local section = sections[project.name]
        if section then
            local path = project.path .. "/" .. OUTPUT_NAME
            local text = project_file_text(project, section, shared, today)
            local old = read_file(path)
            if old and without_date(old) == without_date(text) then
                unchanged = unchanged + 1
            else
                local ok, err = write_file(path, text)
                if not ok then
                    io.stderr:write("generate-directory-trees: cannot write ", path, ": ", tostring(err), "\n")
                    os.exit(1)
                end
                written = written + 1
                io.write("wrote     ", project.name, "/", OUTPUT_NAME, "\n")
            end
        end
    end
    return written, unchanged
end
-- }}}

-- {{{ local function main
local function main()
    parse_args()
    local today = os.date("%Y-%m-%d")
    local projects = list_projects()
    local master_text = build_master(projects, today)

    local master_dir = options.master:match("^(.*)/[^/]+$")
    if master_dir then os.execute("mkdir -p " .. shell_quote(master_dir)) end
    local ok, err = write_file(options.master, master_text)
    if not ok then
        io.stderr:write("generate-directory-trees: cannot write ", options.master, ": ", tostring(err), "\n")
        os.exit(1)
    end
    io.write("master    ", options.master, " (", plural(#projects, "project"), ")\n")

    if options.dry_run then
        io.write("dry run: no project files written\n")
        return
    end
    local written, unchanged = distribute(projects, read_file(options.master), today)
    io.write(plural(written, "project file"), " written, ", unchanged, " unchanged\n")
end
-- }}}

main()
