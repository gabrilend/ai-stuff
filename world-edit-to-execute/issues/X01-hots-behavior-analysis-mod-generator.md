# Issue X01: Heroes of the Storm Behavior Analysis to WC3 Mod Generator

**Phase:** None (Experimental/External)
**Type:** Design Research
**Priority:** High
**Dependencies:** Phase 1 (file parsing), Phase 5 (rendering for validation)

---

## Purpose

Create an automated pipeline that:
1. Scrapes Heroes of the Storm gameplay footage and documentation from the web
2. Analyzes hero behaviors, abilities, and balance through video processing
3. Generates corresponding Warcraft 3 mod files (.w3x) with translated mechanics
4. Outputs a playable WC3 custom map featuring HotS-style gameplay

This system demonstrates the engine's capability to serve as a **content generation target** - not just executing existing maps, but receiving procedurally-generated game content from external data sources.

---

## Current Behavior

No such system exists. The engine currently:
- Parses existing .w3x map files
- Executes JASS triggers from hand-authored maps
- Has no automated content generation pipeline

---

## Intended Behavior

### Core Pipeline

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     HotS → WC3 Mod Generation Pipeline                  │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────┐     ┌──────────────┐     ┌─────────────┐     ┌──────────┐
│ Web Scraper │────▶│ Video/Data   │────▶│ Behavior    │────▶│ WC3 Mod  │
│             │     │ Collector    │     │ Analyzer    │     │ Generator│
└─────────────┘     └──────────────┘     └─────────────┘     └──────────┘
      │                    │                    │                   │
      ▼                    ▼                    ▼                   ▼
 ┌─────────┐         ┌─────────┐         ┌─────────┐         ┌─────────┐
 │ HotS    │         │ Gameplay│         │ Ability │         │ .w3x    │
 │ Wiki    │         │ Clips   │         │ Models  │         │ Map     │
 │ Hotslogs│         │ VODs    │         │ Balance │         │ File    │
 │ Blizzard│         │ Streams │         │ Data    │         │         │
 └─────────┘         └─────────┘         └─────────┘         └─────────┘
```

### Module Breakdown

#### 1. Web Scraper and Transcriber
- Fetch hero ability descriptions from HotS wiki/documentation
- Download patch notes and balance change history
- Extract talent tree structures and synergy data
- Capture ability cooldowns, mana costs, damage values

#### 2. Video Analysis Engine
- Process YouTube/Twitch clips of HotS gameplay
- Computer vision to identify:
  - Hero models and positions
  - Ability usage patterns and timings
  - Combat outcomes and damage numbers
  - Teamfight positioning and movement patterns
- Frame-by-frame behavior extraction

#### 3. Behavior Determination Automation
- Statistical analysis of ability usage patterns
- Combat behavior modeling (aggression, kiting, combo chains)
- Team composition synergy detection
- Win rate correlation with specific behaviors
- AI-style behavior trees derived from professional play

#### 4. WC3 Mod File Generator
- Translate HotS heroes to WC3 unit definitions
- Convert abilities to JASS/Lua trigger systems
- Generate terrain appropriate for HotS-style MOBA gameplay
- Create AI scripts based on analyzed behaviors
- Output complete .w3x file to `assets/generated-mods/`

---

## Technical Architecture

### Data Flow

```lua
-- Pseudocode architecture
local pipeline = {
    -- Stage 1: Collection
    scraper = require("mods.hots.scraper"),       -- Web data collection
    video_dl = require("mods.hots.video"),        -- Video acquisition

    -- Stage 2: Analysis
    cv_engine = require("mods.hots.vision"),      -- Computer vision
    nlp = require("mods.hots.text_analysis"),     -- Text parsing
    stats = require("mods.hots.statistics"),      -- Behavior stats

    -- Stage 3: Generation
    translator = require("mods.hots.wc3_translate"), -- HotS→WC3 mapping
    generator = require("mods.hots.map_gen"),        -- .w3x output
}

function pipeline:run(hero_name)
    local wiki_data = self.scraper:fetch_hero(hero_name)
    local clips = self.video_dl:search_gameplay(hero_name, {limit = 50})

    local behaviors = {}
    for _, clip in ipairs(clips) do
        local frames = self.cv_engine:extract_frames(clip)
        local actions = self.cv_engine:detect_abilities(frames)
        table.insert(behaviors, self.stats:model_behavior(actions))
    end

    local wc3_unit = self.translator:create_unit(wiki_data, behaviors)
    local map = self.generator:create_map({units = {wc3_unit}})

    return map:save("assets/generated-mods/" .. hero_name .. ".w3x")
