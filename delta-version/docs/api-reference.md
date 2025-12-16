# Delta-Version API Reference

This document provides comprehensive documentation for all Delta-Version scripts and utilities.

## Scripts Overview

| Script | Purpose | Status |
|--------|---------|--------|
| `list-projects.sh` | Project discovery and listing | Complete |
| `analyze-gitignore.sh` | Gitignore file discovery and analysis | Complete |
| `design-unification-strategy.sh` | Gitignore conflict resolution design | Complete |
| `process-gitignore-patterns.sh` | Pattern processing and categorization | Complete |

---

## list-projects.sh

Project listing utility that provides standardized discovery and listing of project directories with flexible output formats.

### Location
```
scripts/list-projects.sh
```

### Synopsis
```bash
list-projects.sh [OPTIONS] [DIRECTORY]
```

### Description
Discovers and lists project directories within the repository. Uses heuristic scoring based on project characteristics (presence of `src/`, `issues/`, `Cargo.toml`, `package.json`, etc.) to distinguish projects from non-project directories.

### Options

| Option | Description |
|--------|-------------|
| `--names` | Return project names only (default) |
| `--abs-paths` | Return absolute paths |
| `--rel-paths` | Return relative paths |
| `--format FORMAT` | Output format: `names`, `abs-paths`, `rel-paths`, `json`, `csv`, `lines` |
| `--inverse` | Return non-project directories instead |
| `--include-libs` | Include library directories (normally excluded) |
| `-I`, `--interactive` | Run in interactive mode |
| `--help` | Show help message |

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DIR` | `/mnt/mtwo/programming/ai-stuff` | Base directory for project discovery |

### Output Formats

**names** (default)
```
project-a
project-b
project-c
```

**abs-paths**
```
/mnt/mtwo/programming/ai-stuff/project-a
/mnt/mtwo/programming/ai-stuff/project-b
```

**json**
```json
{
  "projects": [
    {"name": "project-a", "path": "/full/path/to/project-a"},
    {"name": "project-b", "path": "/full/path/to/project-b"}
  ]
}
```

**csv**
```
name,path
project-a,/full/path/to/project-a
project-b,/full/path/to/project-b
```

### Examples
```bash
# List all project names
list-projects.sh --names

# Get JSON output for a specific directory
list-projects.sh --format json /path/to/repo

# List non-project directories with absolute paths
list-projects.sh --inverse --abs-paths

# Run interactively
list-projects.sh -I
```

### Integration Functions
The script provides functions that can be sourced for use in other scripts:

```bash
source /path/to/list-projects.sh

# Get project list programmatically
projects=$(get_project_list_for_integration "names" "$DIR")

# Check if directory is a project
if is_project_directory "/some/path"; then
    echo "Is a project"
fi

# Get non-project directories
non_projects=$(get_non_project_directories "abs-paths" "$DIR")
```

### Project Detection Criteria
A directory is classified as a project if its characteristic score >= 50:

| Characteristic | Score |
|----------------|-------|
| Has `src/` directory | +50 |
| Has `issues/` directory | +40 |
| Has `Cargo.toml` | +30 |
| Has `package.json` | +30 |
| Has `Makefile` | +25 |
| Has `.gitignore` | +20 |
| Has `README.md` | +15 |
| Has `docs/` directory | +10 |

---

## analyze-gitignore.sh

Gitignore discovery and analysis utility that systematically discovers, categorizes, and analyzes `.gitignore` patterns across the repository.

### Location
```
scripts/analyze-gitignore.sh
```

### Synopsis
```bash
analyze-gitignore.sh [OPTIONS]
```

### Description
Scans the repository for all `.gitignore` files, extracts patterns, categorizes them by type and location, and generates analysis reports.

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DIR` | `/mnt/mtwo/programming/ai-stuff` | Base directory for discovery |
| `ANALYSIS_OUTPUT_DIR` | `${DIR}/delta-version/assets` | Output directory for reports |

### Output Files
Generated in `assets/` directory:

| File | Description |
|------|-------------|
| `gitignore-analysis-report.txt` | Comprehensive analysis of all discovered patterns |
| `pattern-classification.conf` | Pattern categorization configuration |

### Pattern Categories
The analyzer classifies patterns into:

- **build_artifacts**: Compiled files, build output directories
- **ide_files**: Editor/IDE specific files and directories
- **language_specific**: Package managers, caches, language-specific outputs
- **os_specific**: Operating system generated files
- **version_control**: VCS-related patterns
- **logs**: Log files and directories
- **dependencies**: External dependencies and vendor directories
- **project_specific**: Project-specific patterns

### Key Functions

```bash
# Discover all gitignore files
discover_gitignore_files

# Extract patterns from a single file
extract_patterns "/path/to/.gitignore"

# Classify a pattern
classify_pattern "*.o"  # Returns: build_artifacts
```

