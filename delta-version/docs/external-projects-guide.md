# External Projects Configuration Guide

This guide explains how to configure Delta-Version to discover and manage projects located outside the main repository directory structure.

## Overview

By default, Delta-Version's project listing utility searches for projects only within the main repository directory (`/mnt/mtwo/programming/ai-stuff/`). The external projects feature allows you to register additional directories containing projects, enabling unified project discovery across multiple locations.

## Quick Start

### 1. Configure External Directories

Edit the configuration file at `config/external-projects.conf`:

```ini
[external_directories]
# Format: symbolic_name=absolute_path
personal_dev=/home/ritz/personal-development
work_projects=/opt/company/projects
```

### 2. Verify Configuration

```bash
./scripts/list-projects.sh --list-external
```

### 3. Use Combined Listings

```bash
# List all projects (main + external)
./scripts/list-projects.sh --names

# List only external projects
./scripts/list-projects.sh --external-only --abs-paths
```

## Configuration File

### Location

The configuration file is located at:
```
delta-version/config/external-projects.conf
```

You can override this by setting the `DELTA_CONFIG_DIR` environment variable:
```bash
export DELTA_CONFIG_DIR=/path/to/custom/config
```

### File Format

The configuration uses INI format with the following sections:

#### [external_directories]

Define additional directories to search for projects:

```ini
[external_directories]
# Each entry: name=path
# - name: Symbolic identifier (used in management commands)
# - path: Absolute path to the directory

personal_dev=/home/ritz/personal-development
work_projects=/opt/company/projects
archived_code=/mnt/storage/archived-projects
```

#### [settings]

Global settings for external project handling:

```ini
[settings]
# Include external projects in default listings (when no flags specified)
include_in_default_listings=true

# Validate directory existence when loading configuration
validate_paths_on_load=true

# Cache external project discovery results (not yet implemented)
cache_external_discoveries=false
cache_duration_minutes=30
```

#### [path_validation]

Path validation rules for security:

```ini
[path_validation]
# Only accept absolute paths
require_absolute_paths=true

# Reject network/remote paths
forbid_network_paths=true

# Verify read access before accepting directory
check_read_permissions=true

# Print warning for configured but missing directories
warn_on_missing_directories=true
```

#### [integration]

Integration with other Delta-Version systems:

```ini
[integration]
# Include in gitignore analysis scripts
include_in_gitignore_analysis=true

# Include in ticket distribution system
include_in_ticket_distribution=true

# Include in git branch operations (use with caution)
include_in_branch_management=false
```

## Command Line Options

### Listing Options

| Option | Description |
|--------|-------------|
| `--include-external` | Include external projects in listing (default) |
| `--exclude-external` | Only search main repository directory |
| `--external-only` | Only list projects from external directories |

### Management Options

| Option | Description |
|--------|-------------|
| `--list-external` | Display configured external directories with status |
| `--manage-external` | Interactive external directory management |
| `--validate-external` | Validate all external directory configurations |

## Interactive Management

Launch interactive management mode:

```bash
./scripts/list-projects.sh --manage-external
```

This provides options to:
1. List configured external directories
2. Add new external directory
3. Remove existing external directory
4. Validate all configurations
5. Test external project discovery
6. Show configuration file path

## Usage Examples

### Basic Usage

```bash
# List all projects including external directories
./scripts/list-projects.sh --names

# List with absolute paths
./scripts/list-projects.sh --abs-paths

# JSON output for scripting
./scripts/list-projects.sh --format json
```

### Filtering

```bash
# Only main repository projects
./scripts/list-projects.sh --exclude-external --names

# Only external projects
./scripts/list-projects.sh --external-only --names

# External projects as absolute paths
./scripts/list-projects.sh --external-only --abs-paths
```

### Management

```bash
# Check configured directories
./scripts/list-projects.sh --list-external

# Validate all external directories
./scripts/list-projects.sh --validate-external

# Interactive management
./scripts/list-projects.sh --manage-external
```

## Troubleshooting

### Directory Not Found

If you see warnings about missing directories:

1. Verify the path in configuration is correct
2. Check if the directory exists: `ls -la /path/to/directory`
3. Run validation: `./scripts/list-projects.sh --validate-external`

### Permission Denied

If external directories are not readable:

1. Check permissions: `ls -la /path/to/directory`
2. Ensure your user has read access
3. Update `check_read_permissions=false` in config to skip validation

### No Projects Found

If a directory exists but no projects are discovered:

1. External directories use the same project detection logic as main repository
2. Projects need: `src/` directory, `issues/` directory, or project files
3. Check what's detected: `./scripts/list-projects.sh --external-only --abs-paths`

### Configuration Not Loading

1. Check file path: `echo $(./scripts/list-projects.sh --help 2>&1 | grep -A1 "or by default")`
2. Verify file exists and is readable
3. Check for syntax errors in INI format

## Security Considerations

- All paths must be absolute (starting with `/`)
- Network paths are rejected by default
- Read permissions are validated before accepting directories
- Sensitive system directories should not be configured

## Integration with Other Tools

### Gitignore Analysis

When `include_in_gitignore_analysis=true`:
- External project `.gitignore` files are included in analysis
- Unified gitignore generation considers external patterns

### Ticket Distribution

When `include_in_ticket_distribution=true`:
- External projects appear in ticket distribution system
- Keywords from external projects are processed

### Git Branch Management

When `include_in_branch_management=true` (use with caution):
- Branch operations may span external repositories
- Recommended to keep `false` unless specifically needed

## Best Practices

1. **Use descriptive names**: Choose symbolic names that clearly identify the directory purpose
2. **Validate after changes**: Run `--validate-external` after modifying configuration
3. **Backup configuration**: The remove command creates `.bak` files automatically
4. **Start conservative**: Begin with `include_in_branch_management=false` until comfortable
5. **Regular validation**: Periodically verify external directories still exist and are accessible

## Related Documentation

- [Project Listing Utility](api-reference.md#list-projectssh) - Core utility documentation
- [Project Structure](project-structure.md) - Directory organization
- [Issue 024](../issues/024-external-project-directory-configuration.md) - Implementation details
