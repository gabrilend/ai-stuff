# Branch Topology and Dependency Visualization

## The Question

> Can you branch inside of a branch? Or is that a fork?

## Git Branching Explained

In Git, **branches are not nested containers** - they're simply **pointers to commits**. When you "branch from a branch," you're creating a new pointer that starts at the same commit as the source branch.

```
          A---B---C  feature-x
         /
    D---E---F---G  main
             \
              H---I  feature-y (branched from main at F)
                   \
                    J---K  feature-y-subfeature (branched from feature-y at I)
```

### Branch vs Fork

| Concept | Definition | Location |
|---------|------------|----------|
| **Branch** | A movable pointer to a commit | Same repository |
| **Fork** | A complete copy of a repository | Different repository (usually different remote) |

You can absolutely create branches from other branches. This is common in workflows like:

- **Feature branches** from `main`
- **Sub-feature branches** from feature branches
- **Hotfix branches** from release branches

## The Idea: Issue-Driven Branch Topology

### Concept

Use the `Dependencies` and `Blocks` relationships already parsed from issue files (implemented in Issue 035b) to:

1. **Create separate branches** for each issue or section of work
2. **Automatically merge** in dependency order
3. **Generate a visual tree diagram** of project structure
4. **Enable impact analysis** for debugging

### Why This Is Interesting

The dependency graph we already build in `reconstruct-history.sh` using Kahn's algorithm for topological sort contains exactly this information. We're currently using it only to order commits, but it could also drive:

1. **Parallel development workflows**
2. **Automated merge sequencing**
3. **Visual documentation**
4. **Debug impact analysis**

## Proposed Architecture

### Phase 1: Dependency Graph Extraction

We already have this in `build_dependency_graph()` and `topological_sort_issues()`:

```
Input (from issue files):
  001 → []              (no dependencies)
  002 → [001]           (depends on 001)
  003 → [001]           (depends on 001)
  004 → [002, 003]      (depends on both)

Output (topological order):
  001 → 002 → 003 → 004
  or
  001 → 003 → 002 → 004
```

### Phase 2: Branch-Per-Issue Strategy

```
main ─────────────────────────────────────────────────────▶

issue-001 ─────┬───────────────────────────────────────────▶
               │
issue-002 ─────┴──────┬────────────────────────────────────▶
                      │
issue-003 ────────────┴───────┬────────────────────────────▶
                              │
issue-004 ────────────────────┴────────────────────────────▶
```

Each issue gets its own branch. Branches are created from their dependency branches and merged back in topological order.

### Phase 3: Tree Diagram Generation

```
┌─────────────────────────────────────────────────────────────┐
│                  Project Dependency Tree                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│                        ┌──────┐                              │
│                        │ 001  │  Foundation                  │
│                        └───┬──┘                              │
│                    ┌───────┴───────┐                         │
│                    │               │                         │
│                ┌───┴──┐       ┌────┴─┐                       │
│                │ 002  │       │ 003  │  Parallel work        │
│                └───┬──┘       └────┬─┘                       │
│                    │               │                         │
│                    └───────┬───────┘                         │
│                        ┌───┴──┐                              │
│                        │ 004  │  Integration                 │
│                        └──────┘                              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Approaches

### Option A: Full Branch-Per-Issue (Heavy)

Create actual git branches for each issue. Pros: Full isolation, can work in parallel. Cons: Branch explosion, complex merge management.

```bash
# For each issue in topological order
for issue in $(topological_sort_issues); do
    deps=$(get_dependencies "$issue")

    if [[ -z "$deps" ]]; then
        git checkout -b "issue-$issue" main
    else
        # Create from the merge of all dependencies
        git checkout -b "issue-$issue" "issue-${deps[0]}"
        for dep in "${deps[@]:1}"; do
            git merge "issue-$dep"
        done
    fi

    # Work happens here...
    # Then merge back to main
