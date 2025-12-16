I have the issue content from your message. Let me analyze it.

## Analysis

This issue is a good candidate for splitting. It covers **four distinct file formats**, each requiring independent research and producing separate documentation. The work is naturally parallelizable and each sub-issue has clear boundaries.

## Suggested Sub-Issues

### 101a-research-mpq-archive-format
**Description:** Research and document the MPQ (Mo'PaQ) archive format, which is the container format for .w3m/.w3x map files.

**Covers:**
- Header structure (magic bytes, version, hash table offset, block table offset)
- Hash table entry format
- Block table entry format  
- Compression methods (PKWARE, zlib, bzip2)
- Reference existing implementations (StormLib, libmpq)
- Decision: use existing library vs implement from scratch

**Dependencies:** None

**Output:** `docs/formats/mpq-archive.md`

---

### 101b-research-w3i-map-info-format
**Description:** Research and document the war3map.w3i file format containing map metadata.

**Covers:**
- File header and version bytes
- Map name, author, description fields
- Player slot definitions
- Force definitions
- Loading screen settings
- Map flags and options
- Version-specific variations

**Dependencies:** 101a (need to extract .w3i from MPQ to validate)

**Output:** `docs/formats/w3i-map-info.md`

---

### 101c-research-wts-trigger-strings-format
**Description:** Research and document the war3map.wts file format for localized trigger strings.

**Covers:**
- String table structure
- String ID to content mapping
- Encoding considerations (UTF-8 vs legacy encodings)
- How strings are referenced by other files

**Dependencies:** 101a (need to extract .wts from MPQ to validate)

**Output:** `docs/formats/wts-trigger-strings.md`

---

### 101d-research-w3e-terrain-format
**Description:** Research and document the war3map.w3e file format for terrain data.

**Covers:**
- Terrain tile format
- Height map encoding
- Tile texture indices
- Water level data
- Cliff/ramp encoding
- Map dimensions and coordinate systems

**Dependencies:** 101a (need to extract .w3e from MPQ to validate)

**Output:** `docs/formats/w3e-terrain.md`

---

## Dependency Graph

```
101a (MPQ Archive)
    ├── 101b (W3I Map Info)
    ├── 101c (WTS Trigger Strings)
    └── 101d (W3E Terrain)
```

## Recommendation

**Split this issue.** The benefits are:

1. **Clear ownership** - Each sub-issue produces exactly one document
2. **Parallelizable** - 101b, 101c, 101d can be worked in parallel after 101a completes
3. **Trackable progress** - Can mark MPQ research complete while still working on terrain
4. **Appropriate granularity** - Each sub-issue is 1-3 hours of focused research work
5. **Natural blocking order** - MPQ must be understood first since it's the container format

The parent issue 101 should remain as a tracking issue that's considered complete when all four sub-issues are done.
