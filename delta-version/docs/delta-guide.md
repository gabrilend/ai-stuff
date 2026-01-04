# Delta-Version: Project Maintainer Guide

This guide covers all delta-version capabilities available to project maintainers in the ai-stuff monorepo. Delta-version is the meta-project that provides shared infrastructure, tooling, and coordination across all projects.

**Canonical location:** `delta-version/docs/delta-guide.md`

---

## Table of Contents

1. [Project Discovery](#project-discovery)
2. [Project Metadata](#project-metadata)
3. [Issue Management](#issue-management)
4. [History Tools](#history-tools)
5. [Gitignore System](#gitignore-system)
6. [Repository Validation](#repository-validation)
7. [Dependency Visualization](#dependency-visualization)
8. [Quick Reference](#quick-reference)

---

## Project Discovery

### list-projects.sh

Discovers and lists all projects in the monorepo.

```bash
# List project names (default)
delta-version/scripts/list-projects.sh

# List absolute paths
delta-version/scripts/list-projects.sh --abs-paths

# JSON output (for scripting)
delta-version/scripts/list-projects.sh --format=json

# CSV output
delta-version/scripts/list-projects.sh --format=csv

# List non-project directories (inverse mode)
delta-version/scripts/list-projects.sh --inverse

# Interactive mode
delta-version/scripts/list-projects.sh --interactive
```

**Detection heuristics:** Projects are identified by presence of `src/`, `issues/`, `Cargo.toml`, `package.json`, `Makefile`, etc. Directories like `libs/`, `tools/`, `backup/` are excluded.

---

## Project Metadata

### project.meta.json

Each project can declare metadata via a `project.meta.json` file in its root:

```json
{
  "name": "my-project",
  "status": "active",
  "description": "Brief description of the project",
  "language": ["lua", "bash"],
  "phase": 2,
  "tags": ["game", "modding"],
  "dependencies": ["other-project"],
  "created": "2024-06-15",
  "updated": "2025-01-04"
}
```

**Required fields:** `name`, `status`
**Status values:** `active`, `maintenance`, `experimental`, `archived`

### manage-metadata.sh

Query and manage metadata across all projects.

```bash
# List all projects with metadata
delta-version/scripts/manage-metadata.sh list

# Table format (human-readable)
delta-version/scripts/manage-metadata.sh list --format=table

# Filter by status
delta-version/scripts/manage-metadata.sh list --status=active

# Filter by language
delta-version/scripts/manage-metadata.sh list --language=lua

# Filter by tag
delta-version/scripts/manage-metadata.sh list --tag=game

# Show specific project
delta-version/scripts/manage-metadata.sh show my-project

# Validate all metadata files
delta-version/scripts/manage-metadata.sh validate --all

# Aggregate statistics
delta-version/scripts/manage-metadata.sh stats

# Create template for new project
delta-version/scripts/manage-metadata.sh init my-new-project
```

**Note:** Projects without `project.meta.json` do not appear in metadata queries. This is by design — explicit opt-in only.

---

## Issue Management

### Issue File Convention

Issues live in `your-project/issues/` with naming: `{PHASE}{ID}-{description}.md`

Examples:
- `101-setup-infrastructure.md` — Phase 1, Issue 01
- `205-add-caching.md` — Phase 2, Issue 05
- `035a-sub-issue-name.md` — Sub-issue with alphabetic suffix

### manage-issues.sh

Create, validate, and complete issues.

```bash
# List all issues in a project
delta-version/scripts/manage-issues.sh list /path/to/project

# Create new issue (interactive)
delta-version/scripts/manage-issues.sh create /path/to/project

# Create with specific details
delta-version/scripts/manage-issues.sh create /path/to/project \
  --phase=2 --id=15 --title="add-user-auth"

# Validate issue format
delta-version/scripts/manage-issues.sh validate /path/to/project

# Complete an issue (moves to completed/)
delta-version/scripts/manage-issues.sh complete /path/to/project 205

# Search issues
delta-version/scripts/manage-issues.sh search /path/to/project "keyword"

# Show statistics
delta-version/scripts/manage-issues.sh stats /path/to/project
```

### Issue Template Structure

```markdown
# Issue {PHASE}{ID}: {Title}

## Current Behavior
What currently happens (or doesn't exist).

## Intended Behavior
What should happen after implementation.

## Suggested Implementation Steps
1. Step one
2. Step two
3. Step three

## Acceptance Criteria
- [ ] Criterion one
- [ ] Criterion two

## Related Issues
- {OTHER_ISSUE}.md

## Dependencies
- Blocked by: {ISSUE}
- Blocks: {ISSUE}
```

---

## History Tools

### generate-history.sh

Generate readable HISTORY.txt narratives from git log.

```bash
# Generate for specific project
delta-version/scripts/generate-history.sh --project my-project

# Generate for all projects with history
delta-version/scripts/generate-history.sh --all

# Preview without writing
delta-version/scripts/generate-history.sh --project my-project --dry-run

# Skip specification files (focus on implementation commits)
delta-version/scripts/generate-history.sh --project my-project --skip-specs

# Only include completed issue commits
delta-version/scripts/generate-history.sh --project my-project --completed-only

# Output as markdown instead of txt
delta-version/scripts/generate-history.sh --project my-project --format=md
```

**Output example:**
```
[1] 2024-12-08 - Initial project vision and structure
    Created foundational architecture for the application.

[2] 2024-12-10 - Issue 001: Setup infrastructure
    Implemented core build system and directory layout.
```

### reconstruct-history.sh

Rebuild meaningful git history from issue files (for projects imported without history).

```bash
# Preview reconstruction plan
delta-version/scripts/reconstruct-history.sh --dry-run /path/to/project

# Reconstruct history
delta-version/scripts/reconstruct-history.sh /path/to/project

# Preserve post-blob commits (if project has some real history)
delta-version/scripts/reconstruct-history.sh --preserve-post-blob /path/to/project

# Replace original branch with reconstructed version
delta-version/scripts/reconstruct-history.sh --replace-original /path/to/project
```

**Reconstruction order:**
1. Vision file commit (if exists)
2. Each completed issue (topologically sorted by dependencies)
3. Bulk commit of remaining files

### import-project-histories.sh

Import external projects while preserving their git history.

```bash
# Import a project
delta-version/scripts/import-project-histories.sh /external/path/to/project

# Import with specific branch name
delta-version/scripts/import-project-histories.sh /external/path --branch=my-branch
```

---

## Gitignore System

The monorepo uses a unified `.gitignore` at the root, aggregated from all project patterns.

### analyze-gitignore.sh

Discover and analyze gitignore patterns across all projects.

```bash
# Run analysis
delta-version/scripts/analyze-gitignore.sh

# Output location: delta-version/assets/gitignore-analysis-report.txt
```

**Output includes:**
- Pattern count per project
- Categorization by type (build, IDE, language-specific, etc.)
- Conflict detection

### generate-unified-gitignore.sh

Produce the unified `.gitignore` from all discovered patterns.

```bash
# Generate (with backup)
delta-version/scripts/generate-unified-gitignore.sh

# Preview without writing
delta-version/scripts/generate-unified-gitignore.sh --dry-run
```

### validate-gitignore.sh

Run validation tests on the gitignore.

```bash
# Run all 39 tests
delta-version/scripts/validate-gitignore.sh

# Generate report
delta-version/scripts/validate-gitignore.sh --report

# Interactive mode
delta-version/scripts/validate-gitignore.sh --interactive
```

**Tests include:** Syntax validation, critical file protection, functional pattern matching, performance checks.

### maintain-gitignore.sh

Health monitoring and maintenance.

```bash
# Check gitignore health
delta-version/scripts/maintain-gitignore.sh status

# Detect changes since last generation
delta-version/scripts/maintain-gitignore.sh check

# Interactive maintenance
delta-version/scripts/maintain-gitignore.sh --interactive
```

---

## Repository Validation

### validate-repository.sh

Verify repository structure, branches, and configuration.

```bash
# Run validation
delta-version/scripts/validate-repository.sh

# Validate specific project
delta-version/scripts/validate-repository.sh --project my-project

# Check all branch configurations
delta-version/scripts/validate-repository.sh --branches
```

**Validates:**
- Directory structure conventions
- Branch existence and configuration
- Remote setup
- Gitignore presence

---

## Dependency Visualization

### visualize-deps.sh

Visualize issue dependencies as trees or graphs.

```bash
# Show dependency tree for a project
delta-version/scripts/visualize-deps.sh /path/to/project

# Export as DOT format (for Graphviz)
delta-version/scripts/visualize-deps.sh /path/to/project --format=dot

# Show what's blocked by an issue
delta-version/scripts/visualize-deps.sh /path/to/project --blocked-by=035

# Identify parallelizable work
delta-version/scripts/visualize-deps.sh /path/to/project --parallel
```

---

## History Viewer

### history-viewer.sh

Browse project git history as a readable narrative with vim-style navigation.

```bash
# Interactive project selection
delta-version/scripts/history-viewer.sh

# View specific project
delta-version/scripts/history-viewer.sh delta-version

# Start at specific commit
delta-version/scripts/history-viewer.sh --project delta-version --commit abc123f
```

**Navigation:**

| Key | Action |
|-----|--------|
| ←/h | Previous commit (older) |
| →/l | Next commit (newer) |
| ↑/k | Scroll up |
| ↓/j | Scroll down |
| ↑↑/kk | Jump to top (double-tap) |
| ↓↓/jj | Jump to bottom (double-tap) |
| PgUp/PgDn | Scroll page |
| g/G | First/last commit |
| q/Esc | Quit |

**Content Priority:** For each commit, content is displayed in this order:
1. Commit message
2. Notes (`notes/` directory)
3. Completed issues (`issues/completed/` only — not root-level plans)
4. Documentation (`docs/` directory)
5. Other markdown files

---

## Quick Reference

### New Project Checklist

When creating a new project:

1. **Create directory structure:**
   ```bash
   mkdir -p my-project/{docs,notes,src,libs,assets,issues}
   ```

2. **Create vision document:**
   ```bash
   touch my-project/notes/vision.md
   ```

3. **Add project metadata:**
   ```bash
   delta-version/scripts/manage-metadata.sh init my-project
   # Then edit my-project/project.meta.json
   ```

4. **Symlink this guide:**
   ```bash
   ln -s ../../delta-version/docs/delta-guide.md my-project/docs/delta-guide.md
   ```

5. **Create initial issues:**
   ```bash
   delta-version/scripts/manage-issues.sh create my-project
   ```

### Common Workflows

| Task | Command |
|------|---------|
| Find all Lua projects | `manage-metadata.sh list --language=lua` |
| See what's in progress | `manage-issues.sh list PROJECT \| grep -v completed` |
| Generate project history | `generate-history.sh --project PROJECT` |
| Check gitignore health | `maintain-gitignore.sh status` |
| Validate issue format | `manage-issues.sh validate PROJECT` |
| See all active projects | `manage-metadata.sh list --status=active --format=table` |

### Script Locations

All scripts are in `delta-version/scripts/`. You can run them from anywhere:

```bash
# From any directory
/mnt/mtwo/programming/ai-stuff/delta-version/scripts/list-projects.sh

# Or add to PATH
export PATH="$PATH:/mnt/mtwo/programming/ai-stuff/delta-version/scripts"
list-projects.sh
```

### Getting Help

Every script supports `--help`:

```bash
delta-version/scripts/manage-metadata.sh --help
delta-version/scripts/manage-issues.sh --help
delta-version/scripts/generate-history.sh --help
```

---

## Further Reading

- [Project Status](PROJECT-STATUS.md) — Current development state
- [Project Metadata Schema](project-metadata-schema.md) — Full JSON schema details
- [History Tools Guide](history-tools-guide.md) — Deep dive on history reconstruction
- [Roadmap](roadmap.md) — Development phases and future plans

---

*This guide is maintained in `delta-version/docs/delta-guide.md` and symlinked to all project `docs/` directories.*
