# Issue 040h: Worldbuilding and Game Design Oracle

## Status
- **Parent Issue**: 040 (Dynamic CLAUDE.md Revision System)
- **Priority**: Medium
- **Type**: Implementation (Creative Extension)
- **Dependencies**: 040g (Transcript Analysis), 040d (History System)
- **Blocks**: None

## Current Behavior
Creative project questions ("how should the story flow?", "what would this character do?", "does this mechanic fit the theme?") require manually searching through scattered design documents, lore files, and mod data. There is no unified way to query worldbuilding decisions or understand the design philosophy behind creative choices.

## Intended Behavior
Extend the reasoning memory system to answer worldbuilding and game design questions by:

1. **Read-only access** to game-design project directories
2. **Read-only access** to mod files (Elentalus and others)
3. **Story coherence checking** - does a new idea fit the established world?
4. **Design philosophy extraction** - why was a mechanic designed this way?
5. **Cross-reference** between lore, mechanics, and implementation

## Target Data Sources

### Elentalus Mod (Dominions 6)

```lua
local ELENTALUS_SOURCES = {
    -- Active mod directory (latest version)
    mod_dir = "/home/ritz/.dominions6/mods/elentalus-0.96/",

    -- Mod definition file (units, spells, weapons, events)
    dm_file = "elentalus-0.96.dm",

    -- Lore and design documents
    lore_dir = "elentalus/lore/",

    -- Key documents:
    -- - game-design-document: mages, units, statues, altars
    -- - computer: lore about magical computers of Sulatnele
    -- - urn-combination-event-guide.png: visual mechanics reference

    -- Visual references
    sprites = {
        "elentalus/sturm-sprites/",
        "elentalus/denh-sprites/",
        "elentalus/elementals/",
        "elentalus/dragons/"
    },

    -- Changelog (version history)
    changelog = "changelog",

    -- All mod versions for historical reference
    versions = {
        "/home/ritz/.dominions6/mods/elentalus-0.95/",
        "/home/ritz/.dominions6/mods/elentalus-0.96/"
    }
}
```

### Game Design Music/Assets

```lua
local GAME_DESIGN_SOURCES = {
    -- Music composed for the game (Everrune tracks)
    music_dir = "/mnt/mtwo/music/video-game-music/dominions/6/",

    -- Historical versions
    version_dirs = {
        "/mnt/mtwo/music/video-game-music/dominions/4/",
        "/mnt/mtwo/music/video-game-music/dominions/5/",
        "/mnt/mtwo/music/video-game-music/dominions/6/"
    }
}
```

### Future: Monorepo Integration

```lua
-- Elentalus files are copied to monorepo as a project directory
-- This enables unified project management and version control
local MONOREPO_LOCATION = "{ai-stuff}/elentalus/"
```

## Elentalus Design Summary (Extracted)

### Core Concept
> "A nation of refugees, adrift in the elements."

### The Turn-1 Configuration System (User's Vision)
A nation that configures itself on the first turn:
- Spawns commanders that last one turn
- Each has special actions corresponding to "nation option" buttons
- Right-click shows description of each option
- After configuration, plays as the most flexible nation: **specialized in mystery**

### Magic System
- **6 paths**: 4 elements (fire, water, earth, air) + 2 sorceries (mind/body via astral/nature)
- Elements represent the land
- Sorceries represent mind (astral) and body (nature)

### Commander Tiers
| Tier | Armor | Leadership | Morale Bonus |
|------|-------|------------|--------------|
| T1 | Weak | High | Low |
| T2 | Medium | Medium | Medium |
| T3 | High | Low | High |

### Supermages
Autonomous battle squads with bodyguards:
- **Fire/Air**: Main battle mage, most bodyguards, best melee
- **Earth/Astral**: Technical utility, gravitic chains, javelins
- **Water/Nature**: Ice shurikens, blessings, amphibious raids

### Altars and Vertical Play
- Mages building forts create magic sites (1 gem/type)
- Three sites per fort, no duplicates
- T3 commanders can consume sites to empower themselves
- Immobile L3 mages summon different elementals
- Defeated chaos elementals yield stationary mages with gem income

### Lore Fragments
- **Sulatnele**: The nation's original name (Elentalus reversed)
- **Magical computers**: Powered by mana drawn from an extra-dimensional ocean
- **Doom Horrors**: Can see mana connections like dust seeing a splinter in glass

## Query Types

### 1. LORE - "What is the story behind X?"

```lua
-- Query the lore behind a mechanic or entity
worldbuilding.lore("urns")
-- Returns: Lore about sacred urn statues, their temple-building capability,
--          elemental summoning, and the royal elemental system

worldbuilding.lore("doom horrors")
-- Returns: Extra-dimensional creatures that observe mana connections,
--          referenced in the magical computers lore
```

### 2. DESIGN - "Why was X designed this way?"

