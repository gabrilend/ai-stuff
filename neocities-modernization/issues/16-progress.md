# Phase 16 Progress Report

## Phase 16 Goals

**"Network Media — Android as Source, WiFi as Bridge, Timeline as Destination"**

Phase 16 extends the neocities modernization project beyond local files to treat an Android device's photos and videos as a live file source. The media integrates directly into the existing chronological and similar/different page infrastructure as a new "type: network" source.

### **From Previous Phases**
- Chronological HTML generation pipeline
- Similar/different page infrastructure
- File type abstraction (text, image)
- Static HTML generation with embedded navigation

### **Phase 16 Objectives**
- Implement dual-mode file server (Termux+Lua CLI, Native Android GUI)
- Create "type: network" file source integration
- Generate HTTPS endpoints with self-signed certificates
- Build trust warning intermediate pages with chronological back-navigation
- Scan and serve photos/videos from DCIM and Camera directories

## The Core Integration

| Existing System | Phase 16 Addition |
|-----------------|-------------------|
| Local files (poems, images) | Network files (Android photos/videos) |
| type: text, type: image | type: network |
| Direct file links | HTTPS endpoint links via trust page |
| Back button to similar/different | Back button to chronological position |

## Phase 16 Issues

### Active Issues

| Issue | Description | Status | Priority |
|-------|-------------|--------|----------|
| 16-001 | Termux + Lua server implementation | Open | High |
| 16-002 | Native Android background service | Open | High |
| 16-003 | Network file type integration | Open | High |
| 16-004 | HTTPS with self-signed certificates | Open | Medium |
| 16-005 | Trust warning intermediate page | Open | Medium |
| 16-006 | Chronological position-aware back navigation | Completed | Medium |
| 16-007 | File scanning and metadata extraction | Open | High |
| 16-008 | Torrent file generation for distribution | Open | Medium |
| 16-009 | WebTorrent in-browser streaming (JS option) | Open | Low |
### Completed Issues

| Issue | Description | Status | Completed |
|-------|-------------|--------|-----------|
| 16-006 | Chronological position-aware back navigation | Completed | 2026-03-18 |
| 16-010 | Monospace font enforcement | Completed | 2026-03-18 |

**16-006: Chronological Position-Aware Back Navigation** - COMPLETED (2026-03-18)
- Changed anchor ID format from category-based (`poem-fediverse-0042`) to sequential (`poem-4625`)
- Updated `get_poem_anchor_id()` to use `poem_index` directly
- Updated parallel worker anchor generation to match
- Design decision: Sequential IDs are machine+human readable without leaking metadata

## Key Concepts

### Dual-Mode Operation

The server can be configured and run via:
1. **CLI mode**: `lua android-server.lua --port 8443 --dir /sdcard/DCIM`
2. **GUI mode**: Native Android app with background service toggle

Both modes serve the same HTTPS endpoints with the same API.

### Network File Type

```lua
-- File types in the pipeline
local file_types = {
    text = { source = "local", extension = ".txt" },
    image = { source = "local", extension = ".png,.jpg" },
    network = { source = "https", endpoint = "192.168.0.X:8443" }
}
```

### Trust Warning Flow

```
User clicks photo link in chronological.html
         |
         v
+----------------------------+
|   HTTPS Trust Warning      |
|                            |
| "This is secured with      |
|  HTTPS, but I don't have   |
|  a certificate so..."      |
|                            |
| [Back]    [trust-me]       |
|  (to chronological)        |
+----------------------------+
         |
         v (click trust-me)
    Actual photo displayed
```

### Chronological Position Preservation

The back button returns users to their exact position in the timeline based on when the photo was taken:

```
chronological.html#2026-02-15-143022
                    ^timestamp from EXIF
```

## Architecture

```
+------------------+     WiFi      +--------------------+
|  Android Device  | -----------> |  Desktop/Browser   |
|  (File Server)   |    HTTPS     |  (View & Download) |
+------------------+              +--------------------+
        |                                   |
   Termux/Native                    chronological.html
        |                           similar/different
   Scan DCIM/                       with type:network
   Camera dirs                          entries
```

## Completion Criteria

- [ ] Termux + Lua server running on Android
- [ ] Native Android app with background service
- [ ] HTTPS with self-signed certificate working
- [ ] Trust warning intermediate page generated
- [ ] Photos/videos appear in chronological.html as type:network
- [ ] Back navigation returns to correct timeline position
- [ ] File count and listing API endpoint functional

---

**Phase Status: OPEN**

**Created**: 2026-02-20

## Cross-Phase Dependencies

**Depends on:**
- Phase 8: HTML generation pipeline
- Chronological page infrastructure

**Enables:**
- Live media integration from mobile devices
- Cross-device content unification
- Personal media archive with semantic navigation

## Related Documents

- `src/html-generator.lua` — HTML generation infrastructure
- `output/chronological/` — Chronological page output
- Phase 8: HTML generation and pagination

## Philosophical Note

> *The phone captures moments. The server shares them. The timeline preserves them. When network files integrate as first-class citizens alongside local poems and images, the boundary between devices dissolves. Your life's media becomes a single navigable river, flowing through whatever device holds it.*
