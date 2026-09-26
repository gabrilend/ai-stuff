-- 037-the-harness-table.lua
--
-- The programs that can run a turn (docs/005, "the harness table"). One row
-- per harness, the same fields each; adding a harness is adding a row.
--
-- A row:
--   name     string    "stand-in" | "claude-code"
--   needs    array     programs that must be on the PATH
--   cost     string    "free" | "subscription" | "per-token"
--   pool     number    how many turns may run at once by default
--   limit    number    seconds a turn may run before it is stopped
--   command  function(project, turn) -> the program line that runs one turn,
--            to be run from the turn's working folder
--
-- Every turn is run by the same shell line around the row's command: go to
-- the working folder, run under `timeout`, send standard output to
-- result.json and standard error to stderr.txt, and write the exit status
-- to `exit`. Status 124 is `timeout`'s own: the turn ran past its limit.

local fs = require("017-the-filesystem")

local harnesses = {}

-- {{{ local function folder_of
-- A write prefix names a folder ("design/"), a file ("…/outline.tsv") or a
-- file-name prefix ("…/issues/101-"); the folder holding it is where a
-- harness can be pointed.
local function folder_of(prefix)
    if prefix:sub(-1) == "/" then
        return (prefix:gsub("/$", ""))
    end
    return prefix:match("^(.*)/[^/]*$") or prefix
end
-- }}}

-- {{{ function harnesses.working_folder
-- The folder a turn runs in: the one holding its first writable path.
function harnesses.working_folder(turn)
    return folder_of(turn.writes[1])
end
-- }}}

-- {{{ local function json_string
-- A string as a JSON string literal (for the settings rules).
local function json_string(s)
    return '"' .. s:gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' end
        if c == "\\" then return "\\\\" end
        return string.format("\\u%04x", c:byte())
    end) .. '"'
end
-- }}}

-- {{{ function harnesses.claude_settings
-- The settings JSON handed to Claude Code: deny writing and editing inside
-- every folder the turn may only read. Paths starting with // are absolute.
function harnesses.claude_settings(turn)
    local deny = {}
    for _, read in ipairs(turn.reads) do
        local writable = false
        for _, write in ipairs(turn.writes) do
            if write:sub(1, #read) == read or read:sub(1, #write) == write then
                writable = true
            end
        end
        if not writable then
            -- A folder is denied with everything under it; a single file
            -- (the outline, a request) is denied by its own path.
            local target = read:gsub("/$", "")
            if fs.is_folder(target) then
                target = target .. "/**"
            end
            deny[#deny + 1] = json_string("Edit(/" .. target .. ")")
            deny[#deny + 1] = json_string("Write(/" .. target .. ")")
        end
    end
    return '{"permissions":{"deny":[' .. table.concat(deny, ",") .. ']}}'
end
-- }}}

-- {{{ function harnesses.claude_directories
-- Every folder the turn may read or write, other than its working folder,
-- each once: handed to Claude Code with --add-dir so its file tools can
-- reach them and nothing else.
function harnesses.claude_directories(turn)
    local working = harnesses.working_folder(turn)
    local seen, out = { [working] = true }, {}
    for _, list in ipairs({ turn.reads, turn.writes }) do
        for _, p in ipairs(list) do
            local folder = folder_of(p)
            -- A single readable file (a request) is reached through its folder.
            if not seen[folder] then
                seen[folder] = true
                out[#out + 1] = folder
            end
        end
    end
    table.sort(out)
    return out
end
-- }}}

harnesses.TABLE = {
    ["stand-in"] = {
        name = "stand-in",
        needs = { "luajit", "timeout" },
        cost = "free",
        pool = 8,
        limit = 60,
        command = function(project, turn)
            return "luajit " .. fs.quote(project.src .. "/038-the-stand-in.lua") .. " "
                .. fs.quote(project.dir) .. " " .. fs.quote(turn.folder)
        end,
    },
    ["claude-code"] = {
        name = "claude-code",
        needs = { "claude", "timeout" },
        cost = "subscription",
        pool = 4,
        limit = 1800,
        command = function(project, turn)
            local parts = {
                "claude", "-p",
                "--output-format", "json",
                -- Restricted: file tools confined to the working folder and the
                -- added folders; tools that run commands removed; settings
                -- files of the person ignored.
                "--restricted",
                "--tools", "Read,Write,Edit,Glob,Grep",
                "--permission-mode", "acceptEdits",
                -- Anything that would ask is refused: nobody is there to answer.
                "--permission-prompts", "none",
                "--no-session-persistence",
                "--settings", fs.quote(harnesses.claude_settings(turn)),
                "--append-system-prompt", '"$(cat ' .. fs.quote(turn.folder .. "/instructions.md") .. ')"',
            }
            for _, folder in ipairs(harnesses.claude_directories(turn)) do
                parts[#parts + 1] = "--add-dir"
                parts[#parts + 1] = fs.quote(folder)
            end
            -- The prompt arrives on standard input.
            parts[#parts + 1] = "< " .. fs.quote(turn.folder .. "/prompt.md")
            return table.concat(parts, " ")
        end,
    },
}

-- {{{ function harnesses.row
-- The named row, after checking every program it needs is installed.
function harnesses.row(name)
    local row = harnesses.TABLE[name]
    if not row then
        error("harnesses: no harness named '" .. tostring(name) .. "'")
    end
    local missing = {}
    for _, program in ipairs(row.needs) do
        if not fs.run("command -v " .. fs.quote(program) .. " > /dev/null") then
            missing[#missing + 1] = program
        end
    end
    if #missing > 0 then
        error("harnesses: '" .. name .. "' needs " .. table.concat(missing, ", ") .. ", not installed")
    end
    return row
end
-- }}}

-- {{{ function harnesses.shell_line
-- The whole shell line that runs one turn and records its outcome.
function harnesses.shell_line(project, row, turn, limit)
    local folder = turn.folder
    return "cd " .. fs.quote(harnesses.working_folder(turn))
        .. " && timeout --kill-after=10 " .. tostring(limit or row.limit) .. " "
        .. row.command(project, turn)
        .. " > " .. fs.quote(folder .. "/result.json")
        .. " 2> " .. fs.quote(folder .. "/stderr.txt")
        .. "; echo $? > " .. fs.quote(folder .. "/exit")
end
-- }}}

return harnesses
