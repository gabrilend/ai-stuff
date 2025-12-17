# Issue 037: Project History Narrative Generator

## Current Behavior

Git log output is optimized for developers, not for reading as a narrative:
- `git log` shows newest commits first (reverse chronological)
- Output is dense with metadata (hashes, dates, authors)
- No project-level separation in a monorepo
- Requires manual effort to create readable history documents

### Current Workflow
```bash
# To see project history, must manually:
git log --oneline -- project-name/
# Or for full messages:
git log --reverse -- project-name/
```

This produces raw git output, not a readable narrative document.

## Intended Behavior

Create a script that generates readable history files for each project in the monorepo:

### Output Format

For each project, create `{project}/docs/HISTORY.txt` (or configurable location):

```
================================================================================
                         PROJECT NAME - Development History
================================================================================

This document traces the development of PROJECT NAME from inception to present.
Generated: 2024-12-17 14:30:00

--------------------------------------------------------------------------------

[1] Initial vision: Project purpose and goals
    2024-01-15

    Establishes the foundational vision for this project.

--------------------------------------------------------------------------------

[2] Issue 001: Implement core data structures
    2024-01-18

    Adds the fundamental data structures needed for the project:
    - LinkedList implementation
    - HashMap with custom hashing
    - Priority queue for scheduling

--------------------------------------------------------------------------------

[3] Issue 002: Create command-line interface
    2024-01-22

    Implements the CLI with the following commands:
    - init: Initialize a new workspace
    - run: Execute the main pipeline
    - status: Show current state

    This enables users to interact with the tool from the terminal.

--------------------------------------------------------------------------------

[4] Fix typo in README
    2024-01-23

    Corrected spelling of "recieve" to "receive".

--------------------------------------------------------------------------------

... (continues chronologically)

--------------------------------------------------------------------------------

[47] Latest feature: Add export functionality
     2024-12-15

     Adds ability to export data in multiple formats:
     - JSON for programmatic access
     - CSV for spreadsheet import
     - Markdown for documentation

================================================================================
                                 End of History
                              47 commits recorded
================================================================================
```

### Features

1. **Chronological Order**: First commit at top, latest at bottom (like a story)
2. **Clean Formatting**: Dashes and newlines separate commits for readability
3. **Numbered Commits**: Sequential numbers show progress through history
4. **Date Display**: Human-readable dates without timestamps cluttering the view
5. **Full Messages**: Complete commit messages, not just first lines
6. **Project Isolation**: Only commits affecting that project's files
7. **Header/Footer**: Document metadata and summary statistics
8. **Completed Work Focus**: Emphasize commits that complete work, not just add plans

### Commit Classification

Not all commits represent equal narrative value. The history should emphasize **completed work** over **planning commits**:

| Commit Type | Example | Narrative Value |
|-------------|---------|-----------------|
| Completed Issue | "Issue 035a: Implement project detection" | **HIGH** - actual work done |
| Retroactive Issue | File added directly to `issues/completed/` | **HIGH** - work was done, ticket created after |
| New Issue Spec | "Create Issue 036 specification" | **LOW** - just planning, no implementation |
| Vision/Notes | Changes to `notes/vision` | **HIGH** - foundational narrative |
| Code Changes | "Fix bug in parser" | **MEDIUM** - implementation progress |

#### Filtering Options

```
--completed-only     Show only commits touching issues/completed/
--skip-specs         Hide commits that only add issues/*.md (not completed/)
--all-commits        Include all commits (default behavior)
```

#### Retroactive Tickets

When an issue file is added directly to `issues/completed/` (not moved there from `issues/`), this indicates:
- Work was done first, ticket created retroactively
- The commit represents **completed work**, not planning
- Should be treated the same as any other completed issue

### CLI Interface

