# Issue 011: Combine Duplicate Run-Demo Scripts

## Current Behavior

There are two separate demo runner scripts in the project root:
- `run_demo.sh` (underscore) - Simple menu with Phase 0 and 1 support
- `run-demo.sh` (hyphen) - More elaborate with argument parsing, expects Lua demos

This creates confusion about which script to use and duplicates functionality.

## Intended Behavior

A single unified `run-demo.sh` script that:
1. Follows the neocities-modernization project pattern
2. Has proper DIR setup with argument support
3. Supports all completed phases (currently Phase 0 and 1)
4. Has interactive mode (default) and non-interactive mode (-n)
5. Calls the appropriate demo scripts (bash or lua)
6. Shows completion status for each phase
7. Has main menu loop with clean navigation

## Suggested Implementation Steps

- [x] Study neocities-modernization/phase-demo.sh for reference pattern
- [x] Create combined run-demo.sh with:
  - setup_dir_path function with argument support
  - Main menu showing Phase 0 and 1 with status
  - Phase 0: Launch issue-splitter.sh -I (from run_phase0.sh)
  - Phase 1: Run phase1_demo.lua (interactive Lua demo)
  - Non-interactive mode support (-n flag)
  - Help flag (-h)
- [x] Remove the old run_demo.sh (underscore version)
- [x] Update any documentation references

## Related Documents

- `/home/ritz/programming/ai-stuff/neocities-modernization/phase-demo.sh` - Reference implementation
- `issues/completed/demos/run_phase0.sh` - Phase 0 demo script
- `issues/completed/demos/run_phase1.sh` - Phase 1 test runner
- `issues/completed/demos/phase1_demo.lua` - Phase 1 interactive demo

## Acceptance Criteria

- [x] Single run-demo.sh script exists
- [x] Script supports -h, -n, -I flags
- [x] Script runs from any directory with proper DIR handling
- [x] Phase 0 demo launches issue-splitter TUI
- [x] Phase 1 demo shows interactive map parsing demo
- [x] Non-interactive mode exits with proper status code
- [x] Old run_demo.sh removed

## Implementation Notes

Combined the two scripts into a unified `run-demo.sh` following the neocities-modernization
pattern. Features include:

- Interactive menu loop with all 10 phases listed (0-9)
- Color-coded status indicators (green checkmarks for complete, yellow pending)
- Statistics option [S] showing project architecture and metrics
- Test runner option [T] for Phase 1 validation tests
- Non-interactive mode (-n) for CI/headless testing
- Proper DIR handling that only uses $1 as directory if it actually exists as one

Documentation updates made to:
- CLAUDE.md (line 383)
- issues/408-phase-4-integration-test.md
- issues/A07-phase-a-integration-test.md (2 references)
