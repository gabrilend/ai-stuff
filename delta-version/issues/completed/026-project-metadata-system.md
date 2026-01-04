# Issue 026: Project Metadata System

## Current Behavior
No standardized system exists for storing and retrieving project metadata, making it difficult to generate reports, track project characteristics, or perform automated project classification.

## Intended Behavior
Implement a project-agnostic metadata aggregation system where individual projects can register their own metadata, and Delta-Version provides discovery, storage, and cross-project coordination services without analyzing project internals.

## Design Decisions (2025-01-04)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Storage | Per-project `project.meta.json` | Decentralized; projects own their data |
| Format | JSON | Standard, parseable in any language |
| Fallback | None — explicit declaration required | Enforces discipline; no guessing |
| Schema | Minimal required fields | name + status required; all else optional |

## JSON Schema

### Required Fields
- `name` (string): Project identifier
- `status` (string): One of "active", "maintenance", "experimental", "archived"

### Optional Fields
- `description` (string): Brief project description
- `language` (string or array): Primary language(s) — "lua", "bash", "rust", etc.
- `phase` (number): Current development phase
- `dependencies` (array): Other projects this depends on
- `tags` (array): Freeform categorization tags
- `created` (string): ISO date of project creation
- `updated` (string): ISO date of last significant update

## Suggested Implementation Steps

1. **Schema Definition**
   - Document JSON schema with required/optional fields
   - Create example project.meta.json for delta-version

2. **Aggregation Script**
   - Create scripts/manage-metadata.sh
   - Discover all project.meta.json files across monorepo
   - Build aggregated index for fast queries
   - Provide query/filter capabilities (by status, language, tags)

3. **Query Interface**
   - List all projects with metadata
   - Filter by field values (--status=active, --language=lua)
   - Output formats: names, json, table

4. **Integration with Project Tools**
   - Reference from list-projects.sh where appropriate
   - Metadata-aware project discovery

## Acceptance Criteria
- [x] Metadata schema defined and documented
- [x] Per-project project.meta.json format working
- [x] Aggregation script discovers and indexes metadata
- [x] Query/filter capabilities operational
- [x] Delta-version itself has project.meta.json as example

## Implementation Notes (2025-01-04)

### Files Created
- `project.meta.json` — Example metadata for delta-version
- `scripts/manage-metadata.sh` — Aggregation and query tool
- `docs/project-metadata-schema.md` — Schema documentation
- `assets/metadata-cache.json` — Generated cache file

### Commands Available
```bash
manage-metadata.sh list                    # List projects with metadata
manage-metadata.sh list --format=table     # Table format
manage-metadata.sh list --status=active    # Filter by status
manage-metadata.sh list --language=lua     # Filter by language
manage-metadata.sh list --tag=tooling      # Filter by tag
manage-metadata.sh validate --all          # Validate all metadata
manage-metadata.sh show PROJECT            # Show specific project
manage-metadata.sh stats                   # Aggregate statistics
manage-metadata.sh init PROJECT            # Create template
```

### Design Rationale
- **No fallback by design**: Projects must explicitly opt-in via project.meta.json
- **Minimal required fields**: Only name + status required, everything else optional
- **Cached aggregation**: Metadata cached in assets/ for fast queries

## Related Issues
- 023-create-project-listing-utility.md
- 025-repository-structure-validation.md
- 027-basic-reporting-framework.md (blocked by this)
- 032-project-donation-support-links.md (blocked by this)

## Implementation Priority
Medium - Important for project management and reporting

## Estimated Complexity
Medium - Clear scope with design decisions made