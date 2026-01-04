# Project Metadata Schema

This document defines the `project.meta.json` format used by the Delta-Version metadata system.

## Overview

Each project in the monorepo can declare metadata by placing a `project.meta.json` file in its root directory. Delta-Version's metadata tools discover and aggregate these files to enable cross-project queries and reporting.

**Key Principle:** Projects must explicitly declare metadata. There is no automatic detection or fallback — a project without `project.meta.json` does not appear in metadata queries.

## File Location

```
your-project/
├── project.meta.json    <-- Place here
├── src/
├── docs/
└── ...
```

## Schema

### Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Project identifier (should match directory name) |
| `status` | string | One of: `"active"`, `"maintenance"`, `"experimental"`, `"archived"` |

### Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `description` | string | Brief description of the project's purpose |
| `language` | string or array | Primary language(s): `"lua"`, `"bash"`, `"rust"`, `["lua", "c"]` |
| `phase` | number | Current development phase (1, 2, 3, etc.) |
| `dependencies` | array | Other projects this depends on: `["lib-a", "lib-b"]` |
| `tags` | array | Freeform categorization: `["game", "tui", "utility"]` |
| `created` | string | ISO date of project creation: `"2024-06-15"` |
| `updated` | string | ISO date of last significant update: `"2025-01-04"` |

### Status Values

| Status | Meaning |
|--------|---------|
| `active` | Under active development |
| `maintenance` | Stable, receiving bug fixes only |
| `experimental` | Proof of concept or early exploration |
| `archived` | No longer maintained |

## Examples

### Minimal Example

```json
{
  "name": "my-project",
  "status": "active"
}
```

### Full Example

```json
{
  "name": "delta-version",
  "status": "active",
  "description": "Meta-project for managing the ai-stuff monorepo",
  "language": ["bash", "lua"],
  "phase": 2,
  "tags": ["infrastructure", "tooling", "meta"],
  "dependencies": [],
  "created": "2024-12-08",
  "updated": "2025-01-04"
}
```

### Game Project Example

```json
{
  "name": "world-edit-to-execute",
  "status": "active",
  "description": "Warcraft 3 map with execute-on-edit gameplay",
  "language": ["lua", "jass"],
  "phase": 1,
  "tags": ["game", "warcraft3", "modding"],
  "dependencies": ["wow-chat"],
  "created": "2024-09-01"
}
```

## Querying Metadata

Use `scripts/manage-metadata.sh` to query across all projects:

```bash
# List all projects with metadata
./scripts/manage-metadata.sh list

# Filter by status
./scripts/manage-metadata.sh list --status=active

# Filter by language
./scripts/manage-metadata.sh list --language=lua

# Filter by tag
./scripts/manage-metadata.sh list --tag=game

# JSON output
./scripts/manage-metadata.sh list --format=json
```

## Validation

The metadata script validates:
- Required fields (`name`, `status`) are present
- `status` is a known value
- JSON syntax is valid

```bash
# Validate a specific project
./scripts/manage-metadata.sh validate /path/to/project

# Validate all discovered metadata
./scripts/manage-metadata.sh validate --all
```

## Related Documentation

- [Issue 026: Project Metadata System](../issues/026-project-metadata-system.md)
- [Issue 027: Basic Reporting Framework](../issues/027-basic-reporting-framework.md)
