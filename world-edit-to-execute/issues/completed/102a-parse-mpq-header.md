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

### Sector Size

The sector size is calculated as `512 << sector_size_shift`. Typical values:
- Shift of 3 = 4096 bytes per sector

### Version Differences

- Version 0: Original MPQ format (WC3 uses this)
- Version 1: Extended format (Burning Crusade+, not needed for WC3)

We only need to support version 0 for WC3 maps.

### User Data Header

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

- [x] Can read header from assets/DAoW-2.1.w3x
- [x] Correctly identifies MPQ magic signature
- [x] Extracts all header fields accurately
- [x] Handles user data header (MPQ\x1B) if present
- [x] Returns clear error for non-MPQ files
- [x] Unit tests cover normal and error cases

---

## Notes

This is the first code written for the project. Establish good patterns:
- Clear error handling
- Comprehensive logging (optional, toggleable)
- Clean module structure
- Documentation comments

---

## Implementation Notes

*Completed 2025-12-16*

### Files Created

1. **src/mpq/header.lua** - MPQ header parser module
   - `parse_hm3w(data)` - Parses HM3W wrapper header (WC3-specific)
   - `parse_mpq(data, offset)` - Parses MPQ archive header
   - `open_w3x(filepath)` - Opens WC3 map file, parses both headers
   - `validate(mpq)` - Validates header contains sensible values
   - `format(result)` - Returns human-readable header summary

2. **src/tests/test_header.lua** - Unit tests
   - Tests DAoW-2.1.w3x parsing in detail
   - Tests error handling (non-existent file, invalid file)
   - Tests all 16 map files in assets/

### Test Results

```
Tests: 20 passed, 0 failed, 20 total
ALL TESTS PASSED

Maps: 16/16 parsed successfully
```

### Key Implementation Details

1. **HM3W Header Parsing**
   - Magic: "HM3W" at offset 0
   - Map name as null-terminated string at offset 8
   - Map flags and max players follow map name
   - MPQ archive always at offset 512 (0x200)

2. **MPQ Header Parsing**
   - Handles MPQ\x1A (standard) and MPQ\x1B (shunt) magic
   - Parses all standard header fields
   - Calculates absolute offsets for hash/block tables
   - Derives sector size from shift value

3. **Patterns Established**
   - Vimfolds for function organization
   - Clear error returns (nil, error_message)
   - Module with exported functions
   - Comprehensive unit tests

### Quirks Discovered

- Sector size shift of 12 found in test files (2MB sectors, unusually large)
- HeaderSize field contains non-standard values in WC3 maps
