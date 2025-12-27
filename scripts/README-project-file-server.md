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
Configure options interactively.

```bash
./project-file-server -I
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
| `[directory]` | Directory to scan (default: `/home/ritz/programming/ai-stuff`) |
| `-I, --interactive` | Run in interactive mode |
| `-o, --output <file>` | Specify output HTML file |
| `-h, --help` | Show help message |

## Interactive Mode Options

When run with `-I`:

1. **Generate file server HTML** - Create the HTML file
2. **Start HTTP server (port 8080)** - Serve via Python
3. **Start HTTP server (custom port)** - Choose your port
4. **Open file server in browser** - Launch with xdg-open
5. **Change directory to scan** - Modify source directory
6. **Change output location** - Modify output path
7. **Exit** - Quit interactive mode

## Capabilities

- **Pure HTML Output**: No CSS, no JavaScript, just semantic HTML
- **Collapsible Folders**: Uses `<details>`/`<summary>` for native folding
- **File Links**: Uses `file://` protocol for direct access
- **Cross-Browser**: Works in Firefox, Chrome, and other modern browsers
- **Offline Use**: No external dependencies after generation

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