```lua
-- Query design rationale
worldbuilding.design("why steel is rare")
-- Returns: "steel is rare, meaning the high resource units have increased
--          resource costs to simulate the lack of infrastructure present
--          in the early era. But the knowledge came with them (time travellers)
--          so while they *can* make steel and plate armor it's not always
--          a good idea."

worldbuilding.design("supermage bodyguards")
-- Returns: Design philosophy around supermages as squad units that move
--          automatically toward enemies, cannot receive orders, and lose
--          the entire squad if the supermage dies
```

### 3. COHERENCE - "Does X fit the world?"

```lua
-- Check if a new idea fits established design
worldbuilding.coherence({
    proposed = "Add a unit that teleports anywhere on the map",
    context = "elentalus"
})
-- Returns: {
--     fits = false,
--     reason = "Elentalus emphasizes terrain-bound elements. Water elementals
--              cannot leave their province, nature elementals die outside
--              their forest. Unlimited teleportation contradicts the theme
--              of being 'adrift in the elements' - refugees constrained by
--              their elemental nature.",
--     alternatives = {
--         "Limited teleport within favored terrain",
--         "Astral path teleport (mind-based, not element-based)"
--     }
-- }
```

### 4. FLOW - "How should the story/mechanic flow?"

```lua
-- Get narrative or mechanical flow suggestions
worldbuilding.flow({
    element = "elemental progression",
    question = "how do elementals grow stronger?"
})
-- Returns: {
--     current_design = "urns summon weak elementals monthly → temple causes
--                      combination → culminates in royal elemental → two
--                      royals spawn chaos elemental → defeating it yields
--                      stationary gem-income mage",
--     narrative_arc = "scarcity → accumulation → transcendence → conflict
--                     → resolution/reward",
--     suggested_extensions = {...}
-- }
```

### 5. FIXME - "What's on the todo list?"

```lua
-- Extract FIXME comments from mod file
worldbuilding.fixmes("elentalus")
-- Returns all FIXME comments from the .dm file, categorized:
-- {
--     balance = {"remove shields from heavy spears", ...},
--     features = {"adventurers random events", "mounted javelin cost", ...},
--     bugs = {"altar spawning problem", ...},
--     lore = {"heroes should be titans", ...}
-- }
```

## Mod File Parser

```lua
-- {{{ dominions_parser module
-- Parses .dm mod files for Dominions 6
-- READ-ONLY access to extract structure

local parser = {}

-- {{{ function parser.parse_dm_file
function parser.parse_dm_file(filepath)
    local content = read_file(filepath)  -- READ-ONLY

    local mod = {
        info = {},
        weapons = {},
        armor = {},
        units = {},
        spells = {},
        events = {},
        sites = {},
        fixmes = {},
        comments = {}
    }

    -- Extract mod info
    mod.info.name = content:match('#modname "([^"]+)"')
    mod.info.description = content:match('#description "([^"]+)"')
    mod.info.version = content:match('#version ([%d.]+)')

    -- Extract FIXME comments
    for fixme in content:gmatch("%-%-?%s*FIXME:?%s*([^\n]+)") do
        table.insert(mod.fixmes, fixme)
    end

    -- Extract weapons (between #newweapon and #end)
    for weapon_block in content:gmatch("#newweapon%s+(%d+).-#end") do
        local weapon = parse_weapon_block(weapon_block)
        table.insert(mod.weapons, weapon)
    end

    -- Extract units
    for unit_block in content:gmatch("#newmonster%s+(%d+).-#end") do
        local unit = parse_unit_block(unit_block)
        table.insert(mod.units, unit)
    end

    -- Extract design comments (## style)
    for comment in content:gmatch("##%s*([^\n]+)") do
        table.insert(mod.comments, comment)
    end

    return mod
end
-- }}}

-- {{{ function parser.extract_design_philosophy
function parser.extract_design_philosophy(mod)
    local philosophy = {}

    -- From mod description
    philosophy.core_theme = mod.info.description

    -- From design comments
    for _, comment in ipairs(mod.comments) do
        local category = categorize_design_comment(comment)
        philosophy[category] = philosophy[category] or {}
        table.insert(philosophy[category], comment)
    end

    return philosophy
end
-- }}}

return parser
-- }}}
```

## Integration with Reasoning Memory

The worldbuilding oracle extends 040g's capabilities:

```lua
-- {{{ Extended reasoning_memory for worldbuilding

-- Extend the "why" function to handle game design questions
function reasoning_memory.why(query)
    -- First, check if this is a worldbuilding query
    if is_worldbuilding_query(query) then
        return worldbuilding_why(query)
    end

    -- Otherwise, use standard guideline provenance
    return standard_why(query)
end

-- {{{ function worldbuilding_why
function worldbuilding_why(query)
    -- 1. Search game design documents
    local design_docs = search_design_docs(query)

    -- 2. Search mod files (.dm) for related mechanics
    local mod_refs = search_mod_files(query)

    -- 3. Search lore files
    local lore_refs = search_lore_files(query)

    -- 4. Check transcripts for design discussions
    local transcript_refs = search_transcripts_for_design(query)

    -- 5. Synthesize answer
    return {
        answer = synthesize_worldbuilding_answer(
            design_docs, mod_refs, lore_refs, transcript_refs
        ),
        sources = {
            design = design_docs,
            mechanics = mod_refs,
            lore = lore_refs,
            discussions = transcript_refs
        },
        confidence = calculate_confidence(...)
    }
end
-- }}}
-- }}}
```

