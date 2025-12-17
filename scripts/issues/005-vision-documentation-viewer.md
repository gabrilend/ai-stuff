# Issue 005: Vision Documentation Viewer

## Current Behavior

Vision documents are scattered across multiple project directories under `/home/ritz/programming/ai-stuff/`:
- Some projects store them as `notes/vision` or `notes/vision.md`
- Some store them at the project root as `vision` or `vision.md`
- Some have multiple vision files (e.g., `risc-v-university` has `vision-personal-playground` and `vision-educational-platform`)

### Current Issues
- No centralized location to browse all vision documents
- Difficult to quickly reference project purposes across the collection
- No tooling to discover which projects have vision documentation
- Manual navigation required to find vision files

### Known Vision File Locations (as of 2024-12-17)
```
/home/ritz/programming/ai-stuff/games/city-of-chat/notes/vision
/home/ritz/programming/ai-stuff/games/gameboy-color-rpg/vision
/home/ritz/programming/ai-stuff/games/gameboy-color-rpg/notes/vision
/home/ritz/programming/ai-stuff/world-edit-to-execute/notes/vision
/home/ritz/programming/ai-stuff/factory-war/notes/vision
/home/ritz/programming/ai-stuff/project-orchestration/vision
/home/ritz/programming/ai-stuff/console-demakes/notes/vision
/home/ritz/programming/ai-stuff/healer-td/notes/vision
/home/ritz/programming/ai-stuff/shanna-lib/vision
/home/ritz/programming/ai-stuff/picture-generator/vision
/home/ritz/programming/ai-stuff/neocities-modernization/notes/vision
/home/ritz/programming/ai-stuff/delta-version/notes/vision.md
/home/ritz/programming/ai-stuff/dark-volcano/notes/vision
/home/ritz/programming/ai-stuff/authorship-tool/vision
/home/ritz/programming/ai-stuff/ai-playground/notes/vision
/home/ritz/programming/ai-stuff/adroit/src/notes/vision
/home/ritz/programming/ai-stuff/continual-co-operation/notes/vision
/home/ritz/programming/ai-stuff/risc-v-university/notes/vision-personal-playground
/home/ritz/programming/ai-stuff/risc-v-university/notes/vision-educational-platform
```

## Intended Behavior

1. **Symlink Directory Structure**: Create `/home/ritz/programming/ai-stuff/scripts/visions/` containing symlinks organized by project name
   - Each symlink named after the project for easy identification
   - Projects with multiple vision files get multiple symlinks with descriptive suffixes
   - Example: `risc-v-university-personal.md` and `risc-v-university-educational.md`

2. **Discovery Script**: Create `sync-visions.sh` that:
   - Trawls through all project directories to find vision files
   - Uses common patterns: `notes/vision*`, `vision*`, `docs/vision*`
   - Creates/updates symlinks in the visions directory
   - Reports which projects have vision documents and which are missing

3. **Vision Viewer (Sub-Issue 005a)**: Create `vision-viewer` script that:
   - Lists all available vision documents
   - Allows selecting and viewing vision documents
   - Supports both interactive (TUI) and headless modes
   - **BLOCKED BY**: TUI interface implementation in `/home/ritz/programming/ai-stuff/scripts/libs/`
   - **RELATED**: Issue 004 (Fix TUI Menu Incremental Rendering)

## Suggested Implementation Steps

### 1. Create Visions Directory Structure
```bash
mkdir -p /home/ritz/programming/ai-stuff/scripts/visions
```

### 2. Create Sync Script
```bash
#!/usr/bin/env bash
# sync-visions.sh - Discover and symlink vision documents from all projects
#
# Trawls through project directories, finds vision files, and creates
# symlinks in the visions/ directory for centralized access.

# -- {{{ Configuration
DIR="${DIR:-/home/ritz/programming/ai-stuff}"
VISIONS_DIR="${DIR}/scripts/visions"
# }}}

# -- {{{ discover_vision_files
discover_vision_files() {
    local base_dir="$1"

    # Search patterns for vision files
    find "$base_dir" -maxdepth 4 \( \
        -path "*/notes/vision" -o \
        -path "*/notes/vision.md" -o \
        -path "*/notes/vision-*" -o \
        -name "vision" -o \
        -name "vision.md" \
    \) -type f 2>/dev/null | grep -v "\.git"
}
# }}}

# -- {{{ extract_project_name
extract_project_name() {
    local vision_path="$1"
    local base_dir="$2"

    # Extract project directory name from path
    local relative="${vision_path#$base_dir/}"
    echo "${relative%%/*}"
}
# }}}

# -- {{{ create_symlinks
create_symlinks() {
    local vision_file="$1"
    local project_name="$2"
    local suffix=""

    # Handle multiple vision files per project
    local basename=$(basename "$vision_file")
    if [[ "$basename" == vision-* ]]; then
        suffix="-${basename#vision-}"
        suffix="${suffix%.md}"
    fi

    local link_name="${project_name}${suffix}"
    ln -sf "$vision_file" "${VISIONS_DIR}/${link_name}"
}
# }}}

# -- {{{ main
main() {
    mkdir -p "$VISIONS_DIR"

    # Clear existing symlinks
    rm -f "${VISIONS_DIR}"/*

    local count=0
    while IFS= read -r vision_file; do
        local project_name=$(extract_project_name "$vision_file" "$DIR")
        create_symlinks "$vision_file" "$project_name"
        ((count++))
        echo "Linked: ${project_name} -> ${vision_file}"
    done < <(discover_vision_files "$DIR")

    echo ""
    echo "Created ${count} symlinks in ${VISIONS_DIR}"
}
# }}}

main "$@"
```

