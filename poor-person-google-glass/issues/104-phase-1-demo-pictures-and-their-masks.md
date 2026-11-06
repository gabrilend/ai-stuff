# 104 — Phase 1 demo: pictures and their masks

**Phase:** 1 — The mask
**Blocked by:** 101, 102, 103
**Blocks:** 601

## Current Behavior
No phase 1 demo.

## Intended Behavior
A window (Lua, separate from the data generation) showing pictures beside
their planned masks with match scores and travel times, and one scene change
played tab by tab.

## Suggested Implementation Steps
1. Generate the data to tmp/shared-memory/.
2. Viewer draws it; `issues/completed/demos/phase-1-demo` runs both.
