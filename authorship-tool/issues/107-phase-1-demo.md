# Issue 107: Phase 1 Demo Program

**Phase**: 1 - Foundation & Core Infrastructure
**Status**: Open
**Priority**: High (blocking phase completion)
**Created**: 2026-01-08

---

## Current Behavior

No demonstration program exists for Phase 1 functionality.

---

## Intended Behavior

Create a comprehensive demo program that:
- Demonstrates all Phase 1 deliverables working together
- Loads configuration from input/
- Initializes module loading system
- Loads and displays documents via TUI
- Shows logging system capturing events
- Demonstrates state persistence (restores UI state)
- Provides visual/statistical output
- Is runnable via simple bash script
- Can be invoked from root test runner script

---

## Suggested Implementation Steps

1. Ensure all Phase 1 issues (101-106) are completed
2. Create `issues/completed/demos/phase-1-demo.lua` main program
3. Create `issues/completed/demos/run-phase-1-demo.sh` runner script
4. Implement demo workflow:
   - Load configuration
   - Initialize module system
   - Load test module
   - Start TUI
   - Load documents from input/
   - Display document list
   - Allow document viewing
   - Show module registry status
   - Display log entries
   - Save state on exit
   - Restore state on next run
5. Create sample input documents for demo
6. Create sample configuration for demo
7. Add statistics display:
   - Number of modules loaded
   - Number of documents found
   - Configuration values in use
   - Log entries written
   - State save/restore status
8. Test demo from clean state
9. Update root test runner to include Phase 1 option
10. Document demo in issues/completed/demos/phase-1-demo.md

---

## Related Documents

- docs/roadmap.md (Phase 1 demo requirements)
- User's global instructions (phase demo requirements)
- All Phase 1 issues (101-106)

---

## Implementation Notes

**Demo Script Location**:
```
issues/completed/demos/
├── phase-1-demo.lua           # Main demo program
├── phase-1-demo.md            # Demo documentation
└── run-phase-1-demo.sh        # Runner script
```

**Root Test Runner**:
```bash
# In project root: run-demo.sh
#!/bin/bash
# Runs phase demonstration programs

echo "Authorship Tool - Phase Demos"
echo ""
echo "Select phase to demo:"
echo "1) Phase 1 - Foundation & Core Infrastructure"
echo ""
read -p "Enter phase number: " phase

case $phase in
    1)
        ./issues/completed/demos/run-phase-1-demo.sh
        ;;
    *)
        echo "Invalid phase number or demo not yet available"
        ;;
esac
```

**Demo Output Should Show**:
- Configuration loaded successfully
- Modules discovered: [list of module names]
- Modules initialized: [count]
- Documents found: [count] in [path]
- Document list with preview
- TUI navigation working (instructions displayed)
- Log file location and recent entries
- State saved on exit
- State restored on next run (show previous scroll position)

**Interactive Elements**:
- Display document list
- Navigate with j/k
- Select document to view
- View full document with scrolling
- Press 'l' to view recent log entries
- Press 'm' to view module status
- Press 'q' to quit (saves state)

---

## Testing Criteria

- [ ] Demo runs successfully from bash script
- [ ] All Phase 1 features demonstrated
- [ ] Configuration loading visible
- [ ] Module system working
- [ ] Documents loaded and displayed
- [ ] TUI navigation functional
- [ ] Logging captured and viewable
- [ ] State persists across runs
- [ ] Statistics displayed clearly
- [ ] No errors or warnings during demo
- [ ] Root test runner includes Phase 1
- [ ] Demo documented clearly

---

## Dependencies

- 101 (module loading framework)
- 102 (TUI framework)
- 103 (document reader)
- 104 (configuration system)
- 105 (logging)
- 106 (persistence)

---

## Blocks

- Phase 1 completion
- Beginning of Phase 2
