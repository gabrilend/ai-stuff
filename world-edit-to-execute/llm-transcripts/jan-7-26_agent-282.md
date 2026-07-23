# Conversation Summary: e04f5853-97b1-42e0-b0f4-d4ed56551847

Generated on: Tue Dec 30 09:35:24 PM PST 2025

--------------------------------------------------------------------------------

### User Request 1

Hello computer, all is well. I have a root issue that already has sub-issues.
Please review it and suggest:

1. Whether any existing sub-issues should be broken down further
2. Whether the root issue needs additional sub-issues to cover gaps
3. Any structural improvements to the sub-issue organization

For each suggestion, provide the issue ID and your recommendation.

Here is the root issue and its sub-issues:

═══════════════════════════════════════════════════════════════
ROOT ISSUE: 102-implement-mpq-archive-parser.md
═══════════════════════════════════════════════════════════════

# Issue 102: Implement MPQ Archive Parser

**Phase:** 1 - Foundation
**Type:** Feature (Core Infrastructure)
**Priority:** Critical
**Dependencies:** 101-research-wc3-file-formats

---

## Current Behavior

No ability to read .w3m or .w3x files. These are MPQ archives containing all map
data.
Without an MPQ parser, no map content can be accessed.

---

## Intended Behavior

A Lua module that can:
- Open .w3m/.w3x files (MPQ archives)
- List all files contained within the archive
- Extract individual files by name
- Handle all compression formats used by WC3 maps
- Provide a clean API for other modules to access map contents

---

## Sub-Issues

This issue is complex and broken into sub-issues:

| Sub-Issue | Description | Status |
|-----------|-------------|--------|
| 102a | Parse MPQ header structure | Pending |
| 102b | Parse MPQ hash table | Pending |
| 102c | Parse MPQ block table | Pending |
| 102d | Implement file extraction with decompression | Pending |

Complete sub-issues in order (a → b → c → d).

---

## Suggested Implementation Steps

1. Create `src/mpq/` module directory
2. Implement header parser (102a)
3. Implement hash table parser (102b)
4. Implement block table parser (102c)
5. Implement file extraction (102d)
6. Create unified `mpq.lua` API module
7. Write unit tests for each component

---

## API Design (Proposed)

```lua
local mpq = require("src.mpq")

-- Open an archive
local archive, err = mpq.open("/path/to/map.w3x")
if not archive then
    error("Failed to open: " .. err)
end

-- List files
local files = archive:list()
for _, filename in ipairs(files) do
    print(filename)
end

-- Check if file exists
if archive:has("war3map.w3i") then
    -- Extract file contents
    local data = archive:extract("war3map.w3i")
end

-- Close archive
archive:close()
```

---

## Technical Considerations

## Decision: Library vs. Custom Implementation

**Option A: Use StormLib via FFI**
- Pros: Battle-tested, handles all edge cases, maintained
- Cons: External dependency, C library FFI complexity, licensing (MIT)

**Option B: Pure Lua Implementation**
- Pros: No dependencies, educational value, full control
- Cons: More work, potential edge cases, compression library needs

**Recommendation:** Start with pure Lua for header/tables, use existing Lua libraries
for compression (lua-zlib, lua-bzip2). Consider StormLib fallback if edge cases
arise.

## Compression Formats

WC3 maps may use:
- No compression (raw)
- PKWARE DCL (implode)
- zlib (deflate)
- bzip2

Need Lua bindings or pure implementations for each.

---

## Related Documents

- docs/formats/mpq-archive.md (format specification)
- issues/102a-parse-mpq-header.md
- issues/102b-parse-mpq-hash-table.md
- issues/102c-parse-mpq-block-table.md
- issues/102d-implement-file-extraction.md

## Test Files

- assets/DAoW-2.1.w3x
- assets/DAoW-5.4c-PUBLIC-TEST-OCTOBER.w3x
- (any .w3x in assets/)

---

## Acceptance Criteria

- [ ] Can open any .w3x file in assets/ without error
- [ ] Can list all files in an archive
- [ ] Can extract war3map.w3i from test archives
- [ ] Can extract war3map.j (JASS script) from test archives
- [ ] Handles both compressed and uncompressed files
- [ ] Clean error messages for corrupt/invalid archives
- [ ] Unit tests pass for all components

---

## Notes

This is the foundational module - everything else depends on it. Take time to
get
the API right, as many other modules will depend on it.

