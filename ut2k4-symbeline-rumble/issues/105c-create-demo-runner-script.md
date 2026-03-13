# Issue 105c: Create Demo Runner Script

## Status
- Phase: 1
- Priority: Medium
- Status: Open
- Dependencies: 105a-create-core-build-scripts
- Parent Issue: 105-create-build-and-test-scripts

## Current Behavior
No way to easily run phase demonstration scripts.

## Intended Behavior
A script that lists available phase demos and runs the selected one, making it easy to showcase completed work.

## Suggested Implementation Steps

### 1. Create run-phase-demo.sh Script

```bash
#!/bin/bash
# Run phase demonstration

# Load configuration
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/../config.sh"

# Accept DIR override from command line
if [ -n "$1" ]; then
    PROJECT_DIR="$1"
    source "$PROJECT_DIR/config.sh"
fi

echo "=== SymbelineRumble Phase Demos ==="
echo "Project dir: $PROJECT_DIR"
echo ""

DEMOS_DIR="$PROJECT_DIR/issues/completed/demos"

# Check if demos directory exists
if [ ! -d "$DEMOS_DIR" ]; then
    echo "No demos directory found yet."
    echo "Complete a phase to create demos!"
    exit 1
fi

# List available phases
echo "Available phases:"
FOUND_DEMOS=false

# Find all phase-* directories
for demo_dir in "$DEMOS_DIR"/phase-*; do
    if [ -d "$demo_dir" ]; then
        FOUND_DEMOS=true
        phase_num=$(basename "$demo_dir" | sed 's/phase-//')

        # Check if run.sh exists
        if [ -f "$demo_dir/run.sh" ]; then
            # Try to get description from README if it exists
            if [ -f "$demo_dir/README.md" ]; then
                desc=$(head -n 1 "$demo_dir/README.md" | sed 's/^# *//')
                echo "  $phase_num) $desc"
            else
                echo "  $phase_num) Phase $phase_num demo"
            fi
        else
            echo "  $phase_num) Phase $phase_num demo (WARNING: run.sh missing)"
        fi
    fi
done

if [ "$FOUND_DEMOS" = false ]; then
    echo "  (none found)"
    echo ""
    echo "Complete a phase to create demos!"
    exit 1
fi

echo ""

# Prompt for selection
read -p "Select phase number (or 'q' to quit): " phase

if [ "$phase" = "q" ] || [ "$phase" = "Q" ]; then
    echo "Cancelled."
    exit 0
fi

# Validate input
if ! [[ "$phase" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Invalid phase number: $phase"
    exit 1
fi

demo_script="$DEMOS_DIR/phase-$phase/run.sh"

if [ -f "$demo_script" ]; then
    echo ""
    echo "======================================"
    echo "   Running Phase $phase Demo"
    echo "======================================"
    echo ""

    # Make sure it's executable
    chmod +x "$demo_script"

    # Run the demo
    bash "$demo_script"

    DEMO_RESULT=$?

    echo ""
    if [ $DEMO_RESULT -eq 0 ]; then
        echo "Demo completed successfully"
    else
        echo "Demo exited with errors (code: $DEMO_RESULT)"
        exit $DEMO_RESULT
    fi
else
    echo "ERROR: Phase $phase demo not found at: $demo_script"
    exit 1
fi
```

### 2. Create Quick Demo Launcher

Create convenience script in project root: `demo`
```bash
#!/bin/bash
# Quick demo launcher

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -n "$1" ]; then
    # Direct phase number provided
    phase="$1"
    demo_script="$DIR/issues/completed/demos/phase-$phase/run.sh"

    if [ -f "$demo_script" ]; then
        bash "$demo_script"
    else
        echo "ERROR: Phase $phase demo not found"
        echo "Try running without arguments to see available demos"
        exit 1
    fi
else
    # Interactive mode
    "$DIR/scripts/run-phase-demo.sh"
fi
```

### 3. Document Demo System

Add to `scripts/README.md`:
```markdown
## Demo Runner

### run-phase-demo.sh
Interactive menu to select and run phase demonstrations.

Usage:
```bash
./scripts/run-phase-demo.sh
```

This will:
1. List all available phase demos
2. Prompt for selection
3. Run the selected demo
4. Report results

### Quick Demo Access
For convenience, use the `demo` script in the project root:

```bash
# Interactive mode
./demo

# Direct phase selection
./demo 1    # Run Phase 1 demo
./demo 2    # Run Phase 2 demo
```

## Creating Phase Demos

When completing a phase, create a demo in:
```
issues/completed/demos/phase-N/
├── run.sh           # Demo script (required)
├── README.md        # Demo documentation (recommended)
└── expected-output.txt  # Expected output (optional)
```

The `run.sh` script should:
- Be executable (`chmod +x`)
- Use bash shebang: `#!/bin/bash`
- Source project config.sh if needed
- Return 0 on success, non-zero on failure
- Be self-contained and reproducible
```

### 4. Test Demo Runner
- Create a test demo directory structure
- Test interactive selection
- Test with missing demos directory
- Test with missing run.sh
- Test error handling
- Verify output is clear

### 5. Make Scripts Executable
```bash
chmod +x scripts/run-phase-demo.sh
chmod +x demo
```

## Related Documents
- docs/005-roadmap.md (all phases have demos)
- issues/106-phase-1-demo.md

## Tools Required
- Bash shell
- sed (for text processing)

## Technical Notes

### Demo Directory Structure
```
issues/completed/demos/
├── phase-1/
│   ├── run.sh
│   ├── README.md
│   └── expected-output.txt
├── phase-2/
│   ├── run.sh
│   └── README.md
└── phase-N/
    └── run.sh
```

### Demo Script Requirements
Each `run.sh` should:
- Start with `#!/bin/bash`
- Be self-documenting (echo what it's doing)
- Use absolute paths or source config.sh
- Return proper exit codes
- Clean up after itself if needed

### Why Demos Matter
Per project guidelines: "Phase demos are not just a development artifact - they are part of the deliverable product."

This means demos should be:
- High quality
- Continuously updated
- Feature-complete for their phase
- Runnable at any time

## Acceptance Criteria
- [ ] run-phase-demo.sh created and executable
- [ ] Script lists available demos correctly
- [ ] Script runs selected demo
- [ ] Script handles missing demos gracefully
- [ ] Quick demo launcher created in project root
- [ ] Documentation added to README
- [ ] Error messages are clear
- [ ] Scripts tested and working

## Notes
This script will be used after each phase completion to showcase progress. It should be polished and user-friendly since it's part of the deliverable product.

The quick launcher (`demo` script in root) makes it very easy to run demos without navigating to the scripts directory.
