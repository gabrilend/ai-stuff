# Issue 031: Import Project Histories

## Current Behavior

Multiple projects within the repository have their own `.git` directories with existing commit history. The meta-repository needs to preserve these histories when consolidating into a unified repository with branch-per-project structure.

### Projects with History
- handheld-office: 7 commits
- risc-v-university: 5 commits
- progress-ii: 2 commits
- magic-rumble: 1 commit
- adroit: 1 commit
- game-state: 1 commit

### External Libraries (history can be recovered from upstream)
- raylib, rgbds, emsdk, luasocket, effil, luahpdf, pixellib

## Intended Behavior

Create a system that:
1. **Imports project histories** as branches in the meta-repository
2. **Preserves complete commit history** for each project
3. **Creates proper branch structure** where each project branch contains its full history
4. **Handles external libraries** by either importing or excluding based on configuration
5. **Prepares master branch** that contains all projects as a unified collection

## Suggested Implementation Steps

### 1. History Import Script
```bash
# -- {{{ import_project_history
function import_project_history() {
    local project_path="$1"
    local branch_name="$2"

    # Add project as remote
    git remote add "temp-${branch_name}" "${project_path}/.git"

    # Fetch its history
    git fetch "temp-${branch_name}"

    # Create branch from its history
    git branch "${branch_name}" "temp-${branch_name}/master" || \
    git branch "${branch_name}" "temp-${branch_name}/main"

    # Clean up temp remote
    git remote remove "temp-${branch_name}"
}
# }}}
```

### 2. Project Discovery and Import
```bash
# -- {{{ import_all_projects
function import_all_projects() {
    local base_dir="$1"

    for project in handheld-office risc-v-university progress-ii magic-rumble adroit; do
        if [[ -d "${base_dir}/${project}/.git" ]]; then
            import_project_history "${base_dir}/${project}" "${project}"
        fi
    done
}
# }}}
```

### 3. Master Branch Creation
After importing project histories:
```bash
# Remove embedded .git directories (history now preserved in branches)
# Add all files to master
# Create initial master commit
```

## Implementation Details

### Import Strategy
1. First import all project histories as separate branches
2. Then remove embedded `.git` directories
3. Finally create master branch with all project files

### Branch Naming Convention
- Project branches: `{project-name}` (e.g., `handheld-office`, `progress-ii`)
- Master branch: `master` (contains all projects)

### External Library Handling
Options:
1. Exclude from import (recommended - can re-clone from upstream)
2. Import as separate branches (preserves fork history if modified)
3. Convert to submodules (complex)

## Related Documents
- `006-initialize-master-branch.md` - Master branch setup
- `007-remote-repository-setup.md` - Remote configuration
- `005-configure-branch-isolation.md` - Branch isolation strategy

## Metadata
- **Priority**: High
- **Complexity**: Medium-High
- **Dependencies**: None
- **Impact**: Preserves project development history

## Success Criteria
- All project histories imported as branches
- Each branch contains complete commit history from original repo
- Master branch created with all project files
- Embedded `.git` directories removed after import
- Repository ready for remote push
