# Issue #006: Binary Name Inconsistencies Between Documentation and Cargo.toml

## Priority: Low

## Description
Binary names referenced in documentation don't match the actual binary names defined in Cargo.toml, causing confusion and broken commands.

## Documented Functionality
**File**: `README.md`, various documentation files

References to:
- `src/daemon.rs` as "Project Daemon" 
- `src/desktop_llm.rs` for LLM services

## Implemented Functionality
**File**: `Cargo.toml`  
**Lines**: Binary definitions

Actual binary names:
- `daemon` (matches)
- `desktop-llm` (with hyphen, not underscore)
- Also has `laptop_daemon.rs` (unclear relationship to main daemon)

## Issue
1. **Hyphen vs Underscore**: Documentation refers to `desktop_llm.rs` but binary is named `desktop-llm`
2. **Daemon Confusion**: Both `daemon.rs` and `laptop_daemon.rs` exist - unclear which is primary
3. **Command Examples**: Users will get "binary not found" errors

## Impact
- Build commands in documentation fail
- Confusion about which daemon to run
- Installation/deployment scripts may be broken

## Examples of Broken Commands
Documentation might show:
```bash
cargo run --bin desktop_llm    # FAILS - should be desktop-llm
```

## Suggested Fixes

**Option 1**: Update documentation to match Cargo.toml
- Change all references from `desktop_llm` to `desktop-llm`
- Clarify daemon vs laptop_daemon usage

**Option 2**: Update Cargo.toml to match documentation  
- Change `desktop-llm` to `desktop_llm` in Cargo.toml
- Rename binary to use underscores consistently

**Option 3**: Standardize naming convention
- Choose either hyphens or underscores consistently
- Update both code and docs to match

## Related Files
- `README.md` (binary references)
- `Cargo.toml` (binary definitions)  
- `docs/` (deployment and usage examples)
- Build scripts and CI configuration

## Recommendation
**Option 1** is recommended - update documentation to match Cargo.toml, as changing binary names could break existing deployments.

## Additional Investigation Needed
- Clarify relationship between `daemon` and `laptop_daemon`
- Audit all documentation for binary name references
- Check if any scripts or CI depends on current names