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

### File Offset Calculation

The offset in block table is relative to the start of the MPQ archive,
not the start of the file. If there's a user data header, add that offset.

### Sector-Based Storage

Large files are split into sectors (size from header). Each sector may
be compressed independently. Need sector offset table for multi-sector files.

```lua
-- For multi-sector files, a sector offset table precedes the data:
-- uint32[num_sectors + 1] - offsets relative to file start
-- The last entry gives the total compressed size (for calculating last sector size)
```

### Encrypted Files

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

- [x] Can decrypt block table from test archive
- [x] Correctly parses offset, sizes, flags for all entries
- [x] Identifies compression method for compressed files
- [x] Identifies encrypted files
- [x] Can retrieve block info by index
- [x] Unit tests for flag parsing

---

## Notes

The block table tells us everything about how file data is stored. The
actual extraction (reading data, decompressing, decrypting) is handled
in 102d. This module just parses the metadata.

---

## Implementation Notes

*Completed 2025-12-16*

### Files Created

1. **src/mpq/blocktable.lua** - Block table parser module
   - `parse(file_data, mpq_header)` - Parses encrypted block table
   - `get_block(block_table, index)` - Gets block entry by index
   - `list_files(block_table)` - Lists all valid entries
   - `get_compression_name(byte)` - Human-readable compression method
   - `format(block_table)` - Human-readable output
   - Constants: FLAGS, COMPRESSION

2. **src/tests/test_blocktable.lua** - Unit tests (26 tests)

### Test Results

```
Tests: 26 passed, 0 failed, 26 total
ALL TESTS PASSED

Maps: 16/16 parse successfully
```

### Key Findings from DAoW-2.1.w3x

| File | Block | Compressed | Uncompressed | Encrypted | Ratio |
|------|-------|------------|--------------|-----------|-------|
| war3map.w3e | 0 | varies | varies | true | ~40% |
| war3map.w3i | 1 | 351 | 841 | true | 42% |
| war3map.wts | 2 | varies | varies | true | varies |

Key finding: **All files in DAoW maps are encrypted**. This means 102d must
implement decryption for file extraction to work.

### Flag Combinations Observed

- EXISTS + COMPRESS + ENCRYPTED - Most common
- EXISTS + COMPRESS + ENCRYPTED + FIX_KEY - Some files
- EXISTS + SINGLE_UNIT + COMPRESS + ENCRYPTED - Small files
