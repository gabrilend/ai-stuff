# Issue 042: Project Integration Checker and Auto-Remediation System

## Vision

Delta-version should serve as the **connective tissue** that brings all monorepo projects together. This tool audits projects for integration opportunities, missing metadata, and shared utility adoption - then either fixes issues programmatically or creates issue files for project maintainers.

**Current adoption stats:**
- 21 projects discovered
- 20 have delta-guide.md symlinks (95%)
- 1 has project.meta.json (5%)
- 11 have llm-transcripts directories

## Current Behavior

Scripts like `phase-1-demo.sh` include graceful degradation checks:
```bash
if [[ -x "${SCRIPTS_DIR}/list-projects.sh" ]]; then
    # use it
else
    echo -e "    ${RED}list-projects.sh not found${NC}"
fi
```

When utilities are missing or misconfigured:
- The demo mentions the problem but takes no action
- The user must manually investigate and fix
- No issue tracking is created automatically
- Problems can be forgotten or overlooked

## Intended Behavior

Create a `check-utilities.sh` script that:

1. **Audits** all expected utilities across the delta-version toolkit
2. **Detects** missing scripts, broken dependencies, misconfigured paths
3. **Offers remediation** for each problem found:
   - If fixable programmatically → offer to fix it
   - If requires manual work → offer to create an issue file
4. **Queries the user** for each detected problem (interactive mode)
5. **Reports** a summary of health status (non-interactive mode)

### Use Cases

| Situation | Detection | Remediation |
|-----------|-----------|-------------|
| Script missing execute permission | `[[ ! -x "$script" ]]` | `chmod +x "$script"` |
| Script missing entirely | `[[ ! -f "$script" ]]` | Create issue file |
| Required directory missing | `[[ ! -d "$dir" ]]` | `mkdir -p "$dir"` |
| Missing dependency (jq, git, etc.) | `! command -v jq` | Warn + create issue |
| Broken symlink | `[[ -L "$link" && ! -e "$link" ]]` | Remove or recreate |
| Missing shebang | `head -1` check | Add shebang line |
| Script syntax error | `bash -n "$script"` | Create issue file |

## Suggested Implementation Steps

### 1. Define Utility Registry

```bash
# -- {{{ UTILITY_REGISTRY
# Format: name|path|type|description
UTILITY_REGISTRY=(
    "list-projects|scripts/list-projects.sh|required|Project discovery"
    "validate-repository|scripts/validate-repository.sh|required|Repository validation"
    "manage-metadata|scripts/manage-metadata.sh|required|Metadata management"
    "manage-issues|scripts/manage-issues.sh|required|Issue tracking"
    "reconstruct-history|scripts/reconstruct-history.sh|optional|History reconstruction"
    "generate-history|scripts/generate-history.sh|optional|History generation"
)
# }}}
```

### 2. Define Check Functions

```bash
# -- {{{ check_script_exists
check_script_exists() {
    local script_path="$1"
    [[ -f "$script_path" ]]
}
# }}}

# -- {{{ check_script_executable
check_script_executable() {
    local script_path="$1"
    [[ -x "$script_path" ]]
}
# }}}

# -- {{{ check_script_syntax
check_script_syntax() {
    local script_path="$1"
    bash -n "$script_path" 2>/dev/null
}
# }}}

# -- {{{ check_script_shebang
check_script_shebang() {
    local script_path="$1"
    head -1 "$script_path" 2>/dev/null | grep -qE '^#!/bin/(ba)?sh'
}
# }}}

# -- {{{ check_external_dependency
check_external_dependency() {
    local cmd="$1"
    command -v "$cmd" &>/dev/null
}
# }}}
```

### 3. Define Remediation Functions

