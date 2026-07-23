# Conversation Summary: 58affc66-27a1-4cb2-8a5d-0e0327486e4e

Generated on: Tue Dec 30 09:34:59 PM PST 2025

--------------------------------------------------------------------------------

### User Request 1

hi, can you familiarize yourself with the project and then combine the
run_demo.sh and run-demo.sh scripts? If you need an example of how a run-demo.sh
script should be set up, please refer to the
/home/ritz/programming/ai-stuff/neocities-modernization/ implementation.

--------------------------------------------------------------------------------

### Assistant Response 1

Done! I've combined the two scripts into a unified `run-demo.sh`. Here's what
was done:

**Changes made:**
1. Created combined `run-demo.sh` following the neocities-modernization pattern
2. Removed old `run_demo.sh` (underscore version)
3. Updated documentation references in CLAUDE.md and issue files
4. Created issue 011 and moved it to completed/

**New script features:**
- Interactive menu with all 10 phases (0-9) and status indicators
- Phase 0: Launches issue-splitter TUI
- Phase 1: Runs the interactive Lua map parsing demo
- `[S]` Statistics & Architecture view
- `[T]` Run Phase 1 validation tests
- `-n` Non-interactive mode for CI/testing
- `-h` Help flag
- Proper DIR handling (directory argument optional)

**Usage:**
```bash
./run-demo.sh           # Interactive menu
./run-demo.sh 0         # Phase 0 demo
./run-demo.sh 1         # Phase 1 demo
./run-demo.sh -n 1      # Non-interactive mode
./run-demo.sh -h        # Show help
```

--------------------------------------------------------------------------------
