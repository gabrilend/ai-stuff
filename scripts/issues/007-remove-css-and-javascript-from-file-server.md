# 007: Remove CSS and JavaScript from File Server

## Status
- **Priority**: HIGH - BLOCKING
- **Type**: Refactoring / Standards Compliance
- **Blocker**: Application usage is BLOCKED until this issue is resolved

## Current Behavior

The project file server (`scripts/libs/project-file-server.lua`) generates HTML with:

1. **~230 lines of embedded CSS** (lines 313-543)
   - Custom dark theme styling
   - Flexbox layouts
   - Hover effects and transitions
   - Responsive media queries

2. **~80 lines of JavaScript** (lines 572-648)
   - `toggleNode()` - Expand/collapse folders
   - `expandAll()` / `collapseAll()` - Bulk operations
   - `showLargeFiles()` / `showRecentFiles()` - Stub functions
   - `filterTree()` - Search filtering
   - `DOMContentLoaded` - Auto-expand first level

## Intended Behavior

Generate **pure HTML** output with no CSS or JavaScript:

1. **Remove all `<style>` blocks**
2. **Remove all `<script>` blocks**
3. **Remove all inline `style=` attributes**
4. **Remove all `onclick=` handlers**
5. **Use semantic HTML** for structure (no CSS-dependent layouts)
6. **Use `<details>/<summary>`** for collapsible sections (native HTML5)
7. **Use `<font color="">` and `<b>`** tags for emphasis (Neocities style)

## Why This Matters

1. **Consistency** - Neocities-modernization project explicitly removed CSS/JS (issues 8-003, 8-006, 8-007)
2. **Accessibility** - Pure HTML works everywhere, no JS required
3. **Simplicity** - Less code to maintain
4. **Philosophy** - "Data generation separate from data viewing"

## Suggested Implementation Steps

### Phase A: Remove JavaScript Dependencies
1. [ ] Replace `onclick="toggleNode(this)"` with `<details>/<summary>` elements
2. [ ] Remove expand/collapse all (or implement via `<details open>` generation)
3. [ ] Remove search functionality (users can use Ctrl+F)
4. [ ] Remove large files / recent files stubs
5. [ ] Delete entire `<script>` block

### Phase B: Remove CSS Dependencies
6. [ ] Remove `<style>` block (lines 313-543)
7. [ ] Remove `.sidebar`, `.main-content` flexbox layout
8. [ ] Convert to linear HTML document flow
9. [ ] Replace styled divs with semantic elements (`<nav>`, `<main>`, `<section>`)
10. [ ] Use `<pre>` for tree structure with ASCII art

### Phase C: Rebuild with Pure HTML
11. [ ] Sidebar becomes a `<nav>` section at top of document
12. [ ] Tree uses `<details>/<summary>` for expand/collapse
13. [ ] File sizes in parentheses (plain text)
14. [ ] Links remain as `<a href="file://...">`
15. [ ] Use `<hr>` for visual separation
16. [ ] Use `<font color="">` for coloring (optional)

### Phase D: Testing
17. [ ] Verify `file://` links still work
18. [ ] Test `<details>` expand/collapse in major browsers
19. [ ] Confirm no CSS or JS remains in output
20. [ ] Update README-project-file-server.md

## Example Output Structure

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Project File Server</title>
</head>
<body>
<pre>
================================================================================
                        PROJECT FILE SERVER
================================================================================
Root Path: /mnt/mtwo/programming
Generated: 2025-12-17 23:00:00

--------------------------------------------------------------------------------
                           STATISTICS
--------------------------------------------------------------------------------
Total Files: 45,231
Directories: 3,892
Top File Types: .lua (1,234) | .md (892) | .sh (445) | .json (312)

================================================================================
                          DIRECTORY TREE
================================================================================
</pre>

<details>
<summary><a href="file:///mnt/mtwo/programming/ai-stuff">ai-stuff/</a> (2.1G)</summary>
    <details>
    <summary><a href="file:///mnt/mtwo/programming/ai-stuff/neocities-modernization">neocities-modernization/</a> (156M)</summary>
        <a href="file:///mnt/mtwo/programming/ai-stuff/neocities-modernization/run.sh">run.sh</a> (2KB)<br>
        <a href="file:///mnt/mtwo/programming/ai-stuff/neocities-modernization/README.md">README.md</a> (4KB)<br>
    </details>
</details>

<details>
<summary><a href="file:///mnt/mtwo/programming/rust">rust/</a> (892M)</summary>
    ...
</details>

<hr>
<pre>
================================================================================
Use Ctrl+F to search | Click triangles to expand/collapse
================================================================================
</pre>
</body>
</html>
```

## Related Documents

- `/home/ritz/programming/ai-stuff/scripts/libs/project-file-server.lua`
- `/home/ritz/programming/ai-stuff/scripts/project-file-server`
- `/home/ritz/programming/ai-stuff/scripts/libs/README-project-file-server.md`
- Neocities 8-003: Remove remaining CSS from HTML generation

## Unblock Criteria

This issue blocks usage of the file server. To unblock:

1. Change issue status from "BLOCKING" to "IN PROGRESS"
2. Remove the exit guard from `scripts/project-file-server`
3. Begin implementation

---
