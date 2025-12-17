# Issue 036: Commit History Viewer

## Current Behavior

There is no unified way to browse through a project's git history as a readable narrative. Developers must use `git log`, `git show`, and manually navigate between commits to understand project evolution.

### Current Issues
- `git log` shows commit metadata but not content
- `git show` displays raw diffs, not readable documentation
- No way to "flip through" commits like pages of a book
- No prioritization of meaningful content (vision, issues, docs) over code churn
- Requires multiple commands to understand what changed in each commit

## Intended Behavior

Create a terminal-based commit history viewer that presents project history as a readable book:

### Core Features

1. **Project Selection**: List available projects or accept one via CLI flag
2. **Commit Navigation**: Left/right arrows flip between commits chronologically
3. **Page Scrolling**: Up/down arrows scroll within current commit's content
4. **Position Preservation**: Scroll position preserved when flipping commits
5. **Quick Navigation**: Double-tap up/down jumps to top/bottom of content

### Content Display Order

For each commit, concatenate content in this priority order:

```
┌─────────────────────────────────────────────────┐
│ COMMIT: abc123f                                 │
│ DATE: 2024-12-17 14:30:00                       │
│ AUTHOR: username                                │
├─────────────────────────────────────────────────┤
│                                                 │
│ [Commit Message]                                │
│ Full commit message text here...                │
│                                                 │
├─────────────────────────────────────────────────┤
│ § NOTES                                         │
│ ─────────────────────────────────────────────── │
│ (changed files from notes/ directory)           │
│                                                 │
├─────────────────────────────────────────────────┤
│ § COMPLETED ISSUES                              │
│ ─────────────────────────────────────────────── │
│ (files from issues/completed/ in this commit)   │
│                                                 │
├─────────────────────────────────────────────────┤
│ § DOCUMENTATION                                 │
│ ─────────────────────────────────────────────── │
│ (new/changed files from docs/ directory)        │
│                                                 │
├─────────────────────────────────────────────────┤
│ § OTHER MARKDOWN                                │
│ ─────────────────────────────────────────────── │
│ (other .md files not in above categories)       │
│                                                 │
└─────────────────────────────────────────────────┘

[←] Prev Commit    [↑↓] Scroll    [→] Next Commit    [q] Quit
```

### Navigation Behavior

| Input | Action |
|-------|--------|
| `←` / `h` | Previous commit (older) |
| `→` / `l` | Next commit (newer) |
| `↑` / `k` | Scroll up one line |
| `↓` / `j` | Scroll down one line |
| `↑↑` (double-tap) | Jump to top of content |
| `↓↓` (double-tap) | Jump to bottom of content |
| `PgUp` | Scroll up one page |
| `PgDn` | Scroll down one page |
| `g` | Go to first commit |
| `G` | Go to last commit |
| `q` / `Esc` | Quit viewer |

### Position Preservation Logic

```
Session State:
  positions = {}  # commit_hash -> scroll_position

On commit flip (left/right):
  positions[current_commit] = current_scroll_position
  new_commit = get_adjacent_commit(direction)
  current_scroll_position = positions.get(new_commit, 0)

On session start/end:
  positions = {}  # Clear all preserved positions
```

### Double-Tap Detection

```
DOUBLE_TAP_THRESHOLD_MS = 300

last_key = nil
last_key_time = 0

on_keypress(key):
  current_time = now_ms()

  if key == last_key and (current_time - last_key_time) < DOUBLE_TAP_THRESHOLD_MS:
    # Double-tap detected
    if key in [UP, 'k']:
      scroll_to_top()
    elif key in [DOWN, 'j']:
      scroll_to_bottom()
    last_key = nil  # Reset to prevent triple-tap
  else:
    # Single tap - normal behavior
    handle_single_keypress(key)
    last_key = key
    last_key_time = current_time
```

## Suggested Implementation Steps

### Sub-Issue Structure

This issue requires the following sub-issues:

#### 036a: Project Selection Interface
- Integrate with `list-projects.sh` for project discovery
- CLI flag `--project <name>` to skip selection
- Filter to projects with git history
- Show commit count per project in selection menu

#### 036b: Git Commit Traversal
- Walk commits chronologically (oldest to newest)
- Cache commit metadata for quick navigation
- Extract changed files per commit
- Handle edge cases (first/last commit, empty commits)

#### 036c: Content Extraction and Ordering
- Extract full file content (not diffs) at each commit
- Filter to text files only (skip binaries)
- Categorize files: notes/, issues/completed/, docs/, other .md
- Concatenate in priority order with section headers

#### 036d: Paginator TUI Component
- Scrollable text area with line wrapping
- Header bar with commit info
- Footer bar with navigation hints
- Handle terminal resize events

#### 036e: Navigation and Input Handling
- Vim-style and arrow key bindings
- Double-tap detection with configurable threshold
- Position preservation state machine
- Smooth scrolling (optional)

