# Issue 044: Project Directory Tree Generator with Auto-Distribution

## Vision

Each project in the monorepo should have an up-to-date directory structure map that shows:
1. Its own directory tree (respecting .gitignore)
2. Relevant shared utilities from the monorepo root
3. Important delta-version scripts that apply to all projects

This provides quick orientation for developers and AI agents, and ensures everyone has a consistent view of project structure without needing to explore directories manually.

## Current Behavior

No automated directory tree generation exists. Developers must:
- Manually run `tree` or `ls -R` commands
- Navigate directories to understand structure
- No consistent format across projects
- No awareness of what shared utilities are available
- `filesystem_scanner.sh` exists but doesn't respect .gitignore and doesn't split by project

## Intended Behavior

A single command generates and distributes directory trees:

```bash
./scripts/generate-directory-trees.sh
```

This should:

1. **Generate master tree file** with all projects separated by markers
2. **Respect .gitignore** - only show tracked/relevant files
3. **Split and distribute** - create/update per-project structure files
4. **Include shared context** - add monorepo utilities section to each project

### Example Master Output

```
][ delta-version ][
delta-version/
  ├── scripts/
  │   ├── list-projects.sh
  │   ├── manage-worktree.sh
  │   ├── check-utilities.sh
  │   └── initialize-issue.sh
  ├── docs/
  │   ├── worktree-guide.md
  │   └── delta-guide.md
  ├── issues/
  │   ├── 042-utility-health-checker.md
  │   └── 043-issue-initialization-workflow.md
  └── libs/

][ world-edit-to-execute ][
world-edit-to-execute/
  ├── src/
  │   ├── runtime/
  │   └── render/
  ├── libs/
  ├── issues/
  └── docs/

][ neocities-modernization ][
neocities-modernization/
  ├── input/
  ├── output/
  ├── issues/
  └── scripts/

][ shared-monorepo-utilities ][
scripts/  (monorepo root)
  ├── issue-splitter.sh
  ├── filesystem_scanner.sh
  └── sync-visions.sh

libs/  (monorepo root)
  └── (shared libraries)
```

### Per-Project Output

Each project gets `DIRECTORY_STRUCTURE.txt`:

```
# world-edit-to-execute Directory Structure

Generated: 2026-01-08

## Project Structure

world-edit-to-execute/
  ├── src/
  │   ├── runtime/
  │   └── render/
  ├── libs/
  ├── issues/
  └── docs/

## Shared Monorepo Utilities

Available in /mnt/mtwo/programming/ai-stuff/scripts/:
  ├── issue-splitter.sh        - Split issues into sub-issues
  ├── sync-visions.sh           - Sync vision files
  └── backup-conversations      - Backup LLM conversations

Available in /mnt/mtwo/programming/ai-stuff/delta-version/scripts/:
  ├── list-projects.sh          - Discover all projects
  ├── manage-worktree.sh        - Manage git worktrees
  ├── check-utilities.sh        - Health check utilities
  └── initialize-issue.sh       - Initialize issue workflow

## Important Configuration

- Main repository: /mnt/mtwo/programming/ai-stuff
- Project path: /mnt/mtwo/programming/ai-stuff/world-edit-to-execute
- Worktrees: /mnt/mtwo/programming/ai-worktrees/wete/
```

## Suggested Implementation Steps

### 1. Create Script Skeleton

```bash
#!/usr/bin/env bash
# generate-directory-trees.sh - Generate and distribute project directory trees
#
# Creates directory structure maps for all projects, respecting .gitignore,
# with separation markers for parsing and auto-distribution to each project.

DIR="${DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MONOREPO_ROOT="$(dirname "$DIR")"

# Output files
MASTER_OUTPUT="${DIR}/assets/master-directory-structure.txt"
MARKER_PREFIX="][ "
MARKER_SUFFIX=" ]["

# Options
INCLUDE_FILES=true
MAX_DEPTH=5
RESPECT_GITIGNORE=true
```

### 2. Git-Aware Tree Generation

```bash
# -- {{{ generate_project_tree
generate_project_tree() {
    local project_dir="$1"
    local project_name="$2"

    # Use git ls-files to respect .gitignore
    if $RESPECT_GITIGNORE && [[ -d "${project_dir}/.git" ]]; then
        # Get tracked files from git
        git -C "$project_dir" ls-files | generate_tree_from_list "$project_name"
    else
        # Fallback to find with .gitignore parsing
        generate_tree_with_find "$project_dir" "$project_name"
    fi
}
# }}}

# -- {{{ generate_tree_from_list
generate_tree_from_list() {
    local project_name="$1"

    # Read file paths from stdin and build tree structure
    local tree_map=()

    while IFS= read -r filepath; do
        # Build hierarchical structure
        local path_parts=()
        IFS='/' read -ra path_parts <<< "$filepath"

        # Process each directory level
        for i in "${!path_parts[@]}"; do
            local depth=$i
            local name="${path_parts[$i]}"

            # Determine if directory or file
            if [[ $i -eq $((${#path_parts[@]} - 1)) ]]; then
                # File
                if $INCLUDE_FILES; then
                    echo "${indent}├── $name"
                fi
            else
                # Directory
                echo "${indent}├── $name/"
            fi
        done
    done | sort -u
}
# }}}
```