```
generate-history.sh [OPTIONS] [PROJECT...]

Options:
    -a, --all            Generate history for all projects
    -p, --project NAME   Generate history for specific project(s)
    -o, --output DIR     Output directory (default: {project}/docs/)
    -f, --filename NAME  Output filename (default: HISTORY.txt)
    --format FORMAT      Output format: txt, md, html (default: txt)
    --since DATE         Only include commits after DATE
    --until DATE         Only include commits before DATE
    --min-commits N      Skip projects with fewer than N commits
    --completed-only     Only show commits touching issues/completed/
    --skip-specs         Hide commits that only add issue specs (issues/*.md)
    -n, --dry-run        Show what would be generated
    -v, --verbose        Show progress during generation
    -I, --interactive    Select projects interactively
    -h, --help           Show help message

Examples:
    # Generate history for all projects
    generate-history.sh --all

    # Generate for specific project
    generate-history.sh --project delta-version

    # Custom output location
    generate-history.sh --project factory-war --output ./histories/

    # Only recent history
    generate-history.sh --all --since "2024-01-01"

    # Interactive selection
    generate-history.sh -I
```

## Suggested Implementation Steps

### 1. Core Git Log Extraction

```bash
# -- {{{ get_project_commits
get_project_commits() {
    local project_dir="$1"
    local project_name
    project_name=$(basename "$project_dir")

    # Get commits in chronological order (oldest first)
    # that touched files in this project
    git log --reverse --format='%H|%ci|%s|%b' -- "$project_name/" 2>/dev/null
}
# }}}
```

### 2. Commit Formatting

```bash
# -- {{{ format_commit
format_commit() {
    local index="$1"
    local hash="$2"
    local date="$3"
    local subject="$4"
    local body="$5"

    # Extract just the date part (no time)
    local date_only="${date%% *}"

    echo "--------------------------------------------------------------------------------"
    echo ""
    echo "[$index] $subject"
    echo "    $date_only"
    echo ""

    # Format body with indentation if present
    if [[ -n "$body" ]]; then
        echo "$body" | sed 's/^/    /'
        echo ""
    fi
}
# }}}
```

### 3. Document Generation

```bash
# -- {{{ generate_history_document
generate_history_document() {
    local project_dir="$1"
    local output_file="$2"
    local project_name
    project_name=$(basename "$project_dir")

    local commit_count=0
    local generated_date
    generated_date=$(date '+%Y-%m-%d %H:%M:%S')

    # Header
    cat <<EOF
================================================================================
$(printf '%*s' $(( (80 - ${#project_name} - 22) / 2 )) '')${project_name^^} - Development History
================================================================================

This document traces the development of $project_name from inception to present.
Generated: $generated_date

EOF

    # Process each commit
    while IFS='|' read -r hash date subject body; do
        ((commit_count++))
        format_commit "$commit_count" "$hash" "$date" "$subject" "$body"
    done < <(get_project_commits "$project_dir")

    # Footer
    cat <<EOF
--------------------------------------------------------------------------------

================================================================================
$(printf '%*s' 30 '')End of History
$(printf '%*s' 28 '')$commit_count commits recorded
================================================================================
EOF
}
# }}}
```

### 4. Project Iteration

```bash
# -- {{{ process_all_projects
process_all_projects() {
    local projects_script="${DIR}/delta-version/scripts/list-projects.sh"

    while IFS= read -r project_path; do
        local project_name
        project_name=$(basename "$project_path")

        # Check if project has any commits
        local commit_count
        commit_count=$(git log --oneline -- "$project_name/" 2>/dev/null | wc -l)

        if [[ "$commit_count" -lt "$MIN_COMMITS" ]]; then
            log "Skipping $project_name ($commit_count commits, min: $MIN_COMMITS)"
            continue
        fi

        local output_dir="${project_path}/${OUTPUT_SUBDIR}"
        local output_file="${output_dir}/${OUTPUT_FILENAME}"

        mkdir -p "$output_dir"

        log "Generating history for $project_name ($commit_count commits)..."
        generate_history_document "$project_path" > "$output_file"

        echo "  Created: $output_file"
    done < <("$projects_script" --paths)
}
# }}}
```

