-- MPQ Archive Library
-- Unified API for opening and extracting files from MPQ archives (WC3 maps).
-- Ties together header, hash table, block table, and extraction modules.

local header = require("mpq.header")
local hashtable = require("mpq.hashtable")
local blocktable = require("mpq.blocktable")
local extract = require("mpq.extract")

local mpq = {}

-- {{{ Archive class
local Archive = {}
Archive.__index = Archive
-- }}}

-- {{{ Archive:new
-- Creates a new Archive instance.
local function Archive_new(filepath, file_data, headers, hash_tbl, block_tbl)
    local self = setmetatable({}, Archive)
    self.filepath = filepath
    self._data = file_data
    self._headers = headers
    self._hash_table = hash_tbl
    self._block_table = block_tbl
    self._sector_size = headers.mpq.sector_size
    self._listfile_cache = nil
    self._closed = false
    return self
end
-- }}}

-- {{{ Archive:close
-- Closes the archive and releases resources.
function Archive:close()
    if self._closed then
        return
    end
    self._data = nil
    self._headers = nil
    self._hash_table = nil
    self._block_table = nil
    self._listfile_cache = nil
    self._closed = true
end
-- }}}

-- {{{ Archive:_check_closed
-- Raises error if archive is closed.
local function check_closed(self)
    if self._closed then
        error("Archive is closed", 3)
    end
end
-- }}}

-- {{{ Archive:has
-- Checks if a file exists in the archive.
function Archive:has(filename)
    check_closed(self)
    return hashtable.has_file(self._hash_table, filename)
end
-- }}}

-- {{{ Archive:extract
-- Extracts a file from the archive.
-- Returns file contents as string, or nil and error message.
function Archive:extract(filename)
    check_closed(self)
    return extract.extract_file(
        self._data,
        self._hash_table,
        self._block_table,
        self._sector_size,
        filename
    )
end
-- }}}

-- {{{ Archive:extract_to_file
-- Extracts a file and writes it to disk.
-- Returns bytes written, or nil and error message.
function Archive:extract_to_file(filename, output_path)
    check_closed(self)
    return extract.extract_to_file(
        self._data,
        self._hash_table,
        self._block_table,
        self._sector_size,
        filename,
        output_path
    )
end
-- }}}

-- {{{ Archive:list
-- Lists all files in the archive.
-- Returns array of filenames if (listfile) exists, otherwise nil and message.
-- Note: MPQ archives don't store filenames directly; they rely on (listfile).
function Archive:list()
    check_closed(self)

    -- Return cached result if available
    if self._listfile_cache then
        return self._listfile_cache
    end

    -- Try to extract (listfile)
    local listfile_data, err = self:extract("(listfile)")
    if not listfile_data then
        return nil, "Cannot list files: (listfile) not found or extraction failed"
    end

    -- Parse listfile (one filename per line, CRLF or LF)
    local files = {}
    for line in listfile_data:gmatch("[^\r\n]+") do
        if line ~= "" then
            files[#files + 1] = line
        end
    end

    self._listfile_cache = files
    return files
end
-- }}}

-- {{{ Archive:file_count
-- Returns the number of files based on block table entries.
-- This counts actual file blocks, not (listfile) entries.
function Archive:file_count()
    check_closed(self)
    local count = 0
    for i = 0, self._block_table.entry_count - 1 do
        local entry = self._block_table.entries[i]
        if entry.flags.exists and not entry.flags.delete_marker then
            count = count + 1
        end
    end
    return count
end
-- }}}

-- {{{ Archive:info
-- Returns archive metadata.
function Archive:info()
    check_closed(self)
    local h = self._headers

    local info = {
        filepath = self.filepath,
        file_size = h.file_size,
        archive_size = h.mpq.archive_size,
        format_version = h.mpq.format_version,
        sector_size = self._sector_size,
        hash_table_entries = h.mpq.hash_table_entries,
        block_table_entries = h.mpq.block_table_entries,
        file_count = self:file_count(),
    }

    -- Include HM3W info if present (WC3 map wrapper)
    if h.hm3w then
        info.map_name = h.hm3w.map_name
        info.max_players = h.hm3w.max_players
        info.map_flags = h.hm3w.map_flags
    end

    return info
end
-- }}}

-- {{{ Archive:get_block_info
-- Returns block table info for a file (for debugging/advanced use).
function Archive:get_block_info(filename)
    check_closed(self)

    local block_index = hashtable.find_file(self._hash_table, filename)
    if not block_index then
        return nil, "File not found"
    end

    return blocktable.get_block(self._block_table, block_index)
end
-- }}}

-- {{{ mpq.open
-- Opens an MPQ archive (WC3 map file).
-- Returns Archive object on success, or nil and error message.
function mpq.open(filepath)
    -- Open and parse headers
    local headers, err = header.open_w3x(filepath)
    if not headers then
        return nil, err
    end

    -- Read entire file for table parsing and extraction
    local file = io.open(filepath, "rb")
    if not file then
        return nil, "Cannot open file: " .. filepath
    end
    local file_data = file:read("*a")
    file:close()

    -- Parse hash table
    local hash_tbl, hash_err = hashtable.parse(file_data, headers.mpq)
    if not hash_tbl then
        return nil, "Hash table parse failed: " .. hash_err
    end

    -- Parse block table
    local block_tbl, block_err = blocktable.parse(file_data, headers.mpq)
    if not block_tbl then
        return nil, "Block table parse failed: " .. block_err
    end

    return Archive_new(filepath, file_data, headers, hash_tbl, block_tbl)
end
-- }}}

-- {{{ mpq.VERSION
mpq.VERSION = "1.0.0"
-- }}}

return mpq
