# Issue #003: Test Runner Binary Referenced But Not Implemented

## Priority: Medium

## Description
The testing documentation references a `test_runner` binary that doesn't exist in the project configuration.

## Documented Functionality
**File**: `TESTING.md`  
**Lines**: 129, 159-169

Documentation shows commands like:
```bash
cargo run --bin test_runner -- --integration
cargo run --bin test_runner -- --benchmarks
cargo run --bin test_runner -- --coverage
```

## Implemented Functionality
**File**: `Cargo.toml`  
**Reality**: No `test_runner` binary is defined in the `[[bin]]` sections

Actual binaries defined:
- `daemon`
- `handheld` 
- `desktop-llm`
- `paint-demo`
- `music-demo`
- etc.

## Issue
Users following the testing documentation will get errors:
```
error: no bin target named `test_runner`
```

## Impact
- Testing documentation is unusable
- Contributors cannot run tests as documented
- CI/CD setup instructions are broken

## Suggested Fixes

**Option 1**: Implement the test_runner binary
- Add to `Cargo.toml`:
```toml
[[bin]]
name = "test_runner"
path = "src/bin/test_runner.rs"
```
- Create `src/bin/test_runner.rs` with test orchestration functionality

**Option 2**: Update documentation to use standard Rust testing
Replace test_runner commands with:
```bash
cargo test                           # Run all tests
cargo test --test integration        # Integration tests
cargo bench                         # Benchmarks  
cargo test --release                # Performance tests
```

**Option 3**: Use existing tooling
Update docs to use `cargo-nextest` or similar established test runners

## Related Files
- `TESTING.md` (lines 129, 159-169)
- `Cargo.toml` (needs binary definition if implementing)
- `src/bin/test_runner.rs` (needs creation if implementing)

## Recommendation
**Option 2** is recommended - update documentation to use standard Rust testing patterns rather than implementing a custom test runner, unless there are specific orchestration needs that justify the complexity.