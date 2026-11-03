# Issue 608: Phase 6 Integration Test

**Phase:** 6
**Type:** Testing
**Priority:** High
**Dependencies:** Issues 601, 602, 603, 604, 605, 606, 606a (the file server issue was retired 2026-09-26)

---

## Current Behavior

No integration testing for the asset system as a whole.

## Intended Behavior

A comprehensive integration test that validates the complete asset pipeline:
1. Asset loading from various sources
2. Wire-frame fallback for missing assets
3. Client-server asset download
4. Deduplication working correctly
5. Storage management operations
6. Hot-reload functionality

### Test Scenarios

#### Scenario 1: WC3 Map Asset Loading

```
1. Load a WC3 map (.w3x)
2. Extract assets via MPQ parser
3. Load textures, verify dimensions
4. Load sounds, verify format
5. Request missing asset, verify fallback triggers
6. Verify cache statistics
```

#### Scenario 2: Server Asset Download

```
1. Start mock file server with test assets
2. Connect client to server
3. Verify manifest received
4. Report "already have" for some assets
5. Download remaining assets
6. Verify all assets accessible via loader
7. Disconnect, reconnect, verify no re-download
```

#### Scenario 3: Deduplication

```
1. Create two mock servers with overlapping assets
2. Download assets from server A
3. Download assets from server B
4. Verify shared assets stored once
5. Check dedup stats match expected savings
6. Delete server A
7. Verify shared assets still available for server B
8. Delete server B
9. Run GC, verify orphan blobs removed
```

#### Scenario 4: Storage Management

```
1. Populate storage with known test data
2. Query overview, verify totals
3. Query per-server stats, verify unique vs shared
4. Delete one server
5. Verify bytes freed match unique bytes
6. Run GC
7. Verify total storage reduced correctly
```

#### Scenario 5: Hot-Reload (Development)

```
1. Load asset into engine
2. Enable hot-reload
3. Modify asset on disk
4. Verify reload callback fires
5. Verify asset updated in memory
6. Introduce error in asset
7. Verify error callback fires
8. Verify old asset still functional
```

### Test Structure

```
src/tests/
├── test_phase6_integration.lua    # Main integration test
├── fixtures/
│   ├── test-map.w3x               # Small WC3 map with known assets
│   ├── server-a/                  # Mock server A assets
│   │   ├── manifest.lua
│   │   ├── unique-a.png
│   │   └── shared.png
│   └── server-b/                  # Mock server B assets
│       ├── manifest.lua
│       ├── unique-b.png
│       └── shared.png             # Same as server-a/shared.png
└── mocks/
    └── mock_fileserver.lua        # In-process mock server
```

### Phase Demo

```bash
#!/bin/bash
# issues/completed/demos/run_phase6.sh

echo "=== Phase 6: Asset System Demo ==="
echo ""

# Test 1: Asset Loading
echo "Test 1: Loading assets from WC3 map..."
lua src/tests/test_phase6_integration.lua --scenario=map_loading

# Test 2: Wire-frame Fallback
echo "Test 2: Wire-frame fallback for missing assets..."
lua src/tests/test_phase6_integration.lua --scenario=fallback

# Test 3: Download Protocol
echo "Test 3: Client-server asset download..."
lua src/tests/test_phase6_integration.lua --scenario=download

# Test 4: Deduplication
echo "Test 4: Asset deduplication..."
lua src/tests/test_phase6_integration.lua --scenario=dedup

# Test 5: Storage Management
echo "Test 5: Storage management..."
lua src/tests/test_phase6_integration.lua --scenario=storage

# Test 6: Hot-Reload
echo "Test 6: Hot-reload system..."
lua src/tests/test_phase6_integration.lua --scenario=hotreload

# Summary
echo ""
echo "=== Phase 6 Complete ==="
lua src/tests/test_phase6_integration.lua --summary
```

## Suggested Implementation Steps

1. Create test fixture assets (small, deterministic)
2. Create mock file server for download testing
3. Implement Scenario 1 tests (map loading)
4. Implement Scenario 2 tests (download)
5. Implement Scenario 3 tests (deduplication)
6. Implement Scenario 4 tests (storage)
7. Implement Scenario 5 tests (hot-reload)
8. Create phase demo script
9. Document test coverage

## Acceptance Criteria

- [x] All 5 scenarios pass (and the fallback's, as a sixth), on a tree
      with every phase 6 branch combined; see the notes
- [x] Test fixtures are small and fast (< 5 seconds total): under 0.1 s
      of processor time, under 1 s in all
- [x] Mock server works without network (in-process)
- [x] Phase demo runs all tests with clear output
- [x] No external dependencies (no real servers needed)
- [x] Tests clean up after themselves (no leftover temp files)

## Related Documents

- Issues 601-606 (components being tested; 607 retired 2026-09-26)
- `issues/completed/demos/` (phase demo location)

## Notes

- Keep test assets small (few KB each) for fast tests
- Mock server should simulate network delays optionally
- Consider fuzz testing for protocol robustness
- Hot-reload test needs to actually modify files, be careful with temp dirs
- May want "visual demo" in addition to automated tests (show wire-frame mode, etc.)

## Implementation Notes (2026-11-03)

- `src/tests/test_phase6_integration.lua` has six scenarios:
  `map_loading`, `fallback`, `download`, `dedup`, `storage` and
  `hotreload`. Run one with `--scenario=NAME`, or all of them (with a
  summary) with no flag or `--summary`.
- `issues/completed/demos/run_phase6.sh` is the phase demo. It runs each
  scenario under its own heading, then the summary.

**How it was checked.** Phase 6 is spread over two stacks of open pull
requests: the storage stack (#30 → #64 → #88, #121) and the loader stack
(#30 → #66 → #79 → #138 → #186, and #109 → #148 → #158 → #175, #166).
No one branch holds every part. This test was run on a scratch tree that
combines every branch, built with `git merge-tree`; nothing was merged
or pushed that way. There, all six scenarios pass (38 checks). On its
own branch (609a), the scenarios whose modules aren't there yet say
"skipped" and name the missing module, rather than failing. Once every
phase 6 PR is merged, the demo should show all six passing.

### Decisions made while building

1. **"Server download" is the shared-list exchange (609a), run
   in-process.** The file server (607) was retired. A list is the
   manifest, a want is "here is what I already have", and the files
   message is the download. An offer of the same list again downloads
   nothing, which is the reconnect check. 603's fetcher, which reads
   local files only, has its own tests.
2. **"Two servers with overlapping assets" are two asset packs** in the
   storage manager (605). Deleting one is deleting a "server".
3. **No committed fixtures.** Every fixture is written into a temporary
   folder at run time: a few TGAs, a WAV and some bytes. The one binary
   used is a test map already in `assets/` (DAoW 2.1). The issue's
   `fixtures/` and `mocks/` folders aren't needed.
4. **The test maps hold no sounds**, so a pack brings a tiny PCM WAV.
   Its header (PCM, mono, 22050 Hz) is checked after it has come
   through the loader.
5. **The wire-frame fallback is a sixth scenario**, since the issue's
   demo lists it on its own.
6. **A scenario whose part isn't here yet is skipped, not failed.** The
   summary names the missing module, so the test can land before the
   rest of phase 6 does.
7. **`run-demo.sh` isn't changed.** Its `COMPLETED_PHASES` stays at 5
   while 602a, 603 and 606a are still open.

