# Issue 909: AI Editor

**Phase:** 9
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 901 (Editor core), Phase 4 (Runtime)

---

## Current Behavior

No AI editing capability exists. Computer players cannot be configured.

## Intended Behavior

Full AI editing with feature parity to WC3 AI Editor:

### AI Components

| Component | Description |
|-----------|-------------|
| **Build Order** | What structures to build and when |
| **Attack Waves** | When and how to attack |
| **Defense** | How to defend base |
| **Workers** | Worker management and harvesting |
| **Heroes** | Hero usage and leveling |
| **Conditions** | When to trigger behaviors |

### Editor Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│ AI EDITOR                                                           │
├─────────────────────────────────────────────────────────────────────┤
│ AI Script: [Custom AI v1.0 ▼]    Race: [Human ▼]    [New] [Delete] │
├──────────────────────────────┬──────────────────────────────────────┤
│ SECTIONS                     │ BUILD ORDER                          │
│                              │                                      │
│ ○ Build Order               │ Priority  Building       Workers     │
│ ○ Attack Waves              │ ───────────────────────────────────  │
│ ○ Defense                    │ 1         Town Hall      5          │
│ ○ Workers                    │ 2         Barracks       -          │
│ ○ Heroes                     │ 3         Farm           -          │
│ ○ Conditions                 │ 4         Altar          -          │
│                              │ 5         Lumber Mill    3          │
│ ─────────────────────────── │ 6         Blacksmith     -          │
│ QUICK SETTINGS               │ 7         Farm           -          │
│                              │ 8         Workshop       -          │
│ Difficulty: [Normal ▼]      │                                      │
│ Aggression: [====|===] 70%  │ [+ Add] [Remove] [Move Up] [Down]   │
│ Expansion:  [===|====] 50%  │                                      │
│                              │ Condition: [Gold >= 500 ▼]          │
└──────────────────────────────┴──────────────────────────────────────┘
```

### Attack Wave Configuration

```
ATTACK WAVES
┌────────────────────────────────────────────────────────────┐
│ Wave   Trigger              Units                          │
├────────────────────────────────────────────────────────────┤
│ 1      Time: 5:00          4x Footman, 2x Rifleman        │
│ 2      Time: 8:00          6x Footman, 4x Rifleman        │
│ 3      Gold >= 2000        2x Knight, 2x Mortar           │
│ 4      Enemy < 50%         All available                   │
├────────────────────────────────────────────────────────────┤
│ WAVE EDITOR                                                │
│                                                            │
│ Trigger:                                                   │
│   ○ Time elapsed: [5:00___]                               │
│   ● Resource threshold: [Gold ▼] >= [2000]                │
│   ○ Enemy strength: [< ▼] [50]%                           │
│   ○ Custom condition...                                   │
│                                                            │
│ Units:                                                     │
│   ┌─────┐ ┌─────┐ ┌─────┐                                │
│   │4x 🗡️│ │2x 🏹│ │    │  [+ Add Unit]                   │
│   │Foot │ │Rifle│ │    │                                  │
│   └─────┘ └─────┘ └─────┘                                │
│                                                            │
│ Target: [Nearest enemy ▼]                                 │
│                                                            │
│ [Save Wave] [Test Wave]                                   │
└────────────────────────────────────────────────────────────┘
```

### Defense Configuration

```
DEFENSE SETTINGS
┌────────────────────────────────────────────────────────────┐
│ DEFENDERS                                                  │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ Unit              Count    Priority                    │ │
│ │ Footman           4        High                        │ │
│ │ Tower             2        Medium                      │ │
│ │ Rifleman          2        Low                         │ │
│ └────────────────────────────────────────────────────────┘ │
│                                                            │
│ DEFENSE REGIONS                                            │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ Region            Priority    Defenders                │ │
│ │ Main Base         Critical    6                        │ │
│ │ Gold Mine         High        2                        │ │
│ │ Expansion         Medium      2                        │ │
│ └────────────────────────────────────────────────────────┘ │
│                                                            │
│ Response Threshold: [3] attacking units triggers defense  │
│ Return Delay: [5] seconds after threat cleared           │
└────────────────────────────────────────────────────────────┘
```

### Hero Configuration

```
HERO SETTINGS
┌────────────────────────────────────────────────────────────┐
│ HERO SELECTION                                             │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ Order    Hero              Priority                    │ │
│ │ 1        Paladin           Always                      │ │
│ │ 2        Archmage          If gold > 1000             │ │
│ │ 3        Mountain King     Never                       │ │
│ └────────────────────────────────────────────────────────┘ │
│                                                            │
│ ABILITY PRIORITY (Paladin)                                │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ Level    Ability                                       │ │
│ │ 1        Holy Light                                    │ │
│ │ 2        Divine Shield                                 │ │
│ │ 3        Holy Light                                    │ │
│ │ 4        Devotion Aura                                 │ │
│ │ 5        Holy Light                                    │ │
│ │ 6        Resurrection (Ultimate)                       │ │
│ └────────────────────────────────────────────────────────┘ │
│                                                            │
│ Item Priority: [Healing ▼] > [Damage ▼] > [Armor ▼]      │
└────────────────────────────────────────────────────────────┘
```

### API Design

```lua
local ai_editor = require("editor.ai")