done
```

### Option B: Visualization Only (Light)

Don't create branches, just generate the tree diagram from issue metadata. This is useful for:

- Understanding project structure
- Identifying bottlenecks (issues that block many others)
- Debug impact analysis

```bash
# Generate DOT format for graphviz
generate_dependency_dot() {
    echo "digraph dependencies {"
    echo "  rankdir=TB;"

    for issue_file in issues/completed/*.md; do
        issue_id=$(extract_issue_id "$issue_file")
        deps=$(parse_issue_dependencies "$issue_file")

        for dep in $deps; do
            echo "  \"$dep\" -> \"$issue_id\";"
        done
    done

    echo "}"
}

# Usage: generate_dependency_dot | dot -Tpng -o deps.png
```

### Option C: Hybrid (Recommended)

1. **Generate visualization** from issue metadata (always)
2. **Optionally create branches** when requested (`--create-branches`)
3. **Auto-merge script** that follows topological order

## Debug Use Cases

### 1. Impact Analysis

"If I change code related to Issue 003, what else might break?"

```
Issue 003 is blocked by: [001]
Issue 003 blocks: [004, 007, 012]

Impact radius: 4 issues may be affected
```

### 2. Root Cause Tracing

"Bug appeared after Issue 012. What's the dependency chain?"

```
012 ← 007 ← 004 ← 003 ← 001
                 ↖ 002 ↙

Check: 001, 002, 003, 004, 007, then 012
```

### 3. Parallel Work Identification

"Which issues can be worked on simultaneously?"

```
No dependencies (can start now):
  - 001, 016, 024

After 001 completes:
  - 002, 003, 009 can start in parallel
```

## ASCII Tree Generator (Prototype)

```bash
# -- {{{ generate_ascii_tree
generate_ascii_tree() {
    local project_dir="$1"
    local completed_dir="${project_dir}/issues/completed"

    echo "Project Dependency Tree"
    echo "========================"
    echo ""

    # Find root nodes (no dependencies)
    local -a roots=()
    for issue_file in "$completed_dir"/*.md; do
        local deps=$(parse_issue_dependencies "$issue_file")
        if [[ -z "$deps" ]]; then
            roots+=("$(extract_issue_id "$issue_file")")
        fi
    done

    # Recursive tree printer
    print_tree() {
        local node="$1"
        local prefix="$2"
        local is_last="$3"

        local connector="├──"
        [[ "$is_last" == true ]] && connector="└──"

        echo "${prefix}${connector} $node"

        # Find children (issues that depend on this one)
        local -a children=()
        for issue_file in "$completed_dir"/*.md; do
            local deps=$(parse_issue_dependencies "$issue_file")
            if echo " $deps " | grep -q " $node "; then
                children+=("$(extract_issue_id "$issue_file")")
            fi
        done

        local child_prefix="$prefix"
        [[ "$is_last" == true ]] && child_prefix+="    " || child_prefix+="│   "

        local i=0
        for child in "${children[@]}"; do
            ((i++))
            local child_is_last=false
            [[ $i -eq ${#children[@]} ]] && child_is_last=true
            print_tree "$child" "$child_prefix" "$child_is_last"
        done
    }

    # Print from each root
    local i=0
    for root in "${roots[@]}"; do
        ((i++))
        local is_last=false
        [[ $i -eq ${#roots[@]} ]] && is_last=true
        print_tree "$root" "" "$is_last"
    done
}
# }}}
```

## Relation to Existing Work

| Existing | New Use |
|----------|---------|
| `build_dependency_graph()` (035b) | Source data for visualization |
| `topological_sort_issues()` (035b) | Determines merge order |
| `parse_issue_dependencies()` | Extracts blocking relationships |
| `reconstruct-history.sh` | Could add `--visualize` flag |

## Proposed New Issue

**Issue 038: Dependency Visualization and Branch Topology Tool**

- Generate ASCII and DOT format dependency trees
- Optional branch-per-issue creation mode
- Impact analysis queries
- Integration with `reconstruct-history.sh`

## Conclusion

Yes, you can absolutely branch from branches - Git's model supports arbitrary branching topologies. The idea of using issue dependencies to:

1. **Visualize project structure** - Immediately useful for understanding
2. **Drive parallel workflows** - Useful for teams
3. **Enable impact analysis** - Useful for debugging

...is sound and builds naturally on the dependency graph work already done in Issue 035b. The visualization aspect (Option B) is low-effort and high-value. Full branch-per-issue (Option A) is more complex but enables true parallel development.

## References

- Issue 035b: Dependency graph and topological sort
- `reconstruct-history.sh`: Current implementation
- Git internals: branches as commit pointers