Consider memory efficiency for large archives. Streaming extraction may be
needed
for very large embedded files.

SUB-ISSUES:

───────────────────────────────────────────────────────────────
102a-parse-mpq-header.md
───────────────────────────────────────────────────────────────

# Issue 102a: Parse MPQ Header Structure

**Phase:** 1 - Foundation
**Type:** Sub-Issue of 102
**Priority:** Critical
**Dependencies:** 101-research-wc3-file-formats

---

## Current Behavior

No MPQ parsing capability exists. Cannot read the header of .w3x files.

---

## Intended Behavior

A module that reads and validates MPQ archive headers, extracting:
- Magic signature verification ("MPQ\x1A")
- Header size
- Archive size
- Format version
- Sector size
- Hash table offset and size
- Block table offset and size

---

## Suggested Implementation Steps

1. **Create file structure**
   ```
   src/mpq/
   ├── init.lua          (main module, created later)
   └── header.lua        (this issue)
   ```

2. **Implement binary reader utilities**
   - Read uint32 little-endian
   - Read uint16 little-endian
   - Seek to position
   - Validate remaining bytes

3. **Parse MPQ header**
   ```lua
   -- MPQ Header v1 structure (32 bytes):
   -- Offset  Size  Description
   -- 0x00    4     Magic ('MPQ\x1A')
   -- 0x04    4     Header size
   -- 0x08    4     Archive size
   -- 0x0C    2     Format version
   -- 0x0E    2     Sector size shift
   -- 0x10    4     Hash table offset
   -- 0x14    4     Block table offset
   -- 0x18    4     Hash table entries
   -- 0x1C    4     Block table entries
   ```

4. **Handle archive detection**
   - Some .w3x files have MPQ header at offset 512 (user data header)
   - Scan for MPQ magic if not at offset 0

5. **Return parsed header struct**
   ```lua
   return {
       magic = "MPQ\x1A",
       header_size = 32,
       archive_size = 12345678,
       format_version = 0,
       sector_size_shift = 3,
       sector_size = 4096,  -- 512 << shift
       hash_table_offset = 1234,
       block_table_offset = 5678,
       hash_table_entries = 1024,
       block_table_entries = 256
   }
   ```

6. **Write unit tests**
   - Test with known good .w3x file
   - Test error handling for non-MPQ file
   - Test error handling for truncated file

---

## Technical Notes

## Sector Size

The sector size is calculated as `512 << sector_size_shift`. Typical values:
- Shift of 3 = 4096 bytes per sector

## Version Differences

- Version 0: Original MPQ format (WC3 uses this)
- Version 1: Extended format (Burning Crusade+, not needed for WC3)

We only need to support version 0 for WC3 maps.

## User Data Header

Some map editors prepend a 512-byte user data section. The structure:
```
Offset  Size  Description
0x00    4     Magic ('MPQ\x1B')
0x04    4     User data size
0x08    4     Header offset (where real MPQ header starts)
0x0C    4     User data header size
```

If we see 'MPQ\x1B' at offset 0, read header_offset and seek there.

---

## Related Documents

- docs/formats/mpq-archive.md
- issues/102-implement-mpq-archive-parser.md (parent)

---

## Acceptance Criteria

- [ ] Can read header from assets/DAoW-2.1.w3x
- [ ] Correctly identifies MPQ magic signature
- [ ] Extracts all header fields accurately
- [ ] Handles user data header (MPQ\x1B) if present
- [ ] Returns clear error for non-MPQ files
- [ ] Unit tests cover normal and error cases

---

## Notes

This is the first code written for the project. Establish good patterns:
- Clear error handling
- Comprehensive logging (optional, toggleable)
- Clean module structure
- Documentation comments

───────────────────────────────────────────────────────────────
102b-parse-mpq-hash-table.md
───────────────────────────────────────────────────────────────

# Issue 102b: Parse MPQ Hash Table

**Phase:** 1 - Foundation
**Type:** Sub-Issue of 102
**Priority:** Critical
**Dependencies:** 102a-parse-mpq-header

---

## Current Behavior

Header parsing exists (102a), but cannot locate files within the archive.
The hash table maps filenames to block table indices.

---

## Intended Behavior

A module that:
- Reads the encrypted hash table from the MPQ archive
- Decrypts the hash table using MPQ's hash algorithm
- Provides filename-to-block-index lookup
- Handles hash collisions via linear probing

---

## Suggested Implementation Steps

