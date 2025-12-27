# sync-visions.sh

Discovers and symlinks vision documents from all projects into a centralized `visions/` directory. Provides statistics on documentation coverage and identifies projects missing vision files.

## Use Cases

### Sync All Vision Documents
Create symlinks for all discovered vision files.

```bash
./sync-visions.sh
```

### List Vision Files Without Syncing
Preview what would be synced without making changes.

```bash
./sync-visions.sh --list
```

### View Documentation Coverage Statistics
See which projects have vision docs and which are missing them.

```bash
./sync-visions.sh --stats
```

### Sync from Multiple Directories
Search additional project directories.

```bash
./sync-visions.sh --extra "/other/projects:/more/projects"
```

### Custom Output Location
Store symlinks in a different directory.

```bash
./sync-visions.sh --output ~/my-visions
```

### Verbose Mode for Debugging
See detailed progress information.

```bash
./sync-visions.sh -v
```

## Configuration Options

| Option | Description |
|--------|-------------|
| `-d, --dir <path>` | Base directory to search (default: `$DIR` or `~/programming/ai-stuff`) |
| `-o, --output <dir>` | Output directory for symlinks (default: `scripts/visions/`) |
| `-e, --extra <dirs>` | Additional directories to search (colon-separated) |
| `-l, --list` | List vision files without creating symlinks |
| `-s, --stats` | Show statistics only (no syncing) |
| `-q, --quiet` | Suppress output except errors |
| `-v, --verbose` | Show detailed progress |
| `--no-clear` | Don't clear existing symlinks before syncing |
| `-I, --interactive` | Interactive mode (future TUI support) |
| `-h, --help` | Show help message |

## Capabilities

- **Pattern Matching**: Finds `vision`, `vision.md`, and `vision-*` files
- **Nested Project Support**: Handles projects like `games/city-of-chat`
- **Variant Support**: Links `vision-features` as `project-features`
- **Coverage Statistics**: Reports percentage of projects with vision docs
- **Missing Project List**: Identifies which projects need vision documentation

## Vision File Patterns Searched

| Location | Pattern |
|----------|---------|
| `notes/` | `vision`, `vision.md`, `vision-*` |
| `docs/` | `vision`, `vision.md` |
| Project root | `vision`, `vision.md` |

## Symlink Naming Convention

| Vision Location | Symlink Name |
|-----------------|--------------|
| `project/notes/vision` | `project` |
| `games/project/notes/vision` | `games-project` |
| `project/notes/vision-features` | `project-features` |

## Statistics Output

```
=== Vision Documentation Statistics ===

Projects with vision docs: 12
Total projects found:      18
Coverage:                  67%

Projects missing vision documentation:
  - delta-version
  - scripts
  - temp-project

Projects with vision documentation:
  + city-of-chat
  + handheld-office
  + neocities-modernization
  + world-edit-to-execute
  ...
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `DIR` | Base directory (default: `/home/ritz/programming/ai-stuff`) |
| `EXTRA_DIRS` | Additional search directories (colon-separated) |

## Related Scripts

- `project-file-server` - Browse projects in HTML interface
- `filesystem_scanner.sh` - Scan filesystem hierarchy