### 3. Add Headless Options
```bash
# Add to sync-visions.sh
# -- {{{ parse_args
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dir)
                DIR="$2"
                shift 2
                ;;
            -o|--output)
                VISIONS_DIR="$2"
                shift 2
                ;;
            -l|--list)
                LIST_ONLY=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -I|--interactive)
                INTERACTIVE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
        esac
    done
}
# }}}
```

### 4. Add Statistics Output
```bash
# -- {{{ report_statistics
report_statistics() {
    local linked_projects="$1"
    local all_projects="$2"

    echo "=== Vision Documentation Statistics ==="
    echo "Projects with vision docs: ${linked_projects}"
    echo "Total projects: ${all_projects}"
    echo ""
    echo "Projects missing vision documentation:"
    # Compare against list-projects.sh output
}
# }}}
```

## Implementation Details

### Symlink Naming Convention
| Source Pattern | Symlink Name Example |
|----------------|---------------------|
| `project/notes/vision` | `project` |
| `project/notes/vision.md` | `project` |
| `project/notes/vision-foo` | `project-foo` |
| `project/vision` | `project` |
| `games/project/notes/vision` | `games-project` |

### Directory Structure After Implementation
```
/home/ritz/programming/ai-stuff/scripts/
├── visions/
│   ├── city-of-chat -> ../../../games/city-of-chat/notes/vision
│   ├── delta-version -> ../../../delta-version/notes/vision.md
│   ├── factory-war -> ../../../factory-war/notes/vision
│   ├── risc-v-university-personal -> ../../../risc-v-university/notes/vision-personal-playground
│   ├── risc-v-university-educational -> ../../../risc-v-university/notes/vision-educational-platform
│   └── ... (other projects)
├── sync-visions.sh
└── vision-viewer (sub-issue 005a)
```

### Integration with Existing Tools
- Uses `list-projects.sh` from delta-version for project discovery comparison
- Compatible with TUI library in `/home/ritz/programming/ai-stuff/scripts/libs/` (for 005a)

## Sub-Issues

### Issue 005a: Vision Viewer TUI
**Status:** Blocked
**Blocked By:** Issue 004 (Fix TUI Menu Incremental Rendering)
**Location:** `/home/ritz/programming/ai-stuff/world-edit-to-execute/issues/`

The vision-viewer script will provide an interactive interface for browsing and viewing vision documents. Implementation deferred until TUI library rendering issues are resolved.

Planned features:
- Menu listing all available vision documents
- Preview pane or full-screen view of selected document
- Search/filter functionality
- Both `-I` interactive and headless `--view <project>` modes

## Related Documents
- `004-fix-tui-menu-incremental-rendering.md` - TUI rendering bug blocking 005a
- `/home/ritz/programming/ai-stuff/world-edit-to-execute/issues/004*.md` - Original TUI implementation
- `/mnt/mtwo/programming/ai-stuff/delta-version/scripts/list-projects.sh` - Project discovery utility

## Tools Required
- Bash 4.3+ (for associative arrays)
- `find` command
- TUI library (for sub-issue 005a)

## Metadata
- **Priority**: Medium
- **Complexity**: Low (005), Medium (005a)
- **Dependencies**: None (005), Issue 004 completion (005a)
- **Impact**: Improved project discoverability and documentation access

## Success Criteria
- [ ] `/home/ritz/programming/ai-stuff/scripts/visions/` directory exists
- [ ] `sync-visions.sh` discovers all vision files across projects
- [ ] Symlinks are created with meaningful project-based names
- [ ] Script handles projects with multiple vision files
- [ ] Script reports statistics on vision documentation coverage
- [ ] Both headless and interactive modes work (interactive can be minimal until 005a)
- [ ] Script follows DIR variable pattern for portability
