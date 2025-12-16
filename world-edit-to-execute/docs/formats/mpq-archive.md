# MPQ Archive Format Specification

MPQ (Mo'PaQ, "Mike O'Brien Pack") is Blizzard Entertainment's archive format used for
Warcraft III map files (.w3m/.w3x). This document covers the format as used by WC3.

---

## Overview

MPQ archives are read-optimized containers using hash-based file lookup. Key features:

- Hash table for O(1) filename lookup (no stored filenames)
- Block table for file metadata (offsets, sizes, flags)
- Per-file compression and encryption
- Sector-based storage for large files

---

## Archive Structure

```
┌─────────────────────────────────────┐
│          Archive Header             │  32 bytes (format v0)
├─────────────────────────────────────┤
│                                     │
│           File Data                 │  Variable (sectors)
│                                     │
├─────────────────────────────────────┤
│          Hash Table                 │  16 bytes × entries
├─────────────────────────────────────┤
│         Block Table                 │  16 bytes × entries
└─────────────────────────────────────┘
```

Note: This layout is typical but not mandatory. Tables may appear in different order.

---

## Archive Header

The header begins at offset 0x00, 0x200, 0x400, etc. (512-byte boundaries).

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0x00 | 4 | Magic | `MPQ\x1A` (4D 50 51 1A) or `MPQ\x1B` (shunt) |
| 0x04 | 4 | HeaderSize | Size of header (0x20 for v0, 0x2C for v1) |
| 0x08 | 4 | ArchiveSize | Size of entire archive including header |
| 0x0C | 2 | FormatVersion | 0x0000 = Original, 0x0001 = Burning Crusade+ |
| 0x0E | 2 | SectorSizeShift | Sector size = 512 × 2^shift (typically 3 = 4096) |
| 0x10 | 4 | HashTableOffset | Offset to hash table (relative to archive start) |
| 0x14 | 4 | BlockTableOffset | Offset to block table (relative to archive start) |
| 0x18 | 4 | HashTableEntries | Number of hash table entries (must be power of 2) |
| 0x1C | 4 | BlockTableEntries | Number of block table entries |

### Format Version 1 Extensions (Burning Crusade+)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0x20 | 8 | ExtBlockTableOffset | 64-bit extended block table offset |
| 0x28 | 2 | HashTableOffsetHigh | High 16 bits of hash table offset |
| 0x2A | 2 | BlockTableOffsetHigh | High 16 bits of block table offset |

---

## Hash Table

Files are located by hashing filenames. No actual filenames are stored in the archive.

### Hash Table Entry (16 bytes)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0x00 | 4 | FilePathHashA | First hash of filename (hash type 1) |
| 0x04 | 4 | FilePathHashB | Second hash of filename (hash type 2) |
| 0x08 | 2 | Language | Windows LANGID (0 = neutral) |
| 0x0A | 2 | Platform | Platform ID (0 = default) |
| 0x0C | 4 | FileBlockIndex | Index into block table |

### Special FileBlockIndex Values

| Value | Meaning |
|-------|---------|
| 0xFFFFFFFF | Empty slot (never used) |
| 0xFFFFFFFE | Deleted entry (was used, now free) |

### File Lookup Algorithm

```
1. hash_index = HashString(filename, HASH_TYPE_TABLE_OFFSET) & (table_size - 1)
2. Check entry at hash_index
3. If FilePathHashA and FilePathHashB match: found
4. If empty slot: file not in archive
5. Otherwise: linear probe to next slot
```

---

## Block Table

Each entry describes a file's location and attributes within the archive.

### Block Table Entry (16 bytes)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0x00 | 4 | BlockOffset | Offset to file data (relative to archive start) |
| 0x04 | 4 | BlockSize | Size of compressed data in archive |
| 0x08 | 4 | FileSize | Size of uncompressed file |
| 0x0C | 4 | Flags | File attribute bitmask |

### Block Flags

| Flag | Value | Description |
|------|-------|-------------|
| MPQ_FILE_IMPLODE | 0x00000100 | File is PKWARE DCL compressed |
| MPQ_FILE_COMPRESS | 0x00000200 | File is compressed (multi-method) |
| MPQ_FILE_ENCRYPTED | 0x00010000 | File is encrypted |
| MPQ_FILE_KEY_ADJUST | 0x00020000 | Encryption key adjusted by block offset |
| MPQ_FILE_SINGLE_UNIT | 0x01000000 | File stored as single unit (no sectors) |
| MPQ_FILE_DELETE_MARKER | 0x02000000 | File is deleted |
| MPQ_FILE_SECTOR_CRC | 0x04000000 | File has CRC for each sector |
| MPQ_FILE_EXISTS | 0x80000000 | File exists (set for all valid files) |

---

## Hashing Algorithm

MPQ uses a custom hash function with a precomputed 1280-entry table.

### Crypto Table Generation

```lua
-- {{{ generate_crypto_table
local function generate_crypto_table()
    local crypt_table = {}
    local seed = 0x00100001

    for index1 = 0, 255 do
        local index2 = index1
        for i = 0, 4 do
            seed = (seed * 125 + 3) % 0x2AAAAB
            local temp1 = (seed & 0xFFFF) << 16

            seed = (seed * 125 + 3) % 0x2AAAAB
            local temp2 = seed & 0xFFFF

            crypt_table[index2] = temp1 | temp2
            index2 = index2 + 256
        end
    end

    return crypt_table
end
-- }}}
```

### Hash String Function

```lua
-- {{{ hash_string
local function hash_string(str, hash_type)
    local seed1 = 0x7FED7FED
    local seed2 = 0xEEEEEEEE

    str = str:upper():gsub("/", "\\")

    for i = 1, #str do
        local ch = str:byte(i)
        seed1 = crypt_table[hash_type * 256 + ch] ~ (seed1 + seed2)
        seed2 = ch + seed1 + seed2 + (seed2 << 5) + 3
    end

    return seed1 & 0xFFFFFFFF
end
-- }}}
```

### Hash Types

| Type | Value | Usage |
|------|-------|-------|
| HASH_TABLE_OFFSET | 0 | Hash table slot lookup |
| HASH_NAME_A | 1 | First filename verification |
| HASH_NAME_B | 2 | Second filename verification |
| HASH_FILE_KEY | 3 | Encryption key generation |

---

## Encryption

Hash and block tables are encrypted. Files may optionally be encrypted.

### Decryption Function

```lua
-- {{{ decrypt_data
local function decrypt_data(data, key)
    local seed1 = key
    local seed2 = 0xEEEEEEEE
    local result = {}

    for i = 1, #data, 4 do
        seed2 = seed2 + crypt_table[0x400 + (seed1 & 0xFF)]
        local value = string.unpack("<I4", data, i)
        value = value ~ (seed1 + seed2)

        seed1 = ((~seed1 << 21) + 0x11111111) | (seed1 >> 11)
        seed2 = value + seed2 + (seed2 << 5) + 3

        result[#result + 1] = string.pack("<I4", value)
    end

    return table.concat(result)
end
-- }}}
```

### Table Encryption Keys

- Hash Table: `hash_string("(hash table)", HASH_FILE_KEY)`
- Block Table: `hash_string("(block table)", HASH_FILE_KEY)`

### File Encryption Key

For encrypted files:
1. Base key = `hash_string(filename, HASH_FILE_KEY)`
2. If KEY_ADJUST flag: `key = (base_key + block_offset) XOR file_size`

---

## Compression

Files may use multiple compression algorithms, applied in sequence.

### Compression Byte (first byte of compressed sector)

| Flag | Value | Algorithm |
|------|-------|-----------|
| HUFFMAN | 0x01 | Huffman encoding |
| ZLIB | 0x02 | zlib deflate |
| PKWARE | 0x08 | PKWARE DCL implode |
| BZIP2 | 0x10 | bzip2 compression |
| SPARSE | 0x20 | Sparse representation |
| ADPCM_MONO | 0x40 | IMA ADPCM mono audio |
| ADPCM_STEREO | 0x80 | IMA ADPCM stereo audio |

### Decompression Order

When multiple algorithms are combined, decompress in reverse flag order:
ADPCM → SPARSE → BZIP2 → PKWARE → ZLIB → HUFFMAN

---

## Sector Format

Large files are split into sectors for streaming access.

### Sector Size

`sector_size = 512 * (2 ^ SectorSizeShift)`

Typical value: SectorSizeShift = 3 → 4096 bytes per sector

### Sector Table

Compressed files have a sector offset table at the start of file data:

```
uint32 sector_offsets[num_sectors + 1]
```

Where: `num_sectors = ceil(file_size / sector_size)`

The extra entry provides end offset for calculating last sector size.

### Single Unit Files

Files with MPQ_FILE_SINGLE_UNIT are stored without sector table, compressed as one block.

---

## WC3 Map File Wrapper (HM3W Header)

Warcraft III .w3m/.w3x files have a 512-byte header before the MPQ archive.

### HM3W Header Structure (512 bytes)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0x00 | 4 | Magic | `"HM3W"` (48 4D 33 57) |
| 0x04 | 4 | Unknown | Usually 0x00000000 |
| 0x08 | var | MapName | Null-terminated string (map name preview) |
| var | 4 | MapFlags | Map flags bitmask (same as in w3i) |
| var | 4 | MaxPlayers | Maximum player count |
| ... | ... | Padding | Zeros to fill 512 bytes |

### Map Flags (in HM3W header)

Same values as war3map.w3i flags - see w3i-map-info.md for details.

### W3X Authentication Footer (optional)

W3X (TFT) files may have an authentication footer after the MPQ:

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0x00 | 4 | Magic | `"NGIS"` (signature marker) |
| 0x04 | 256 | Signature | RSA signature bytes |

### File Layout

```
┌─────────────────────────────────────┐
│        HM3W Header (512 bytes)      │  Map preview info
├─────────────────────────────────────┤
│                                     │
│         MPQ Archive                 │  Actual map data
│                                     │
├─────────────────────────────────────┤
│    NGIS Footer (260 bytes, opt)     │  W3X only
└─────────────────────────────────────┘
```

### Locating MPQ Archive

The MPQ archive starts at offset 0x200 (512 bytes) after the HM3W header.
Look for `MPQ\x1A` magic at this offset.

### WC3 MPQ Header Quirks

Validation against DAoW-2.1.w3x reveals:
- HeaderSize field (offset 0x04) contains unexpected value in WC3 maps
- ArchiveSize correctly equals (file_size - 512)
- Hash/Block table offsets and counts are valid
- Tables are properly encrypted

For WC3 maps, rely on ArchiveSize and table offsets rather than HeaderSize.

---

## WC3 Map Considerations

Warcraft III .w3m/.w3x files are MPQ archives with specific contents:

### Required Files

| Filename | Description |
|----------|-------------|
| `war3map.w3i` | Map info (metadata) |
| `war3map.wts` | Trigger strings |
| `war3map.w3e` | Terrain data |
| `war3map.j` | JASS script |
| `war3map.wtg` | Trigger definitions |

### Common Compression

WC3 maps typically use:
- zlib (0x02) for most files
- PKWARE DCL (0x08) for some files
- Single-unit storage for small files

---

## Implementation Notes

### Pure Lua Approach

For this project, we implement:
1. Header/hash/block table parsing in pure Lua
2. Use lua-zlib for zlib decompression
3. Implement PKWARE DCL implode in Lua (reference: blast.c)
4. bzip2 via lua-bzip2 if needed (rare in WC3 maps)

### StormLib Alternative

StormLib (C library with FFI bindings) provides complete MPQ support but adds
external dependency. Consider as fallback for edge cases.

---

## References

- [MPQ Archives - zezula.net](http://www.zezula.net/en/mpq/mpqformat.html)
- [MPQ - wowdev.wiki](https://wowdev.wiki/MPQ)
- [MoPaQ File Format 1.0 - StormLib](https://github.com/dcramer/ghostplusplus/blob/master/StormLib/doc/The%20MoPaQ%20File%20Format%201.0.txt)
- [StormLib - GitHub](https://github.com/ladislav-zezula/StormLib)