#### 036f: Session State Management
- Per-commit scroll position tracking
- Session initialization and cleanup
- Optional: persist state to file for resume

## Implementation Details

### Content Extraction Algorithm

```bash
# For each commit, get the tree state and extract readable content
get_commit_content() {
    local commit="$1"
    local project_dir="$2"

    # Get commit metadata
    local message=$(git -C "$project_dir" log -1 --format='%B' "$commit")
    local date=$(git -C "$project_dir" log -1 --format='%ci' "$commit")
    local author=$(git -C "$project_dir" log -1 --format='%an' "$commit")

    # Get files changed in this commit
    local changed_files=$(git -C "$project_dir" diff-tree --no-commit-id --name-only -r "$commit")

    # Categorize and extract content
    local notes_content=""
    local issues_content=""
    local docs_content=""
    local other_md_content=""

    for file in $changed_files; do
        # Skip non-text files
        if ! is_text_file "$file"; then continue; fi

        # Get file content at this commit
        local content=$(git -C "$project_dir" show "${commit}:${file}" 2>/dev/null)

        case "$file" in
            notes/*)
                notes_content+="### $file\n$content\n\n"
                ;;
            issues/completed/*)
                issues_content+="### $file\n$content\n\n"
                ;;
            docs/*)
                docs_content+="### $file\n$content\n\n"
                ;;
            *.md)
                other_md_content+="### $file\n$content\n\n"
                ;;
        esac
    done

    # Concatenate in priority order
    echo "$message"
    [[ -n "$notes_content" ]] && echo -e "\n§ NOTES\n$notes_content"
    [[ -n "$issues_content" ]] && echo -e "\n§ COMPLETED ISSUES\n$issues_content"
    [[ -n "$docs_content" ]] && echo -e "\n§ DOCUMENTATION\n$docs_content"
    [[ -n "$other_md_content" ]] && echo -e "\n§ OTHER MARKDOWN\n$other_md_content"
}
```

### File Structure

```
delta-version/scripts/
├── history-viewer.sh          # Main entry point
├── libs/
│   ├── hv-git.sh              # Git traversal functions (036b)
│   ├── hv-content.sh          # Content extraction (036c)
│   ├── hv-paginator.sh        # TUI paginator (036d)
│   ├── hv-input.sh            # Input handling (036e)
│   └── hv-state.sh            # Session state (036f)
```

### CLI Interface

```
history-viewer.sh [OPTIONS] [PROJECT]

Options:
    -p, --project NAME    Select project directly (skip menu)
    -c, --commit HASH     Start at specific commit
    -r, --reverse         Show newest commits first
    -n, --no-color        Disable syntax highlighting
    -I, --interactive     Force interactive mode
    -h, --help            Show help message

Examples:
    # Interactive project selection
    history-viewer.sh

    # View specific project's history
    history-viewer.sh --project delta-version

    # Start at specific commit
    history-viewer.sh --project delta-version --commit abc123f
```

## Dependencies

### Blocked By
- **Issue 035**: Project History Reconstruction
  - Projects need reconstructed history before viewing makes sense
  - Vision-first, issue-by-issue commits create meaningful narrative

### Related Issues
- **Issue 005**: Vision Documentation Viewer (similar symlink/discovery patterns)
- **Issue 004**: TUI Menu Incremental Rendering (TUI library)
- **Issue 023**: Project Listing Utility (project discovery)

### Technical Dependencies
- Bash 4.3+ (associative arrays for position tracking)
- Git (commit traversal)
- TUI library from `/scripts/libs/` (for paginator)
- Terminal with ANSI escape support

## Metadata
- **Priority**: Medium
- **Complexity**: High (6 sub-issues)
- **Dependencies**: Issue 035 (blocking)
- **Impact**: Enables narrative browsing of project evolution

## Success Criteria

### Core Functionality
- [ ] Projects with git history can be selected from menu
- [ ] Left/right navigation moves between commits
- [ ] Up/down navigation scrolls within commit content
- [ ] Content displays in priority order (notes, issues, docs, other md)
- [ ] Commit message always visible at top

### Navigation
- [ ] Position preserved when flipping between commits
- [ ] Double-tap up/down jumps to top/bottom
- [ ] Vim keybindings work (h/j/k/l)
- [ ] Page up/down work for large content
- [ ] g/G jump to first/last commit

### Edge Cases
- [ ] Handles projects with single commit
- [ ] Handles commits with no markdown content
- [ ] Handles large files gracefully (truncation or warning)
- [ ] Terminal resize updates layout correctly
- [ ] Binary files are skipped with indicator

### User Experience
- [ ] Clear visual separation between content sections
- [ ] Navigation hints visible in footer
- [ ] Current commit position shown (e.g., "3 of 47")
- [ ] Loading indicator for large histories
