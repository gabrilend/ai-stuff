# Issue #003: Test Runner Binary Not Implemented

## Description

The TESTING.md documentation extensively references a test runner binary that does not exist in the codebase.

## Documentation States

**In TESTING.md lines 129-168:**
```bash
# Critical tests only
cargo run --bin test_runner -- --critical-only

# Quick pre-commit tests
cargo run --bin test_runner -- --quick

# Full CI pipeline  
cargo run --bin test_runner -- --ci

# Nightly comprehensive tests
cargo run --bin test_runner -- --nightly
```

**In TESTING.md lines 226-234 (pre-commit hooks):**
```bash
cargo run --bin test_runner -- --critical
```

## Actual Implementation

**In Cargo.toml:** No `test_runner` binary is defined

**Available binaries are:**
- daemon, handheld, desktop-llm
- paint-demo, music-demo, mmo-demo, email-demo
- battleship-pong, rocketship-bacterium, scuttlebutt-mesh
- terminal-demo, media-demo

## Impact

Users following the testing guide will get errors like:
```
error: no bin target named `test_runner`
```

The comprehensive testing strategy described in TESTING.md cannot be executed as documented.

## Suggested Fixes

1. **Option A:** Implement the test_runner binary in src/test_runner.rs
   - Add `[[bin]]` entry to Cargo.toml
   - Implement the --critical, --quick, --ci, --nightly modes
   - Add test discovery and execution logic

2. **Option B:** Update TESTING.md to use standard cargo test commands
   - Replace test_runner references with `cargo test` commands
   - Update CI examples to use `scripts/run_tests.sh` instead
   - Remove references to non-existent binary

3. **Option C:** Use the existing scripts/run_tests.sh
   - Update all test_runner references to use the shell script
   - Ensure run_tests.sh supports all the modes mentioned

## Line Numbers

- TESTING.md: Lines 129-168, 226-234 (test runner references)
- Cargo.toml: Missing test_runner binary definition
- Missing: src/test_runner.rs

## Priority

High - Makes the documented testing workflow completely unusable