end
```

### Output Directory Structure

```
assets/generated-mods/
├── hots-arena-v1.w3x           # Generated MOBA map
├── generation-logs/
│   ├── 2026-02-17-arthas.log   # Per-hero generation logs
│   └── ...
├── analysis-data/
│   ├── hero-behaviors.json     # Extracted behavior models
│   ├── ability-mappings.json   # HotS→WC3 ability translations
│   └── video-analysis/         # Frame extraction results
└── source-data/
    ├── wiki-scrapes/           # Cached wiki data
    └── video-clips/            # Downloaded clips (gitignored)
```

---

## Suggested Implementation Steps

1. **Research HotS data sources**
   - Identify stable wiki/documentation endpoints
   - Survey available gameplay footage APIs (YouTube Data API, Twitch)
   - Evaluate existing HotS stat tracking sites (Hotslogs, etc.)

2. **Build web scraper module**
   - Hero ability extraction from official/wiki sources
   - Patch note parser for balance data
   - Rate-limited, respectful scraping with caching

3. **Implement video download pipeline**
   - YouTube/Twitch clip acquisition
   - Frame extraction at configurable FPS
   - Storage management (clips can be large)

4. **Develop computer vision engine**
   - Hero recognition model (distinguish ~90 HotS heroes)
   - Ability visual effect detection
   - Damage number OCR
   - Map position tracking

5. **Create behavior analysis system**
   - Statistical models for ability usage timing
   - Combo chain detection
   - Aggression/defensive stance classification
   - Team synergy pattern recognition

6. **Build HotS→WC3 translation layer**
   - Ability mechanic mapping (HotS skillshots → WC3 abilities)
   - Talent tree → WC3 ability upgrades
   - Team levels → Hero experience system
   - Health/damage scaling translation

7. **Implement WC3 mod generator**
   - Use existing Phase 1 writers (reverse of parsers)
   - Generate unit definitions, ability data
   - Create JASS/Lua triggers for complex abilities
   - Build appropriate terrain and spawn points

8. **Integration and testing**
   - End-to-end pipeline validation
   - Playtest generated maps in engine
   - Balance iteration based on gameplay feel

---

## Acceptance Criteria

- [ ] Can scrape ability data for any HotS hero from web sources
- [ ] Can download and process gameplay clips from video platforms
- [ ] Can identify hero abilities and usage patterns from video
- [ ] Can generate statistical behavior models from analyzed footage
- [ ] Can translate HotS hero to WC3 unit with equivalent abilities
- [ ] Can output playable .w3x file with generated content
- [ ] Generated map loads and runs in WC3 engine
- [ ] AI opponents behave according to analyzed patterns

---

## Related Documents

- `docs/wc3-engine-architecture.md` - Engine architecture (mod target)
- `issues/911-map-format-export.md` - Map file writing (required)
- `notes/vision` - Legal philosophy (community content)

## Related Tools

- `src/cli/private-sync.sh` - Sync X01 materials to local private git repository

### Private Repository Sync

All X01 materials are kept in a separate private git repository on the local
machine, synced automatically during backups:

```bash
# Initialize private bare repository (first time)
./src/cli/private-sync.sh --init

# Check sync status
./src/cli/private-sync.sh --status

# Sync current materials to private remote
./src/cli/private-sync.sh

