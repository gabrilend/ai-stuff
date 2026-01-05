# Issue 042: Utility Health Checker and Auto-Remediation System

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
