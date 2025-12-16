# Issue 102d: Implement File Extraction with Decompression

**Phase:** 1 - Foundation
**Type:** Sub-Issue of 102
**Priority:** Critical
**Dependencies:** 102a, 102b, 102c

---

## Current Behavior

Can parse headers, locate files via hash table, and read block metadata.
Cannot actually extract file contents from the archive.

---

## Intended Behavior

Complete file extraction capability:
- Read raw file data from archive at correct offset
- Handle sector-based file storage
- Decrypt encrypted files
- Decompress using appropriate algorithm (zlib, bzip2, PKWARE)
- Return uncompressed file contents as string/buffer

---

## Suggested Implementation Steps

1. **Create extraction module**
   ```
   src/mpq/
   ├── header.lua
   ├── hash.lua
   ├── hashtable.lua
   ├── blocktable.lua
   └── extract.lua      (this issue)
   ```

2. **Implement sector reading**
   ```lua
   function read_sectors(file_handle, block_info, sector_size)
       local sectors = {}
       local num_sectors = math.ceil(block_info.uncompressed_size / sector_size)

       -- Read sector offset table (if not single unit)
       if not block_info.flags.single_unit then
           local offsets = read_sector_offsets(file_handle, num_sectors + 1)
           for i = 1, num_sectors do
               local sector_data = read_sector(file_handle,
                   block_info.offset + offsets[i],
                   offsets[i+1] - offsets[i])
               table.insert(sectors, sector_data)
           end
       else
           -- Single unit: read entire file as one chunk
           sectors[1] = read_bytes(file_handle,
               block_info.offset,
               block_info.compressed_size)
       end

       return sectors
   end
   ```

3. **Implement decryption**
   ```lua
   function decrypt_data(data, key)
       local seed = 0xEEEEEEEE
       local result = {}

       for i = 1, #data, 4 do
           seed = seed + crypto_table[0x400 + (key & 0xFF)]
           local ch = read_uint32(data, i) XOR (key + seed)
           key = ((~key << 21) + 0x11111111) | (key >> 11)
           seed = ch + seed + (seed << 5) + 3
           write_uint32(result, ch)
       end

       return table.concat(result)
   end
   ```

4. **Implement decompression**
   ```lua
   function decompress(data, method)
       if method == "none" then
           return data
       elseif method == "zlib" then
           return zlib.decompress(data)
       elseif method == "bzip2" then
           return bzip2.decompress(data)
       elseif method == "pkware" then
           return pkware.explode(data)
       else
           error("Unknown compression: " .. method)
       end
   end
   ```

5. **Handle multi-compression**
   ```lua
   -- Files can use multiple compression passes
   -- First byte indicates methods used
   function decompress_multi(data)
       local flags = data:byte(1)
       data = data:sub(2)  -- Remove flag byte

       -- Decompress in reverse order of compression
       if flags & 0x10 ~= 0 then  -- bzip2
           data = bzip2.decompress(data)
       end
       if flags & 0x08 ~= 0 then  -- pkware
           data = pkware.explode(data)
       end
       if flags & 0x02 ~= 0 then  -- zlib
           data = zlib.decompress(data)
       end
       if flags & 0x01 ~= 0 then  -- huffman
           data = huffman.decompress(data)
       end

       return data
   end
   ```

6. **Create main extraction function**
   ```lua
   function extract_file(archive, filename)
       -- Look up file in hash table
       local block_index = archive.hash_table:find(filename)
       if not block_index then
           return nil, "File not found: " .. filename
       end

       -- Get block info
       local block = archive.block_table[block_index]
       if not block.flags.exists then
           return nil, "File deleted: " .. filename
       end

       -- Read sectors
       local sectors = read_sectors(archive.handle, block, archive.sector_size)

       -- Decrypt if needed
       if block.flags.encrypted then
           local key = compute_file_key(filename, block)
           for i, sector in ipairs(sectors) do
               sectors[i] = decrypt_data(sector, key - i + 1)
           end
       end

       -- Decompress sectors
       local output = {}
       for i, sector in ipairs(sectors) do
           if block.flags.compress or block.flags.implode then
               sector = decompress(sector, block.compression)
           end
           table.insert(output, sector)
       end

       return table.concat(output)
   end
   ```

7. **Set up compression library dependencies**
   - lua-zlib or lzlib for zlib decompression
   - Consider pure-Lua fallbacks for portability
   - PKWARE DCL may need custom implementation

---

## Technical Notes

### Encryption Key Calculation

For encrypted files:
```lua
function compute_file_key(filename, block)
    -- Extract base filename (remove path)
    local basename = filename:match("\\([^\\]+)$") or filename
    local key = mpq_hash(basename, 3)

    if block.flags.fix_key then
        key = (key + block.offset) ~ block.uncompressed_size
    end

    return key
end
```

### Sector CRC

If SECTOR_CRC flag is set, each sector has a 4-byte CRC after the offset table.
Can be used for verification but is optional.

### WC3-Specific Notes

WC3 maps typically use:
- zlib compression for most files
- No encryption for most map files
- JASS scripts may be lightly obfuscated but not truly encrypted

---

## Dependencies (External Libraries)

| Library | Purpose | Fallback |
|---------|---------|----------|
| lua-zlib | zlib decompression | Pure Lua inflate |
| lua-bzip2 | bzip2 (rare in WC3) | Error if encountered |
| n/a | PKWARE DCL | Must implement |

---

## Related Documents

- docs/formats/mpq-archive.md
- issues/102a-parse-mpq-header.md
- issues/102b-parse-mpq-hash-table.md
- issues/102c-parse-mpq-block-table.md
- issues/102-implement-mpq-archive-parser.md (parent)

---

## Acceptance Criteria

- [ ] Can extract war3map.w3i from test archives
- [ ] Can extract war3map.j (JASS script) from test archives
- [ ] Can extract war3map.wts from test archives
- [ ] Handles zlib-compressed files
- [ ] Handles uncompressed files
- [ ] Returns clear error for missing files
- [ ] Extracted data matches expected size
- [ ] Unit tests for extraction

---

## Notes

This completes the MPQ parser. After this issue, we have full read access
to any file within a .w3x archive.

The parent issue (102) should add a unified API module (`src/mpq/init.lua`)
that ties all sub-modules together with a clean interface.
