# Issue 105: Create Build and Testing Scripts

## Status
- Phase: 1
- Priority: High
- Status: Open
- Dependencies: 102-create-mod-package-structure

## Current Behavior
No automated build or testing scripts exist. Manual compilation and testing required.

## Intended Behavior
Automated scripts that streamline development workflow:
- Quick compilation
- Easy testing
- Clean build management
- Error reporting

## Suggested Implementation Steps

### 1. Create compile.sh Script

```bash
#!/bin/bash
# Compile the SymbelineRumble mod

DIR="/mnt/mtwo/programming/ai-stuff/ut2k4-symbeline-rumble"
UT2004_DIR="${UT2004_DIR:-$HOME/.ut2004}"

# Accept DIR override from command line
if [ -n "$1" ]; then
    DIR="$1"
fi

echo "=== SymbelineRumble Compiler ==="
echo "Project dir: $DIR"
echo "UT2004 dir: $UT2004_DIR"

# Sync source files to UT2004 installation
echo "Syncing source files..."
rsync -av "$DIR/src/" "$UT2004_DIR/SymbelineRumble/Classes/"

# Run compiler
echo "Compiling..."
cd "$UT2004_DIR/System"
./ucc make

if [ $? -eq 0 ]; then
    echo "=== Build successful ==="
    ls -lh SymbelineRumble.u
else
    echo "=== Build failed ==="
    exit 1
fi
```

### 2. Create test.sh Script

```bash
#!/bin/bash
# Launch UT2004 for testing

DIR="/mnt/mtwo/programming/ai-stuff/ut2k4-symbeline-rumble"
UT2004_DIR="${UT2004_DIR:-$HOME/.ut2004}"

if [ -n "$1" ]; then
    DIR="$1"
fi

echo "=== SymbelineRumble Test Launcher ==="
echo "Launching UT2004..."

cd "$UT2004_DIR/System"

# Launch with test map and mutator
./ut2004-bin \
    DM-Rankin?Mutator=SymbelineRumble.SR_SymbelineRumbleMutator \
    -log

# Alternative: Just launch to menu
# ./ut2004-bin -log
```

### 3. Create clean.sh Script

```bash
#!/bin/bash
# Clean build artifacts

DIR="/mnt/mtwo/programming/ai-stuff/ut2k4-symbeline-rumble"
UT2004_DIR="${UT2004_DIR:-$HOME/.ut2004}"

if [ -n "$1" ]; then
    DIR="$1"
fi

echo "=== SymbelineRumble Clean ==="

# Remove compiled package
rm -fv "$UT2004_DIR/System/SymbelineRumble.u"

# Remove temporary files
rm -rf "$DIR/tmp/"*

echo "=== Clean complete ==="
```

### 4. Create watch-log.sh Script

```bash
#!/bin/bash
# Watch UT2004 log for SymbelineRumble messages

UT2004_DIR="${UT2004_DIR:-$HOME/.ut2004}"

LOG_FILE="$UT2004_DIR/System/UT2004.log"

echo "=== Watching SymbelineRumble log entries ==="
echo "Log file: $LOG_FILE"
echo ""

# Follow log, grep for our messages
tail -f "$LOG_FILE" | grep --line-buffered "SymbelineRumble"
```

### 5. Create full-rebuild.sh Script

```bash
#!/bin/bash
# Clean and rebuild

DIR="/mnt/mtwo/programming/ai-stuff/ut2k4-symbeline-rumble"

if [ -n "$1" ]; then
    DIR="$1"
fi

echo "=== Full Rebuild ==="

"$DIR/scripts/clean.sh" "$DIR"
"$DIR/scripts/compile.sh" "$DIR"
```

### 6. Create run-phase-demo.sh Script

```bash
#!/bin/bash
# Run phase demonstration

DIR="/mnt/mtwo/programming/ai-stuff/ut2k4-symbeline-rumble"

if [ -n "$1" ]; then
    DIR="$1"
fi

echo "=== SymbelineRumble Phase Demos ==="
echo ""
echo "Available phases:"

# List completed phases
for demo in "$DIR/issues/completed/demos/"phase-*; do
    if [ -d "$demo" ]; then
        phase_num=$(basename "$demo" | grep -oP 'phase-\K\d+')
        echo "  $phase_num) Phase $phase_num demo"
    fi
done

echo ""
read -p "Select phase number: " phase

demo_script="$DIR/issues/completed/demos/phase-$phase/run.sh"

if [ -f "$demo_script" ]; then
    bash "$demo_script"
else
    echo "Error: Phase $phase demo not found"
    exit 1
fi
```

### 7. Set Up Scripts Directory
- Create scripts/ directory in project root
- Place all scripts there
- Make executable: `chmod +x scripts/*.sh`
- Test each script
- Document usage in README or docs

### 8. Create Master Build Script

Create `build` wrapper in project root:
```bash
#!/bin/bash
# Master build script - delegates to specific scripts

DIR="/mnt/mtwo/programming/ai-stuff/ut2k4-symbeline-rumble"

case "$1" in
    compile|build)
        "$DIR/scripts/compile.sh"
        ;;
    test|run)
        "$DIR/scripts/test.sh"
        ;;
    clean)
        "$DIR/scripts/clean.sh"
        ;;
    rebuild)
        "$DIR/scripts/full-rebuild.sh"
        ;;
    watch|log)
        "$DIR/scripts/watch-log.sh"
        ;;
    demo)
        "$DIR/scripts/run-phase-demo.sh"
        ;;
    *)
        echo "Usage: $0 {compile|test|clean|rebuild|watch|demo}"
        exit 1
        ;;
esac
```

### 9. Document Scripts
Create `scripts/README.md`:
- List all scripts
- Explain what each does
- Provide usage examples
- Document environment variables
- List troubleshooting tips

## Related Documents
- docs/005-roadmap.md (Phase 1)
- issues/101-setup-dev-environment.md

## Tools Required
- Bash shell
- rsync
- grep
- tail

## Technical Notes

### Environment Variables
- UT2004_DIR: Override UT2004 installation path
- Default: $HOME/.ut2004

### Script Design Principles
- All scripts accept optional DIR argument
- Hard-coded default DIR at top
- Relative paths resolved against DIR
- Error checking and reporting
- User feedback (echo statements)

## Acceptance Criteria
- [ ] All scripts created and documented
- [ ] Scripts are executable
- [ ] compile.sh successfully builds mod
- [ ] clean.sh removes build artifacts
- [ ] test.sh launches game with mod
- [ ] watch-log.sh shows real-time log output
- [ ] full-rebuild.sh does clean + compile
- [ ] Master build script works for all operations
- [ ] Scripts work from any directory
- [ ] Documentation is clear and complete

## Notes
These scripts will be used throughout development. Keep them maintained and updated as the build process evolves.

Future enhancements might include:
- Automatic version bumping
- Git integration (commit on successful build)
- Parallel compilation (if multi-package)
- Deployment scripts
- Packaging for distribution
