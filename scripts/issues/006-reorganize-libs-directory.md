# Issue 006: Reorganize Libs Directory Structure

## Current Behavior

The `/home/ritz/programming/ai-stuff/scripts/` directory currently contains:
- Executable scripts (backup-conversations, sync-visions.sh, etc.)
- A `libs/` subdirectory with TUI components (menu.sh, tui.sh, checkbox.sh, etc.)
- Test scripts mixed in various locations
- Subdirectories for specific tools (poem-context-generator, debug, issues, visions)

### Current Structure
```
scripts/
├── libs/
│   ├── checkbox.sh        # TUI checkbox component
│   ├── input.sh           # TUI input component
│   ├── menu.sh            # TUI menu component (46KB)
│   ├── multistate.sh      # TUI multistate component
│   ├── tui.sh             # TUI core utilities
│   ├── test-checkbox.sh   # Test scripts mixed with libs
│   ├── test-input.sh
│   ├── test-menu.sh
│   ├── test-multistate.sh
│   └── test-tui.sh
├── backup-conversations   # Executable script
├── sync-visions.sh        # Executable script
├── issue-splitter.sh      # Executable script
├── git-history.sh         # Executable script
├── ... (other scripts)
└── ... (subdirectories)
```

### Current Issues
- Library files live inside the scripts directory, mixing concerns
- Test scripts are mixed with library implementations
- No documentation of which projects depend on which libraries
- When a library has breaking changes, no clear way to know what to update
- The scripts directory serves dual purpose (executables + libraries)

## Intended Behavior

### New Structure
```
/home/ritz/programming/ai-stuff/
├── my-libs/                          # NEW: Centralized library location
│   ├── README.md                     # Dependency reference list
│   ├── tui/                          # TUI component library
│   │   ├── tui.sh                    # Core utilities
│   │   ├── menu.sh                   # Menu component
│   │   ├── checkbox.sh               # Checkbox component
│   │   ├── input.sh                  # Input component
│   │   ├── multistate.sh             # Multistate component
│   │   └── tests/                    # Test scripts in subdirectory
│   │       ├── test-tui.sh
│   │       ├── test-menu.sh
│   │       └── ...
│   ├── lua/                          # Future: Lua libraries
│   └── c/                            # Future: C libraries
│
├── scripts/                          # Executable shortcuts ONLY
│   ├── README.md                     # Documents shortcut pattern
│   ├── backup-conversations          # Shortcut → implementation
│   ├── sync-visions                  # Shortcut → implementation
│   ├── issue-splitter                # Shortcut → implementation
│   ├── git-history                   # Shortcut → implementation
│   └── _impl/                        # Actual implementations
│       ├── backup-conversations.sh
│       ├── sync-visions.sh
│       └── ...
```

### Shortcut Pattern

Each script in `scripts/` is a minimal bash wrapper:

```bash
#!/usr/bin/env bash
# backup-conversations - Shortcut to backup-conversations implementation
#
# This file exists for PATH convenience. Actual implementation lives in _impl/

DIR="${DIR:-/home/ritz/programming/ai-stuff}"
exec "${DIR}/scripts/_impl/backup-conversations.sh" "$@"
```

### Library README.md Format

The `my-libs/README.md` should contain a dependency reference list:

```markdown
# My Libraries

Shared libraries used across the AI project collection.

## Dependency Reference

This section tracks which projects use each library. Update this list
when adding new consumers to ensure breaking changes can be coordinated.

### tui/ - Terminal UI Components

| Library | Consumers | Notes |
|---------|-----------|-------|
| tui.sh | scripts, world-edit-to-execute | Core TUI utilities |
| menu.sh | scripts, world-edit-to-execute | Interactive menus |
| checkbox.sh | scripts | Multi-select checkboxes |
| input.sh | scripts | Text input fields |
| multistate.sh | scripts | Toggle/cycle widgets |

### lua/ - Lua Libraries

(Future - no libraries yet)

### c/ - C Libraries

(Future - no libraries yet)

## Adding a New Consumer

When a project starts using a library:
1. Add an entry to the appropriate table above
2. Include notes about which features are used
3. Consider whether the project needs pinned version

## Making Breaking Changes

Before making breaking changes to a library:
1. Check the consumer list above
2. Update each consumer or coordinate deprecation
3. Consider semantic versioning for critical libraries
```

## Suggested Implementation Steps

### Sub-Issue Structure

#### 006a: Create my-libs Directory Structure
- Create `/home/ritz/programming/ai-stuff/my-libs/`
- Create subdirectories: `tui/`, `tui/tests/`, `lua/`, `c/`
- Move TUI libraries from `scripts/libs/` to `my-libs/tui/`
- Move test scripts to `my-libs/tui/tests/`
- Create `my-libs/README.md` with dependency reference template

#### 006b: Create Scripts Implementation Directory
- Create `scripts/_impl/` directory
- Move implementation scripts to `_impl/`
- Update any internal paths in moved scripts
- Create `scripts/README.md` documenting the shortcut pattern

