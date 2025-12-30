# Quest & Bounty Template System

```
The Gamified Task Management Pattern

"Every bug is a monster. Every fix is a victory."
```

---

## Philosophy

Technical debt and bugs are demotivating. Reframing them as quests with
progression, rewards, and lore transforms maintenance into adventure.

This template system provides:
1. **Bounty Boards** - Boss-level complex bugs requiring deep understanding
2. **Quest Logs** - Tiered tasks sorted by difficulty
3. **Guild Rosters** - Progress tracking and capability unlocks
4. **Generators** - Scripts to create consistent formatted files

---

## Pattern Structure

### The Difficulty Spectrum

| Tier | Symbol | XP Range | Typical Scope |
|------|--------|----------|---------------|
| Seedling | :seedling: | 50-75 | Single-line fixes, documentation |
| Apprentice | :herb: | 100-150 | Simple logic fixes, single file |
| Journeyman | :crossed_swords: | 200-300 | Multi-file changes, error handling |
| Veteran | :european_castle: | 400-600 | Architectural changes, performance |
| Boss | :dragon: | 800-1000 | Cross-cutting concerns, deep bugs |

### Bounty Board Elements

```
+-- Header Box (ASCII art, threat level meter)
|
+-- Monster's Nature (root cause explanation)
|
+-- Lair Location (file:line with code snippet)
|
+-- Battle Strategy
|   +-- What the Monster Exploits (attack pattern)
|   +-- Weapons Required (solution approaches)
|
+-- Victory Conditions (acceptance criteria)
|
+-- Test Arena (validation code)
|
+-- Adventurer's Log (flavor/lore)
|
+-- Related Scrolls (documentation links)
```

### Quest Log Elements

```
+-- Quest Header (name, location, XP, skill)
|
+-- Flavor Text (italicized problem description)
|
+-- Code Snippet (the bug in context)
|
+-- Task Checklist (actionable steps)
|
+-- Reward Description (what completing teaches)
```

---

## Template Files

| File | Purpose |
|------|---------|
| `bounty-template.md` | Boss monster bounty board |
| `quest-template.md` | Individual quest entry |
| `quest-log-template.md` | Full quest log with tiers |
| `guild-roster-template.md` | Progress tracking roster |

---

## Generator Usage

```bash
# Generate a bounty board
lua src/cli/quest-generator.lua bounty \
    --name "The Phantom Priority" \
    --threat 8 \
    --location "astar.lua:355" \
    --output issues/B04-new-bounty.md

# Generate a quest
lua src/cli/quest-generator.lua quest \
    --name "The Trimmed Tale" \
    --tier seedling \
    --xp 50 \
    --location "wts.lua:48" \
    --output issues/quests/S1.md

# Generate from YAML spec
lua src/cli/quest-generator.lua from-spec quests.yaml
```

---

## Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Bounty | `B{NN}-{kebab-name}.md` | `B01-the-phantom-priority.md` |
| Quest Log | `Q{NN}-{description}.md` | `Q00-adventurer-quest-log.md` |
| Individual Quest | `{TIER}{N}-{name}.md` | `S1-the-trimmed-tale.md` |
| Guild Roster | `GUILD-ROSTER.md` | Single per project |

---

## Reward Design Principles

1. **Capability Unlocks** - Completing quests unlocks tools/patterns
2. **Title Progression** - Accumulate titles showing expertise
3. **Equipment Metaphors** - Skills as weapons, patterns as armor
4. **Lore Integration** - Stories that teach the "why" behind fixes

---

## Cross-Project Application

To apply this system to another project:

1. Copy `docs/templates/` to the new project
2. Run the generator to create initial bounties from known issues
3. Create a quest log by auditing the codebase for common bugs
4. Set up a guild roster to track progress

The pattern works for any codebase with:
- Accumulated technical debt
- Contributors at various skill levels
- Need for knowledge transfer through fixing bugs
