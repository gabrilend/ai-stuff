--[[
stormlib.lua - LuaJIT binding to StormLib, the reference MPQ library

Why this exists beside our own reader (src/mpq/): our reader handles WC3 map
archives, which use zlib and PKWARE compression. Blizzard's game and patch
archives also use bzip2 and other methods, and patch programs carry their
archive embedded partway into an .exe. StormLib reads all of those, so this
binding is how the project reads stock game data and patch contents
(issue 112a). StormLib itself is built by src/cli/build-stormlib.sh.

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
]]
-- }}}

local MPQ_OPEN_READ_ONLY  = 0x00000100
local SFILE_OPEN_FROM_MPQ = 0x00000000

-- 1024 name bytes (already 8-aligned, so no padding) + 8-byte pointer
-- + 8 x 4-byte fields = 1064 bytes on 64-bit
assert(ffi.sizeof("SFILE_FIND_DATA") == 1024 + 8 + 8 * 4,
    "SFILE_FIND_DATA layout does not match StormLib v9.40 on 64-bit Linux")

local DEFAULT_LIB = "/mnt/mtwo/programming/ai-stuff/world-edit-to-execute/libs/stormlib/lib/libstorm.so"

local M = {}
local lib = nil

-- {{{ local function load_library
-- Loads libstorm.so once. A missing library is an error naming the build
-- script, never a silent switch to our own reader.
local function load_library(path)
    if lib then return lib end
    local ok, loaded = pcall(ffi.load, path or DEFAULT_LIB)
    if not ok then
        error("StormLib not found at " .. tostring(path or DEFAULT_LIB)
            .. "; build it with src/cli/build-stormlib.sh (" .. tostring(loaded) .. ")")
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

-- {{{ function Archive:list
-- Lists files matching a mask ("*" for all). Uses the archive's own listfile;
-- files with no listfile entry appear under StormLib's generated names
-- ("File00000012.xxx"). Returns a list of {name, size, compressed_size, flags}.
function Archive:list(mask, listfile)
    local L = lib
    local data = ffi.new("SFILE_FIND_DATA")
    local find = L.SFileFindFirstFile(self.handle, mask or "*", data, listfile)
    local out = {}
    if find == nil then
        return out
    end
    repeat
        out[#out + 1] = {
            name = ffi.string(data.cFileName),
            size = data.dwFileSize,
            compressed_size = data.dwCompSize,
            flags = data.dwFileFlags,
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