```bash
# -- {{{ fix_executable_permission
fix_executable_permission() {
    local script_path="$1"
    chmod +x "$script_path"
    echo "Fixed: Made $script_path executable"
}
# }}}

# -- {{{ fix_missing_directory
fix_missing_directory() {
    local dir_path="$1"
    mkdir -p "$dir_path"
    echo "Fixed: Created directory $dir_path"
}
# }}}

# -- {{{ create_issue_for_problem
create_issue_for_problem() {
    local problem_type="$1"
    local affected_item="$2"
    local description="$3"
    local project_dir="$4"

    local issue_id
    issue_id=$(get_next_issue_id "$project_dir")

    local issue_file="${project_dir}/issues/${issue_id}-fix-${problem_type}.md"

    cat > "$issue_file" <<EOF
# Issue ${issue_id}: Fix ${problem_type}

## Current Behavior
${description}

Affected: \`${affected_item}\`

## Intended Behavior
The ${problem_type} should be resolved so the utility functions correctly.

## Suggested Implementation Steps
1. Investigate the root cause
2. Implement the fix
3. Test the utility
4. Update this issue with completion notes

## Metadata
- **Priority**: Medium
- **Created**: $(date +%Y-%m-%d)
- **Created By**: check-utilities.sh (auto-generated)
EOF

    echo "Created issue: $issue_file"
}
# }}}
```

### 4. Interactive Query Loop

```bash
# -- {{{ prompt_for_action
prompt_for_action() {
    local problem="$1"
    local can_auto_fix="$2"
    local fix_command="$3"

    echo
    echo -e "${YELLOW}Problem detected:${NC} $problem"
    echo

    if [[ "$can_auto_fix" == "true" ]]; then
        echo "  1) Fix automatically"
        echo "  2) Create issue file"
        echo "  3) Skip"
        echo -n "  Choice [1/2/3]: "
    else
        echo "  1) Create issue file"
        echo "  2) Skip"
        echo -n "  Choice [1/2]: "
    fi

    read -r choice
    echo "$choice"
}
# }}}
```

### 5. Main Audit Loop

```bash
# -- {{{ audit_utilities
audit_utilities() {
    local issues_found=0
    local issues_fixed=0
    local issues_created=0

    for entry in "${UTILITY_REGISTRY[@]}"; do
        IFS='|' read -r name path type desc <<< "$entry"
        local full_path="${DIR}/${path}"

        # Check existence
        if ! check_script_exists "$full_path"; then
            ((issues_found++))
            handle_missing_script "$name" "$full_path" "$type"
            continue
        fi

        # Check executable
        if ! check_script_executable "$full_path"; then
            ((issues_found++))
            handle_not_executable "$name" "$full_path"
        fi

        # Check syntax
        if ! check_script_syntax "$full_path"; then
            ((issues_found++))
            handle_syntax_error "$name" "$full_path"
        fi

        # Check shebang
        if ! check_script_shebang "$full_path"; then
            ((issues_found++))
            handle_missing_shebang "$name" "$full_path"
        fi
    done

    print_summary "$issues_found" "$issues_fixed" "$issues_created"
}
# }}}
```

### 6. CLI Interface

```bash
Usage: check-utilities.sh [OPTIONS]

OPTIONS:
    -h, --help          Show this help
    -q, --quiet         Non-interactive mode (report only)
    --fix-all           Auto-fix all fixable problems
    --create-issues     Create issues for all non-fixable problems
    --project PATH      Check utilities for specific project
    --registry FILE     Use custom utility registry file

EXAMPLES:
    check-utilities.sh                    # Interactive audit
    check-utilities.sh --quiet            # Report only
    check-utilities.sh --fix-all          # Auto-fix everything possible
    check-utilities.sh --project world-edit-to-execute
```

## External Dependencies to Check

| Dependency | Required By | Check Command |
|------------|-------------|---------------|
| `bash` 4.0+ | All scripts | `bash --version` |
| `git` | validate-repository, reconstruct-history | `git --version` |
| `jq` | JSON processing | `jq --version` |
| `find` | File discovery | `find --version` |
| `stat` | File metadata | `stat --version` |
| `curl` | LLM integration | `curl --version` |

## Directory Structure Checks

```bash
REQUIRED_DIRS=(
    "scripts"
    "docs"
    "issues"
    "issues/completed"
    "issues/completed/demos"
)

OPTIONAL_DIRS=(
    "libs"
    "assets"
    "notes"
    "src"
    "config"
)
```

## Files to Create

- `delta-version/scripts/check-utilities.sh` - Main utility checker script

## Related Issues

- Issue 028: Foundation Demo Script (contains graceful degradation patterns)
- Issue 025: Repository Structure Validation (validates directory structure)

