# Issue #002: Binary Naming Mismatch in Documentation

## Description

The Lua orchestrator script references binary names that don't match the actual binary names defined in Cargo.toml.

## Documentation States

**In scripts/orchestrator.lua lines 16-28:**
```lua
daemon = {
    name = "daemon",
    binary_path = "target/release/daemon",
    ...
},
handheld = {
    name = "handheld", 
    binary_path = "target/release/handheld",
    ...
},
desktop_llm = {
    name = "desktop-llm",
    binary_path = "target/release/desktop-llm",
    ...
}
```

## Actual Implementation

**In Cargo.toml lines 26-36:**
```toml
[[bin]]
name = "daemon"
path = "src/daemon.rs"

[[bin]]
name = "handheld"
path = "src/handheld.rs"

[[bin]]
name = "desktop-llm"
path = "src/desktop_llm.rs"
```

## Issue Details

The orchestrator script expects binaries to be named consistently, but there's a mismatch:
- Script expects: `target/release/desktop-llm`  
- Cargo.toml defines: `desktop-llm` (with hyphen)
- But script refers to it as `desktop_llm` in some variables (line 25)

This inconsistency could cause the orchestrator to fail when trying to start the desktop LLM service.

## Suggested Fixes

1. Standardize naming convention across all files
2. Either use hyphens consistently or underscores consistently
3. Update orchestrator.lua to match exact binary names from Cargo.toml
4. Test that `lua scripts/orchestrator.lua start-llm` actually works

## Line Numbers

- scripts/orchestrator.lua: Lines 16-28 (component definitions)
- Cargo.toml: Lines 26-36 (binary definitions)

## Priority

Medium - Could cause runtime failures when using the orchestrator script