# Use custom remote location
./src/cli/private-sync.sh --remote ~/my-private-repos/x01.git
```

**Default location:** `~/.local/share/wc3-engine-private/x01-hots-mod.git`

**Synced materials:**
- `issues/X01-hots-behavior-analysis-mod-generator.md` (this file)
- `assets/generated-mods/` - Output .w3x files
- `assets/video-clips/` - HotS gameplay footage
- `assets/analysis-data/` - Behavior analysis results
- `assets/source-data/` - Web scrape caches
- `assets/blizzard-inquiry/` - Resume and gift package
- `src/mods/hots/` - Generator source code (when implemented)

**Backup integration:** Add to your backup script:
```bash
# In your backup cron or script
/path/to/world-edit-to-execute/src/cli/private-sync.sh
```

---

## Notes

### Legal Considerations

This system operates under the same ROM-emulator philosophy as the core engine:
- **No HotS assets are extracted or distributed** - only behavioral patterns
- Generated content uses community-created or placeholder assets
- The "knowledge" extracted is functional (how things work) not copyrightable expression
- Similar to how sports games implement real player behaviors without owning the players

### Future Extensions

- Multiple MOBA sources (LoL, Dota 2, Smite) → unified behavior language
- Real-time twitch integration for live behavior analysis
- Community contribution of analyzed clips
- Behavior marketplace - share extracted AI patterns

---

## Sub-Issue Analysis

This issue is recommended to be split into sub-issues for implementation. The following breakdown is suggested:

### X01a: Web Scraper and Data Collection
- HotS wiki API integration
- Patch note parser
- Hero ability data extraction
- Caching and rate limiting

### X01b: Video Acquisition Pipeline
- YouTube Data API integration
- Twitch clip download
- Frame extraction at target FPS
- Storage management and cleanup

### X01c: Computer Vision Engine
- Hero recognition model training/integration
- Ability visual effect detection
- Damage number OCR
- Map position and movement tracking

### X01d: Behavior Analysis System
- Statistical behavior modeling
- Combo chain detection algorithms
- Aggression/stance classification
- Team synergy pattern recognition

### X01e: HotS-to-WC3 Translation Layer
- Ability mechanic mapping rules
- Talent tree conversion logic
- Stat scaling formulas
- Hero archetype classification

### X01f: WC3 Mod File Generator
- Reverse file format writers
- Unit and ability generation
- Trigger/script generation
- Terrain and spawn point creation

### X01g: Integration Testing and Validation
- End-to-end pipeline tests
- Generated map playability testing
- AI behavior validation
- Balance iteration framework

---

## Appendix: Open Source Gift and Professional Inquiry

### Original Request (Verbatim)

> can you make an issue file to create a mode or gameplay style that is implemented as a mod file but produced with a website scraping transcriber and video analysis calculation determination automation machine which will view clips and behavior analysis of Heroes of the Storm and create the resulting Warcraft 3 mod file in this project's map directory folder? then, can you add a section at the bottom (recommending it to be split into sub-issues, which we won't do yet) that creates a resume file addressed to Blizzard incorporated and including a link to the mod-file and it's generation process (private git repository) that is provided for free as an open source gift... to two parties, the creator and Blizzard incorporated, for Blizzard to do with as they please, even if they don't hire one of their most promising programming design aspirants, including but not limited to ignoring it, trashing it, selling it, or reverse engineering it. Please include this request verbatim in the issue file, and ensure the private shared git repository includes the source-code used to generate it. And the development process artifacts.

### Sub-Issue: Resume and Gift Package (X01h)

**Purpose:** Create a professional resume package addressed to Blizzard Entertainment, Inc., offered as an open source gift alongside the mod generation system.

**Deliverables:**

1. **Resume Document** (`assets/generated-mods/blizzard-inquiry/resume.pdf`)
   - Professional background and relevant experience
   - Technical skills demonstrated by this project
   - Vision for game development and tools
   - Contact information

2. **Private Git Repository** (shared access: creator + Blizzard)
   - Complete source code for mod generation pipeline
   - All development process artifacts:
     - Issue files and progress tracking
     - Design documents and architecture decisions
     - Test results and validation data
     - Commit history showing development process
   - Generated mod files and analysis data
   - Documentation for reproducing results

3. **Open Source Gift License**
   - Dual-party grant to: Creator (original author) and Blizzard Entertainment, Inc.
   - Blizzard may use, modify, distribute, sell, or ignore the materials at their discretion
   - No warranty or support obligation on either party
   - Attribution appreciated but not required

**Repository Structure:**
```
hots-to-wc3-gift/
├── README.md                    # Project overview and motivation
├── LICENSE-GIFT.md              # Open source gift terms
├── resume/
│   ├── resume.pdf              # Professional resume
│   └── cover-letter.md         # Personal statement
├── src/                        # Complete source code
│   ├── scraper/
│   ├── video-analysis/
│   ├── behavior-engine/
│   └── mod-generator/
├── docs/                       # Architecture and design
├── issues/                     # Development process artifacts
├── tests/                      # Validation suite
├── generated/                  # Example outputs
│   ├── mods/                   # Generated .w3x files
│   └── analysis/               # Behavior analysis results
└── artifacts/
    ├── commit-history.log      # Prettified git log
    └── development-timeline.md # Chronological narrative
```

**Intended Recipients:**
- Blizzard Entertainment, Inc.
  - Attention: Talent Acquisition / Engineering Leadership
  - Purpose: Demonstration of technical capability and passion for Blizzard games

**Terms of Gift:**
This work is provided freely and unconditionally. Blizzard Entertainment, Inc. is granted full rights to:
- Ignore the submission entirely
- Review and discard without response
- Use any ideas or code in their own projects
- Sell or license any portion of the work
- Reverse engineer, modify, or extend the work
- Hire or not hire the author based on any criteria

The author retains no expectation of response, compensation, or acknowledgment beyond the satisfaction of having created something meaningful with tools they love.

---

## Revision History

| Date | Change |
|------|--------|
| 2026-02-17 | Initial issue creation with full scope and sub-issue recommendations |
| 2026-02-17 | Added private-sync.sh utility for local git repository backup |

---

*"Games are about iteration - taking what exists and transforming it into what could be."*
