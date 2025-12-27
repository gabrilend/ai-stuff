# filesystem_scanner.sh

Scans filesystem hierarchy and generates a text-based tree optimized for LLM processing. Supports automatic cron scheduling for periodic scans.

## Use Cases

### Scan a Directory
Generate a hierarchy file for the specified directory.

```bash
./filesystem_scanner.sh /path/to/scan
```

### Scan Entire Filesystem
Run from root (requires appropriate permissions).

```bash
sudo ./filesystem_scanner.sh /
```

### Install Automatic Scanning
Set up a cron job for regular filesystem snapshots.

```bash
./filesystem_scanner.sh --install-cron
```

### View Cron Configuration
Check the current schedule settings.

```bash
./filesystem_scanner.sh --show-cron
```

### Remove Cron Job
Uninstall automatic scanning.

```bash
./filesystem_scanner.sh --uninstall-cron
```

## Configuration Options

| Option | Description |
|--------|-------------|
| `[directory]` | Directory to scan (default: `/`) |
| `--install-cron` | Install cron job with configured schedule |
| `--uninstall-cron` | Remove cron job for this script |
| `--show-cron` | Show current cron job configuration |
| `-h, --help` | Show usage information |

## Cron Configuration Variables

Modify these at the top of the script to customize the schedule:

| Variable | Default | Description |
|----------|---------|-------------|
| `CRON_MINUTE` | 0 | Minute (0-59) |
| `CRON_HOUR` | 2 | Hour (0-23, 24-hour format) |
| `CRON_DAY_OF_MONTH` | * | Day of month (1-31 or *) |
| `CRON_MONTH` | * | Month (1-12 or *) |
| `CRON_DAY_OF_WEEK` | 0 | Day of week (0-7, 0=Sunday) |
| `CRON_LOG_FILE` | `/var/log/filesystem_scanner.log` | Log file path |

## Capabilities

- **Tree Generation**: Creates indented directory structure with file sizes
- **Statistics Summary**: Counts directories, files, symlinks, and total size
- **Symlink Tracking**: Identifies symlinks and their targets
- **Depth Limiting**: Default max depth of 8 to prevent overwhelming output
- **LLM Optimization**: Output formatted for easy LLM ingestion

## Output Format

```
=== FILESYSTEM HIERARCHY SCAN ===
Scan Date: Sat Dec 27 14:00:00 2024
Base Directory: /home/ritz/projects
Max Depth: 8 levels
===============================

├── [ROOT: /home/ritz/projects]/
│   ├── project-a/
│   │   ├── src/
│   │   │   ├── main.lua (1234 bytes)
│   │   │   ├── utils.lua (567 bytes)
│   │   ├── docs/
│   │   │   ├── README.md (890 bytes)
│   ├── project-b/
│   │   ├── config -> /etc/project-b/config [SYMLINK]

=== FILESYSTEM STATISTICS ===
Total Directories: 45
Total Files: 234
Total Symlinks: 12
Total Size: 15678901 bytes
============================

=== LLM PROCESSING NOTES ===
This filesystem hierarchy scan is optimized for LLM ingestion.
Structure follows standard tree format with consistent indentation.
File sizes included for context and analysis.
Symlinks clearly marked to prevent confusion.
Scan completed at: Sat Dec 27 14:00:05 2024
===========================
```

## Output Location

Output is saved to `filesystem_hierarchy.txt` in the scanned directory.

## Scanning Behavior

- Validates directory exists and is readable before scanning
- Sorts directories and files alphabetically
- Includes file sizes in bytes for each file
- Marks symlinks with `[SYMLINK]` and shows target
- Handles permission errors gracefully

## Related Scripts

- `project-file-server` - HTML-based project browser (different output format)
- `sync-visions.sh` - Discovers specific files across projects
