# Issue 106: Create Phase 1 Demo

## Status
- Phase: 1
- Priority: Medium
- Status: Open
- Dependencies: 103-implement-minimal-mutator, 104-verify-linux-compatibility, 105-create-build-and-test-scripts

## Current Behavior
No demo exists to showcase Phase 1 completion.

## Intended Behavior
A simple demo that proves Phase 1 objectives have been met:
- Mod compiles successfully
- Mod loads in-game
- Build system works
- Basic infrastructure is functional

## Suggested Implementation Steps

### 1. Create Demo Directory Structure
```
issues/completed/demos/phase-1/
├── run.sh           # Demo launcher script
├── README.md        # Demo description
└── expected-output.txt  # What user should see
```

### 2. Create Demo Script

```bash
#!/bin/bash
# Phase 1 Demo: Foundation and Basic Infrastructure

DIR="/mnt/mtwo/programming/ai-stuff/ut2k4-symbeline-rumble"
UT2004_DIR="${UT2004_DIR:-$HOME/.ut2004}"

echo "======================================"
echo "   Phase 1 Demo: Infrastructure"
echo "======================================"
echo ""

# Show project structure
echo "=== Project Structure ==="
tree -L 2 "$DIR" -I 'tmp'
echo ""

# Show that build system works
echo "=== Testing Build System ==="
"$DIR/scripts/compile.sh"
echo ""

# Show compiled package stats
echo "=== Compiled Package ==="
if [ -f "$UT2004_DIR/System/SymbelineRumble.u" ]; then
    ls -lh "$UT2004_DIR/System/SymbelineRumble.u"
    echo "✓ Package compiled successfully"
else
    echo "✗ Package not found!"
    exit 1
fi
echo ""

# Show version info
echo "=== Version Information ==="
grep -i "version" "$DIR/src/"*.uc || echo "Version: 0.1.0-phase1"
echo ""

# Launch game for manual testing
echo "=== Launching UT2004 for Manual Verification ==="
echo ""
echo "Manual Test Steps:"
echo "1. Navigate to Mutators menu"
echo "2. Look for 'Symbeline Rumble' in the list"
echo "3. Enable the mutator"
echo "4. Start a match on DM-Rankin"
echo "5. Check console log for load message"
echo ""
read -p "Press Enter to launch UT2004..."

"$DIR/scripts/test.sh"

# After game closes, check log
echo ""
echo "=== Checking Log ==="
echo "Last 20 SymbelineRumble log entries:"
grep "SymbelineRumble" "$UT2004_DIR/System/UT2004.log" | tail -n 20
echo ""

echo "======================================"
echo "   Phase 1 Demo Complete"
echo "======================================"
echo ""
echo "Success Criteria:"
echo "✓ Project structure created"
echo "✓ Build system functional"
echo "✓ Mutator compiles"
echo "✓ Mutator appears in game"
echo "✓ Mutator loads without errors"
echo "✓ Game runs normally with mutator"
echo ""
```

### 3. Create Demo Documentation

Create `issues/completed/demos/phase-1/README.md`:
```markdown
# Phase 1 Demo: Foundation and Basic Infrastructure

## What This Demo Shows

This demo proves that the basic development infrastructure is in place:

1. **Project Structure** - All necessary directories created
2. **Build System** - Automated compilation works
3. **Mutator Foundation** - Minimal mutator compiles and loads
4. **Linux Compatibility** - Works on base UT2004 Linux version
5. **Development Scripts** - Automation tools functional

## How to Run

```bash
cd /mnt/mtwo/programming/ai-stuff/ut2k4-symbeline-rumble
./issues/completed/demos/phase-1/run.sh
```

## What You Should See

1. Project structure displayed
2. Successful compilation
3. Package file created
4. UT2004 launches
5. Mutator appears in menu
6. Game runs without errors
7. Log shows load confirmation

## Success Criteria

All of the following must be true:
- [ ] Scripts run without errors
- [ ] Package compiles successfully
- [ ] Mutator appears in game's mutator list
- [ ] Game starts with mutator enabled
- [ ] No errors in UT2004.log
- [ ] Game runs normally

## Known Limitations

At this phase, the mutator does nothing except load. It:
- Does NOT change gameplay
- Does NOT add any features
- Does NOT modify camera or controls
- ONLY proves the infrastructure works

Features begin in Phase 2.

## Troubleshooting

### Mutator doesn't compile
- Check UT2004_DIR environment variable
- Verify UT2004 installation path
- Check ucc compiler is accessible

### Mutator doesn't appear in menu
- Verify SymbelineRumble.u exists in System/
- Check for SymbelineRumble.int file
- Review UT2004.log for load errors

### Game crashes on load
- Check UT2004.log for error messages
- Verify code has no syntax errors
- Test on clean UT2004 installation
```

