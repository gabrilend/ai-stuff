#!/usr/bin/env luajit
-- 141-a-bootable-medium.lua
--
-- Wraps a single file into a medium a firmware will open: a partition table,
-- a partition, a filesystem in it, and the file at a named path. Issue 502,
-- steps seven through nine.
--
-- For a general: everything this project built produced correct bytes in a
-- correct order and nothing that a computer would look at. A computer starting
-- up does not read a card from the beginning -- it looks for a table saying
-- where the partitions are, opens the one marked as the startup partition,
-- expects a filesystem inside it, and opens one file at one fixed name. This
-- makes that. What goes in the file is somebody else's business.
--
-- WHY THIS EXISTS AT ALL. For months every emulated machine here booted from a
-- directory the emulator turned into a filesystem on the fly, so the thing the
-- image builder produced was never the thing under test. Both halves were right
-- about their own half: the builder's offsets matched what the engine looks for
-- exactly. Nobody asked the component that has to find the first byte.
--
-- WHY IT IS WRITTEN HERE RATHER THAN SHELLED OUT TO A TOOL. The same argument
-- that produced this project's own executable-envelope generator: the format is
-- a fixed arrangement of numbers, and writing the generator is less work than
-- depending on a tool being installed, being the same version, and being
-- reachable from a build that must produce identical bytes every time.
--
-- WHY FAT16 AND NOT FAT32. The startup specification requires a firmware to
-- understand FAT12, FAT16 and FAT32, so all three are allowed. FAT16 is far the
-- simplest: its root directory is a fixed run of sectors rather than a chain of
-- clusters, and it has no second bookkeeping sector to keep consistent. With
-- the largest cluster this project would use it addresses two gigabytes, which
-- is more than any image here. And it is the arrangement the emulator itself
-- synthesises for the directories these boards have been booting from all
-- along, so it is the arrangement already known to work with this firmware.
--
-- WHY LONG FILENAMES ARE HERE, HAVING BEEN ARGUED AGAINST. The first version of
-- this said the whole long-name mechanism was unnecessary, because the path a
-- firmware looks for is EFI/BOOT/BOOTX64.EFI or one of its two siblings and
-- every one of those fits the eight-and-three naming FAT has always had.
--
-- The third architecture disproved it in one line. Its path is
-- EFI/BOOT/BOOTRISCV64.EFI, and that stem is eleven characters. The
-- specification says so and has always said so; the claim was made by looking
-- at one machine and generalising, which is the mistake this project has
-- written down about assembly and had not thought applied to filenames.
--
-- So a name that does not fit gets the long-name treatment: a run of extra
-- entries carrying the real name in front of an ordinary entry carrying a
-- shortened one, which is how every FAT filesystem has held long names since
-- they were bolted on. The short alias still has to be right, because a reader
-- that ignores long names entirely must still find A file there.
--
-- REPRODUCIBLE. Same inputs, same bytes. The identifiers a partition table
-- carries are derived from the caller's own identity string rather than drawn
-- at random, because a builder that produces a different image every time from
-- the same recipe has given up the one kind of reproducibility this project has.

local bit = require("bit")

local M = {}

-- {{{ M.SECTOR -- the unit everything here is counted in
-- Five hundred and twelve bytes, which is what a partition table, a firmware
-- and every medium this project targets all assume. Named rather than repeated
-- so the assumption is in one place if a medium with larger sectors ever turns
-- up.
M.SECTOR = 512
-- }}}