## Acceptance Criteria

- [ ] Script audits all registered utilities
- [ ] Detects missing scripts, permission issues, syntax errors
- [ ] Interactive mode queries user for each problem
- [ ] Auto-fix works for permission and directory issues
- [ ] Creates well-formatted issue files for non-fixable problems
- [ ] Non-interactive mode produces summary report
- [ ] External dependency checks included
- [ ] Help text documents all options

## Metadata

- **Priority**: Medium
- **Complexity**: Medium
- **Phase**: 1 (Foundation Infrastructure)
- **Dependencies**: None
- **Blocks**: Improved developer experience

## Notes

This tool embodies the principle from CLAUDE.md:
> "prefer error messages and breaking functionality over fallbacks. Be sure to notify
> the user every time a fallback is used, and create a new issue file to resolve any
> fallbacks if they are present"

Rather than silently degrading, this tool makes problems visible and actionable.

---

## Part 2: Project Integration Checks

Beyond checking delta-version's own utilities, this tool audits **all projects** in the monorepo for integration opportunities.

### Integration Check Categories

#### 1. Delta-Version Registration

What delta-version needs from each project to function:

| Check | Detection | Auto-Fix | Prompt |
|-------|-----------|----------|--------|
| `project.meta.json` missing | `[[ ! -f "$proj/project.meta.json" ]]` | Create template | Ask for status, language, description |
| `delta-guide.md` symlink missing | `[[ ! -L "$proj/docs/delta-guide.md" ]]` | Create symlink | Confirm docs/ exists |
| `docs/` directory missing | `[[ ! -d "$proj/docs" ]]` | `mkdir -p` | Auto-create |
| `issues/` directory missing | `[[ ! -d "$proj/issues" ]]` | `mkdir -p` | Auto-create |
| `notes/vision.md` missing | `[[ ! -f "$proj/notes/vision.md" ]]` | Create template | Ask for project vision |

#### 2. Shared Utility Symlinks

Useful monorepo utilities that projects can link to:

```bash
SHARED_UTILITIES=(
    # Format: name|source|target_in_project|description
    "issue-splitter|scripts/issue-splitter.sh|scripts/issue-splitter.sh|Split large issues into sub-issues"
    "git-history|scripts/git-history.sh|scripts/git-history.sh|Git history visualization"
    "sync-visions|scripts/sync-visions.sh|scripts/sync-visions.sh|Sync vision docs across projects"
)
```

**Interactive prompt:**
```
Project: world-edit-to-execute

The following shared utilities are available but not linked:
  • issue-splitter.sh - Split large issues into sub-issues

  1) Create symlink to shared utility
  2) Create issue file for maintainer
  3) Skip (not relevant for this project)
  Choice: _
```

#### 3. TUI Library Integration

Check if projects have TUI scripts that could use the shared menu library:

```bash
# -- {{{ check_tui_integration
check_tui_integration() {
    local project_dir="$1"

    # Find scripts that use terminal manipulation but don't source menu library
    find "$project_dir" -name "*.sh" -type f | while read -r script; do
        # Check if script uses TUI patterns (tput, escape codes, read -s)
        if grep -qE 'tput|\\033\[|\\e\[|read -s' "$script"; then
            # Check if it sources the shared menu library
            if ! grep -qE 'source.*menu\.sh|source.*tui\.sh' "$script"; then
                echo "$script"
            fi
        fi
    done
}
# }}}
```

**Prompt for TUI scripts without library:**
```
Found TUI script not using shared menu library:
  world-edit-to-execute/src/cli/interactive-menu.sh

  1) Create issue to migrate to menu library
  2) Add comment noting intentional non-use
  3) Skip
  Choice: _
```

#### 4. LLM Transcript Cataloguing

Check if projects have LLM transcripts and if they're registered:

```bash
# -- {{{ check_transcript_integration
check_transcript_integration() {
    local project_dir="$1"
    local project_name=$(basename "$project_dir")

    # Check if project has transcripts
    if [[ -d "$project_dir/llm-transcripts" ]]; then
        local count=$(find "$project_dir/llm-transcripts" -name "*.md" -o -name "*.jsonl" | wc -l)

        # Check if registered in delta-version's transcript index
        if ! grep -q "$project_name" "$DELTA_DIR/config/transcript-index.json" 2>/dev/null; then
            echo "unregistered|$project_name|$count"
        fi
    fi
}
# }}}
```