## Example Queries and Answers

### "Why do water elementals suffer when leaving their province?"

```
DESIGN RATIONALE (from game-design-document):
  "water elementals cannot leave their home province without suffering damage"

THEMATIC CONNECTION:
  The nation is "adrift in the elements" - refugees constrained by their
  elemental nature. Water is bound to its source.

MECHANICAL PURPOSE:
  Creates vertical gameplay - instead of expanding horizontally, players
  invest in making provinces more powerful through the altar system.

RELATED MECHANICS:
  - Nature elementals die outside their forest
  - Defeating chaos elementals yields stationary mages (gem income)
  - "vertical playstyles instead of just horizontal"

TRANSCRIPT EVIDENCE:
  [None found - design predates transcript system]
```

### "How should the turn-1 configuration system work?"

```
USER VISION (from conversation):
  "A dominions nation that altered its behavior for the rest of the run
   by spawning with commanders that last one turn and have special actions,
   each of which corresponds to 'setting' a 'nation option' button with
   a description if they right click. After the first wave, they can play
   as the most flexible nation in the game - specialized, in mystery."

DESIGN IMPLICATIONS:
  1. Turn 1: Spawn N "configuration commanders" (1-turn lifespan)
  2. Each commander has unique special action = one nation option
  3. Right-click on commander shows option description
  4. Player chooses which options to activate
  5. Turn 2+: Nation plays with selected configuration

FITS THEME:
  ✓ Mystery specialization aligns with flexible/configurable nature
  ✓ One-turn commanders mirror transient elemental manifestations
  ✓ Player agency in configuration reflects refugees adapting to new land

IMPLEMENTATION CONSIDERATIONS:
  - Use events to detect which commanders survive turn 1
  - Commander death = option de-selected
  - Commander action = option selected
  - Permanent effects via hidden sites or nation modifiers

NOT YET IMPLEMENTED - Ready for design phase
```

## Storage Locations

```
~/.claude/
├── analysis/
│   ├── decisions/           # Guideline provenance (existing)
│   ├── reasoning_chains/    # Multi-session traces (existing)
│   ├── reconciliations/     # Signpost targets (existing)
│   └── worldbuilding/       # NEW: Creative project analysis
│       ├── elentalus/
│       │   ├── design_philosophy.md
│       │   ├── lore_index.json
│       │   ├── mechanic_rationales/
│       │   └── coherence_checks/
│       └── index.json

# Source locations (READ-ONLY)
/home/ritz/.dominions6/mods/elentalus-*/
/mnt/mtwo/music/video-game-music/dominions/
{project}/game-design/
```

## Suggested Implementation Steps

1. **Create Dominions mod parser** (`src/parsers/dominions.lua`)
   - Parse .dm file structure
   - Extract weapons, units, spells, events
   - Extract FIXME/design comments

2. **Build lore indexer** (`src/worldbuilding/lore_indexer.lua`)
   - Index lore/ directory contents
   - Create searchable lore database
   - Link lore to mechanics

3. **Implement design philosophy extractor** (`src/worldbuilding/philosophy.lua`)
   - Extract design rationales from game-design-document
   - Categorize by mechanic type
   - Link to implementation in .dm file

4. **Create coherence checker** (`src/worldbuilding/coherence.lua`)
   - Compare new ideas against established themes
   - Identify contradictions
   - Suggest alternatives that fit

5. **Build flow analyzer** (`src/worldbuilding/flow.lua`)
   - Trace progression systems
   - Identify narrative arcs in mechanics
   - Suggest extensions

6. **Integrate with reasoning memory** (update 040g)
   - Extend `why()` for worldbuilding queries
   - Add `worldbuilding.lore()`, `.design()`, `.coherence()`, `.flow()`

7. **Add to TUI** (update 040f)
   - Worldbuilding query interface
   - Project selector (Elentalus, future projects)
   - FIXME browser for mod development

## Related Documents
- [Issue 040](./040-dynamic-claudemd-revision-system.md) - Parent issue
- [Issue 040g](./040g-transcript-analysis-memory.md) - Reasoning memory this extends
- [Elentalus Game Design Document](/home/ritz/.dominions6/mods/elentalus-0.96/elentalus/lore/game-design-document)
- [Elentalus Website](https://ritz-menardi.neocities.org/dominions/elentalus/elentalus)

## Notes
- Start with Elentalus as proof-of-concept, extend to other creative projects
- Mod file parsing is domain-specific (Dominions .dm format)
- Consider image analysis for sprite references and diagrams
- The "specialized in mystery" theme suggests the configuration system should offer non-obvious, synergistic choices
- Magical computers of Sulatnele could be in-world justification for the configuration UI