1. **Create hash table module**
   ```
   src/mpq/
   ├── header.lua       (from 102a)
   ├── hash.lua         (this issue - hash algorithms)
   └── hashtable.lua    (this issue - table parsing)
   ```

2. **Implement MPQ hash function**
   ```lua
   -- MPQ uses a custom hash algorithm with a pre-computed crypto table
   -- Three hash types:
   --   0: Hash for hash table offset
   --   1: Hash A for verification
   --   2: Hash B for verification
   --   3: Hash for encryption key

   function mpq_hash(str, hash_type)
       -- Implementation using crypto table
   end
   ```

3. **Generate crypto table**
   ```lua
   -- 1280-entry table generated from seed algorithm
   -- This is a one-time computation, can be stored as constant
   function init_crypto_table()
       local table = {}
       local seed = 0x00100001
       for i = 0, 255 do
           for j = 0, 4 do
               -- Generation algorithm
           end
       end
       return table
   end
   ```

4. **Parse hash table entries**
   ```lua
   -- Each hash table entry is 16 bytes:
   -- Offset  Size  Description
   -- 0x00    4     Hash A (name verification)
   -- 0x04    4     Hash B (name verification)
   -- 0x08    2     Locale (0 = neutral)
   -- 0x0A    2     Platform (0 = default)
   -- 0x0C    4     Block index (0xFFFFFFFF = empty)
   ```

5. **Decrypt hash table**
   ```lua
   -- Hash table is encrypted with key = mpq_hash("(hash table)", 3)
   function decrypt_table(data, key)
       -- MPQ decryption algorithm
   end
   ```

6. **Implement file lookup**
   ```lua
   function find_file(hash_table, filename)
       local hash_offset = mpq_hash(filename, 0) % #hash_table
       local hash_a = mpq_hash(filename, 1)
       local hash_b = mpq_hash(filename, 2)

       -- Linear probe from hash_offset
       for i = 0, #hash_table - 1 do
           local idx = (hash_offset + i) % #hash_table
           local entry = hash_table[idx]

           if entry.block_index == 0xFFFFFFFF then
               return nil  -- Empty slot, file not found
           end

           if entry.hash_a == hash_a and entry.hash_b == hash_b then
               return entry.block_index
           end
       end

       return nil  -- Table full, not found
   end
   ```

---

## Technical Notes

## Hash Collision Resolution

MPQ uses linear probing. If slot N is occupied by a different file, check N+1,
N+2, etc.
An empty slot (block_index = 0xFFFFFFFF) terminates the search.
A deleted slot (block_index = 0xFFFFFFFE) continues the search.

## Case Sensitivity

