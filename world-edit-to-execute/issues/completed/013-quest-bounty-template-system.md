# Issue 013: Quest & Bounty Template System

## Current Behavior

Bug tracking and technical debt documentation uses standard markdown issue files. While functional, this format doesn't provide:
- Motivational framing for contributors
- Skill progression tracking
- Clear difficulty estimation
- Gamified completion rewards

## Intended Behavior

A template system that transforms bug documentation into adventure-style quests and bounties:
- Boss Monster Bounty Boards for complex, cross-cutting bugs
- Tiered Quest Logs for smaller fixes sorted by difficulty
- Guild Rosters for tracking contributor progress
- A Lua generator for creating formatted documentation from structured specs

## Implementation Steps

- [x] Create docs/templates/ directory
- [x] Create bounty-template.md with placeholder variables
- [x] Create quest-template.md for individual quest entries
- [x] Create quest-log-template.md for full quest log structure
- [x] Create guild-roster-template.md for progress tracking
- [x] Build src/cli/quest-generator.lua with commands:
  - [x] `bounty` - Generate boss monster bounty board
  - [x] `quest` - Generate individual quest entry
  - [x] `from-spec` - Generate from Lua specification file
  - [x] `scan` - Scan codebase for TODOs/FIXMEs
- [x] Create example-spec.lua demonstrating the specification format
- [x] Update docs/table-of-contents.md with templates section
- [x] Test generator with all commands

## Related Documents

- `docs/templates/README.md` - Template system documentation
- `docs/templates/bounty-template.md` - Boss monster template
- `docs/templates/quest-template.md` - Individual quest template
- `docs/templates/quest-log-template.md` - Quest log container template
- `docs/templates/guild-roster-template.md` - Progress tracking template
- `docs/templates/example-spec.lua` - Example specification file
- `src/cli/quest-generator.lua` - Generator script
- `issues/Q00-adventurer-quest-log.md` - Example quest log output
- `issues/B01-the-phantom-priority.md` - Example bounty board
- `issues/GUILD-ROSTER.md` - Example guild roster

## Acceptance Criteria

- [x] Templates contain all necessary placeholder variables
- [x] Generator produces valid markdown matching template structure
- [x] Generator can scan codebase and suggest quest candidates
- [x] Example spec demonstrates all features
- [x] Documentation is complete and indexed

## Implementation Notes

Created a complete template system for gamified task documentation:

1. **Templates Created:**
   - bounty-template.md: ASCII art header, threat meter, lair location, battle strategy, victory conditions, test arena, lore sections
   - quest-template.md: Field definitions, tier-specific styling guide, flavor text guidelines
   - quest-log-template.md: Multi-tier structure with progression path visualization
   - guild-roster-template.md: Adventurer registry, capability unlocks, reward milestones

2. **Generator Features:**
   - `bounty`: Generates boss monster boards with threat meters (uses `#` and `.` characters)
   - `quest`: Generates individual quest entries with XP and skill rewards
   - `from-spec`: Reads Lua table specifications to generate complete quest logs
   - `scan`: Uses grep to find TODO/FIXME/BUG comments, estimates difficulty tier and XP

3. **Design Patterns Captured:**
   - Tier system: Seedling (50-75 XP) -> Apprentice (100-150) -> Journeyman (200-300) -> Veteran (400-600) -> Boss (800-1000)
   - Flavor text as poetic symptom descriptions
   - Victory conditions as checkboxes
   - Related scrolls linking to documentation
   - Guild statistics for progress tracking

4. **Existing Artifacts:**
   - Q00-adventurer-quest-log.md: 8 quests across 4 tiers
   - B01, B02, B03: Three boss bounties created earlier
   - GUILD-ROSTER.md: Tracking capability unlocks

The pattern can now be replicated to other projects by copying docs/templates/ and adapting the example-spec.lua file.

---

**Status:** Completed
**Completed:** 2025-12-29
