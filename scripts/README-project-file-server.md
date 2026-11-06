# project-file-server

Generates a pure HTML interface for browsing programming projects in a tree structure. Uses native `<details>`/`<summary>` elements for collapsible folders - no CSS or JavaScript required.

## Use Cases

### Generate File Browser
Create an HTML file browser for the default directory.

```bash
./project-file-server
```

### Scan Specific Directory
Generate a browser for a different project directory.

```bash
./project-file-server /path/to/projects
```

### Custom Output Location
Save the HTML file to a specific path.

```bash
./project-file-server -o ~/my-server.html
./project-file-server /path/to/projects -o /tmp/browser.html
```

### Interactive Mode
A menu built with `lua-menu.sh` (see Interactive Mode Options below).

```bash
./project-file-server -I
./project-file-server -I /path/to/projects
```

### View in Browser
After generating, open directly in Firefox.

```bash
./project-file-server && firefox project-file-server.html
```

### Serve via HTTP
Start a local web server for the generated file.

```bash
./project-file-server
python3 -m http.server 8080
# Open http://localhost:8080/project-file-server.html
```

## Configuration Options

| Option | Description |
|--------|-------------|
| `[directory]` | Directory to scan (default: `/home/ritz/programming/ai-stuff`); one that does not exist is refused |
| `[output]` | Output HTML file, as a second word (same as `-o`) |
| `-I, --interactive` | Open the menu, on the folder named (if any) |
| `-o, --output <file>` | Specify output HTML file |
| `-h, --help` | Show help message |

## Interactive Mode Options

When run with `-I`, a menu opens. Pick from each section, then Go:

- **Do** - what Go does:
  - **Generate the page** - scan the chosen folder and write the page. The
    library's progress shows as it runs.
  - **Serve the page over HTTP** - `python3 -m http.server` on the chosen
    port, bound to 127.0.0.1 so only this machine can reach it. Ctrl+C stops
    it and brings the menu back.
  - **Open the page in a browser** - hands its `file://` address to
    `xdg-open` (`open` on macOS).
  - **Go into the folder** - makes the chosen folder the current one, so its
    subfolders are listed next; writes nothing.
- **Folder to scan** - the current folder, its parent (`../`), its subfolders
  (`./name`, hidden ones left out), and "Another folder..." to type a path.
- **Page goes to** - inside the scanned folder, or "Another file..." to type
  a path (offered again next time; `-o` given with `-I` starts here).
- **Serving** - the port, 1024-65535 (default 8080).

The panel below the items shows the last lines of the last generation and a
two-level tree of the folder under the cursor. After each step the menu opens
again with a note of what happened in its title; `q` leaves. Its preview files
go in a temporary folder under `$TMPDIR` (or `/tmp`), removed when it exits.

Tests: `tests/test-project-file-server-interactive.sh` drives the menu in a
pretend terminal; `tests/test-project-file-server.sh` checks the page itself.

## Capabilities

- **Pure HTML Output**: No CSS, no JavaScript, just semantic HTML
- **Collapsible Folders**: Uses `<details>`/`<summary>` for native folding
- **File Links**: Uses `file://` protocol for direct access
- **Cross-Browser**: Works in Firefox, Chrome, and other modern browsers
- **Offline Use**: No external dependencies after generation
- **Names Are Data**: names are quoted for the shell, escaped in the page and
  percent-encoded in links, so a file called `<script>.md` or a folder called
  `$(...)` is listed as text and nothing in it runs

## Output Format

The generated HTML uses native browser elements:

```html
<details>
  <summary>project-name/</summary>
  <details>
    <summary>src/</summary>
    <a href="file:///path/to/src/main.lua">main.lua</a>
    <a href="file:///path/to/src/utils.lua">utils.lua</a>
  </details>
  <a href="file:///path/to/README.md">README.md</a>
</details>
```

## Default Paths

| Setting | Default Value |
|---------|---------------|
| Directory | `/home/ritz/programming/ai-stuff` |
| Output | `{directory}/project-file-server.html` |

## Core Logic Location

The actual HTML generation is handled by:
`libs/project-file-server.lua`

This script is a bash wrapper that invokes the Lua core with proper arguments.

## Browser Compatibility

- **Firefox**: Full support, recommended
- **Chrome/Chromium**: Full support
- **Safari**: May require enabling local file access

## Security Note

The generated file uses `file://` URLs which work when opened directly but may be blocked when served via HTTP due to browser security policies.

## Related Scripts

- `filesystem_scanner.sh` - Text-based hierarchy (different output format)
- `sync-visions.sh` - Discovers and links specific files