-- Create AI script
local ai = ai_editor.create({
    name = "Custom AI v1.0",
    race = "human",
    difficulty = "normal",
})

-- Build order
ai_editor.add_build_step(ai, {
    building = "htow",  -- Town Hall
    priority = 1,
    workers = 5,
    condition = nil,
})

-- Attack waves
ai_editor.add_attack_wave(ai, {
    trigger = {type = "time", value = 300},  -- 5 minutes
    units = {
        {id = "hfoo", count = 4},
        {id = "hrif", count = 2},
    },
    target = "nearest_enemy",
})

-- Defense
ai_editor.set_defense(ai, {
    regions = {
        {region = "main_base", priority = "critical", defenders = 6},
    },
    response_threshold = 3,
})

-- Heroes
ai_editor.set_hero_priority(ai, {
    {id = "Hpal", priority = "always"},
    {id = "Hamg", condition = "gold >= 1000"},
})

ai_editor.set_hero_abilities(ai, "Hpal", {
    [1] = "AHhb",  -- Holy Light
    [2] = "AHds",  -- Divine Shield
    [3] = "AHhb",
    -- ...
})

-- Export to AI script
local script = ai_editor.export(ai)

-- Import from AI script
local ai = ai_editor.import(script_path)
```

## Suggested Implementation Steps

1. Create `src/editor/ai/` module structure
2. Implement AI script data model
3. Implement build order editor
4. Implement attack wave editor
5. Implement defense configuration
6. Implement worker management
7. Implement hero configuration
8. Implement conditions system
9. Implement difficulty presets
10. Implement AI script export/import
11. Implement AI testing (simulate)
12. Integrate with undo/redo
13. Create tests

## Acceptance Criteria

- [ ] AI scripts creatable per race
- [ ] Build order editable with conditions
- [ ] Attack waves configurable (timing, units, target)
- [ ] Defense regions configurable
- [ ] Hero priority and ability progression editable
- [ ] Difficulty affects aggression/expansion
- [ ] AI script exportable
- [ ] AI script importable
- [ ] AI testable in simulation
- [ ] All operations support undo/redo

## Related Documents

- Phase 4 - Runtime (AI execution)
- Issue 903 - Object placer (AI uses placed units)
- Issue 904 - Region editor (defense regions)

## Notes

- WC3 AI uses JASS AI scripts (.ai files)
- Consider Lua-based AI for more flexibility
- "Test AI" could run accelerated simulation
- May want AI difficulty scaling (easy → insane)
- Consider "AI templates" for common strategies
- Behavioral trees might be more powerful than script-based AI
