# Troubleshooting Guide

Common issues and solutions for the ai-stuff monorepo.

## Quick Diagnostics

Run the validation script first to identify issues:

```bash
# Quick structural check
./delta-version/scripts/validate-repository.sh --quick

# Full validation (slower but comprehensive)
./delta-version/scripts/validate-repository.sh

# Verbose output for debugging
./delta-version/scripts/validate-repository.sh --verbose
```

---

## Git Issues

### "Permission denied" when running scripts

**Symptom**: `bash: ./delta-version/scripts/list-projects.sh: Permission denied`

**Cause**: Script is not executable.

**Solution**:
```bash
chmod +x ./delta-version/scripts/*.sh
```

Or use the validation script with `--fix`:
```bash
./delta-version/scripts/validate-repository.sh --fix
```

---

### Clone is too slow or large

**Symptom**: `git clone` takes forever or uses too much disk space.

**Cause**: Repository contains many projects with full history.

**Solution**: Use shallow clone:
```bash
# Clone only recent history
git clone --depth 1 https://github.com/gabrilend/ai-stuff.git

# Later, if you need full history
git fetch --unshallow
```

---

### "Detached HEAD" after switching branches

**Symptom**: `git status` shows "HEAD detached at..."

**Cause**: Checking out a commit directly instead of a branch.

**Solution**:
```bash
# Return to master
git checkout master

# Or create a branch at current position
git checkout -b new-branch-name
```

---

## Script Issues

### list-projects.sh returns no projects

**Symptom**: Running `./delta-version/scripts/list-projects.sh` produces no output.

**Cause**: Either the script can't find the repository, or you're in the wrong directory.

**Solution**:
```bash
# Specify the directory explicitly
./delta-version/scripts/list-projects.sh /path/to/ai-stuff

# Or set DIR environment variable
DIR=/path/to/ai-stuff ./delta-version/scripts/list-projects.sh
```

---

### generate-history.sh produces empty file

**Symptom**: HISTORY.txt is generated but contains no commits.

**Cause**: Project has no commits or the project name doesn't match a directory.

**Solution**:
```bash
# Verify project exists
./delta-version/scripts/list-projects.sh | grep "project-name"

# Check if project has commits
git log --oneline -- project-name/ | head -5

# Use dry-run to debug
./delta-version/scripts/generate-history.sh --project project-name --dry-run
```

---

### reconstruct-history.sh fails with "already has git history"

**Symptom**: Script refuses to run, saying project already has history.

**Cause**: Project has existing `.git` directory or commits.

**Solution**: Either this is intended (skip reconstruction), or force it:
```bash
# Preview what would happen
./delta-version/scripts/reconstruct-history.sh --dry-run /path/to/project

# Force reconstruction (DESTROYS existing history!)
./delta-version/scripts/reconstruct-history.sh --force /path/to/project
```

---

### manage-issues.sh can't find issues directory

**Symptom**: "Issues directory not found" error.

**Cause**: Running from wrong directory or project has no issues/ directory.

**Solution**:
```bash
# Navigate to project root first
cd /path/to/ai-stuff/project-name

# Or specify project explicitly
./delta-version/scripts/manage-issues.sh --project project-name list
```

---

## Interactive Mode Issues

### Arrow keys don't work in menus

**Symptom**: Pressing arrow keys types `^[[A` instead of navigating.

**Cause**: Terminal not properly configured for interactive input.

**Solution**: Try using number-based selection instead (most menus support this), or:
```bash
# Check terminal type
echo $TERM

# Set standard terminal
export TERM=xterm-256color
```

---

### Script hangs waiting for input

**Symptom**: Script seems frozen after printing a menu.

**Cause**: Running in a non-interactive environment (like Claude Code's terminal).

**Solution**: Use headless mode with flags instead of interactive mode:
```bash
# Instead of: ./script.sh -I
# Use flags:  ./script.sh --project my-project --option value
```

---

## Documentation Issues

### Broken links in table-of-contents

**Symptom**: Validation reports "Broken link: ../issues/XYZ.md"

**Cause**: Documentation references a file that doesn't exist (often an issue that hasn't been created yet, or was moved to completed/).

**Solution**: Either create the missing file, or update the table-of-contents to remove the broken reference:
```bash
# Check which links are broken
./delta-version/scripts/validate-repository.sh 2>&1 | grep "Broken link"

# Edit table of contents
vim delta-version/docs/table-of-contents.md
```

---

### Project missing standard directories

**Symptom**: Validation shows "projects without docs/ directory"

**Cause**: Not all projects follow the full directory structure.

**Solution**: This is often intentional for smaller projects. If you want to add them:
```bash
cd project-name
mkdir -p docs notes issues src libs assets
```

---

## Environment Issues

### "DIR: unbound variable" error

**Symptom**: Script fails with "DIR: unbound variable"

**Cause**: Running in strict mode without DIR being set.

**Solution**: Most scripts set a default DIR, but you can set it explicitly:
```bash
export DIR=/mnt/mtwo/programming/ai-stuff
./delta-version/scripts/some-script.sh
```

---

### Different behavior on different machines

**Symptom**: Script works on one machine but not another.

**Cause**: Different shell versions, missing utilities, or different default behaviors.

**Solutions**:
1. Check bash version: `bash --version` (need bash 4.0+)
2. Install required tools: `git`, `stat`, `find`, `grep`
3. Check for GNU vs BSD differences (macOS uses BSD tools):
   ```bash
   # On macOS, install GNU tools
   brew install coreutils findutils gnu-sed
   ```

---

## History Reconstruction Issues

### Dates are wrong on reconstructed commits

**Symptom**: `git log` shows all commits on the same date, or dates are clearly incorrect.

**Cause**: File modification times weren't preserved, or explicit dates in issue files are missing.

**Solution**:
```bash
# Check date sources with verbose mode
./delta-version/scripts/reconstruct-history.sh --verbose --dry-run /path/to/project

# Ensure files have correct mtimes when copying
cp -a source/ destination/  # -a preserves timestamps

# Add explicit dates to issue files
# In the issue file:
# **Completed**: 2024-06-15
```

---

### Issues committed in wrong order

**Symptom**: Dependent issues appear before their dependencies.

**Cause**: Dependency fields not parsed correctly or circular dependencies exist.

**Solution**:
```bash
# Check dependency detection with verbose mode
./delta-version/scripts/reconstruct-history.sh --verbose --dry-run /path/to/project

# Verify issue files have proper dependency fields:
# **Dependencies**: 001, 002
# **Blocked By**: Issue 003
```

---

## Getting More Help

1. **Read the documentation**: `delta-version/docs/table-of-contents.md`
2. **Check issue files**: Look for similar issues in `delta-version/issues/`
3. **Run validation**: `./delta-version/scripts/validate-repository.sh --verbose`
4. **Use dry-run**: Most scripts support `--dry-run` to preview actions
5. **Check CLAUDE.md**: Project-specific conventions and guidelines

## Reporting Issues

If you find a bug or have a suggestion:

1. Check existing issues in `delta-version/issues/`
2. Create a new issue file following the template:
   - Current Behavior
   - Intended Behavior
   - Suggested Implementation Steps

3. Or report at: https://github.com/gabrilend/ai-stuff/issues
