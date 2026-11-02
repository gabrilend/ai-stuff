-- {{{ File backends
-- The few file operations template storage needs, behind one small
-- interface so the same storage code runs in the game (LÖVE's save
-- folder), in headless tools (plain files) and in tests (memory).
--
-- A backend has:
--   read(path)            the contents, or nil
--   write(path, data)     true, or false and a message
--   remove(path)          true when something was removed
--   exists(path)          true or false
--   make_directory(path)  makes it and any parents; true or false
--   list(directory)       file names in it, sorted, or nil when the
--                         backend can't list (storage then relies on its
--                         index alone)
-- Paths use "/" and are relative to the backend's root.
local FileBackends = {}

-- {{{ FileBackends.memory
-- Everything in a table. For tests, and for a game that shouldn't touch
-- the disk.
function FileBackends.memory()
    local files = {}
    local backend = {kind = "memory", files = files}
    function backend.read(path) return files[path] end
    function backend.write(path, data)
        files[path] = data
        return true
    end
    function backend.remove(path)
        local had = files[path] ~= nil
        files[path] = nil
        return had
    end
    function backend.exists(path) return files[path] ~= nil end
    function backend.make_directory() return true end
    function backend.list(directory)
        local prefix = directory:gsub("/*$", "") .. "/"
        local names = {}
        for path in pairs(files) do
            if path:sub(1, #prefix) == prefix and not path:sub(#prefix + 1):find("/") then
                table.insert(names, path:sub(#prefix + 1))
            end
        end
        table.sort(names)
        return names
    end
    return backend
end
-- }}}

-- {{{ FileBackends.love
-- LÖVE's save folder, through love.filesystem.
function FileBackends.love()
    local fs = love.filesystem
    local backend = {kind = "love"}
    function backend.read(path)
        if not fs.getInfo(path, "file") then
            return nil
        end
        return (fs.read(path))
    end
    function backend.write(path, data)
        local ok, message = fs.write(path, data)
        return ok and true or false, message
    end
    function backend.remove(path) return fs.remove(path) and true or false end
    function backend.exists(path) return fs.getInfo(path) ~= nil end
    function backend.make_directory(path) return fs.createDirectory(path) and true or false end
    function backend.list(directory)
        local names = {}
        for _, name in ipairs(fs.getDirectoryItems(directory)) do
            if fs.getInfo(directory .. "/" .. name, "file") then
                table.insert(names, name)
            end
        end
        table.sort(names)
        return names
    end
    return backend
end
-- }}}

-- {{{ FileBackends.disk
-- Plain files under a root folder, for headless tools. Folders are made
-- with mkdir; the folder names come from storage's own fixed list, never
-- from a template's name. It can't list folders, so storage keeps to its
-- index.
function FileBackends.disk(root)
    root = (root or "."):gsub("/*$", "")
    local backend = {kind = "disk", root = root}
    local function full(path)
        return root .. "/" .. path
    end
    function backend.read(path)
        local file = io.open(full(path), "rb")
        if not file then
            return nil
        end
        local data = file:read("*a")
        file:close()
        return data
    end
    function backend.write(path, data)
        local file, message = io.open(full(path), "wb")
        if not file then
            return false, message
        end
        file:write(data)
        file:close()
        return true
    end
    function backend.remove(path) return os.remove(full(path)) and true or false end
    function backend.exists(path)
        local file = io.open(full(path), "rb")
        if file then
            file:close()
            return true
        end
        return false
    end
    function backend.make_directory(path)
        local target = full(path)
        if target:find("'", 1, true) then
            return false
        end
        local result = os.execute("mkdir -p '" .. target .. "'")
        return result == true or result == 0
    end
    backend.list = nil
    return backend
end
-- }}}

-- {{{ FileBackends.default
-- LÖVE's save folder when running in LÖVE, otherwise memory.
function FileBackends.default()
    if love and love.filesystem and love.filesystem.write then
        return FileBackends.love()
    end
    return FileBackends.memory()
end
-- }}}

return FileBackends
-- }}}
