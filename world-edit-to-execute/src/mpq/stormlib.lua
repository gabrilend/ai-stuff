--[[
stormlib.lua - LuaJIT binding to StormLib, the reference MPQ library

Why this exists: it is how the project reads every MPQ archive. Maps go
through src/mpq/init.lua (the mpq module), which wraps this binding; stock
game archives, patch programs and the per-map game data chain use it
directly (issues 112a, 114). It replaced the project's own Lua reader after
a coverage check: over the 16 test maps it reads every stored file (2,786),
including 2,416 with no known name. StormLib itself is built by
scripts/build-dependencies.sh.

StormLib finds an archive embedded in another file by itself: it scans the
file for the MPQ signature at 512-byte steps, so an .exe can be opened
directly.

Usage:
  local stormlib = require("mpq.stormlib")
  local archive = stormlib.open("/path/War3Patch.mpq")
  for _, entry in ipairs(archive:list("*")) do print(entry.name, entry.size) end
  local bytes = archive:read("Units\\UnitData.slk")
  archive:close()
]]

local ffi = require("ffi")

-- {{{ C declarations
-- Copied from StormLib.h / StormPort.h (v9.40) for Linux: DWORD and LCID are
-- unsigned int, HANDLE is void*, MAX_PATH is 1024. A layout mismatch here
-- would corrupt every find result, so the struct size is checked below.
ffi.cdef[[
typedef struct {
    char         cFileName[1024];
    char *       szPlainName;
    unsigned int dwHashIndex;
    unsigned int dwBlockIndex;
    unsigned int dwFileSize;
    unsigned int dwFileFlags;
    unsigned int dwCompSize;
    unsigned int dwFileTimeLo;
    unsigned int dwFileTimeHi;
    unsigned int lcLocale;
} SFILE_FIND_DATA;

bool  SFileOpenArchive(const char * szMpqName, unsigned int dwPriority, unsigned int dwFlags, void ** phMpq);
bool  SFileCloseArchive(void * hMpq);
bool  SFileHasFile(void * hMpq, const char * szFileName);
bool  SFileOpenFileEx(void * hMpq, const char * szFileName, unsigned int dwSearchScope, void ** phFile);
unsigned int SFileGetFileSize(void * hFile, unsigned int * pdwFileSizeHigh);
bool  SFileReadFile(void * hFile, void * lpBuffer, unsigned int dwToRead, unsigned int * pdwRead, void * lpOverlapped);
bool  SFileCloseFile(void * hFile);
bool  SFileExtractFile(void * hMpq, const char * szToExtract, const char * szExtracted, unsigned int dwSearchScope);
void * SFileFindFirstFile(void * hMpq, const char * szMask, SFILE_FIND_DATA * lpFindFileData, const char * szListFile);
bool  SFileFindNextFile(void * hFind, SFILE_FIND_DATA * lpFindFileData);
bool  SFileFindClose(void * hFind);
unsigned int SErrGetLastError();
bool  SFileCreateFile(void * hMpq, const char * szArchivedName, unsigned long long FileTime, unsigned int dwFileSize,
                      unsigned int lcLocale, unsigned int dwFlags, void ** phFile);
bool  SFileWriteFile(void * hFile, const void * pvData, unsigned int dwSize, unsigned int dwCompression);
bool  SFileFinishFile(void * hFile);
bool  SFileRemoveFile(void * hMpq, const char * szFileName, unsigned int dwSearchScope);
bool  SFileFlushArchive(void * hMpq);
bool  SFileCreateArchive(const char * szMpqName, unsigned int dwCreateFlags, unsigned int dwMaxFileCount, void ** phMpq);
bool  SFileSetMaxFileCount(void * hMpq, unsigned int dwMaxFileCount);
unsigned int SFileGetMaxFileCount(void * hMpq);
]]
-- }}}

local MPQ_OPEN_READ_ONLY  = 0x00000100
local SFILE_OPEN_FROM_MPQ = 0x00000000

-- 1024 name bytes (already 8-aligned, so no padding) + 8-byte pointer
-- + 8 x 4-byte fields = 1064 bytes on 64-bit
assert(ffi.sizeof("SFILE_FIND_DATA") == 1024 + 8 + 8 * 4,
    "SFILE_FIND_DATA layout does not match StormLib v9.40 on 64-bit Linux")

local OWNER_LIB = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute/deps/stormlib/lib/libstorm.so"

