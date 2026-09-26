-- 017-the-filesystem.lua
--
-- The few things LuaJIT cannot do to folders by itself — make one, list one,
-- ask whether a path is a folder — done by starting the standard tools
-- (mkdir, find, test) and reading their answers. Everything that touches the
-- disk beyond opening a file goes through here, and every path handed to a
-- shell is quoted here, in one place.

local fs = {}

-- {{{ function fs.quote
-- Quotes a string for a POSIX shell: single quotes, with any single quote
-- inside closed, escaped and reopened. Safe for every byte but NUL.
function fs.quote(s)
    if type(s) ~= "string" then
        error("fs.quote: expected a string, got " .. type(s))
    end
    return "'" .. s:gsub("'", "'\\''") .. "'"
end
-- }}}

-- {{{ function fs.run
-- Runs a shell command line; returns true when it exited 0. LuaJIT's
-- os.execute returns the raw status number (0 is success).
function fs.run(command)
    local status = os.execute(command)
    return status == 0 or status == true
end
-- }}}

-- {{{ function fs.capture
-- Runs a command and returns everything it printed on standard output, and
-- whether it exited 0. The exit status is read from a marker line appended by
-- the shell, since io.popen's close does not report it under LuaJIT.
function fs.capture(command)
    local pipe = assert(io.popen(command .. "; printf '\\n%d' $?", "r"))
    local out = pipe:read("*a")
    pipe:close()
    local body, code = out:match("^(.*)\n(%d+)$")
    if not body then
        return out, false
    end
    return body, tonumber(code) == 0
end
-- }}}

-- {{{ function fs.exists
function fs.exists(path)
    local file = io.open(path, "rb")
    if file then
        file:close()
        return true
    end
    return fs.is_folder(path)
end
-- }}}

-- {{{ function fs.is_folder
function fs.is_folder(path)
    return fs.run("test -d " .. fs.quote(path))
end
-- }}}

-- {{{ function fs.make_folder
-- Makes a folder and any missing parents; refuses if it cannot.
function fs.make_folder(path)
    if not fs.run("mkdir -p " .. fs.quote(path)) then
        error("fs.make_folder: cannot make " .. path)
    end
end
-- }}}

-- {{{ function fs.list
-- The names directly inside a folder (not paths), sorted, hidden ones
-- included. A missing folder is an error: the caller asked about something
-- that should be there.
function fs.list(path)
    if not fs.is_folder(path) then
        error("fs.list: not a folder: " .. path)
    end
    local out, ok = fs.capture("find " .. fs.quote(path) .. " -mindepth 1 -maxdepth 1 -printf '%f\\0'")
    if not ok then
        error("fs.list: find failed on " .. path)
    end
    local names = {}
    for name in out:gmatch("([^%z]+)%z") do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end
-- }}}

-- {{{ function fs.read
function fs.read(path)
    local file = io.open(path, "rb")
    if not file then
        error("fs.read: cannot open " .. path)
    end
    local text = file:read("*a")
    file:close()
    return text
end
-- }}}

-- {{{ function fs.write
-- Writes a whole file through a neighbour name and a rename, so no reader
-- sees half of it.
function fs.write(path, text)
    local tmp_path = path .. ".writing"
    local file = io.open(tmp_path, "wb")
    if not file then
        error("fs.write: cannot write " .. path)
    end
    file:write(text)
    file:close()
    assert(os.rename(tmp_path, path))
end
-- }}}

-- {{{ function fs.remove_tree
-- Removes a folder and everything in it. Only ever called on paths the
-- machine made in its own scratch space or on a case the caller names; the
-- guard refuses anything short enough to be a mistake like "/" or "/home".
function fs.remove_tree(path)
    if type(path) ~= "string" or #path < 12 or path:sub(1, 1) ~= "/" then
        error("fs.remove_tree: refusing to remove " .. tostring(path))
    end
    if not fs.run("rm -rf " .. fs.quote(path)) then
        error("fs.remove_tree: cannot remove " .. path)
    end
end
-- }}}

-- {{{ function fs.real_path
-- The path with every symbolic link resolved, so two spellings of one folder
-- compare equal.
function fs.real_path(path)
    local out, ok = fs.capture("realpath -e " .. fs.quote(path))
    if not ok then
        return nil
    end
    return (out:gsub("\n$", ""))
end
-- }}}

return fs
