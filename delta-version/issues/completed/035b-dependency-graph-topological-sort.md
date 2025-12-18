# Issue 035b: Dependency Graph and Topological Sort

## Parent Issue
- **Issue 035**: Project History Reconstruction from Issue Files

## Current Behavior (Before Implementation)

The `reconstruct-history.sh` script ordered completed issues purely by filename using `sort -V`, which gives numerical order (001, 002, 003...) but ignores dependency relationships between issues.

This meant:
- Issues could be committed before their dependencies
- The git history wouldn't reflect the actual development order
- Blocking relationships in issue files were ignored

## Implemented Behavior

Added dependency graph construction and topological sorting to order issues correctly:

### New Functions

1. **`extract_issue_id()`**: Extracts issue ID (e.g., `035b`) from filename
2. **`parse_issue_dependencies()`**: Parses `Dependencies:` and `Blocked By:` fields
3. **`parse_issue_blocks()`**: Parses `Blocks:` field (reverse relationship)
4. **`build_dependency_graph()`**: Constructs graph from all issue files
5. **`topological_sort_issues()`**: Implements Kahn's algorithm for sorting
6. **`order_issues_by_dependencies()`**: Main function combining graph + sort

### Dependency Detection

Parses these patterns in issue files:
```markdown
- **Dependencies**: 001, 002, 003
- **Blocked By**: Issue 005
* Dependencies: 023, 024
```

Also handles reverse relationships:
```markdown
- **Blocks**: 008, 036
```
If issue A blocks issue B, then B depends on A.

### Algorithm

Uses Kahn's algorithm for topological sorting:
1. Build directed graph from dependency relationships
2. Calculate in-degree (dependency count) for each node
3. Initialize queue with nodes having in-degree 0
4. Process queue: output node, decrement dependents' in-degrees
5. When dependent reaches in-degree 0, add to queue
6. Sort queue by issue number for deterministic output

### Output

Commits are now created in dependency order:
```
  [2] 004-extract-project-histories (depends on: 001)
  [3] 006-initialize-master-branch (depends on: 001 002)
  [4] 007-remote-repository-setup (depends on: 005 006)
  ...
```

Issues with unmet dependencies (dependency not in completed list) are treated as having those dependencies already satisfied.

## Files Changed

- `delta-version/scripts/reconstruct-history.sh`:
  - Added dependency graph section (035b)
  - Updated `reconstruct_history()` to use `order_issues_by_dependencies()`
  - Updated `dry_run_report()` to show dependency info
  - Updated help text to document new ordering behavior

## Testing

Tested with dry-run on delta-version project:
```bash
./reconstruct-history.sh --dry-run --verbose /path/to/delta-version
```

Shows issues correctly ordered by dependencies with verbose output showing the graph construction.

## Related Documents
- **Issue 035**: Parent issue for project history reconstruction
- **Issue 035a**: Project detection and external import (completed)
- **Issue 035c**: Date estimation from file timestamps (next)

## Metadata
- **Priority**: High (part of 035)
- **Complexity**: Medium
- **Dependencies**: Issue 035a
- **Blocks**: Issue 035c, 035d, 035e
- **Completed**: 2025-12-17

## Success Criteria

- [x] `parse_issue_dependencies()` extracts Dependencies and Blocked By fields
- [x] `parse_issue_blocks()` extracts Blocks field
- [x] `build_dependency_graph()` constructs complete graph from issue files
- [x] `topological_sort_issues()` implements Kahn's algorithm
- [x] `order_issues_by_dependencies()` combines graph building and sorting
- [x] Issues with no dependencies sorted by issue number
- [x] Issues with missing dependencies (not in completed list) handled correctly
- [x] Dry-run shows dependency information
- [x] Help text documents new functionality