### 3. Separation Markers

```bash
# -- {{{ write_project_section
write_project_section() {
    local project_name="$1"
    local output_file="$2"

    # Write separation marker
    echo "" >> "$output_file"
    echo "${MARKER_PREFIX}${project_name}${MARKER_SUFFIX}" >> "$output_file"
    echo "" >> "$output_file"

    # Generate and write tree
    generate_project_tree "${MONOREPO_ROOT}/${project_name}" "$project_name" >> "$output_file"
}
# }}}

# -- {{{ split_master_file
split_master_file() {
    local master_file="$1"

    # Extract section between markers
    awk -v prefix="$MARKER_PREFIX" -v suffix="$MARKER_SUFFIX" '
        $0 ~ prefix && $0 ~ suffix {
            # Extract project name from marker
            match($0, prefix "(.+)" suffix, arr)
            project = arr[1]
            capturing = 1
            content = ""
            next
        }
        capturing && $0 ~ prefix && $0 ~ suffix {
            # New section started, write previous
            if (project) {
                write_project_file(project, content)
            }
            # Start new section
            match($0, prefix "(.+)" suffix, arr)
            project = arr[1]
            content = ""
            next
        }
        capturing {
            content = content $0 "\n"
        }
        END {
            if (project) {
                write_project_file(project, content)
            }
        }
    ' "$master_file"
}
# }}}
```

### 4. Shared Utilities Section

```bash
# -- {{{ generate_shared_utilities_section
generate_shared_utilities_section() {
    local output_file="$1"

    echo "" >> "$output_file"
    echo "${MARKER_PREFIX}shared-monorepo-utilities${MARKER_SUFFIX}" >> "$output_file"
    echo "" >> "$output_file"
    echo "## Monorepo Scripts" >> "$output_file"
    echo "" >> "$output_file"

    # List important scripts from /scripts/
    if [[ -d "${MONOREPO_ROOT}/scripts" ]]; then
        find "${MONOREPO_ROOT}/scripts" -maxdepth 1 -type f -executable | \
        while read -r script; do
            local name=$(basename "$script")
            local desc=$(extract_script_description "$script")
            echo "  ├── $name - $desc" >> "$output_file"
        done
    fi

    echo "" >> "$output_file"
    echo "## Delta-Version Scripts" >> "$output_file"
    echo "" >> "$output_file"

    # List delta-version utilities
    for script in list-projects.sh manage-worktree.sh check-utilities.sh initialize-issue.sh; do
        if [[ -f "${DIR}/scripts/${script}" ]]; then
            local desc=$(extract_script_description "${DIR}/scripts/${script}")
            echo "  ├── $script - $desc" >> "$output_file"
        fi
    done
}
# }}}

# -- {{{ extract_script_description
extract_script_description() {
    local script="$1"

    # Extract first comment line after shebang
    grep -m 1 "^#" "$script" | tail -1 | sed 's/^# //' | cut -d'-' -f2- | xargs
}
# }}}
```

### 5. Per-Project File Creation

```bash
# -- {{{ create_project_structure_file
create_project_structure_file() {
    local project_name="$1"
    local project_tree="$2"
    local shared_section="$3"

    local project_dir="${MONOREPO_ROOT}/${project_name}"
    local output_file="${project_dir}/DIRECTORY_STRUCTURE.txt"

    cat > "$output_file" <<EOF
# ${project_name} Directory Structure

Generated: $(date +%Y-%m-%d)
Auto-generated by: delta-version/scripts/generate-directory-trees.sh

## Project Structure

${project_tree}

${shared_section}

## Configuration

- Main repository: ${MONOREPO_ROOT}
- Project path: ${project_dir}
- Generated from: git ls-files (respects .gitignore)

---
To regenerate: cd ${DIR} && ./scripts/generate-directory-trees.sh
EOF

    echo "Created: ${project_name}/DIRECTORY_STRUCTURE.txt"
}
# }}}
```

### 6. Main Workflow