#### 006c: Create Shortcut Wrappers
- Create shortcut scripts in `scripts/` for each implementation
- Ensure shortcuts pass all arguments through
- Make shortcuts executable
- Test that all shortcuts work correctly

#### 006d: Update Symlinks and References
- Find all symlinks pointing to old locations
- Update symlinks to point to new locations
- Find all scripts that source from `scripts/libs/`
- Update source paths to `my-libs/tui/`

#### 006e: Populate Dependency Reference
- Audit codebase for library usage
- Create initial dependency list in README.md
- Document any known version constraints
- Add notes for non-obvious dependencies

## Implementation Details

### Finding Library Consumers

```bash
# Find all files that source TUI libraries
grep -r "scripts/libs" /home/ritz/programming/ai-stuff --include="*.sh"
grep -r "source.*tui\.sh" /home/ritz/programming/ai-stuff --include="*.sh"
grep -r "source.*menu\.sh" /home/ritz/programming/ai-stuff --include="*.sh"

# Find symlinks to libs directory
find /home/ritz/programming/ai-stuff -type l -exec sh -c \
  'readlink "$1" | grep -q "libs" && echo "$1"' _ {} \;
```

### Updating Source Paths

Old pattern:
```bash
source "${DIR}/scripts/libs/tui.sh"
source "${DIR}/scripts/libs/menu.sh"
```

New pattern:
```bash
source "${DIR}/my-libs/tui/tui.sh"
source "${DIR}/my-libs/tui/menu.sh"
```

### Shortcut Script Template

```bash
#!/usr/bin/env bash
# {script-name} - Shortcut to {script-name} implementation
#
# This is a thin wrapper for PATH convenience.
# Actual implementation: _impl/{script-name}.sh
# Library dependencies: (list if any)

set -euo pipefail

DIR="${DIR:-/home/ritz/programming/ai-stuff}"
exec "${DIR}/scripts/_impl/{script-name}.sh" "$@"
```

### Scripts to Migrate

| Current Location | New Implementation | New Shortcut |
|------------------|-------------------|--------------|
| `scripts/backup-conversations` | `scripts/_impl/backup-conversations.sh` | `scripts/backup-conversations` |
| `scripts/sync-visions.sh` | `scripts/_impl/sync-visions.sh` | `scripts/sync-visions` |
| `scripts/issue-splitter.sh` | `scripts/_impl/issue-splitter.sh` | `scripts/issue-splitter` |
| `scripts/git-history.sh` | `scripts/_impl/git-history.sh` | `scripts/git-history` |
| `scripts/filesystem_scanner.sh` | `scripts/_impl/filesystem_scanner.sh` | `scripts/filesystem-scanner` |
| `scripts/claude-conversation-exporter.sh` | `scripts/_impl/claude-conversation-exporter.sh` | `scripts/claude-exporter` |
| `scripts/progress-dashboard.lua` | `my-libs/lua/progress-dashboard.lua` | `scripts/progress-dashboard` |

### Directory Decisions

| Item | Destination | Rationale |
|------|-------------|-----------|
| `libs/*.sh` | `my-libs/tui/` | TUI component libraries |
| `libs/test-*.sh` | `my-libs/tui/tests/` | Test scripts belong with their libs |
| `debug/` | `scripts/debug/` | Keep as infrastructure |
| `issues/` | `scripts/issues/` | Keep as infrastructure |
| `visions/` | `scripts/visions/` | Keep as symlink directory |
| `poem-context-generator/` | `scripts/_impl/poem-context-generator/` | Multi-file implementation |

## Related Documents
- Issue 004: Fix TUI Menu Incremental Rendering (uses libs/menu.sh)
- Issue 005: Vision Documentation Viewer (uses scripts/ directory)
- `/home/ritz/programming/ai-stuff/world-edit-to-execute/` - Known TUI consumer

## Metadata
- **Priority**: Low (cleanup/organizational)
- **Complexity**: Medium (many files to move, references to update)
- **Dependencies**: None
- **Blocks**: None (but affects future library usage)
- **Impact**: Cleaner separation of concerns, easier dependency tracking

## Success Criteria

### Structure
- [ ] `my-libs/` directory exists at repository root
- [ ] `my-libs/tui/` contains all TUI components
- [ ] `my-libs/tui/tests/` contains all TUI test scripts
- [ ] `scripts/` contains only shortcut executables and infrastructure
- [ ] `scripts/_impl/` contains actual implementations

### Documentation
- [ ] `my-libs/README.md` exists with dependency reference format
- [ ] All known library consumers are documented
- [ ] `scripts/README.md` explains shortcut pattern

### Functionality
- [ ] All shortcuts execute their implementations correctly
- [ ] All library source paths updated
- [ ] All symlinks updated to new locations
- [ ] No broken references to old `scripts/libs/` path

### Verification
- [ ] `grep -r "scripts/libs" .` returns no results
- [ ] All test scripts pass from new locations
- [ ] Scripts work when called from any directory