-- The library built into this checkout's deps/ (this file is src/mpq/),
-- else the owner's usual place; STORMLIB_PATH overrides both
local function default_lib()
    local env = os.getenv("STORMLIB_PATH")
    if env and env ~= "" then return env end
    -- "@/abs/root/src/mpq/stormlib.lua" or, loaded by a relative path,
    -- "@src/mpq/stormlib.lua" (root = the current directory)
    local here = debug.getinfo(1, "S").source:match("^@(.-)src/mpq/[^/]*$")
    if here then
        local candidate = here .. "deps/stormlib/lib/libstorm.so"
        local f = io.open(candidate, "rb")
        if f then
            f:close()
            return candidate
        end
    end
    return OWNER_LIB
end
local DEFAULT_LIB = default_lib()

local M = {}
local lib = nil

-- {{{ local function load_library
-- Loads libstorm.so once. A missing library is an error naming the build
-- script; there is no other reader to switch to.
local function load_library(path)
    if lib then return lib end
    local ok, loaded = pcall(ffi.load, path or DEFAULT_LIB)
    if not ok then
        error("StormLib not found at " .. tostring(path or DEFAULT_LIB)
            .. "; build it with scripts/build-dependencies.sh (" .. tostring(loaded) .. ")")
    end
    lib = loaded
    return lib
end
-- }}}

local Archive = {}
Archive.__index = Archive

-- {{{ function M.open
-- Opens an archive read-only. path may be a plain .mpq or a program file with
-- an archive embedded in it. Returns an Archive, or raises an error with
-- StormLib's error code.
function M.open(path, lib_path)
    local L = load_library(lib_path)
    local handle = ffi.new("void *[1]")
    if not L.SFileOpenArchive(path, 0, MPQ_OPEN_READ_ONLY, handle) then
        error(string.format("StormLib could not open %s (error %d)", path, L.SErrGetLastError()))
    end
    return setmetatable({ handle = handle[0], path = path }, Archive)
end
-- }}}

-- {{{ function M.open_writable (issue 911a)
-- Opens an archive to change it (a copy: the editor never writes the map
-- it read).
function M.open_writable(path, lib_path)
    local L = load_library(lib_path)
    local handle = ffi.new("void *[1]")
    if not L.SFileOpenArchive(path, 0, 0, handle) then
        error(string.format("StormLib could not open %s for writing (error %d)", path, L.SErrGetLastError()))
    end
    return setmetatable({ handle = handle[0], path = path, writable = true }, Archive)
end
-- }}}

-- {{{ function M.create (issue 911a)
-- A new, empty archive (version 1, as WC3 reads) with a listfile and
-- attributes StormLib keeps up to date
function M.create(path, max_files, lib_path)
    local L = load_library(lib_path)
    local handle = ffi.new("void *[1]")
    local MPQ_CREATE_LISTFILE, MPQ_CREATE_ATTRIBUTES = 0x00100000, 0x00200000
    if not L.SFileCreateArchive(path, MPQ_CREATE_LISTFILE + MPQ_CREATE_ATTRIBUTES, max_files or 1024, handle) then
        error(string.format("StormLib could not create %s (error %d)", path, L.SErrGetLastError()))
    end
    return setmetatable({ handle = handle[0], path = path, writable = true }, Archive)
end
-- }}}

