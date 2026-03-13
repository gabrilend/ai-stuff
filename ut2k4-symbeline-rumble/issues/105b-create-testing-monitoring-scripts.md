# Issue 105b: Create Testing and Monitoring Scripts

## Status
- Phase: 1
- Priority: High
- Status: Open
- Dependencies: 105a-create-core-build-scripts
- Parent Issue: 105-create-build-and-test-scripts

## Current Behavior
No automated testing or log monitoring scripts exist. Must manually launch game and check logs.

## Intended Behavior
Scripts that simplify testing and debugging:
- Launch UT2004 with mutator for testing
- Monitor UT2004 log in real-time
- Filter log for relevant messages

## Suggested Implementation Steps

### 1. Create test.sh Script

```bash
#!/bin/bash
# Launch UT2004 for testing

# Load configuration
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../config.sh"

# Accept DIR override from command line
if [ -n "$1" ]; then
    PROJECT_DIR="$1"
    source "$PROJECT_DIR/config.sh"
fi

# Parse command-line options
MAP="${2:-DM-Rankin}"  # Default map
ENABLE_MUTATOR="${3:-yes}"  # Default: enable mutator

echo "=== SymbelineRumble Test Launcher ==="
echo "Project dir: $PROJECT_DIR"
echo "UT2004 dir: $UT2004_DIR"
echo "Map: $MAP"
echo ""

# Verify UT2004 installation
if [ ! -d "$UT2004_DIR/System" ]; then
    echo "ERROR: UT2004 installation not found at: $UT2004_DIR"
    exit 1
fi

cd "$UT2004_DIR/System"

# Find UT2004 executable
UT2004_BIN=""
if [ -x "./ut2004-bin" ]; then
    UT2004_BIN="./ut2004-bin"
elif [ -x "./ut2004" ]; then
    UT2004_BIN="./ut2004"
elif [ -x "./ut2004-bin-linux-amd64" ]; then
    UT2004_BIN="./ut2004-bin-linux-amd64"
else
    echo "ERROR: UT2004 executable not found in System/"
    exit 1
fi

echo "Launching UT2004..."
echo "Binary: $UT2004_BIN"
echo ""

# Build command line
if [ "$ENABLE_MUTATOR" = "yes" ]; then
    echo "Mutator: $PACKAGE_NAME.$MUTATOR_CLASS"
    $UT2004_BIN "$MAP?Mutator=$PACKAGE_NAME.$MUTATOR_CLASS" -log
else
    echo "Mutator: DISABLED (testing vanilla)"
    $UT2004_BIN "$MAP" -log
fi
```

### 2. Create watch-log.sh Script

```bash
#!/bin/bash
# Watch UT2004 log for SymbelineRumble messages

# Load configuration
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../config.sh"

# Accept options
FOLLOW="${1:-yes}"  # Default: follow mode
FILTER="${2:-$PACKAGE_NAME}"  # Default: filter for our package

LOG_FILE="$UT2004_DIR/System/UT2004.log"

echo "=== Watching SymbelineRumble log entries ==="
echo "Log file: $LOG_FILE"
echo "Filter: $FILTER"
echo ""

# Check if log file exists
if [ ! -f "$LOG_FILE" ]; then
    echo "WARNING: Log file not found (game not run yet?)"
    echo "Waiting for log file to be created..."
fi

# Follow or dump mode
if [ "$FOLLOW" = "yes" ]; then
    echo "Press Ctrl+C to stop watching"
    echo "---"
    tail -f "$LOG_FILE" 2>/dev/null | grep --line-buffered "$FILTER"
else
    # Just show existing entries
    if [ -f "$LOG_FILE" ]; then
        grep "$FILTER" "$LOG_FILE"
    fi
fi
```

### 3. Create check-log.sh Script

