# Issue 001: Add authorship-tool to manage-worktree.sh VALID_PROJECTS

**Phase**: 0 - Bug Fix
**Status**: Open
**Priority**: High (blocking initialization)
**Created**: 2026-01-08

---

## Current Behavior

The `delta-version/scripts/manage-worktree.sh` script does not include `authorship-tool` in its `VALID_PROJECTS` array. This causes two problems:

1. **Validation fails**: When trying to create a worktree for authorship-tool issues, the script rejects the project name:
   ```
   [ERROR] Invalid project: authorship-tool
   [ERROR] Valid projects: delta-version neocities-modernization world-edit-to-execute
   ```

2. **Wrong path assumption**: Even if validation somehow passed, without proper configuration the worktree path would be incorrect.

**Current VALID_PROJECTS** (line 23 of manage-worktree.sh):
```bash
VALID_PROJECTS=("delta-version" "neocities-modernization" "world-edit-to-execute")
```

---

## Intended Behavior

The script should:
- Include `authorship-tool` in the `VALID_PROJECTS` array
- Create worktrees at the correct path: `/mnt/mtwo/programming/ai-worktrees/authorship-tool/issue-XXX/`
- Pass validation when initializing authorship-tool issues

---

## Root Cause

The `manage-worktree.sh` script was created for the original three projects in the mono-repo before `authorship-tool` was added. The VALID_PROJECTS array needs to be updated to include the new project.

---

## Suggested Implementation Steps

1. Open `/home/ritz/programming/ai-stuff/delta-version/scripts/manage-worktree.sh`
2. Locate line 23: `VALID_PROJECTS=(...)`
3. Add `"authorship-tool"` to the array:
   ```bash
   VALID_PROJECTS=("delta-version" "neocities-modernization" "world-edit-to-execute" "authorship-tool")
   ```
4. Verify `get_short_project_name()` function (lines 38-48)
   - Currently, unknown projects fall through to default case: `echo "$project"`
   - For `authorship-tool`, this will return `"authorship-tool"` (full name, no abbreviation)
   - This is correct behavior for this project
5. Test worktree creation:
   ```bash
   cd /home/ritz/programming/ai-stuff
   ./delta-version/scripts/manage-worktree.sh create 101 authorship-tool
   ```
6. Verify worktree created at: `/mnt/mtwo/programming/ai-worktrees/authorship-tool/issue-101/`
7. Clean up test worktree:
   ```bash
   ./delta-version/scripts/manage-worktree.sh remove 101 authorship-tool
   ```

---

## Expected Worktree Path Format

For `authorship-tool` issues:
- Issue 101: `/mnt/mtwo/programming/ai-worktrees/authorship-tool/issue-101/`
- Issue 201: `/mnt/mtwo/programming/ai-worktrees/authorship-tool/issue-201/`

**NOT** (incorrect path):
- ~~`/mnt/mtwo/programming/ai-worktrees/dv/issue-101/authorship-tool`~~

---

## Testing Criteria

- [ ] `manage-worktree.sh` validation accepts "authorship-tool" as valid project
- [ ] Worktree created at correct path: `/mnt/mtwo/programming/ai-worktrees/authorship-tool/issue-XXX/`
- [ ] Can create worktree: `./manage-worktree.sh create 101 authorship-tool`
- [ ] Can get path: `./manage-worktree.sh path 101 authorship-tool`
- [ ] Can list worktrees: `./manage-worktree.sh list authorship-tool`
- [ ] Can remove worktree: `./manage-worktree.sh remove 101 authorship-tool`
- [ ] `initialize-issue.sh` works with authorship-tool issues

---

## Files to Modify

- `/home/ritz/programming/ai-stuff/delta-version/scripts/manage-worktree.sh` (line 23)

---

## Dependencies

None - this is a prerequisite for initializing authorship-tool issues

---

## Blocks

- All authorship-tool Phase 1 issues (101-107)
- All authorship-tool Phase 2 issues (201-207)
- Any use of `initialize-issue.sh` for authorship-tool

---

## Notes

This is a simple one-line fix to add the project to the valid projects array. The existing path generation logic will work correctly once validation passes, creating worktrees at:

```
/mnt/mtwo/programming/ai-worktrees/authorship-tool/issue-XXX/
```

The short name logic doesn't need updating because the default case (returning the full project name) is the desired behavior for authorship-tool.
