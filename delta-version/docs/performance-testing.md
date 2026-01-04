# Performance Testing and Optimization Guide

This document covers performance benchmarking, testing procedures, and optimization strategies for the ai-stuff monorepo.

## Overview

The ai-stuff repository contains multiple projects (20+ as of this writing) with a combined codebase of 100+ Lua files and substantial git history. Performance considerations include:

- Repository clone and fetch times
- Branch switching speed
- Script execution time
- Git operations on large file sets
- Documentation generation

---

## Performance Benchmarks

### Baseline Metrics

Run these commands to establish baseline performance on your system:

```bash
# Time full validation suite
time ./delta-version/scripts/validate-repository.sh

# Time quick validation
time ./delta-version/scripts/validate-repository.sh --quick

# Time project listing
time ./delta-version/scripts/list-projects.sh > /dev/null

# Time history reconstruction dry-run
time ./delta-version/scripts/reconstruct-history.sh --all --dry-run

# Git status timing
time git status
```

### Expected Performance Ranges

| Operation | Expected Time | Notes |
|-----------|---------------|-------|
| Quick validation | 2-5 seconds | Structural tests only |
| Full validation | 5-15 seconds | Includes script tests |
| list-projects.sh | < 1 second | Filesystem scan |
| git status | 1-3 seconds | Depends on working tree state |
| Branch switch | 1-5 seconds | Depends on file differences |
| Full clone | 30-120 seconds | Network dependent |
| Shallow clone | 10-30 seconds | --depth 1 |

---

## Performance Testing Scripts

### Basic Benchmark Script

```bash
#!/bin/bash
# benchmark-basic.sh - Basic performance benchmarking
# Runs key operations and reports timing

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
DELTA_DIR="${DIR}/delta-version"

echo "=== AI-Stuff Repository Performance Benchmark ==="
echo "Repository: $DIR"
echo "Date: $(date)"
echo ""

# Warm up filesystem cache
ls -laR "$DIR" > /dev/null 2>&1

echo "1. list-projects.sh timing:"
time "${DELTA_DIR}/scripts/list-projects.sh" > /dev/null

echo ""
echo "2. validate-repository.sh --quick timing:"
time "${DELTA_DIR}/scripts/validate-repository.sh" --quick > /dev/null

echo ""
echo "3. git status timing:"
time git -C "$DIR" status > /dev/null

echo ""
echo "4. File count in repository:"
find "$DIR" -type f | wc -l

echo ""
echo "5. Git object count:"
git -C "$DIR" count-objects -v | grep "count:"
```

### Detailed Script Performance Test

```bash
#!/bin/bash
# benchmark-scripts.sh - Detailed script performance testing
# Tests each major script with timing and resource usage

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
SCRIPTS_DIR="${DIR}/delta-version/scripts"

# Function to run timed command with /usr/bin/time for detailed stats
benchmark_script() {
    local script="$1"
    local args="${2:-}"

    echo "Testing: $(basename "$script") $args"
    /usr/bin/time -v "${script}" ${args} 2>&1 | grep -E "(Elapsed|Maximum resident)"
    echo ""
}

echo "=== Script Performance Analysis ==="
echo ""

benchmark_script "${SCRIPTS_DIR}/list-projects.sh"
benchmark_script "${SCRIPTS_DIR}/list-projects.sh" "--format json"
benchmark_script "${SCRIPTS_DIR}/validate-repository.sh" "--quick"
benchmark_script "${SCRIPTS_DIR}/validate-gitignore.sh" "--quiet"
```

---

## Optimization Strategies

### Git Performance Optimizations

```bash
# 1. Enable filesystem monitor (recommended for large repos)
git config core.fsmonitor true

# 2. Enable untracked cache
git config core.untrackedCache true

# 3. Enable commit graph for faster log operations
git commit-graph write --reachable

# 4. Enable maintenance for automatic optimization
git maintenance start

# 5. Pack loose objects periodically
git gc --auto

# 6. Configure parallel fetching
git config fetch.parallel 4
```

### Script Optimization Techniques

The delta-version scripts follow these performance principles:

1. **Early Exit**: Scripts exit as soon as they can determine the result
2. **Lazy Loading**: Data is only processed when needed
3. **Caching**: Results are cached where appropriate (see reconstruct-history.sh)
4. **Parallel Processing**: Independent operations run concurrently where possible

Example optimization pattern used in scripts:

