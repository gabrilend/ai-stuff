The analysis file exists but is empty. Let me provide my structural review:

---

## Structural Review: Issue 102 MPQ Archive Parser

### 1. Sub-Issues That Should Be Broken Down Further

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

### 2. Missing Sub-Issues (Gaps)

**102e - Implement Archive File Listing** (NEW)

The root issue's acceptance criteria includes "Can list all files in an archive" but no sub-issue covers this. MPQ archives don't have a directory - file listing requires:
- Parsing `(listfile)` if present (a text file inside the archive listing known filenames)
- Fallback: return "cannot list files, listfile not present"

This is distinct from extraction and should be its own issue.

---

**102f - Create Unified MPQ API Module** (NEW)

The root issue mentions "Create unified `mpq.lua` API module" in step 6, but this isn't captured in a sub-issue. This includes:
- The `mpq.open()` function
- The archive object with `:list()`, `:has()`, `:extract()`, `:close()` methods
- Error handling and resource cleanup

This is the integration point that ties all sub-modules together.

---

**102g - MPQ Parser Integration Tests** (NEW)

The acceptance criteria list 7 items that require end-to-end testing against real archives. Unit tests in each sub-issue test components in isolation; integration tests verify the complete workflow.

---

### 3. Structural Improvements

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

### Summary of Recommendations

| Action | Issue | Recommendation |
|--------|-------|----------------|
| Split | 102b | Extract crypto/hash module as 102b1, rename remainder 102b2 |
| Split | 102d | Split into 102d1 (decompression), 102d2 (sectors), 102d3 (extraction) |
| Add | 102e | File listing via `(listfile)` |
| Add | 102f | Unified API module creation |
| Add | 102g | Integration tests against real .w3x files |
| Update | 102 | Revise sub-issue table and dependency graph |