#### 5. Issue File Standards

Check if project issues follow delta-version conventions:

| Check | Detection | Auto-Fix | Prompt |
|-------|-----------|----------|--------|
| Missing `## Current Behavior` | grep check | ❌ | Create issue for maintainer |
| Missing `## Intended Behavior` | grep check | ❌ | Create issue for maintainer |
| No issue numbering | filename pattern | ❌ | Create issue for maintainer |
| No `issues/completed/` directory | `[[ ! -d ]]` | ✅ mkdir | Auto-create |

### Project Integration Registry

Track what's been checked and when:

```bash
# config/project-integration.json
{
  "projects": {
    "world-edit-to-execute": {
      "last_checked": "2026-01-04",
      "delta_guide": true,
      "metadata": true,
      "tui_audit": "2026-01-04",
      "transcripts_indexed": true,
      "issues_created": ["042a-migrate-tui-scripts"]
    }
  }
}
```

### CLI Interface (Expanded)

```bash
Usage: check-utilities.sh [OPTIONS] [PROJECT...]

MODES:
    (default)              Check delta-version utilities only
    --all-projects         Check all discovered projects
    --project NAME         Check specific project(s)

DELTA-VERSION CHECKS:
    --utilities            Check delta-version script health
    --dependencies         Check external dependencies (jq, git, etc.)
    --structure            Check directory structure

PROJECT INTEGRATION CHECKS:
    --metadata             Check for project.meta.json
    --symlinks             Check for shared utility symlinks
    --tui-audit            Find TUI scripts not using menu library
    --transcripts          Check LLM transcript registration
    --issue-standards      Check issue file format compliance

ACTIONS:
    -i, --interactive      Prompt for each issue (default)
    -q, --quiet            Report only, no prompts
    --fix-all              Auto-fix everything possible
    --create-issues        Create issues for all problems
    --dry-run              Show what would be done

EXAMPLES:
    check-utilities.sh                              # Check delta-version only
    check-utilities.sh --all-projects --metadata    # Check all projects for metadata
    check-utilities.sh --project world-edit-to-execute --tui-audit
    check-utilities.sh --all-projects --fix-all --symlinks
```

### Integration Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                    check-utilities.sh                        │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│ Delta-Version │    │   Project     │    │    Shared     │
│   Utilities   │    │  Integration  │    │   Resources   │
└───────────────┘    └───────────────┘    └───────────────┘
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│ - Permissions │    │ - Metadata    │    │ - TUI libs    │
│ - Syntax      │    │ - Symlinks    │    │ - Transcripts │
│ - Dependencies│    │ - Issue fmt   │    │ - Utilities   │
└───────────────┘    └───────────────┘    └───────────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              ▼
                    ┌───────────────┐
                    │  Interactive  │
                    │    Prompt     │
                    └───────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
        ┌──────────┐   ┌──────────┐   ┌──────────┐
        │ Auto-Fix │   │  Create  │   │   Skip   │
        │          │   │  Issue   │   │          │
        └──────────┘   └──────────┘   └──────────┘
```

### Sample Interactive Session

```
$ check-utilities.sh --all-projects --metadata --symlinks

╔══════════════════════════════════════════════════════════════╗
║           Project Integration Checker v1.0                    ║
║           Scanning 21 projects...                             ║
╚══════════════════════════════════════════════════════════════╝

Checking: world-edit-to-execute
──────────────────────────────────────────────────────────────

[!] Missing: project.meta.json

    This file helps delta-version track project status, language,
    and other metadata for reporting and filtering.

    1) Create template (I'll fill in the details)
    2) Create issue for maintainer
    3) Skip

    Choice [1/2/3]: 1

    Project status? [active/maintenance/experimental/archived]: active
    Primary language? [lua/bash/c/other]: lua
    Brief description: Real-time strategy game with Lua scripting

    ✓ Created: world-edit-to-execute/project.meta.json

