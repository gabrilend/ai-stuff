# Issue 029: Demo Runner Script

## Current Behavior

There is no unified way to run phase demonstrations. Each phase is expected to have a demo script in `issues/completed/demos/`, but there is no master script to coordinate running these demos or providing an interface for selecting which phase demo to run.

### Current Issues
- No central demo runner script exists in project root
- No way to list available phase demos
- No interactive selection of demos
- No validation that demos are runnable

## Intended Behavior

Create a demo runner script in the project root that:
1. **Demo Discovery**: Automatically discover available phase demos in `issues/completed/demos/`
2. **Interactive Selection**: Present menu for selecting which phase demo to run
3. **Headless Mode**: Support running specific demos via command-line flags
4. **Validation**: Check that demo scripts are executable and valid
5. **Statistics Display**: Show phase completion status alongside demo options

## Suggested Implementation Steps

### 1. Demo Discovery Function
```bash
DIR="${DIR:-/mnt/mtwo/programming/ai-stuff/delta-version}"

# -- {{{ discover_demos
function discover_demos() {
    local demos_dir="${DIR}/issues/completed/demos"
    local demos=()

    if [[ -d "$demos_dir" ]]; then
        while IFS= read -r -d '' demo; do
            demos+=("$demo")
        done < <(find "$demos_dir" -name "phase-*-demo.sh" -type f -print0 | sort -z)
    fi

    printf '%s\n' "${demos[@]}"
}
# }}}
```

### 2. Demo Validation
```bash
# -- {{{ validate_demo
function validate_demo() {
    local demo_script="$1"

    [[ -f "$demo_script" ]] || return 1
    [[ -x "$demo_script" ]] || return 1

    # Check for valid bash shebang
    head -1 "$demo_script" | grep -q '^#!/bin/bash' || return 1

    return 0
}
# }}}
```

### 3. Interactive Menu
```bash
# -- {{{ show_demo_menu
function show_demo_menu() {
    local demos=("$@")
    local count=${#demos[@]}

    echo "=== Delta-Version Phase Demos ==="
    echo "Available demos: $count"
    echo

    local i=1
    for demo in "${demos[@]}"; do
        local phase_num
        phase_num=$(basename "$demo" | grep -oP 'phase-\K\d+')
        local status="Ready"
        validate_demo "$demo" || status="Invalid"
        printf "%d. Phase %s Demo [%s]\n" "$i" "$phase_num" "$status"
        ((i++))
    done

    echo
    read -p "Select demo to run [1-$count]: " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
        run_demo "${demos[$((choice-1))]}"
    else
        echo "Invalid selection"
        return 1
    fi
}
# }}}
```

### 4. Demo Execution
```bash
# -- {{{ run_demo
function run_demo() {
    local demo_script="$1"

    echo "Running: $(basename "$demo_script")"
    echo "========================================"

    if validate_demo "$demo_script"; then
        bash "$demo_script"
        local exit_code=$?
        echo "========================================"
        echo "Demo completed with exit code: $exit_code"
    else
        echo "ERROR: Demo script is not valid or executable"
        return 1
    fi
}
# }}}
```

### 5. Headless Mode Support
```bash
# -- {{{ main
function main() {
    local phase_num=""
    local list_only=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--phase)
                phase_num="$2"
                shift 2
                ;;
            -l|--list)
                list_only=true
                shift
                ;;
            -I|--interactive)
                run_interactive_mode
                exit 0
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done

    local demos
    mapfile -t demos < <(discover_demos)

    if [[ "$list_only" == "true" ]]; then
        list_demos "${demos[@]}"
    elif [[ -n "$phase_num" ]]; then
        run_phase_demo "$phase_num" "${demos[@]}"
    else
        run_interactive_mode
    fi
}
# }}}
```

### 6. Help Message
```bash
# -- {{{ show_help
function show_help() {
    echo "Usage: run-demo.sh [OPTIONS]"
    echo
    echo "Options:"
    echo "  -p, --phase NUM    Run demo for specific phase number"
    echo "  -l, --list         List available demos without running"
    echo "  -I, --interactive  Run in interactive mode (default)"
    echo "  --help             Show this help message"
    echo
    echo "Examples:"
    echo "  ./run-demo.sh              # Interactive mode"
    echo "  ./run-demo.sh -p 1         # Run phase 1 demo"
    echo "  ./run-demo.sh --list       # List available demos"
}
# }}}
```

## Implementation Details

### Script Location
The demo runner should be placed at:
```
delta-version/run-demo.sh
```

### Demo Script Naming Convention
Phase demos should be named:
```
issues/completed/demos/phase-{N}-demo.sh
```

Where `{N}` is the phase number (1, 2, 3, etc.).

### Expected Demo Script Structure
Each phase demo should:
```bash
#!/bin/bash
# Phase N Demo: {Description}
# Demonstrates functionality developed in Phase N

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff/delta-version}"

echo "=== Phase N: {Phase Title} ==="
echo

# Display statistics
echo "Statistics:"
echo "  - Metric 1: value"
echo "  - Metric 2: value"

# Demonstrate functionality
echo
echo "Demonstrating {feature}..."
# ... actual demonstration code ...

echo
echo "Phase N demo complete."
```

## Related Documents
- `028-foundation-demo-script.md` - Related demo functionality
- `docs/issue-template.md` - Standard issue format
- Phase progress files - Track demo readiness

## Tools Required
- Bash scripting
- File discovery (find command)
- Interactive menu handling
- Exit code management

## Metadata
- **Priority**: Medium
- **Complexity**: Medium
- **Dependencies**: None (infrastructure utility)
- **Impact**: Enables standardized demo execution across all phases

## Success Criteria
- Demo runner script created at `run-demo.sh` ✅
- Discovers all phase demos automatically ✅
- Interactive mode presents menu with available demos ✅
- Headless mode supports `-p` flag for specific phases ✅
- Validates demo scripts before execution ✅
- Help message documents all options ✅
- Works from any directory via DIR variable ✅

## Implementation Notes

**Completed: 2024-12-15**

### Files Created
- `run-demo.sh` - Main demo runner script (224 lines)
- `issues/completed/demos/phase-1-demo.sh` - Phase 1 demonstration

### Implementation Details
- Used vimfold organization for all functions
- Supports both interactive (`-I`) and headless (`-p N`, `--list`) modes
- Validates demo scripts by checking for bash shebang
- Gracefully handles missing demos directory
- Phase 1 demo demonstrates project listing utility and repository structure

### Testing
- `./run-demo.sh --list` - Lists 1 available demo
- `./run-demo.sh -p 1` - Runs Phase 1 demo successfully
- Exit codes properly propagated from demo scripts
