-- src/build-tools/01-manifest-emitter.lua
-- Walks tmp/build/ after a build completes and writes
-- tmp/build/manifest.txt — the deliverable's table of contents.
-- Each non-directory entry becomes one line:
--   <path-relative-to-build-root>  <size-in-bytes>  <sha256>
--
-- The manifest exists so a reader (developer, future-us, deploy.sh)
-- can answer "what is in this build, and is it the same bytes as
-- last time?" without scanning the bundle by hand.
--
-- Usage:  luajit 01-manifest-emitter.lua <build-root>

local M = {}

-- {{{ list_files
-- Recursively walks 'root' and returns a sorted array of
-- relative paths for every regular file under it. Sorting makes
-- the manifest reproducible: same files → byte-identical manifest.
local function list_files(root)
    local files = {}
    -- The build root may contain symlinks or directories named with
    -- spaces, so we go through a shell pipeline carefully.
    local pipe = io.popen(string.format(
        "find %q -type f -printf '%%P\\n' | LC_ALL=C sort",
        root))
    if pipe == nil then
        error("could not invoke find on " .. tostring(root))
    end
    for line in pipe:lines() do
        if line ~= "" and line ~= "manifest.txt" then
            files[#files + 1] = line
        end
    end
    pipe:close()
    return files
end
-- }}}

-- {{{ stat_size
local function stat_size(path)
    local f = io.open(path, "rb")
    if f == nil then
        return 0
    end
    local size = f:seek("end")
    f:close()
    return size
end
-- }}}

-- {{{ sha256
-- Defers to the host's sha256sum because the broker's host build
-- doesn't need a Lua-side cryptographic implementation just for the
-- manifest. If sha256sum is unavailable, falls back to 'unknown'
-- with a warning.
local function sha256(path)
    local pipe = io.popen(string.format("sha256sum %q 2>/dev/null", path))
    if pipe == nil then
        return "unknown"
    end
    local line = pipe:read("*l")
    pipe:close()
    if line == nil then
        return "unknown"
    end
    return line:match("^(%x+)")
end
-- }}}

-- {{{ emit
function M.emit(root)
    local files = list_files(root)
    local out_path = root .. "/manifest.txt"
    local out = io.open(out_path, "w")
    if out == nil then
        error("could not write manifest at " .. out_path)
    end
    out:write("# Apple IIds build manifest\n")
    out:write("# path  size  sha256\n")
    for _, rel in ipairs(files) do
        local full = root .. "/" .. rel
        local size = stat_size(full)
        local hash = sha256(full)
        out:write(string.format("%s\t%d\t%s\n", rel, size, hash))
    end
    out:close()
    print(string.format("[INFO] manifest written: %s  (%d entries)",
        out_path, #files))
end
-- }}}

-- {{{ main
local function main()
    local root = arg[1]
    if root == nil then
        io.stderr:write("usage: lua 01-manifest-emitter.lua <build-root>\n")
        os.exit(1)
    end
    M.emit(root)
end

main()
-- }}}

return M
