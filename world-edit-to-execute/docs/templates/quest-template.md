# Quest Template

Use this template for individual quest entries within a quest log.

---

## Quest Entry Format

```markdown
### Quest {{ID}}: {{QUEST_NAME}}
**Location:** `{{FILE}}:{{LINE_START}}-{{LINE_END}}`
**XP Reward:** {{XP}}
**Skill Gained:** {{SKILL_NAME}}

*"{{FLAVOR_TEXT}}"*

\`\`\`{{LANGUAGE}}
-- THE PROBLEM
{{PROBLEMATIC_CODE}}
-- {{PROBLEM_COMMENT}}
\`\`\`

**Your Quest:**
- [ ] {{TASK_1}}
- [ ] {{TASK_2}}
- [ ] {{TASK_3}}

**Reward:** {{REWARD_DESCRIPTION}}
```

---

## Field Definitions

| Field | Description | Example |
|-------|-------------|---------|
| `{{ID}}` | Quest identifier (tier + number) | `S1`, `A2`, `J3` |
| `{{QUEST_NAME}}` | Evocative name for the bug | "The Trimmed Tale" |
| `{{FILE}}` | Source file containing bug | `src/parsers/wts.lua` |
| `{{LINE_START}}-{{LINE_END}}` | Line range | `48-52` |
| `{{XP}}` | Experience points (50-600) | `100` |
| `{{SKILL_NAME}}` | What completing teaches | "Parser Edge Cases" |
| `{{FLAVOR_TEXT}}` | Poetic problem description | "The strings speak, but..." |
| `{{LANGUAGE}}` | Code language | `lua` |
| `{{PROBLEMATIC_CODE}}` | The buggy code snippet | `text:gsub("^\n", "")` |
| `{{PROBLEM_COMMENT}}` | What's wrong | "Strips legitimate newlines" |
| `{{TASK_N}}` | Actionable fix step | "Add a flag to preserve..." |
| `{{REWARD_DESCRIPTION}}` | Knowledge gained | "Understanding of WTS format" |

---

## Tier-Specific Styling

### :seedling: Seedling (50-75 XP)
- Single-file fixes
- Documentation updates
- Trivial logic errors
- Style: "A pebble in your boot"

### :herb: Apprentice (100-150 XP)
- Simple logic fixes
- Add error handling
- Basic defensive programming
- Style: "A wolf at the door"

### :crossed_swords: Journeyman (200-300 XP)
- Multi-file changes
- Error propagation
- API design fixes
- Style: "A puzzle with missing pieces"

### :european_castle: Veteran (400-600 XP)
- Architectural changes
- Performance optimization
- Complex refactoring
- Style: "A labyrinth to navigate"

---

## Example Quest (Seedling)

```markdown
### Quest S1: The Trimmed Tale
**Location:** `src/parsers/wts.lua:48-52`
**XP Reward:** 50
**Skill Gained:** Parser Edge Cases

*"The trigger strings speak, but their first words are stolen.
A newline, intentionally placed, vanishes into the void."*

\`\`\`lua
-- THE PROBLEM
text = text:gsub("^\n", ""):gsub("\n$", "")
-- Strips legitimate leading/trailing newlines
\`\`\`

**Your Quest:**
- [ ] Add a flag to preserve intentional whitespace
- [ ] Or document this as intended behavior
- [ ] Test with a WTS file containing `TRIGSTR_001` = `"\nHello"`

**Reward:** Understanding of the WTS format, parser modification basics.
```

---

## Flavor Text Guidelines

Good flavor text:
1. Describes the **symptom**, not the cause
2. Uses metaphor related to the domain
3. Creates mystery/intrigue
4. Is 1-3 sentences max

Examples:
- "Time flows backward. The game pretends it didn't happen."
- "I asked the oracle for four components. She gave me two and fell silent."
- "The blacksmith gave me a tool. It works, until the data runs short."
