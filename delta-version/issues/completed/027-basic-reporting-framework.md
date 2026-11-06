# Issue 027: Basic Reporting Framework

## Current Behavior
Basic reporting exists in `scripts/analyze-gitignore.sh:generate_detailed_report()` for gitignore analysis only. No general-purpose reporting framework exists to generate comprehensive summaries, statistics, or analytics about the repository and its projects.

## Intended Behavior
Implement a meta-analysis reporting framework that aggregates reports from individual projects and provides repository-level summaries, cross-project coordination views, and infrastructure status without analyzing project internals.

## Suggested Implementation Steps

1. **Expand Existing Reporting**
   - Generalize `scripts/analyze-gitignore.sh:generate_detailed_report()` approach
   - Create modular report template architecture
   - Standardize report formats across different utilities

2. **Report Aggregation System**
   - Create APIs for projects to submit their own reports
   - Build aggregation pipeline for cross-project summaries
   - Implement repository infrastructure status monitoring

3. **Repository-Level Reporting**
   - Git repository health and statistics
   - Cross-project coordination status
   - Infrastructure and tooling performance
   - Project registration and discovery metrics

4. **Standard Service Reports**
   - Project discovery and listing summaries
   - Repository structure validation results  
   - Cross-project ticket distribution status
   - Git workflow and branch management statistics

## Acceptance Criteria
- [ ] Report template system functional
- [ ] Data collection framework operational
- [ ] Multiple report types can be generated
- [ ] Reports provide actionable insights and statistics

## Related Issues
- 025-repository-structure-validation.md
- 026-project-metadata-system.md
- 023-create-project-listing-utility.md

## Implementation Priority
Medium - Important for visibility and project management

## Estimated Complexity
Medium - Requires flexible architecture and data processing capabilities
---

## What Happened

**2026-11-02 — closed because the repository-level reports this issue asked for exist, each in the tool that owns its data. The general framework sketched above has no remaining job.**

Against the four groups of reports in the plan:

| Asked for | Where it is now |
|-----------|-----------------|
| Repository statistics, project discovery and listing summaries | `scripts/census-projects.lua`. It covers every project's state, issue counts and completion, three months of activity per project, and how many projects keep each house convention. Output is terminal, markdown or JSON, and it keeps the root README's figures current (`--write-readme` / `--check-readme`). |
| Per-project issue progress | `scripts/progress-dashboard.lua` (monorepo `scripts/`), by phase, in terminal, markdown or JSON |
| Repository structure validation results | `scripts/validate-repository.sh` (issue 025) and the shared `scripts/validate-issues` |
| Infrastructure and tooling status | `scripts/check-utilities.sh` (issues 042/042a) |
| Git history and workflow | `scripts/generate-history.sh`, `history-viewer.lua`, and the shared `scripts/git-history.sh` |
| Project metadata | `scripts/manage-metadata.sh` (issue 026) |

Each of those writes its own report in the formats people actually used
(terminal, markdown, JSON). A shared report-template layer on top would
add an abstraction with no second consumer.

The "APIs for projects to submit their own reports" were never asked for
by any project. They are dropped rather than built.

The acceptance boxes above stay unticked on purpose. They describe the
framework, which was not built. The need behind them is met by the tools
in the table.