MPQ filenames are case-insensitive. Convert to uppercase before hashing.
Also normalize path separators: `/` becomes `\`.

## Encryption

The hash table is always encrypted. The encryption key is derived from
the string "(hash table)" using hash type 3.

---

## Related Documents

- docs/formats/mpq-archive.md
- issues/102a-parse-mpq-header.md (provides table offset/size)
- issues/102-implement-mpq-archive-parser.md (parent)

---

## Acceptance Criteria

- [ ] Crypto table generates correct values (verify against reference)
- [ ] Hash function produces correct hashes for known strings
- [ ] Can decrypt hash table from test archive
- [ ] Can find block index for "war3map.w3i"
- [ ] Can find block index for "war3map.j"
- [ ] Returns nil for non-existent files
- [ ] Handles case-insensitive lookups
- [ ] Unit tests for hash function and lookup

---

## Notes

The crypto table and hash algorithms are well-documented online. Reference
implementations exist in StormLib and various open-source projects.

Consider caching the crypto table as a Lua table literal to avoid
regenerating it each time.

───────────────────────────────────────────────────────────────
102c-parse-mpq-block-table.md
───────────────────────────────────────────────────────────────

# Issue 102c: Parse MPQ Block Table

**Phase:** 1 - Foundation
**Type:** Sub-Issue of 102
**Priority:** Critical
**Dependencies:** 102a-parse-mpq-header, 102b-parse-mpq-hash-table

---

## Current Behavior

Can parse header (102a) and look up files in hash table (102b), but cannot
determine where file data is located or how it's stored. The block table
contains this information.

---

## Intended Behavior

A module that:
- Reads the encrypted block table from the MPQ archive
- Decrypts the block table
- Provides file metadata: offset, sizes, and flags
- Determines compression method and encryption status for each file

---

## Suggested Implementation Steps

1. **Create block table module**
   ```
   src/mpq/
   ├── header.lua       (from 102a)
   ├── hash.lua         (from 102b)
   ├── hashtable.lua    (from 102b)
   └── blocktable.lua   (this issue)
   ```

2. **Parse block table entries**
   ```lua
   -- Each block table entry is 16 bytes:
   -- Offset  Size  Description
   -- 0x00    4     File offset (relative to archive start)
   -- 0x04    4     Compressed size
   -- 0x08    4     Uncompressed size
   -- 0x0C    4     Flags
   ```

3. **Decrypt block table**
   ```lua
   -- Block table is encrypted with key = mpq_hash("(block table)", 3)
   -- Use same decryption function from 102b
   ```

4. **Parse block flags**
   ```lua
   -- Flag bits:
   local FLAGS = {
       IMPLODE      = 0x00000100,  -- PKWARE DCL compressed
       COMPRESS     = 0x00000200,  -- Multi-method compressed
       ENCRYPTED    = 0x00010000,  -- File is encrypted
       FIX_KEY      = 0x00020000,  -- Encryption key adjusted by offset
       PATCH_FILE   = 0x00100000,  -- Patch file (not used in WC3)
       SINGLE_UNIT  = 0x01000000,  -- File is single unit (not sectors)
       DELETE_MARKER= 0x02000000,  -- File is deleted
       SECTOR_CRC   = 0x04000000,  -- Sector CRCs present
       EXISTS       = 0x80000000,  -- File exists
   }

   function parse_flags(flags)
       return {
           implode = (flags & FLAGS.IMPLODE) ~= 0,
           compress = (flags & FLAGS.COMPRESS) ~= 0,
           encrypted = (flags & FLAGS.ENCRYPTED) ~= 0,
           fix_key = (flags & FLAGS.FIX_KEY) ~= 0,
           single_unit = (flags & FLAGS.SINGLE_UNIT) ~= 0,
           exists = (flags & FLAGS.EXISTS) ~= 0,
       }
   end
   ```

5. **Create block info structure**
   ```lua
   return {
       offset = 12345,           -- Absolute file offset
       compressed_size = 1000,   -- Size in archive
       uncompressed_size = 2000, -- Original size
       flags = { ... },          -- Parsed flags
       compression = "zlib",     -- Detected compression type
       encrypted = false,
   }
   ```

6. **Determine compression method**
   - If IMPLODE flag: PKWARE DCL
   - If COMPRESS flag: First byte of file data indicates method
     - 0x02: zlib
     - 0x10: bzip2
     - 0x08: PKWARE
     - 0x01: Huffman (rare)
     - Multiple methods can be combined

---

## Technical Notes

## File Offset Calculation

The offset in block table is relative to the start of the MPQ archive,
not the start of the file. If there's a user data header, add that offset.

## Sector-Based Storage

Large files are split into sectors (size from header). Each sector may
be compressed independently. Need sector offset table for multi-sector files.

```lua
-- For multi-sector files, a sector offset table precedes the data:
-- uint32[num_sectors + 1] - offsets relative to file start
-- The last entry gives the total compressed size (for calculating last sector size)
```

## Encrypted Files

If ENCRYPTED flag is set, file content is encrypted. The key is:
- Base key: mpq_hash(filename, 3)
- If FIX_KEY: key = (base_key + block_offset) XOR uncompressed_size

This is why we need the filename for extraction (covered in 102d).

---

## Related Documents

- docs/formats/mpq-archive.md
- issues/102b-parse-mpq-hash-table.md (provides block index)
- issues/102d-implement-file-extraction.md (uses block info)
- issues/102-implement-mpq-archive-parser.md (parent)

---

## Acceptance Criteria

- [ ] Can decrypt block table from test archive
- [ ] Correctly parses offset, sizes, flags for all entries
- [ ] Identifies compression method for compressed files
- [ ] Identifies encrypted files
- [ ] Can retrieve block info by index
- [ ] Unit tests for flag parsing

---

## Notes

The block table tells us everything about how file data is stored. The
actual extraction (reading data, decompressing, decrypting) is handled
in 102d. This module just parses the metadata.

───────────────────────────────────────────────────────────────
102d-implement-file-extraction.md
───────────────────────────────────────────────────────────────

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

## Encryption Key Calculation

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

## Sector CRC

If SECTOR_CRC flag is set, each sector has a 4-byte CRC after the offset table.
Can be used for verification but is optional.

## WC3-Specific Notes

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

--------------------------------------------------------------------------------

### Assistant Response 1

The analysis file exists but is empty. Let me provide my structural review:

---

## Structural Review: Issue 102 MPQ Archive Parser

## 1. Sub-Issues That Should Be Broken Down Further

**102b - Parse MPQ Hash Table** → Split into 2 sub-issues

This issue conflates two distinct concerns:
- **102b1 - Implement MPQ Crypto Table and Hash Functions**: The crypto table generation and three hash function types are foundational utilities used by multiple components (hash table decryption, block table decryption, file encryption keys). This is a standalone module.
- **102b2 - Parse and Query Hash Table**: The actual hash table parsing, decryption, and lookup logic.

*Rationale*: The hash/crypto module is a dependency of 102b, 102c, AND 102d. Extracting it makes dependencies cleaner and allows independent testing of the cryptographic primitives.

---

**102d - Implement File Extraction** → Split into 3 sub-issues

This issue is overloaded with multiple complex responsibilities:
- **102d1 - Implement Decompression Support**: Set up zlib, bzip2, PKWARE DCL decompression. Handle multi-compression byte flags. This is pure library integration with no MPQ-specific logic.
- **102d2 - Implement Sector Reading and Decryption**: Read sector offset tables, handle single-unit vs multi-sector files, decrypt encrypted sectors.
- **102d3 - Implement File Extraction API**: Tie together lookup, sector reading, decryption, and decompression into the final `extract()` function.

*Rationale*: Decompression setup is significant work (especially PKWARE DCL which may need custom implementation). Sector handling is tricky. Combining all three makes 102d too large to implement in one focused session.

---

## 2. Missing Sub-Issues (Gaps)

**102e - Implement Archive File Listing** (NEW)

The root issue's acceptance criteria includes "Can list all files in an archive"
but no sub-issue covers this. MPQ archives don't have a directory - file listing
requires:
- Parsing `(listfile)` if present (a text file inside the archive listing known filenames)
- Fallback: return "cannot list files, listfile not present"

This is distinct from extraction and should be its own issue.

---

**102f - Create Unified MPQ API Module** (NEW)

The root issue mentions "Create unified `mpq.lua` API module" in step 6, but
this isn't captured in a sub-issue. This includes:
- The `mpq.open()` function
- The archive object with `:list()`, `:has()`, `:extract()`, `:close()` methods
- Error handling and resource cleanup

This is the integration point that ties all sub-modules together.

---

**102g - MPQ Parser Integration Tests** (NEW)

The acceptance criteria list 7 items that require end-to-end testing against
real archives. Unit tests in each sub-issue test components in isolation;
integration tests verify the complete workflow.

---

## 3. Structural Improvements

**Revised Sub-Issue Organization**

| ID | Description | Dependencies |
|----|-------------|--------------|
| 102a | Parse MPQ header structure | - |
| 102b1 | Implement crypto table and hash functions | - |
| 102b2 | Parse and query hash table | 102a, 102b1 |
| 102c | Parse block table | 102a, 102b1 |
| 102d1 | Implement decompression support | - |
| 102d2 | Implement sector reading and decryption | 102b1, 102c |
| 102d3 | Implement file extraction function | 102b2, 102d1, 102d2 |
| 102e | Implement archive file listing | 102d3 |
| 102f | Create unified MPQ API module | 102a-102e |
| 102g | Integration tests with real archives | 102f |

**Suggested Execution Order**:
```
102a ─────────────────┐
                      ├─→ 102b2 ─┐
102b1 ─┬─→ 102c ─┐    │          │
       │         ├────┴─→ 102d2 ─┼─→ 102d3 ─→ 102e ─→ 102f ─→ 102g
       │         │               │
102d1 ─┴─────────┴───────────────┘
```

Note: 102a, 102b1, and 102d1 can be worked in parallel (no interdependencies).

---

## Summary of Recommendations

| Action | Issue | Recommendation |
|--------|-------|----------------|
| Split | 102b | Extract crypto/hash module as 102b1, rename remainder 102b2 |
| Split | 102d | Split into 102d1 (decompression), 102d2 (sectors), 102d3
(extraction) |
| Add | 102e | File listing via `(listfile)` |
| Add | 102f | Unified API module creation |
| Add | 102g | Integration tests against real .w3x files |
| Update | 102 | Revise sub-issue table and dependency graph |

--------------------------------------------------------------------------------
