# Issue 608: Phase 6 Integration Test

**Phase:** 6
**Type:** Testing
**Priority:** High
**Dependencies:** Issues 601-607

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

- [ ] All 5 scenarios pass
- [ ] Test fixtures are small and fast (< 5 seconds total)
- [ ] Mock server works without network (in-process)
- [ ] Phase demo runs all tests with clear output
- [ ] No external dependencies (no real servers needed)
- [ ] Tests clean up after themselves (no leftover temp files)

## Related Documents

- Issues 601-607 (components being tested)
- `issues/completed/demos/` (phase demo location)

## Notes

- Keep test assets small (few KB each) for fast tests
- Mock server should simulate network delays optionally
- Consider fuzz testing for protocol robustness
- Hot-reload test needs to actually modify files, be careful with temp dirs
- May want "visual demo" in addition to automated tests (show wire-frame mode, etc.)
