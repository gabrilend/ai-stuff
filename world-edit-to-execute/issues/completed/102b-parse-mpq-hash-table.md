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

### Hash Collision Resolution

MPQ uses linear probing. If slot N is occupied by a different file, check N+1, N+2, etc.
An empty slot (block_index = 0xFFFFFFFF) terminates the search.
A deleted slot (block_index = 0xFFFFFFFE) continues the search.

### Case Sensitivity

MPQ filenames are case-insensitive. Convert to uppercase before hashing.
Also normalize path separators: `/` becomes `\`.

### Encryption

The hash table is always encrypted. The encryption key is derived from
the string "(hash table)" using hash type 3.

---

## Related Documents

- docs/formats/mpq-archive.md
- issues/102a-parse-mpq-header.md (provides table offset/size)
- issues/102-implement-mpq-archive-parser.md (parent)

---

## Acceptance Criteria

- [x] Crypto table generates correct values (verify against reference)
- [x] Hash function produces correct hashes for known strings
- [x] Can decrypt hash table from test archive
- [x] Can find block index for "war3map.w3i"
- [x] Can find block index for "war3map.j" (note: may not exist in all maps)
- [x] Returns nil for non-existent files
- [x] Handles case-insensitive lookups
- [x] Unit tests for hash function and lookup

---

## Notes

The crypto table and hash algorithms are well-documented online. Reference
implementations exist in StormLib and various open-source projects.

Consider caching the crypto table as a Lua table literal to avoid
regenerating it each time.

---

## Implementation Notes

*Completed 2025-12-16*

### Files Created

1. **src/mpq/hash.lua** - Hash function and decryption module
   - `init_crypt_table()` - Generates 1280-entry crypto table
   - `mpq_hash(str, hash_type)` - Computes MPQ hash (4 types)
   - `decrypt_block(data, key)` - Decrypts data using MPQ algorithm
   - `decrypt_table(data, key_string)` - Decrypts hash/block tables
   - Constants: HASH_TABLE_OFFSET, HASH_NAME_A, HASH_NAME_B, HASH_FILE_KEY

2. **src/mpq/hashtable.lua** - Hash table parser module
   - `parse(file_data, mpq_header)` - Parses encrypted hash table
   - `find_file(hash_table, filename)` - Looks up file by name
   - `list_files(hash_table)` - Lists all valid entries
   - `has_file(hash_table, filename)` - Checks if file exists
   - `get_entry(hash_table, filename)` - Gets full entry details
   - `format(hash_table)` - Human-readable output

3. **src/tests/test_hash.lua** - Unit tests (21 tests)

### Test Results

```
Tests: 21 passed, 0 failed, 21 total
ALL TESTS PASSED

Maps: 16/16 can lookup war3map.w3i
```

### Verified Hash Values

| String | Hash Type | Expected | Actual |
|--------|-----------|----------|--------|
| "(hash table)" | FILE_KEY | 0xC3AF3770 | 0xC3AF3770 |
| "(block table)" | FILE_KEY | 0xEC83B3A3 | 0xEC83B3A3 |

### Key Implementation Details

1. **Crypto Table**: Generated lazily on first use, cached globally
2. **Filename Normalization**: Uppercase + forward→backslash
3. **Linear Probing**: Empty slot (0xFFFFFFFF) terminates, deleted (0xFFFFFFFE) continues
4. **Decryption**: XOR-based with rolling seed values