### 4. Create Expected Output Documentation

Create `issues/completed/demos/phase-1/expected-output.txt`:
```
====================================
   Phase 1 Demo: Infrastructure
====================================

=== Project Structure ===
ut2k4-symbeline-rumble/
├── docs/
│   ├── 000-table-of-contents.md
│   ├── 001-architecture-overview.md
│   ├── 002-rendering-system.md
│   ├── 003-game-mechanics.md
│   ├── 004-ai-behavior.md
│   └── 005-roadmap.md
├── issues/
│   ├── 101-setup-dev-environment.md
│   ├── 102-create-mod-package-structure.md
│   ├── 103-implement-minimal-mutator.md
│   ├── 104-verify-linux-compatibility.md
│   ├── 105-create-build-and-test-scripts.md
│   └── 106-phase-1-demo.md
├── notes/
│   └── vision
├── scripts/
│   ├── clean.sh
│   ├── compile.sh
│   ├── test.sh
│   └── watch-log.sh
└── src/
    └── SR_SymbelineRumbleMutator.uc

=== Testing Build System ===
Syncing source files...
Compiling...
... [compilation output] ...
=== Build successful ===

=== Compiled Package ===
-rw-r--r-- 1 ritz ritz 2.1K Dec 31 12:00 SymbelineRumble.u
✓ Package compiled successfully

=== Version Information ===
Version: v0.1.0-phase1

=== Launching UT2004 ===
[UT2004 launches, user tests manually]

=== Checking Log ===
SymbelineRumble: Mutator loaded successfully
SymbelineRumble: Version v0.1.0-phase1
SymbelineRumble: Initialized on map: DM-Rankin

====================================
   Phase 1 Demo Complete
====================================
```

### 5. Make Demo Executable
```bash
chmod +x issues/completed/demos/phase-1/run.sh
```

### 6. Test the Demo
- Run the demo script
- Verify all output matches expected
- Ensure game launches correctly
- Check that all success criteria are met

### 7. Move Completed Issues
Once Phase 1 is complete:
- Move all 101-106 issues to issues/completed/
- Update phase-1-progress.md to show 100% complete
- Git commit the phase completion

## Related Documents
- docs/005-roadmap.md (Phase 1)
- All Phase 1 issue files (101-105)

## Tools Required
- tree command (for directory visualization)
- All scripts from issue 105
- Functional UT2004 installation

## Acceptance Criteria
- [ ] Demo directory structure created
- [ ] run.sh script created and executable
- [ ] README.md explains demo
- [ ] expected-output.txt shows sample output
- [ ] Demo runs successfully
- [ ] All Phase 1 objectives demonstrated
- [ ] Demo is reproducible
- [ ] Documentation is clear

## Notes
This demo serves multiple purposes:
1. Proves Phase 1 is complete
2. Provides regression test for future changes
3. Shows new developers how to set up environment
4. Demonstrates the build and test workflow

Keep it simple and focused on infrastructure, not features.

According to project guidelines, phase demos should be "part of the deliverable product" and maintained with "feature parity" as the main project evolves. This means as we add features, we should ensure Phase 1 demo still runs correctly as a baseline test.