## Implementation Details

### Handling Multi-line Commit Messages

Git commit messages can have:
- Subject line (first line)
- Blank line
- Body (remaining lines)

The script should preserve the full message structure:

```bash
# Use NUL separator for safety with multi-line messages
git log --reverse --format='%H%x00%ci%x00%s%x00%b%x00' -- "$project_name/"
```

### Filtering Project-Specific Commits

In a monorepo, commits may touch multiple projects. The script should:
1. Filter to commits that include files in the project directory
2. Show the full commit message (even if it mentions other projects)
3. Optionally flag commits that touched multiple projects

### Output Format Options

| Format | Extension | Use Case |
|--------|-----------|----------|
| txt | .txt | Plain text, maximum portability |
| md | .md | Markdown, renders nicely on GitHub |
| html | .html | Standalone viewable document |

### Markdown Format Example

```markdown
# Delta-Version - Development History

> This document traces the development of delta-version from inception to present.
> Generated: 2024-12-17 14:30:00

---

## [1] Initial vision: Project purpose and goals
**Date:** 2024-01-15

Establishes the foundational vision for this project.

---

## [2] Issue 001: Implement core data structures
**Date:** 2024-01-18

Adds the fundamental data structures needed for the project:
- LinkedList implementation
- HashMap with custom hashing
- Priority queue for scheduling

---
```

### Statistics Summary (Optional)

At the end of the document, optionally include:

```
================================================================================
                               History Statistics
================================================================================

Total commits:        47
Date range:           2024-01-15 to 2024-12-15
Active days:          89
Average commits/week: 1.2

Top commit types:
  - Features:    23 (49%)
  - Bug fixes:   12 (26%)
  - Docs:         8 (17%)
  - Refactoring:  4 (8%)

================================================================================
```

## File Structure

```
delta-version/scripts/
├── generate-history.sh      # Main script
└── libs/
    └── history-format.sh    # Formatting functions (optional)

# Generated output per project:
{project}/
└── docs/
    └── HISTORY.txt          # Generated history narrative
```

## Related Documents
- **Issue 035**: Project History Reconstruction (creates the meaningful commits to narrate)
- **Issue 036**: Commit History Viewer (interactive version of this concept)
- **Issue 023**: Project Listing Utility (project discovery)
- CLAUDE.md mentions: "git log should be appended to a long history file... prettified... that can be grepped through easily. Or, printed and read like a book."

## Metadata
- **Priority**: Medium
- **Complexity**: Low-Medium
- **Dependencies**: Issue 035 (optional - works without but better with reconstructed history)
- **Blocks**: None
- **Impact**: Creates readable project narratives, enables history review

## Success Criteria

### Core Functionality
- [ ] Script generates history file for specified project
- [ ] Commits appear in chronological order (oldest first)
- [ ] Full commit messages preserved (subject + body)
- [ ] Clear visual separation between commits

### Formatting
- [ ] Header includes project name and generation date
- [ ] Footer includes commit count summary
- [ ] Commits are numbered sequentially
- [ ] Dates are human-readable (no timestamps)
- [ ] Dashes and newlines create readable separation

### Batch Processing
- [ ] `--all` flag processes every project
- [ ] Projects with few commits can be skipped (`--min-commits`)
- [ ] Progress shown during batch generation
- [ ] Dry-run mode shows what would be created

### Output Options
- [ ] Default output to `{project}/docs/HISTORY.txt`
- [ ] Custom output directory via `--output`
- [ ] Custom filename via `--filename`
- [ ] Multiple format support (txt, md, html)

### Edge Cases
- [ ] Handles projects with no commits gracefully
- [ ] Handles commits with empty bodies
- [ ] Handles special characters in commit messages
- [ ] Works from any directory (uses DIR variable)
