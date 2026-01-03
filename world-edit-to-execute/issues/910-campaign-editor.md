# Issue 910: Campaign Editor

**Phase:** 9
**Type:** Implementation
**Priority:** Medium
**Dependencies:** 901 (Editor core), 911 (Map format)

---

## Current Behavior

No campaign editing capability exists. Multi-map storylines cannot be created.

## Intended Behavior

Full campaign editing with feature parity to WC3 Campaign Editor:

### Campaign Components

| Component | Description |
|-----------|-------------|
| **Maps** | Ordered list of maps in campaign |
| **Progression** | What carries between maps |
| **Cinematics** | Intro/outro movies |
| **Story** | Text, dialogue, briefings |
| **Unlocks** | Conditional map availability |
| **Difficulty** | Campaign-wide difficulty settings |

### Editor Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│ CAMPAIGN EDITOR                                                     │
├─────────────────────────────────────────────────────────────────────┤
│ Campaign: [The Rise of Heroes ▼]                    [New] [Delete] │
├──────────────────────────────┬──────────────────────────────────────┤
│ CAMPAIGN STRUCTURE           │ MAP SETTINGS                         │
│                              │                                      │
│ ◉ Prologue                  │ ┌──────────────────────────────────┐ │
│   └─ 📜 Intro Cinematic     │ │ Chapter 2: The Dark Forest      │ │
│ ◉ Chapter 1: The Beginning  │ ├──────────────────────────────────┤ │
│   └─ 🗺️ Tutorial Map        │ │ Map File: [dark_forest.w3x]     │ │
│ ◉ Chapter 2: The Dark Forest│ │                                  │ │
│   └─ 🗺️ Forest Battle       │ │ Prerequisites:                   │ │
│ ○ Chapter 3: The Siege      │ │   [x] Complete Chapter 1         │ │
│   └─ 🗺️ Castle Defense      │ │   [ ] Hero level >= 5            │ │
│ ○ Epilogue                   │ │                                  │ │
│   └─ 📜 Outro Cinematic     │ │ Difficulty Modifiers:            │ │
│                              │ │   Easy:   Enemy HP -20%          │ │
│ [+ Add Chapter]              │ │   Normal: No change              │ │
│ [+ Add Cinematic]            │ │   Hard:   Enemy HP +30%          │ │
│                              │ │                                  │ │
│ ● = Completed (playtest)    │ │ [Edit Map] [Preview] [Test]      │ │
│ ○ = Not yet reached         │ └──────────────────────────────────┘ │
└──────────────────────────────┴──────────────────────────────────────┘
```

### Progression System

```
PERSISTENT DATA
┌────────────────────────────────────────────────────────────┐
│ What carries between maps:                                 │
├────────────────────────────────────────────────────────────┤
│ [x] Heroes (level, abilities, items)                      │
│ [x] Hero experience                                        │
│ [ ] Gold (with cap: [5000])                               │
│ [ ] Lumber (with cap: [2000])                             │
│ [x] Quest progress                                         │
│ [x] Story flags                                            │
│                                                            │
│ HERO PERSISTENCE                                           │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ Hero            Persist Items    Level Cap             │ │
│ │ Paladin         [x]              [10]                  │ │
│ │ Archmage        [x]              [10]                  │ │
│ │ Ranger          [x]              [10]                  │ │
│ └────────────────────────────────────────────────────────┘ │
│                                                            │
│ CUSTOM VARIABLES                                           │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ Variable        Type      Initial    Persist          │ │
│ │ QuestsComplete  Integer   0          [x]              │ │
│ │ StoryChoice     String    ""         [x]              │ │
│ │ SecretFound     Boolean   false      [x]              │ │
│ └────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────┘
```

### Cinematic Editor

```
CINEMATIC
┌────────────────────────────────────────────────────────────┐
│ Name: [Intro Cinematic____________]                        │
├────────────────────────────────────────────────────────────┤
│ TIMELINE                                                   │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ 0s      5s      10s     15s     20s     25s     30s   │ │
│ │ ├───────┼───────┼───────┼───────┼───────┼───────┤     │ │
│ │ [FADE IN    ][         TEXT          ][FADE OUT]      │ │
│ │         [Camera Pan to Castle]                        │ │
│ │                 [     MUSIC      ]                    │ │
│ │              [DIALOGUE: "Long ago..."]               │ │
│ └────────────────────────────────────────────────────────┘ │
│                                                            │
│ ELEMENTS                                                   │
│ ├─ 🎬 Fade In (0s - 2s)                                  │
│ ├─ 📷 Camera: Pan to Castle (2s - 10s)                   │
│ ├─ 📝 Text: "Chapter 1" (3s - 8s)                        │
│ ├─ 💬 Dialogue: "Long ago..." (5s - 12s)                 │
│ ├─ 🎵 Music: Epic Theme (0s - 30s)                       │
│ └─ 🎬 Fade Out (28s - 30s)                               │
│                                                            │
│ [+ Add Element] [Preview] [Export Video]                  │
└────────────────────────────────────────────────────────────┘
```

### Story/Briefing Editor

```
MISSION BRIEFING
┌────────────────────────────────────────────────────────────┐
│ Chapter: [2 - The Dark Forest ▼]                          │
├────────────────────────────────────────────────────────────┤
│ OBJECTIVES                                                 │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ Type       Description                      Required  │ │
│ │ Primary    Defeat the Orc Warlord           [x]       │ │
│ │ Primary    Rescue the villagers (0/5)       [x]       │ │
│ │ Secondary  Find the hidden treasure         [ ]       │ │
│ │ Secret     Discover the ancient shrine      [ ]       │ │
│ └────────────────────────────────────────────────────────┘ │
│                                                            │
│ BRIEFING TEXT                                              │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ The Dark Forest lies ahead. Intelligence reports      │ │
│ │ indicate an Orc encampment with prisoners. Your       │ │
│ │ mission is to eliminate the threat and rescue any     │ │
│ │ survivors.                                             │ │
│ │                                                        │ │
│ │ Be warned: the forest is treacherous...               │ │
│ └────────────────────────────────────────────────────────┘ │
│                                                            │
│ HINTS                                                      │
│ ├─ Hint 1: "Use the fog to your advantage" (after 2min) │
│ └─ Hint 2: "The shrine is north of the river" (optional)│
└────────────────────────────────────────────────────────────┘
```

### API Design

```lua
local campaign = require("editor.campaign")