```bash
# Early exit pattern - check requirements before expensive operations
if [[ "$QUICK_MODE" == true ]]; then
    print_result "SKIP" "Expensive operation (quick mode)"
    return 0
fi

# Cache pattern - avoid redundant filesystem operations
if [[ -z "${PROJECT_LIST:-}" ]]; then
    PROJECT_LIST=$("${SCRIPTS_DIR}/list-projects.sh")
fi
```

### Filesystem Optimizations

```bash
# 1. Use find with -maxdepth when deep recursion not needed
find "$DIR" -maxdepth 2 -name "*.md" -type f

# 2. Prefer glob patterns over find when possible
# Faster:
ls "$DIR"/*/docs/*.md 2>/dev/null
# Slower:
find "$DIR" -path "*/docs/*.md" -type f

# 3. Use -quit with find when only checking existence
if find "$DIR" -name "target.md" -print -quit | grep -q .; then
    echo "Found"
fi
```

---

## Performance Monitoring

### Watch Repository Growth

Track repository metrics over time:

```bash
#!/bin/bash
# log-repo-stats.sh - Log repository statistics for trend analysis

DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
LOG_FILE="${DIR}/delta-version/docs/repo-stats.log"

{
    echo "=== $(date -Iseconds) ==="
    echo "File count: $(find "$DIR" -type f | wc -l)"
    echo "Directory count: $(find "$DIR" -type d | wc -l)"
    echo "Project count: $("${DIR}/delta-version/scripts/list-projects.sh" | wc -l)"
    echo "Issue count: $(find "${DIR}/delta-version/issues" -name "*.md" | wc -l)"
    echo "Git objects: $(git -C "$DIR" count-objects | awk '{print $1}')"
    echo "Repo size: $(du -sh "$DIR" | cut -f1)"
    echo ""
} >> "$LOG_FILE"
```

### Identifying Slow Operations

```bash
# Use strace to identify slow syscalls
strace -c ./delta-version/scripts/list-projects.sh 2>&1 | tail -20

# Profile bash script execution
bash -x ./delta-version/scripts/script-name.sh 2>&1 | head -50
```

---

## Performance Testing Checklist

### Before Making Changes

- [ ] Record baseline metrics using benchmark scripts
- [ ] Identify the specific operation that needs optimization
- [ ] Understand why the operation is slow (I/O, CPU, network?)

### After Making Changes

- [ ] Re-run benchmark scripts to measure improvement
- [ ] Verify functionality still works (run validate-repository.sh)
- [ ] Document the optimization in commit message
- [ ] Update this guide if new optimization techniques discovered

### Regular Maintenance

- [ ] Run `git gc` periodically (monthly)
- [ ] Check repository size growth
- [ ] Review and prune old branches
- [ ] Update commit graph (`git commit-graph write --reachable`)

---

## Performance Anti-Patterns

Avoid these patterns that hurt performance:

1. **Nested loops over git commands**: Each git invocation has overhead
   ```bash
   # Bad: runs git N times
   for file in $(find . -name "*.md"); do
       git log -1 "$file"
   done

   # Better: run git once
   git log --name-only --pretty=format: -- '*.md' | sort -u
   ```

2. **Unnecessary subshells**: Subshells have overhead
   ```bash
   # Bad: creates subshell
   result=$(cat file.txt)

   # Better: uses built-in
   result=$(<file.txt)
   ```

3. **Piping to grep for simple patterns**: Use bash built-ins
   ```bash
   # Bad: external process
   if echo "$string" | grep -q "pattern"; then

   # Better: bash pattern matching
   if [[ "$string" == *"pattern"* ]]; then
   ```

4. **Reading files line by line in bash**: Slow for large files
   ```bash
   # Bad: slow loop
   while read line; do
       process "$line"
   done < file.txt

   # Better: use awk/sed for bulk processing
   awk '/pattern/ {process}' file.txt
   ```

---

## Related Documents

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions
- [development-guide.md](development-guide.md) - Development conventions
- [api-reference.md](api-reference.md) - Script documentation
- [history-tools-guide.md](history-tools-guide.md) - History tool usage

---

## Metrics Log

Record significant performance changes here:

| Date | Change | Before | After | Notes |
|------|--------|--------|-------|-------|
| 2024-12-17 | Initial validate-repository.sh | N/A | ~5s (quick) | Baseline |
| 2025-01-04 | Performance guide created | N/A | N/A | Documentation |
