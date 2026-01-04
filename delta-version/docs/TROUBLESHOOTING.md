# Troubleshooting Guide

This guide provides solutions for common issues encountered when working with the ai-stuff monorepo and delta-version tools.

## Quick Diagnostics

Before diving into specific issues, run the validation script to identify problems:

```bash
# Quick check (structural tests only)
./delta-version/scripts/validate-repository.sh --quick

# Full validation (includes git operations and script tests)
./delta-version/scripts/validate-repository.sh --verbose

# Auto-fix minor issues (permissions, etc.)
./delta-version/scripts/validate-repository.sh --fix
```

---

## Script Execution Issues

### Script Not Found or Permission Denied

**Symptoms:**
- `command not found` errors
- `Permission denied` when running scripts

**Causes:**
- Running script from wrong directory
- Script lacks execute permissions
- Missing shebang line

**Solutions:**

```bash
# 1. Run scripts with full path (preferred)
/mnt/mtwo/programming/ai-stuff/delta-version/scripts/list-projects.sh

# 2. Or use bash explicitly
bash ./delta-version/scripts/list-projects.sh

# 3. Fix permissions if needed
chmod +x ./delta-version/scripts/*.sh

# 4. Verify script has proper shebang
head -1 ./delta-version/scripts/list-projects.sh
# Should show: #!/bin/bash
```

### Script Output is Empty or Unexpected

**Symptoms:**
- Scripts return nothing when data is expected
- JSON output malformed

**Causes:**
- Working from wrong directory
- DIR variable not set correctly
- Missing dependencies

**Solutions:**

```bash
# 1. Set DIR explicitly when running from non-standard location
DIR=/mnt/mtwo/programming/ai-stuff ./delta-version/scripts/list-projects.sh

# 2. Check script help for options
./delta-version/scripts/list-projects.sh --help

# 3. Run with verbose mode if available
./delta-version/scripts/list-projects.sh --verbose
```

---

## Git Operations Issues

### Branch Switching Problems

**Symptoms:**
- `error: Your local changes to the following files would be overwritten`
- Unexpected files appearing after checkout

**Causes:**
- Uncommitted changes conflict with target branch
- Sparse-checkout configuration mismatch

**Solutions:**

```bash
# 1. Stash changes before switching
git stash
git checkout target-branch
git stash pop

# 2. Check what would change
git diff --stat HEAD target-branch

# 3. Force checkout (CAUTION: discards local changes)
git checkout -f target-branch
```

### Remote Repository Synchronization

**Symptoms:**
- `fatal: 'origin' does not appear to be a git repository`
- `refusing to merge unrelated histories`

**Causes:**
- Remote not configured
- Repository was re-initialized

**Solutions:**

```bash
# 1. Check remote configuration
git remote -v

# 2. Add remote if missing
git remote add origin https://github.com/username/ai-stuff.git

# 3. For unrelated histories (use cautiously)
git pull origin master --allow-unrelated-histories
```

### Large Repository Performance

**Symptoms:**
- `git status` takes a long time
- Clone operations timeout

**Causes:**
- Many files or large history
- Network issues

**Solutions:**

```bash
# 1. Use shallow clone for faster initial download
git clone --depth 1 https://github.com/username/ai-stuff.git

# 2. Enable filesystem monitor for faster status
git config core.fsmonitor true

# 3. Enable untracked cache
git config core.untrackedCache true
```

---

## History Tools Issues

### reconstruct-history.sh Problems

**Symptoms:**
- `No projects found for history reconstruction`
- Dates showing as "Unknown"
- Missing project entries

**Causes:**
- Project directory structure incomplete
- Missing vision.md or CLAUDE.md files
- Date markers not parseable

**Solutions:**

```bash
# 1. Check project is detected
./delta-version/scripts/list-projects.sh | grep project-name

# 2. Verify project has required files
ls -la ./project-name/notes/vision.md
ls -la ./project-name/.claude/CLAUDE.md

# 3. Run in debug mode
./delta-version/scripts/reconstruct-history.sh --project project-name --verbose

# 4. Check date format in files (should be YYYY-MM-DD)
grep -r "202[0-9]-[0-9][0-9]-[0-9][0-9]" ./project-name/notes/
```

### generate-history.sh Output Issues

**Symptoms:**
- HISTORY.txt is empty or incomplete
- Formatting looks wrong

**Causes:**
- No commits in specified range
- Output file permissions

**Solutions:**

```bash
# 1. Run dry-run first to preview
./delta-version/scripts/generate-history.sh --project delta-version --dry-run

# 2. Check output directory is writable
touch ./delta-version/docs/test-write && rm ./delta-version/docs/test-write

# 3. Regenerate with explicit output path
./delta-version/scripts/generate-history.sh --project delta-version --output ./docs/HISTORY.txt
```