-- {{{ local function little(value, width)
-- A number as bytes, least significant first, which is the order every
-- structure in this file stores numbers in. Both a partition table and a
-- filesystem were designed on machines that did it this way and neither has
-- ever changed.
local function little(value, width)
  local out = {}
  for _ = 1, width do
    out[#out + 1] = string.char(value % 256)
    value = math.floor(value / 256)
  end
  return table.concat(out)
end
-- }}}

-- {{{ local CRC_TABLE, and crc32(bytes)
-- A partition table checks itself, and a header whose check fails is ignored
-- SILENTLY -- the firmware finds no partitions and boots nothing, with no
-- message naming the reason. So this has to be right, and being right is
-- checkable: the polynomial has a published answer for the digits one to nine,
-- and 142 requires this to produce it before anything else is trusted.
--
-- The first version of this did the mixing with addition instead of
-- exclusive-or, on the reasoning that adding to a value with no overlapping
-- bits is the same thing. It is the same thing only when the bits do not
-- overlap, which is exactly the case that does not hold here. It produced a
-- plausible thirty-two bit number for every input and the wrong one for all of
-- them, which is this project's usual failure wearing a hat.
local band, bxor, rshift = bit.band, bit.bxor, bit.rshift

local CRC_TABLE = nil
local function build_crc_table()
  CRC_TABLE = {}
  for index = 0, 255 do
    local value = index
    for _ = 1, 8 do
      if band(value, 1) == 1 then
        value = bxor(0xEDB88320, rshift(value, 1))
      else
        value = rshift(value, 1)
      end
    end
    CRC_TABLE[index] = value
  end
end

local function crc32(bytes)
  if not CRC_TABLE then build_crc_table() end
  local value = 0xFFFFFFFF
  for index = 1, #bytes do
    value = bxor(rshift(value, 8), CRC_TABLE[band(bxor(value, bytes:byte(index)), 0xFF)])
  end
  -- The result is signed on a machine whose numbers are thirty-two bits wide,
  -- and every consumer of it wants an unsigned value to write out as four
  -- bytes, so it is brought back into range here rather than at each caller.
  value = bxor(value, 0xFFFFFFFF)
  if value < 0 then value = value + 4294967296 end
  return value
end
M.crc32 = crc32
-- }}}

-- {{{ local function eight_and_three(name)
-- A FAT name is eight characters and an extension of three, both padded with
-- spaces, both upper case. Long names are a later bolt-on that this file
-- deliberately does not implement, because every path a firmware looks for
-- fits without it: EFI, BOOT, BOOTX64.EFI.
--
-- A name that does not fit is REFUSED rather than shortened. A silently
-- truncated name produces a filesystem that is valid, mounts, contains a file,
-- and is not the file the firmware will ask for -- which is a machine that does
-- not boot and a medium that looks perfect.
local function eight_and_three(name)
  local stem, extension = name:match("^([^.]+)%.([^.]+)$")
  if not stem then stem, extension = name, "" end
  stem, extension = stem:upper(), extension:upper()
  -- Not fitting is not an error any more: it means the name needs the long-name
  -- treatment, which the caller arranges. Returning nothing says which.
  if #stem > 8 or #extension > 3 then return nil end
  if stem:match("[^A-Z0-9_%-]") or extension:match("[^A-Z0-9_%-]") then return nil end
  return stem .. string.rep(" ", 8 - #stem) .. extension .. string.rep(" ", 3 - #extension)
end
-- }}}

-- {{{ local function directory_entry(short_name, attributes, cluster, size)
-- Thirty-two bytes describing one name. The times are a fixed moment rather
-- than now, because this builder must produce identical bytes from identical
-- inputs and a clock is the classic way that stops being true.
local FIXED_TIME, FIXED_DATE = 0, 0x5821    -- 2024-01-01, midnight
local function directory_entry(short_name, attributes, cluster, size)
  return short_name
    .. string.char(attributes)
    .. string.char(0)              -- reserved for the system that made it
    .. string.char(0)              -- creation time, finer than two seconds
    .. little(FIXED_TIME, 2) .. little(FIXED_DATE, 2)
    .. little(FIXED_DATE, 2)       -- last read
    .. little(0, 2)                -- high half of the cluster number: FAT32 only
    .. little(FIXED_TIME, 2) .. little(FIXED_DATE, 2)
    .. little(cluster, 2)
    .. little(size, 4)
end
-- }}}

-- {{{ local function geometry(sectors, wanted_bytes)
-- How to divide a partition so that FAT16 applies to it. The count of clusters
-- decides which of the three FATs a filesystem IS -- below about four thousand
-- it must be FAT12 and above about sixty-five thousand it must be FAT32 -- so
-- the cluster size is chosen to land between them rather than picked.
--
-- Getting this wrong does not fail loudly. A filesystem whose cluster count
-- says FAT12 while its boot sector says FAT16 is read by different systems in
-- different ways, which is worse than either.
local function geometry(total_sectors)
  for _, per_cluster in ipairs({1, 2, 4, 8, 16, 32, 64}) do
    local reserved = 1
    local root_entries = 512
    local root_sectors = math.floor((root_entries * 32) / M.SECTOR)
    -- Sectors per copy of the table, solved rather than guessed: each cluster
    -- needs two bytes in it, and the table itself takes sectors away from the
    -- clusters it describes.
    local usable = total_sectors - reserved - root_sectors
    local clusters = math.floor(usable / per_cluster)
    local fat_sectors = math.ceil(((clusters + 2) * 2) / M.SECTOR)
    usable = total_sectors - reserved - root_sectors - (2 * fat_sectors)
    clusters = math.floor(usable / per_cluster)
    if clusters >= 4085 and clusters <= 65524 then
      return {
        per_cluster = per_cluster,
        reserved = reserved,
        root_entries = root_entries,
        root_sectors = root_sectors,
        fat_sectors = fat_sectors,
        clusters = clusters,
        total_sectors = total_sectors,
        data_start = reserved + (2 * fat_sectors) + root_sectors,
      }
    end
  end
  return nil, "no cluster size makes " .. total_sectors
    .. " sectors into a FAT16 filesystem; it is too small or too large"
end
M.geometry = geometry
-- }}}

-- {{{ local function short_alias(name)
-- The eight-and-three name that stands behind a long one. A reader that knows
-- nothing about long names must still find a file, and this is what it finds.
-- The convention is the first six usable characters, a tilde, and a number.
local function short_alias(name)
  local stem, extension = name:match("^(.*)%.([^.]*)$")
  if not stem then stem, extension = name, "" end
  stem = stem:upper():gsub("[^A-Z0-9_%-]", "_")
  extension = extension:upper():gsub("[^A-Z0-9_%-]", "_"):sub(1, 3)
  stem = stem:sub(1, 6) .. "~1"
  return stem .. string.rep(" ", 8 - #stem) .. extension .. string.rep(" ", 3 - #extension)
end
-- }}}

-- {{{ local function alias_checksum(short_name)
-- Ties the long-name entries to the short entry that follows them. A reader
-- that finds the two disagreeing is supposed to ignore the long name entirely,
-- so getting this wrong does not corrupt anything -- it silently loses the long
-- name and leaves a file called BOOTRI~1.EFI, which is not the file the
-- firmware will ask for.
local function alias_checksum(short_name)
  local sum = 0
  for index = 1, 11 do
    local carried = (band(sum, 1) == 1) and 0x80 or 0
    sum = (carried + rshift(sum, 1) + short_name:byte(index)) % 256
  end
  return sum
end
-- }}}

-- {{{ local function long_name_entries(name, short_name)
-- The real name, in front of the short one, thirteen characters at a time and
-- in reverse order -- last piece first, each numbered, the first-written one
-- flagged as the end of the run. Backwards because a reader walks a directory
-- forwards and wants the pieces to arrive in an order it can assemble.
local function long_name_entries(name, short_name)
  local checksum = alias_checksum(short_name)
  local characters = {}
  for index = 1, #name do characters[index] = name:byte(index) end
  characters[#characters + 1] = 0            -- the terminator is part of the name
  local pieces = math.ceil(#characters / 13)

  local out = {}
  for piece = pieces, 1, -1 do
    local sequence = piece
    if piece == pieces then sequence = sequence + 0x40 end   -- this one is the last
    local body = {}
    for slot = 1, 13 do
      local at = (piece - 1) * 13 + slot
      local value = characters[at]
      if value == nil then value = 0xFFFF end                -- unused slots are filled, not zeroed
      body[slot] = little(value, 2)
    end
    out[#out + 1] = string.char(sequence)
      .. table.concat(body, "", 1, 5)
      .. string.char(0x0F)                                   -- what marks this as a name fragment
      .. string.char(0)
      .. string.char(checksum)
      .. table.concat(body, "", 6, 11)
      .. little(0, 2)
      .. table.concat(body, "", 12, 13)
  end
  return table.concat(out)
end
-- }}}

-- {{{ local function name_entries(name, attributes, cluster, size)
-- Everything a directory needs in order to hold one name: the ordinary entry,
-- and in front of it the long-name run if the name did not fit.
local function name_entries(name, attributes, cluster, size)
  local fitted = eight_and_three(name)
  if fitted then
    return directory_entry(fitted, attributes, cluster, size)
  end
  local alias = short_alias(name)
  return long_name_entries(name, alias)
    .. directory_entry(alias, attributes, cluster, size)
end
-- }}}

-- {{{ M.filesystem(options)
--
-- options: sectors        how many sectors the partition is
--          path           where the file goes, e.g. "EFI/BOOT/BOOTX64.EFI"
--          bytes          the file itself
--          hidden         the partition's own first sector on the medium
--          volume_id      four bytes of identity, derived not drawn
--          label          up to eleven characters, for people
--
-- Returns the partition's bytes, or nil and why.
--
-- THE ONE THING TO GET RIGHT is that a cluster number is an index into the
-- table AND a position in the data area, and the data area starts at cluster
-- two rather than zero. The first two table entries are not clusters; they
-- hold a marker for the medium kind and a marker for a clean unmount, and they
-- have been reserved since before anybody reading this was born. An
-- off-by-two here produces a filesystem that mounts, lists the right names,
-- and hands back the wrong bytes for every one of them.
function M.filesystem(options)
  local shape, why = geometry(options.sectors)
  if not shape then return nil, why end

  -- {{{ what the path asks for, in names a short-name filesystem can hold
  local components = {}
  for piece in options.path:gmatch("[^/]+") do components[#components + 1] = piece end
  if #components < 1 then return nil, "the path names nothing" end
  -- Names are kept as written; whether each needs the long-name treatment is
  -- decided where the entry is made rather than here.
  -- }}}

  -- {{{ hand out clusters: one per directory, then the file
  -- Directories here hold three entries at most, so one cluster each is
  -- always enough and the arithmetic stays something a reader can follow.
  local bytes_per_cluster = shape.per_cluster * M.SECTOR
  local file_clusters = math.max(1, math.ceil(#options.bytes / bytes_per_cluster))
  local directory_count = #components - 1
  local needed = directory_count + file_clusters
  if needed > shape.clusters then
    return nil, "the file needs " .. needed .. " clusters and the partition has "
      .. shape.clusters
  end

  local first_directory = 2
  local first_file = first_directory + directory_count
  -- }}}

  -- {{{ the table, twice, because that is what a FAT is
  local entries = {}
  entries[0] = 0xFFF8            -- the medium kind, repeated from the boot sector
  entries[1] = 0xFFFF            -- and a marker saying nothing was interrupted
  for index = 0, directory_count - 1 do
    entries[first_directory + index] = 0xFFFF     -- a directory of one cluster ends at itself
  end
  for index = 0, file_clusters - 1 do
    local cluster = first_file + index
    if index == file_clusters - 1 then
      entries[cluster] = 0xFFFF
    else
      entries[cluster] = cluster + 1
    end
  end

  local table_bytes = {}
  for cluster = 0, shape.clusters + 1 do
    table_bytes[#table_bytes + 1] = little(entries[cluster] or 0, 2)
  end
  local one_table = table.concat(table_bytes)
  local table_padding = (shape.fat_sectors * M.SECTOR) - #one_table
  if table_padding < 0 then return nil, "the table does not fit the sectors reserved for it" end
  one_table = one_table .. string.rep("\0", table_padding)
  -- }}}

  -- {{{ the directories, each holding itself, its parent, and what is inside
  -- A directory that is not the root carries an entry for itself and one for
  -- the parent, and a parent that is the root is written as cluster zero
  -- rather than as the root's real position, because the root of a FAT16
  -- filesystem is not in the data area at all and has no cluster number.
  local DIRECTORY, ARCHIVE = 0x10, 0x20
  local chain = {}
  for index = 1, directory_count do
    local self_cluster = first_directory + index - 1
    local parent_cluster = (index == 1) and 0 or (self_cluster - 1)
    local inside_name = components[index + 1]
    local inside_cluster = self_cluster + 1
    local inside_attributes = (index + 1 <= directory_count) and DIRECTORY or ARCHIVE
    local inside_size = (inside_attributes == ARCHIVE) and #options.bytes or 0
    if inside_attributes == ARCHIVE then inside_cluster = first_file end

    local content = directory_entry(".          ", DIRECTORY, self_cluster, 0)
      .. directory_entry("..         ", DIRECTORY, parent_cluster, 0)
      .. name_entries(inside_name, inside_attributes, inside_cluster, inside_size)
    chain[index] = content .. string.rep("\0", bytes_per_cluster - #content)
  end
  -- }}}

  -- {{{ the root, which is a fixed run of sectors rather than a chain
  local root = ""
  if options.label then
    local label = options.label:upper():sub(1, 11)
    root = root .. directory_entry(label .. string.rep(" ", 11 - #label), 0x08, 0, 0)
  end
  local top_name = components[1]
  local top_attributes = (directory_count >= 1) and DIRECTORY or ARCHIVE
  local top_cluster = (directory_count >= 1) and first_directory or first_file
  local top_size = (top_attributes == ARCHIVE) and #options.bytes or 0
  root = root .. name_entries(top_name, top_attributes, top_cluster, top_size)
  root = root .. string.rep("\0", (shape.root_sectors * M.SECTOR) - #root)
  -- }}}

  -- {{{ the boot sector, which is mostly a description of everything above
  local boot = string.char(0xEB, 0x3C, 0x90)          -- a jump nothing follows
    .. "MSWIN4.1"                                     -- the name every writer puts here
    .. little(M.SECTOR, 2)
    .. string.char(shape.per_cluster)
    .. little(shape.reserved, 2)
    .. string.char(2)                                 -- two copies of the table
    .. little(shape.root_entries, 2)
    .. little(shape.total_sectors < 65536 and shape.total_sectors or 0, 2)
    .. string.char(0xF8)                              -- a medium that is not removable
    .. little(shape.fat_sectors, 2)
    .. little(32, 2) .. little(64, 2)                 -- a geometry nothing uses any more
    .. little(options.hidden or 0, 4)
    .. little(shape.total_sectors >= 65536 and shape.total_sectors or 0, 4)
    .. string.char(0x80) .. string.char(0)
    .. string.char(0x29)                              -- what follows is an identity and a name
    .. little(options.volume_id or 0, 4)
    .. ((options.label or "SEED"):upper() .. string.rep(" ", 11)):sub(1, 11)
    .. "FAT16   "
  boot = boot .. string.rep("\0", 510 - #boot) .. string.char(0x55, 0xAA)
  -- }}}

  local data = table.concat(chain)
  local file_padding = (file_clusters * bytes_per_cluster) - #options.bytes
  data = data .. options.bytes .. string.rep("\0", file_padding)
  local data_sectors = shape.total_sectors - shape.data_start
  data = data .. string.rep("\0", (data_sectors * M.SECTOR) - #data)

  return boot .. one_table .. one_table .. root .. data, nil, shape
end
-- }}}

-- {{{ local function guid(seed, tag)
-- Sixteen bytes of identity, DERIVED rather than drawn. A partition table
-- carries a name for the medium and a name for each partition, and every tool
-- that writes one generates them at random -- which would make this builder
-- produce a different image every time from the same recipe, and give up the
-- one kind of reproducibility this project has (issue 502).
--
-- So they come from the caller's own identity string. Two images built from
-- the same recipe have the same identifiers, which is what "the same image"
-- ought to mean, and two built from different recipes do not collide in any
-- way that matters.
local function guid(seed, tag)
  local out = {}
  local rolling = 2166136261
  local material = tag .. "|" .. seed
  for index = 1, 16 do
    for step = 1, #material do
      rolling = bxor(rolling, material:byte(step))
      rolling = (rolling * 16777619) % 4294967296
    end
    rolling = (rolling + index * 2654435761) % 4294967296
    out[index] = string.char(rolling % 256)
  end
  local bytes = table.concat(out)
  -- The two places a reader looks to decide what kind of identifier this is:
  -- set them so tools call it a random one rather than something malformed.
  return bytes:sub(1, 6)
    .. string.char(bit.bor(bit.band(bytes:byte(7), 0x0F), 0x40))
    .. bytes:sub(8, 8)
    .. string.char(bit.bor(bit.band(bytes:byte(9), 0x3F), 0x80))
    .. bytes:sub(10, 16)
end
-- }}}

-- {{{ M.ESP_TYPE -- what marks a partition as the one to start from
-- A fixed identifier that has meant "this is the partition a firmware starts
-- from" since the specification was written. The first three groups are stored
-- least significant byte first and the last two are stored in the order they
-- are written, which is a wart of the format rather than a choice, and getting
-- it wrong produces a partition every tool displays as an unknown kind.
M.ESP_TYPE = string.char(0x28, 0x73, 0x2A, 0xC1, 0x1F, 0xF8, 0xD2, 0x11,
                         0xBA, 0x4B, 0x00, 0xA0, 0xC9, 0x3E, 0xC9, 0x3B)
-- }}}

-- {{{ M.medium(options)
--
-- options: bytes      the file a firmware will open
--          path       where it goes, e.g. "EFI/BOOT/BOOTX64.EFI"
--          identity   a string the identifiers are derived from
--          sectors    how big the medium is; a default is chosen if absent
--          label      up to eleven characters, for people
--
-- Returns { image, partition_at, partition_sectors, shape } or nil and why.
--
-- The shape of a medium with one partition on it:
--
--     sector 0          a table in the old format, saying "one partition,
--                       covering everything, of a kind you do not understand"
--                       -- which stops an old tool from believing the medium
--                       is empty and offering to help
--     sector 1          the real table's header
--     sectors 2-33      its entries, a hundred and twenty-eight of them
--     sector 2048       the partition itself, starting on a round megabyte
--     ...               the filesystem, and the file
--     last 33 sectors   the same header and entries again, at the other end,
--                       because a table that exists once is a table one bad
--                       sector destroys
function M.medium(options)
  local ENTRIES, ENTRY_SIZE = 128, 128
  local entry_sectors = (ENTRIES * ENTRY_SIZE) / M.SECTOR      -- 32
  local partition_at = 2048                                    -- one megabyte in
  local tail = 1 + entry_sectors                               -- the copy at the far end

  local total_sectors = options.sectors
  if not total_sectors then
    -- THE SMALLEST MEDIUM IS MEGABYTES, NOT KILOBYTES, and the reason is the
    -- filesystem rather than anything here. Which of the three FATs a
    -- filesystem is depends on how many clusters it has, and this one is only
    -- FAT16 above about four thousand of them. So a partition holding a
    -- one-kilobyte file still has to be a couple of megabytes, or it stops
    -- being the format its own boot sector claims.
    --
    -- Found rather than calculated: the arithmetic is circular, because the
    -- cluster size depends on the total and the total depends on the cluster
    -- size. Stepping a megabyte at a time and asking whether it works is a
    -- handful of tries and cannot be subtly wrong.
    local wanted = partition_at + tail + 4200 + 128
    total_sectors = math.ceil(wanted / 2048) * 2048
    while true do
      local candidate = total_sectors - partition_at - tail
      local shape = geometry(candidate)
      if shape then
        local per_cluster_bytes = shape.per_cluster * M.SECTOR
        local room = (shape.clusters - 4) * per_cluster_bytes
        if room >= #options.bytes then break end
      end
      total_sectors = total_sectors + 2048
      if total_sectors > 64 * 1024 * 1024 * 2 then
        return nil, "no medium under sixty-four gigabytes holds this file"
      end
    end
  end
  local partition_sectors = total_sectors - partition_at - tail
  if partition_sectors < 1 then return nil, "the medium is too small to hold a partition" end

  local partition, why, shape = M.filesystem({
    sectors = partition_sectors,
    path = options.path,
    bytes = options.bytes,
    hidden = partition_at,
    volume_id = 0,
    label = options.label or "SEED",
  })
  if not partition then return nil, why end

  -- {{{ the table in the old format, which exists only to be unwelcoming
  local protective = string.rep("\0", 446)
    .. string.char(0x00)                          -- not the one to start from
    .. string.char(0x00, 0x02, 0x00)              -- a geometry nothing reads
    .. string.char(0xEE)                          -- "a kind you do not understand"
    .. string.char(0xFF, 0xFF, 0xFF)
    .. little(1, 4)
    .. little(math.min(total_sectors - 1, 4294967295), 4)
    .. string.rep("\0", 48)
    .. string.char(0x55, 0xAA)
  -- }}}

  -- {{{ the entries, of which exactly one is used
  local entry = M.ESP_TYPE
    .. guid(options.identity or "seed", "partition")
    .. little(partition_at, 8)
    .. little(partition_at + partition_sectors - 1, 8)
    .. little(0, 8)
  local name = options.label or "SEED"
  for index = 1, 36 do
    local character = name:sub(index, index)
    entry = entry .. (character == "" and string.char(0, 0) or (character .. string.char(0)))
  end
  local entries = entry .. string.rep("\0", (ENTRIES - 1) * ENTRY_SIZE)
  local entries_crc = crc32(entries)
  -- }}}

  -- {{{ the header, twice, each pointing at the other
  local disk_guid = guid(options.identity or "seed", "medium")
  local function header(self_lba, other_lba, entries_lba)
    local without_check = "EFI PART"
      .. little(0x00010000, 4)
      .. little(92, 4)
      .. little(0, 4)                              -- the check goes here, once known
      .. little(0, 4)
      .. little(self_lba, 8)
      .. little(other_lba, 8)
      .. little(partition_at, 8)
      .. little(total_sectors - tail - 1, 8)
      .. disk_guid
      .. little(entries_lba, 8)
      .. little(ENTRIES, 4)
      .. little(ENTRY_SIZE, 4)
      .. little(entries_crc, 4)
    local check = crc32(without_check)
    local with_check = without_check:sub(1, 16) .. little(check, 4) .. without_check:sub(21)
    return with_check .. string.rep("\0", M.SECTOR - #with_check)
  end
  -- }}}

  local backup_entries_at = total_sectors - tail
  local pieces = {
    protective,
    header(1, total_sectors - 1, 2),
    entries,
    string.rep("\0", (partition_at - 2 - entry_sectors) * M.SECTOR),
    partition,
    entries,
    header(total_sectors - 1, 1, backup_entries_at),
  }

  local image = table.concat(pieces)
  if #image ~= total_sectors * M.SECTOR then
    return nil, "the medium came out " .. #image .. " bytes and should be "
      .. (total_sectors * M.SECTOR) .. "; the arithmetic above is wrong"
  end

  return {
    image = image,
    partition_at = partition_at,
    partition_sectors = partition_sectors,
    total_sectors = total_sectors,
    shape = shape,
  }
end
-- }}}

return M