---

## design-unification-strategy.sh

Analyzes pattern conflicts and develops a comprehensive unification strategy for gitignore patterns.

### Location
```
scripts/design-unification-strategy.sh
```

### Synopsis
```bash
design-unification-strategy.sh [OPTIONS]
```

### Description
Takes the output from `analyze-gitignore.sh` and develops a conflict resolution framework, priority hierarchy, and unified structure template.

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DIR` | `/mnt/mtwo/programming/ai-stuff` | Base directory |
| `ASSETS_DIR` | `${DIR}/delta-version/assets` | Directory for configuration files |

### Output Files
Generated in `assets/` directory:

| File | Description |
|------|-------------|
| `unification-strategy.md` | Complete unification strategy document |
| `conflict-resolution-rules.md` | Specific conflict handling rules |
| `attribution-format.md` | Pattern attribution system specification |
| `unified-gitignore-template.txt` | Template structure for unified gitignore |

### Priority Hierarchy
The strategy establishes this conflict resolution priority (highest to lowest):

1. **Security** - Credential files, secrets, keys
2. **Critical Build** - Essential build artifacts
3. **Project Specific** - Custom project patterns
4. **Universal** - Common cross-project patterns
5. **Dependencies** - Package manager outputs

---

## process-gitignore-patterns.sh

Pattern processing engine that implements the unification strategy to process, resolve conflicts, and categorize patterns.

### Location
```
scripts/process-gitignore-patterns.sh
```

### Synopsis
```bash
process-gitignore-patterns.sh [OPTIONS]
```

### Description
Core processing engine that:
- Parses patterns from all gitignore files
- Normalizes pattern syntax
- Resolves conflicts using defined rules
- Deduplicates patterns
- Categorizes into 8 pattern types
- Tracks source attribution

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DIR` | `/mnt/mtwo/programming/ai-stuff` | Base directory |
| `ASSETS_DIR` | `${DIR}/delta-version/assets` | Assets directory |

### Data Structures
The script maintains associative arrays for tracking:

```bash
declare -A all_patterns           # pattern -> count
declare -A pattern_sources        # pattern -> source_files
declare -A pattern_categories     # pattern -> category
declare -A pattern_attribution    # pattern -> attribution_info
declare -A conflict_resolutions   # pattern -> resolution_info
```

### Pattern Categories

| Category | Description | Examples |
|----------|-------------|----------|
| security | Credential and secret files | `*.key`, `.env`, `*.pem` |
| build_artifacts | Compiled output | `*.o`, `build/`, `target/` |
| ide_files | Editor configurations | `.vscode/`, `*.swp` |
| language_specific | Language runtime files | `node_modules/`, `__pycache__/` |
| os_specific | OS-generated files | `.DS_Store`, `Thumbs.db` |
| logs | Log files | `*.log`, `logs/` |
| dependencies | External dependencies | `vendor/`, `libs/` |
| project_specific | Custom patterns | Various |

### Key Functions

```bash
# Parse patterns from a gitignore file
parse_patterns "/path/to/.gitignore"

# Normalize a pattern
normalize_pattern "build\\" # Returns: build/

# Classify pattern type
classify_pattern_type "*.key" # Returns: security

# Get human-readable source name
get_source_name "/path/to/project/.gitignore" # Returns: proj:project
```

### Statistics Output
Processing generates statistics including:
- Total patterns discovered
- Unique patterns after deduplication
- Conflicts identified and resolved
- Distribution by category

---

## Common Conventions

### DIR Variable Pattern
All scripts follow the `DIR` variable convention:
```bash
DIR="${DIR:-/mnt/mtwo/programming/ai-stuff}"
```

This allows scripts to be run from any directory while maintaining consistent path resolution. Override by setting `DIR` before execution:
```bash
DIR=/custom/path ./list-projects.sh
```

### Vimfold Organization
All functions use vimfolds for code organization:
```bash
# -- {{{ function_name
function function_name() {
    # implementation
}
# }}}
```

### Interactive Mode
Scripts supporting interactive mode use the `-I` flag:
```bash
script.sh -I
```

Interactive mode provides menu-driven operation for manual use, while headless mode supports automation and scripting.

### Error Handling
Scripts prefer explicit error messages over silent fallbacks. Non-zero exit codes indicate errors.

---

## Integration Examples

### Chaining Scripts
```bash
# Process gitignore workflow
./analyze-gitignore.sh && \
./design-unification-strategy.sh && \
./process-gitignore-patterns.sh
```

### Using Project List in Other Scripts
```bash
#!/bin/bash
source /path/to/delta-version/scripts/list-projects.sh

for project in $(get_project_list_for_integration "abs-paths"); do
    echo "Processing: $project"
    # ... do something with each project
done
```

### JSON Output for External Tools
```bash
./list-projects.sh --format json | jq '.projects[].name'
```