---

## Gitignore Issues

### Files Not Being Ignored

**Symptoms:**
- Tracked files appear in `git status`
- Build artifacts showing up

**Causes:**
- File was tracked before adding to .gitignore
- Pattern syntax incorrect

**Solutions:**

```bash
# 1. Remove file from index (keeps local copy)
git rm --cached path/to/file

# 2. For directories
git rm -r --cached path/to/directory/

# 3. Validate gitignore patterns
./delta-version/scripts/validate-gitignore.sh

# 4. Test if pattern matches
git check-ignore -v path/to/file
```

### Gitignore Conflicts Between Projects

**Symptoms:**
- Unified gitignore causes unexpected behavior
- Project-specific patterns not working

**Solutions:**

```bash
# 1. Check which gitignore applies
git check-ignore -v --no-index path/to/file

# 2. Analyze all gitignore files
./delta-version/scripts/analyze-gitignore.sh

# 3. Regenerate unified gitignore
./delta-version/scripts/generate-unified-gitignore.sh
```

---

## Issue Management Problems

### manage-issues.sh Not Finding Issues

**Symptoms:**
- `No issues found`
- Status counts are wrong

**Causes:**
- Issue files not in expected location
- Issue format doesn't match expected pattern

**Solutions:**

```bash
# 1. Check issue directory structure
find ./delta-version/issues -name "*.md" -type f

# 2. Verify issue file format (should start with # Issue XXX:)
head -5 ./delta-version/issues/008-validation-and-documentation.md

# 3. List issues with verbose output
./delta-version/scripts/manage-issues.sh --list --verbose
```

---

## Environment Issues

### Missing Dependencies

**Symptoms:**
- `command not found: jq`
- `bash: syntax error` on older bash versions

**Required tools:**
- `bash` 4.0+ (for associative arrays)
- `git` 2.0+
- `jq` (for JSON processing in some scripts)
- `find`, `grep`, `awk`, `sed` (standard POSIX tools)

**Solutions:**

```bash
# Check bash version
bash --version

# Check git version
git --version

# Install jq if missing (Void Linux)
sudo xbps-install -S jq

# Install jq (Debian/Ubuntu)
sudo apt install jq
```

### Path and Working Directory Issues

**Symptoms:**
- Scripts work from one directory but not another
- Relative paths break

**Causes:**
- Scripts expect specific working directory
- DIR variable not set

**Solutions:**

```bash
# 1. Always use DIR override when running from different location
DIR=/mnt/mtwo/programming/ai-stuff ./delta-version/scripts/script-name.sh

# 2. Check what DIR is currently set to in script
grep "^DIR=" ./delta-version/scripts/script-name.sh

# 3. Set DIR in environment for multiple commands
export DIR=/mnt/mtwo/programming/ai-stuff
./delta-version/scripts/list-projects.sh
./delta-version/scripts/validate-repository.sh
```

---

## Documentation Issues

### Broken Links in Table of Contents

**Symptoms:**
- Links in documentation lead to 404 or file not found

**Solutions:**

```bash
# 1. Run validation with verbose to see link status
./delta-version/scripts/validate-repository.sh --verbose

# 2. Find all markdown links and check manually
grep -oE '\[[^]]+\]\([^)]+\)' ./delta-version/docs/table-of-contents.md

# 3. Check if referenced file exists
ls -la ./delta-version/docs/referenced-file.md
```

---

## Common Error Messages

| Error Message | Likely Cause | Quick Fix |
|---------------|--------------|-----------|
| `Permission denied` | Missing execute permission | `chmod +x script.sh` |
| `command not found` | Script not in PATH or wrong directory | Use full path |
| `No such file or directory` | Wrong working directory | Set DIR variable |
| `invalid option` | Wrong argument syntax | Check `--help` output |
| `fatal: not a git repository` | Running outside repo | `cd` to repo root |
| `detached HEAD state` | Checked out specific commit | `git checkout master` |

---

## Getting More Help

1. **Run with verbose mode**: Most scripts support `--verbose` or `-v`
2. **Check script help**: Run `script-name.sh --help`
3. **Read the docs**: See [table-of-contents.md](table-of-contents.md) for all documentation
4. **Validate first**: Run `validate-repository.sh` to identify structural issues
5. **Check git status**: Many issues stem from uncommitted changes or wrong branch

## Reporting Issues

If you encounter a problem not covered here:

1. Run `validate-repository.sh --verbose` and capture output
2. Note the exact command that failed and the error message
3. Check `git status` and `git branch` output
4. Create an issue in `delta-version/issues/` following the template in `docs/issue-template.md`