```bash
# -- {{{ main
main() {
    echo "Generating directory trees for all projects..."

    # Initialize master output
    mkdir -p "$(dirname "$MASTER_OUTPUT")"
    echo "# Monorepo Directory Structure" > "$MASTER_OUTPUT"
    echo "Generated: $(date)" >> "$MASTER_OUTPUT"
    echo "" >> "$MASTER_OUTPUT"

    # Get all projects
    local projects
    if [[ -x "${DIR}/scripts/list-projects.sh" ]]; then
        mapfile -t projects < <("${DIR}/scripts/list-projects.sh" --names 2>/dev/null)
    else
        echo "Error: list-projects.sh not found" >&2
        return 1
    fi

    # Generate each project section
    for project in "${projects[@]}"; do
        echo "Processing: $project"
        write_project_section "$project" "$MASTER_OUTPUT"
    done

    # Add shared utilities section
    generate_shared_utilities_section "$MASTER_OUTPUT"

    echo "Master file created: $MASTER_OUTPUT"
    echo ""
    echo "Distributing to projects..."

    # Split and distribute
    distribute_to_projects "$MASTER_OUTPUT"

    echo "Done! Directory trees updated in all projects."
}
# }}}

main "$@"
```

## CLI Interface

```bash
Usage: generate-directory-trees.sh [OPTIONS]

OPTIONS:
    --no-files          Show only directories (no files)
    --max-depth N       Maximum directory depth (default: 5)
    --no-gitignore      Don't respect .gitignore (show all)
    --dry-run           Generate master file only, don't distribute
    --project NAME      Generate for specific project only
    -h, --help          Show this help

EXAMPLES:
    generate-directory-trees.sh
        Generate and distribute trees for all projects

    generate-directory-trees.sh --no-files
        Show only directory structure, no files

    generate-directory-trees.sh --project world-edit-to-execute
        Update only one project's structure file

    generate-directory-trees.sh --dry-run
        Generate master file without distributing
```

## File Locations

### Generated Files

- **Master output**: `delta-version/assets/master-directory-structure.txt`
- **Per-project**: `<project>/DIRECTORY_STRUCTURE.txt`

### Script Location

- `delta-version/scripts/generate-directory-trees.sh`

## Advanced Features (Optional)

### 1. Watch Mode

Monitor for changes and auto-regenerate:
```bash
generate-directory-trees.sh --watch
# Regenerates on file changes
```

### 2. Diff Detection

Only regenerate if structure changed:
```bash
# Compare new tree with existing, only update if different
```

### 3. Custom Markers

Allow projects to customize their section:
```bash
# In project/.directory-tree-config:
include_patterns=("*.lua" "*.sh")
exclude_patterns=("tmp/*" "*.log")
max_depth=3
```

### 4. HTML/Markdown Output

Generate browsable HTML or markdown:
```bash
generate-directory-trees.sh --format=markdown
# Creates DIRECTORY_STRUCTURE.md with collapsible sections
```

## Separation Marker Format

The marker format `][ name ][` was chosen because:
- Easy to parse with regex: `\]\[ (.*?) \]\[`
- Unlikely to appear in natural text
- Visually distinct
- Works in grep/awk/sed

Alternative formats considered:
- `=== name ===` (too common)
- `<!-- name -->` (HTML-specific)
- `--- name ---` (markdown conflicts)

## Integration Points

- **Issue 023**: Uses `list-projects.sh` to discover projects
- **Gitignore system**: Respects .gitignore via `git ls-files`
- **Table of contents**: Similar to docs/table-of-contents.md but for directory structure
- **Issue 043**: Could be called during `initialize-issue.sh` to update structure

## Acceptance Criteria

- [ ] Generates master file with all project trees
- [ ] Uses `][ name ][` separation markers
- [ ] Respects .gitignore (uses git ls-files)
- [ ] Creates/updates DIRECTORY_STRUCTURE.txt in each project
- [ ] Includes shared utilities section in each project file
- [ ] Handles projects without git repos gracefully
- [ ] Supports --dry-run mode
- [ ] Supports single-project generation
- [ ] Generates clean, readable tree format
- [ ] Help text documents all options

## Metadata

- **Priority**: Medium
- **Complexity**: Medium
- **Phase**: 1 (Foundation Infrastructure)
- **Dependencies**: Issue 023 (list-projects.sh)
- **Blocks**: Better project navigation and orientation

## Notes

This tool provides a "map" for each project, helping developers and AI agents quickly understand:
- What directories exist
- What shared utilities are available
- How to regenerate the structure when it changes

The separation marker system enables programmatic parsing, making it easy to extract specific project sections or update individual projects without regenerating everything.

The use of `git ls-files` ensures we only show tracked files, keeping the output clean and relevant (no build artifacts, temp files, or ignored directories).
