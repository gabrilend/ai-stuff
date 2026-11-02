# 007: Remove CSS and JavaScript from File Server

## Status
- **Priority**: COMPLETED ✅
- **Type**: Refactoring / Standards Compliance
- **Completed**: 2025-12-21

## Resolution Notes

Converted project-file-server to pure HTML output:
- Removed ~230 lines of embedded CSS
- Removed ~80 lines of JavaScript
- Replaced `onclick` handlers with native `<details>/<summary>` elements
- Replaced styled divs with `<pre>` blocks and semantic HTML
- Removed blocker guards from both runner script and Lua library
- Tested output: 0 style tags, 0 script tags, 0 onclick handlers

The file server now generates browsable HTML that works in any browser with
native collapsible folders via `<details>/<summary>`.

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

## What Happened

The conversion itself was done on 2025-12-21, as the Resolution Notes say: the
page has had no `<style>`, `<script>` or `onclick` since then. A check on
2026-11-02 found the issue still among the open ones and five gaps between
"no CSS and no JavaScript" and what the tool actually guaranteed. All five
are closed on branch `claude/007-file-server-pure-html`:

1. **A name could put a script into the page.** Names were written into the
   page raw, so a file called `<script>alert(1)<.md` added a `<script>`
   element. Names are now HTML-escaped, and links are escaped too.
2. **A name could run a command.** Paths went to `find`, `du` and `stat` in
   double quotes, so a folder called `$(touch x)` ran `touch x` while the tree
   was scanned. That was seen happening with the old library. Paths are now
   single-quoted. `find -path "<dir>"` became `find -mindepth 1`, because
   `-path` read the folder's name as a pattern.
3. **Links broke on spaces, `#`, `&` and quotes.** `file://` links are now
   percent-encoded.
4. **The runner only worked on the monorepo itself.** It loaded the library
   from under the folder being scanned, so scanning any other folder failed.
   It also ran the library with `lua` rather than LuaJIT, and read `-o` as the
   folder when `-o` came first. The runner now loads the library from beside
   itself and runs it with `luajit`. It reads the folder and output as the
   first and second plain words, works out the default output after all
   arguments are read, and refuses an unknown option or a missing folder.
5. **Step 20 (the README) was never done.** `libs/README-project-file-server.md`
   still described a sidebar, live search and a responsive layout, and a dkjson
   dependency the library never loads. It now describes the page as it is.

### Decisions

- **Escape and quote rather than skip odd names.** A tree can hold any name,
  and leaving names out would hide real files. Every name is listed, as text.
- **The test is a shell test in `tests/`**, like the other scripts tests. It
  builds hostile names in a scratch folder and runs the real runner. The
  "nothing ran" check runs the scan from inside a canary folder that a hidden
  `touch` would write into.
- **The quick links stay hard-coded.** They are Ritz's own folders, and making
  them configurable is a different issue.
- **The interactive menu's `python3 -m http.server` options stay.** They serve
  the finished page and add nothing to it.

### Tests

`tests/test-project-file-server.sh` has 27 checks and all pass. Against the
old runner and library, 15 of the 27 fail. Run directly on a hostile tree, the
old library also ran a folder's `$(touch ...)` and wrote raw `<script>`
elements.
