
═══════════════════════════════════════════════════════════════
Structure Review: 2025-12-26 00:13:51
═══════════════════════════════════════════════════════════════

I've reviewed the root issue and its sub-issues. Here's my assessment:

## Current Structure Evaluation

The 5 sub-issues (301a-301e) provide reasonable coverage of the 6 domains mentioned in the parent issue. The consolidation of inventory + progression into 301e makes sense since both relate to character advancement state.

## Issues with Existing Sub-Issues

**All sub-issues are skeletal** - they contain placeholder text like "(To be filled in during implementation)" and lack:
- Concrete implementation steps
- Acceptance criteria
- Current behavior analysis
- Dependencies on 101/102 protocol research

**Phase metadata is incorrect** - Sub-issues say "Phase: 3 - Logic Layer - Triggers and JASS" but the parent issue is clearly about Phase 3 of *this* project (protocol mapping), not some unrelated JASS system.

## Structural Gaps Identified

1. **No validation sub-issue** - After mapping all domains, there's no task to validate the matrix against actual packet captures
2. **No lookup table implementation** - The parent mentions building `wow_to_coh = {}` tables, but no sub-issue covers creating the actual code artifacts
3. **301a is overloaded** - It combines "create template" (trivial) with "map movement" (substantial), which conflates setup work with domain work

## Recommendations

### Existing Sub-Issues to Expand

- **301a-301e**: All need their implementation steps and acceptance criteria filled in before work begins. The placeholder content violates the project convention that issue files should describe the work clearly.

### Suggested New Sub-Issues

| ID | Name | Description |
|----|------|-------------|
| 301f | implement-type-validation | Create Lua module to validate mapped types against sample packet data from 101/102 research |

### Suggested Restructuring

Consider renaming 301a to better reflect its dual purpose, or split it:

| ID | Name | Description |
|----|------|-------------|
| 301a | create-matrix-template | Create docs/protocol-mapping.md with section structure, feasibility classifications, and priority tier definitions |
| 301b | map-movement-position | Map coordinates, facing, speed, travel powers; establish scale factors and coordinate transforms |

This would shift all existing b-e to c-f, keeping the scope cleaner.

## Priority

Before implementing any sub-issue, I recommend filling in the skeletal content so each issue stands alone as a work specification. The current state makes it difficult to parallelize work or onboard contributors.