```bash
#!/bin/bash
# Check log for errors and important messages

# Load configuration
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../config.sh"

LOG_FILE="$UT2004_DIR/System/UT2004.log"

echo "=== SymbelineRumble Log Analysis ==="
echo "Log file: $LOG_FILE"
echo ""

if [ ! -f "$LOG_FILE" ]; then
    echo "ERROR: Log file not found at: $LOG_FILE"
    exit 1
fi

# Check for our package messages
echo "=== Package Messages ==="
grep "$PACKAGE_NAME" "$LOG_FILE" | tail -n 20
echo ""

# Check for errors
echo "=== Errors ==="
grep -i "error" "$LOG_FILE" | grep -i "$PACKAGE_NAME" | tail -n 10
if [ $? -ne 0 ]; then
    echo "No errors found"
fi
echo ""

# Check for warnings
echo "=== Warnings ==="
grep -i "warning" "$LOG_FILE" | grep -i "$PACKAGE_NAME" | tail -n 10
if [ $? -ne 0 ]; then
    echo "No warnings found"
fi
echo ""

# Check if mutator loaded
echo "=== Load Status ==="
if grep -q "$PACKAGE_NAME.*loaded" "$LOG_FILE"; then
    echo "✓ Mutator loaded successfully"
else
    echo "✗ No load confirmation found"
fi
```

### 4. Document Script Usage

Create `scripts/README.md` section for testing scripts:
```markdown
## Testing Scripts

### test.sh
Launch UT2004 with the mutator for testing.

Usage:
```bash
./scripts/test.sh [PROJECT_DIR] [MAP] [yes|no]
```

Examples:
```bash
# Launch with default map (DM-Rankin) and mutator enabled
./scripts/test.sh

# Launch with specific map
./scripts/test.sh "" "ONS-Torlan"

# Launch without mutator (vanilla test)
./scripts/test.sh "" "DM-Rankin" "no"
```

### watch-log.sh
Monitor UT2004 log in real-time for SymbelineRumble messages.

Usage:
```bash
./scripts/watch-log.sh [yes|no] [FILTER]
```

Examples:
```bash
# Follow mode (live updates)
./scripts/watch-log.sh

# Dump mode (show existing entries)
./scripts/watch-log.sh no

# Custom filter
./scripts/watch-log.sh yes "Error"
```

### check-log.sh
Analyze log for errors, warnings, and status.

Usage:
```bash
./scripts/check-log.sh
```
```

### 5. Test All Scripts
- Test test.sh with different maps
- Test test.sh with mutator enabled/disabled
- Test watch-log.sh in follow mode
- Test watch-log.sh in dump mode
- Test check-log.sh after running game
- Verify all error messages are clear

## Related Documents
- docs/005-roadmap.md (Phase 1)
- issues/105a-create-core-build-scripts.md

## Tools Required
- Bash shell
- grep
- tail
- UT2004 installation

## Technical Notes

### UT2004 Executable Names
Different distributions use different names:
- `ut2004-bin` (most common)
- `ut2004` (some versions)
- `ut2004-bin-linux-amd64` (64-bit)

Script tries all known names.

### Log File Location
Standard location: `UT2004_DIR/System/UT2004.log`

Log is created when game runs with `-log` flag.

### Mutator Command Line Format
```
MapName?Mutator=PackageName.MutatorClass
```

Multiple mutators can be chained with commas.

## Acceptance Criteria
- [ ] test.sh created and executable
- [ ] test.sh can launch game with mutator
- [ ] test.sh can launch game without mutator
- [ ] test.sh handles missing UT2004 gracefully
- [ ] watch-log.sh created and executable
- [ ] watch-log.sh can follow log in real-time
- [ ] watch-log.sh can dump existing log
- [ ] check-log.sh created and executable
- [ ] check-log.sh provides useful analysis
- [ ] All scripts documented in README
- [ ] All scripts tested and working

## Notes
These scripts are essential for the development workflow. They will be used constantly during Phase 2+ development.

The ability to test with and without the mutator is crucial for debugging whether issues are caused by our code or the base game.