-- Create campaign
local c = campaign.create({
    name = "The Rise of Heroes",
    description = "An epic journey...",
})

-- Add chapter
local chapter = campaign.add_chapter(c, {
    name = "The Dark Forest",
    map = "dark_forest.w3x",
    prerequisites = {"chapter_1_complete"},
})

-- Set progression
campaign.set_progression(c, {
    heroes = true,
    hero_items = true,
    gold = {enabled = true, cap = 5000},
    custom_vars = {
        "QuestsComplete",
        "StoryChoice",
    },
})

-- Add cinematic
local cinematic = campaign.add_cinematic(c, {
    name = "Intro",
    duration = 30,
})

campaign.add_cinematic_element(cinematic, {
    type = "fade_in",
    start = 0,
    duration = 2,
})

campaign.add_cinematic_element(cinematic, {
    type = "camera_pan",
    start = 2,
    duration = 8,
    from = camera1,
    to = camera2,
})

-- Mission briefing
campaign.set_briefing(chapter, {
    text = "The Dark Forest lies ahead...",
    objectives = {
        {type = "primary", text = "Defeat the Orc Warlord"},
        {type = "secondary", text = "Find the treasure"},
    },
})

-- Export campaign
campaign.export(c, "my_campaign.w3n")

-- Test campaign from chapter
campaign.test(c, chapter)
```

## Suggested Implementation Steps

1. Create `src/editor/campaign/` module structure
2. Implement campaign data model
3. Implement chapter/map list management
4. Implement progression settings
5. Implement cinematic timeline editor
6. Implement cinematic elements (fade, camera, text, dialogue)
7. Implement mission briefing editor
8. Implement objectives system
9. Implement unlock conditions
10. Implement campaign export (unified format)
11. Implement campaign testing
12. Integrate with undo/redo
13. Create tests

## Acceptance Criteria

- [ ] Campaigns creatable with multiple chapters
- [ ] Maps assignable to chapters
- [ ] Chapter prerequisites configurable
- [ ] Hero persistence works across maps
- [ ] Custom variables persist across maps
- [ ] Cinematics editable with timeline
- [ ] Mission briefings editable
- [ ] Objectives system works
- [ ] Campaign exportable
- [ ] Campaign testable from any chapter
- [ ] All operations support undo/redo

## Related Documents

- Issue 911 - Map format (campaign format)
- Issue 905 - Trigger editor (campaign triggers)
- Issue 904 - Camera editor (cinematic cameras)

## Notes

- Campaign files (.w3n) are archives containing multiple maps
- Consider "campaign hub" map (central location between missions)
- Cinematics could support actual video files in addition to in-engine
- May want "story branch" for non-linear campaigns
- Achievement system could track campaign-wide progress
- Speedrun mode could track completion times