[!] Missing symlink: scripts/issue-splitter.sh

    1) Create symlink to ../../scripts/issue-splitter.sh
    2) Create issue for maintainer
    3) Skip (not relevant)

    Choice [1/2/3]: 1

    ✓ Created symlink: scripts/issue-splitter.sh

Checking: factory-war
──────────────────────────────────────────────────────────────

[✓] project.meta.json exists
[✓] delta-guide.md symlink exists
[!] Missing symlink: scripts/issue-splitter.sh

    Choice [1/2/3]: 3 (skip)

... (continues for all projects) ...

══════════════════════════════════════════════════════════════
Summary:
  Projects checked:     21
  Metadata created:     15
  Symlinks created:      8
  Issues created:        3
  Skipped:              12
══════════════════════════════════════════════════════════════
```

## Expanded Acceptance Criteria

### Delta-Version Utility Checks
- [ ] Script audits all registered utilities
- [ ] Detects missing scripts, permission issues, syntax errors
- [ ] Auto-fix works for permission and directory issues
- [ ] External dependency checks included

### Project Integration Checks
- [ ] Scans all projects for delta-guide.md symlink
- [ ] Scans all projects for project.meta.json
- [ ] Interactive prompts for missing metadata fields
- [ ] Creates proper symlinks to shared utilities
- [ ] Detects TUI scripts not using shared library
- [ ] Catalogs LLM transcript directories

### Issue Creation
- [ ] Creates well-formatted issue files in target project
- [ ] Uses next available issue number
- [ ] Includes current behavior and intended behavior sections
- [ ] Tags as "auto-generated by check-utilities.sh"

### Reporting
- [ ] Non-interactive mode produces summary report
- [ ] Tracks integration status in config file
- [ ] Help text documents all options

## Files to Create

- `delta-version/scripts/check-utilities.sh` - Main checker script ✓
- `delta-version/config/project-integration.json` - Integration status tracking (deferred)
- `delta-version/config/shared-utilities.conf` - Registry of shared utilities (deferred)
- `delta-version/assets/project-meta-template.json` - Template for project.meta.json (inline in script)

---

## Implementation Notes

**Date**: 2026-01-07
**Status**: COMPLETED (core functionality)

### Completed Features

**Part 1: Delta-Version Utility Checks** ✓
- Implemented utility registry with all delta-version scripts
- Check functions for: existence, executability, syntax, shebang
- Remediation functions for auto-fixable issues (chmod, mkdir)
- Issue file creation for non-fixable problems
- External dependency checks (bash, git, jq, find, stat)
- Directory structure validation

**Part 2: Project Integration Audit** ✓
- Project discovery via list-projects.sh integration
- Metadata checking (project.meta.json)
- Delta-guide symlink checking and creation
- Interactive metadata template creation
- Automatic symlink creation with proper relative paths
- Per-project audit with detailed reporting

**CLI Interface** ✓
- Multiple operation modes (interactive, quiet, fix-all, dry-run)
- Granular check selection (--utilities, --metadata, --symlinks, etc.)
- Project targeting (--all-projects, --project NAME)
- Comprehensive help documentation
- Color-coded output with severity levels
- Summary statistics

### Key Implementation Decisions

1. **Inline templates**: Rather than external config files, metadata templates are generated inline in the script for simplicity

2. **Shebang validation**: Updated regex to accept `#!/usr/bin/env bash` as valid (more portable than `/bin/bash`)

3. **Graceful degradation**: Script continues even if list-projects.sh is missing, with clear error messages

4. **Interactive prompts**: For metadata creation, the script asks for status, language, and description interactively

### Test Results
- Delta-version checks: All passed (0 issues)
- Project integration: Found 19 issues across monorepo (expected - most projects lack metadata/symlinks)
- All modes tested: interactive, quiet, fix-all, dry-run, help

### Deferred Features (Future Work)
The following Part 2 features are marked as TODO for future iterations:
- TUI audit (find scripts not using shared menu library)
- Transcript cataloging (LLM transcript directory registration)
- Issue file standards validation
- Shared utility symlink suggestions beyond delta-guide.md
- Integration status tracking (config/project-integration.json)
- Shared utilities registry (config/shared-utilities.conf)

These features have clear placeholders in the code and can be added incrementally as needed.

### Files Created
- `scripts/check-utilities.sh` (1047 lines, fully functional)