-- {{{ function Archive:write
-- Puts a file in (replacing one of that name), compressed with zlib
local MPQ_FILE_COMPRESS, MPQ_FILE_REPLACEEXISTING = 0x00000200, 0x80000000
local MPQ_COMPRESSION_ZLIB = 0x02
function Archive:write(name, bytes)
    local L = lib
    if not self.writable then error(self.path .. ": opened read-only") end
    local file = ffi.new("void *[1]")
    local flags = MPQ_FILE_COMPRESS + MPQ_FILE_REPLACEEXISTING
    if not L.SFileCreateFile(self.handle, name, 0, #bytes, 0, flags, file) then
        local code = L.SErrGetLastError()
        -- a full hash table: make room once and try again
        if code == 1 or code == 39 or code == 112 then
            L.SFileSetMaxFileCount(self.handle, L.SFileGetMaxFileCount(self.handle) * 2)
            if not L.SFileCreateFile(self.handle, name, 0, #bytes, 0, flags, file) then
                error(string.format("%s: cannot add %s (error %d)", self.path, name, L.SErrGetLastError()))
            end
        else
            error(string.format("%s: cannot add %s (error %d)", self.path, name, code))
        end
    end
    if #bytes > 0 and not L.SFileWriteFile(file[0], bytes, #bytes, MPQ_COMPRESSION_ZLIB) then
        local code = L.SErrGetLastError()
        L.SFileFinishFile(file[0])
        error(string.format("%s: cannot write %s (error %d)", self.path, name, code))
    end
    if not L.SFileFinishFile(file[0]) then
        error(string.format("%s: cannot finish %s (error %d)", self.path, name, L.SErrGetLastError()))
    end
    return true
end

function Archive:remove(name)
    if not self.writable then error(self.path .. ": opened read-only") end
    return lib.SFileRemoveFile(self.handle, name, 0)
end

function Archive:flush()
    return lib.SFileFlushArchive(self.handle)
end
-- }}}

-- {{{ function Archive:list
-- Lists files matching a mask ("*" for all). Uses the archive's own listfile;
-- files with no listfile entry appear under StormLib's generated names
-- ("File00000012.xxx"). Returns a list of {name, size, compressed_size, flags,
-- locale, hash_index, block_index}. One name can appear more than once: an MPQ
-- keeps a separate entry per language (locale 0 = neutral), and protected maps
-- sometimes plant duplicate entries to confuse editors.
function Archive:list(mask, listfile)
    local L = lib
    -- An empty extra listfile made StormLib's search find nothing at all, and
    -- the list came back empty without a word (issue 114). A listfile given
    -- must exist and hold something.
    if listfile then
        local f = io.open(listfile, "rb")
        if not f then
            error(self.path .. ": extra listfile " .. listfile .. " doesn't exist")
        end
        local size = f:seek("end")
        f:close()
        if size == 0 then
            error(self.path .. ": extra listfile " .. listfile .. " is empty")
        end
    end
    local data = ffi.new("SFILE_FIND_DATA")
    local find = L.SFileFindFirstFile(self.handle, mask or "*", data, listfile)
    local out = {}
    if find == nil then
        -- "No more files" (1001 in StormPort.h) is a genuinely empty result;
        -- any other failure is an error.
        local code = L.SErrGetLastError()
        if code ~= 1001 then
            error(string.format("%s: listing %s failed (error %d)", self.path, mask or "*", code))
        end
        return out
    end
    repeat
        out[#out + 1] = {
            name = ffi.string(data.cFileName),
            size = data.dwFileSize,
            compressed_size = data.dwCompSize,
            flags = data.dwFileFlags,
            locale = data.lcLocale,
            hash_index = data.dwHashIndex,
            block_index = data.dwBlockIndex,
        }
    until not L.SFileFindNextFile(find, data)
    L.SFileFindClose(find)
    return out
end
-- }}}

-- {{{ function Archive:has
function Archive:has(name)
    return lib.SFileHasFile(self.handle, name)
end
-- }}}

-- {{{ function Archive:read
-- Reads one file into a Lua string. A missing or unreadable file raises an
-- error naming the file and the archive.
function Archive:read(name)
    local L = lib
    local file = ffi.new("void *[1]")
    if not L.SFileOpenFileEx(self.handle, name, SFILE_OPEN_FROM_MPQ, file) then
        error(string.format("%s: cannot open %s (error %d)", self.path, name, L.SErrGetLastError()))
    end
    local size = L.SFileGetFileSize(file[0], nil)
    local buffer = ffi.new("uint8_t[?]", size)
    local got = ffi.new("unsigned int[1]")
    local ok = L.SFileReadFile(file[0], buffer, size, got, nil)
    L.SFileCloseFile(file[0])
    if not ok or got[0] ~= size then
        error(string.format("%s: short read of %s (%d of %d bytes, error %d)",
            self.path, name, got[0], size, L.SErrGetLastError()))
    end
    return ffi.string(buffer, size)
end
-- }}}

-- {{{ function Archive:extract
-- Writes one file to disk at dest_path.
function Archive:extract(name, dest_path)
    if not lib.SFileExtractFile(self.handle, name, dest_path, SFILE_OPEN_FROM_MPQ) then
        error(string.format("%s: cannot extract %s to %s (error %d)",
            self.path, name, dest_path, lib.SErrGetLastError()))
    end
end
-- }}}

-- {{{ function Archive:close
function Archive:close()
    if self.handle ~= nil then
        lib.SFileCloseArchive(self.handle)
        self.handle = nil
    end
end
-- }}}

return M
