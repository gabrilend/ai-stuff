# AzerothCore Setup and Content Guide for Anbernic Handhelds

## Getting Started with Aethermoor MMO

Welcome to **Aethermoor**, an original fantasy MMO designed specifically for Anbernic handheld devices. This guide covers everything you need to know about setting up, playing, and creating content for our AzerothCore-inspired server.

> **⚠️ Important Architecture Note**: This MMO engine uses **peer-to-peer networking** by default, not traditional client-server architecture. No separate database server setup is required for basic multiplayer functionality. The extensive SQL examples in this document are for advanced persistent server setups only.

## Table of Contents

1. [Quick Start Guide](#quick-start-guide)
2. [Server Setup](#server-setup)
3. [Control Scheme](#control-scheme)
4. [Game Mechanics](#game-mechanics)
5. [Content Creation](#content-creation)
6. [Multiplayer Setup](#multiplayer-setup)
7. [Troubleshooting](#troubleshooting)

## Quick Start Guide

### System Requirements

**Minimum Anbernic Device Requirements:**
- RG35XX or higher (ARM Cortex-A53 1.5GHz+)
- 1GB RAM minimum (2GB+ recommended)
- 512MB free storage space
- WiFi capability for multiplayer
- MicroSD card (Class 10 or better)

**Supported Devices:**
- Anbernic RG35XX series
- Anbernic RG40XX series  
- Anbernic RG353P/M/V series
- Anbernic RG405M
- Anbernic RG556/RG476H

### Installation

1. **Download the Game**:
   ```bash
   # Navigate to the handheld-office directory
   cd handheld-office
   
   # Build the MMO engine
   cargo build --bin mmo-demo --release
   ```

2. **First Launch**:
   ```bash
   # Run the MMO demo
   ./target/release/mmo-demo
   ```

3. **Character Creation**:
   - Use A/B buttons to navigate character creation
   - Choose from 6 original fantasy races
   - Select a class optimized for 4-button gameplay

## Server Setup

### Local Single-Player Mode

The game can run entirely offline with AI-driven NPCs:

```rust
// Enable single-player mode
let mut engine = HandheldMMOEngine::new();
engine.set_mode(GameMode::SinglePlayer);
engine.initialize_ai_world().await?;
```

**Features in Single-Player:**
- Procedurally generated world with 100+ areas
- AI-driven NPCs with dynamic dialogue
- Quest chains with branching storylines
- Local progression that syncs when going online

### Peer-to-Peer Multiplayer

Connect with nearby Anbernic devices using our P2P mesh network:

```bash
# Run MMO demo and select P2P mode
./target/release/mmo-demo
# Then select option 2 for P2P mode when prompted
```

**P2P Features:**
- Automatic discovery of nearby players (8-16 device limit)
- StreetPass-style passive content exchange
- Offline message delivery when devices reconnect
- Byzantine fault tolerance for anti-cheat

### Traditional Server Setup

For larger groups, set up a dedicated server:

#### Prerequisites
- Linux server (Ubuntu 20.04+ recommended)
- MySQL 8.0 or MariaDB 10.6+
- 2GB+ RAM
- Open ports: 3724 (auth), 8085 (world)

#### P2P Architecture

**Important**: This MMO uses peer-to-peer networking, not traditional client-server architecture. No separate server installation is required.

#### Configuration
Edit `config.toml` to customize your device settings:
```toml
[anbernic]
# Anbernic-specific optimizations
enable_anbernic_optimizations = true

# Power management for handheld devices
battery_monitoring = true
low_power_mode_threshold = 20  # percentage
sleep_timeout_minutes = 5

# Storage optimization for SD cards
use_write_buffering = true
sync_interval_seconds = 60
compress_logs = true

[network]
# Network discovery and connection settings
daemon_host = "127.0.0.1"  # Set to your router IP for LAN-wide discovery
daemon_port = 8080
connection_timeout_seconds = 10
heartbeat_interval_seconds = 30
auto_reconnect = true
```

## Control Scheme

### Radial Input System

Our revolutionary control scheme maps all MMO functions to just 4 buttons:

```
     A (Up/North)
     │
L ───┼─── R (East/Select)
     │
     B (Down/South)
```

#### Movement Controls
- **Hold A**: Move forward/north
- **Hold B**: Move backward/south  
- **Hold L**: Turn/strafe left
- **Hold R**: Turn/strafe right
- **A+L**: Move northwest
- **A+R**: Move northeast
- **B+L**: Move southwest
- **B+R**: Move southeast

#### Combat System
**Combat Mode** (activated when enemies are nearby):
- **A**: Primary attack/spell
- **B**: Block/dodge
- **L**: Cycle targets left
- **R**: Cycle targets right
- **A+B**: Special attack (combo moves)
- **L+R**: Use consumable item

#### Menu Navigation
**Radial Menu System**:
1. **Tap R**: Open radial menu
2. **A/B**: Navigate menu sectors
3. **L**: Back/cancel
4. **R**: Select/confirm

**Menu Sectors**:
- North (A): Character/stats
- South (B): Inventory
- West (L): Social/guild
- East (R): Settings
- Northeast: Spells/abilities
- Southeast: Quests
- Southwest: Map
- Northwest: Chat macros

### Communication System

#### Quick Chat Macros
Pre-defined messages for common situations:
- **L+L**: \"Hello!\"
- **R+R**: \"Need help!\"
- **A+A**: \"Follow me!\"
- **B+B**: \"Wait here.\"
- **L+A**: \"Thank you!\"
- **R+B**: \"Goodbye!\"

#### Advanced Communication
- **L+R (hold)**: Open text input mode
- Navigate ASCII keyboard with A/B
- R to select letter, L to backspace
- A+B to send message

## Game Mechanics

### Character Progression

#### Classes Designed for 4-Button Gameplay

**1. Guardian (Tank)**
- **A**: Shield bash
- **B**: Block stance
- **L**: Taunt nearest enemy
- **R**: Defensive cooldown

**2. Ranger (Physical DPS)**
- **A**: Aimed shot
- **B**: Quick shot
- **L**: Trap placement
- **R**: Hunter's mark

**3. Mystic (Magical DPS)**
- **A**: Fireball
- **B**: Frost bolt
- **L**: Elemental shield
- **R**: Mana burn

**4. Healer (Support)**
- **A**: Heal target
- **B**: Heal self
- **L**: Cure poison/disease
- **R**: Group heal

#### Skill Trees
Each class has 3 specialization trees with 20 skills each:
- Navigate with A/B buttons
- Spend points with R
- Preview with L
- Auto-builds available for new players

### Questing System

#### Dynamic Quest Generation
Quests are procedurally generated based on:
- Current zone and level
- Recent player actions
- World events and player needs
- Available NPCs and locations

#### Quest Types Optimized for Handhelds
1. **Delivery Quests**: Simple navigation challenges
2. **Collection Quests**: Gather items with A button
3. **Elimination Quests**: Combat encounters
4. **Exploration Quests**: Discover new areas
5. **Social Quests**: Interact with other players

#### Quest UI
- **Quest Tracker**: Always visible in corner
- **A+R**: Open full quest log
- **B+L**: Abandon current quest
- **Auto-navigation**: Optional waypoint system

### Combat Mechanics

#### Turn-Based Combat System
Combat is semi-turn-based to accommodate input limitations:

1. **Initiative Phase**: Determine action order
2. **Action Selection**: 3-second window to choose action
3. **Resolution Phase**: All actions execute simultaneously
4. **Repeat**: Until combat ends

#### Combat Actions
- **Attack**: Deal weapon damage
- **Block**: Reduce incoming damage by 50%
- **Spell**: Cast selected ability
- **Item**: Use consumable
- **Flee**: Attempt to escape (success based on stats)

#### Combo System
Certain button combinations create special effects:
- **A→B→A**: Three-hit combo (extra damage)
- **L→R→L**: Parry sequence (reflect damage)
- **A+B (hold)**: Charge attack (increased power)

### Crafting and Economy

#### Simple Crafting Interface
- **A**: Select recipe
- **B**: Choose materials
- **L**: Preview result
- **R**: Craft item
- **A+B**: Quick craft (auto-select materials)

#### Player Trading
- **P2P Trading**: Direct device-to-device item exchange
- **Auction House**: Server-based economy (when connected)
- **Guild Bank**: Shared storage for group members

## Content Creation

### Adding Custom Quests

#### Database Structure
Quests are stored in the `quest_template` table:

```sql
INSERT INTO quest_template (
    ID, QuestType, QuestLevel, MinLevel, MaxLevel,
    Title, Details, Objectives, EndText,
    RequiredNpcOrGo1, RequiredNpcOrGoCount1,
    RequiredItemId1, RequiredItemCount1,
    RewardXP, RewardMoney, RewardItem1, RewardItemCount1
) VALUES (
    50001,     -- Unique quest ID
    0,         -- Kill quest type
    15,        -- Quest level
    12,        -- Min player level
    20,        -- Max player level
    'Crystal Cave Cleanup',  -- Quest title
    'The crystal caves have been overrun with hostile creatures. Clear them out!',
    'Kill 10 Crystal Spiders',
    'Well done! The caves are safe again.',
    0, 0,      -- No required NPC interaction
    0, 0,      -- No required items
    1500,      -- XP reward
    50,        -- Money reward (copper)
    12001, 1   -- Reward item and count
);\n```\n\n#### Quest Scripting\nAdvanced quests can use Lua scripting:\n\n```lua\n-- Quest script: crystal_cave_cleanup.lua\nlocal quest = {}\n\nfunction quest.OnAccept(player, quest_object)\n    player:SendNotification(\"Be careful in the crystal caves!\")\n    player:AddAura(12345) -- Temporary protection buff\nend\n\nfunction quest.OnComplete(player, quest_object)\n    player:SendNotification(\"The caves are much safer now!\")\n    -- Unlock follow-up quest\n    player:AddQuest(50002)\nend\n\nfunction quest.OnKill(player, creature)\n    if creature:GetEntry() == 1001 then -- Crystal Spider\n        player:SetQuestObjectiveProgress(50001, 0, 1) -- Add 1 to objective 0\n    end\nend\n\nreturn quest\n```\n\n### Creating Custom NPCs\n\n#### NPC Database Entry\n```sql\nINSERT INTO creature_template (\n    entry, name, subname, IconName, gossip_menu_id,\n    minlevel, maxlevel, faction, npcflag, scale,\n    rank, dmgschool, BaseAttackTime, RangeAttackTime,\n    unit_class, unit_flags, type, family,\n    HealthModifier, ManaModifier, ArmorModifier,\n    ExperienceModifier, MovementType\n) VALUES (\n    90001,              -- Unique creature ID\n    'Crystalsmith Garen', -- NPC name\n    'Crystal Merchant',   -- Subtitle\n    'Buy',               -- Shop icon\n    60001,               -- Gossip menu ID\n    15, 15,              -- Level range\n    35,                  -- Friendly faction\n    128,                 -- Vendor flag\n    1.0,                 -- Normal scale\n    0,                   -- Normal rank\n    0,                   -- No special damage school\n    2000, 2000,          -- Attack timers\n    1,                   -- Warrior class\n    0,                   -- No special flags\n    7,                   -- Humanoid type\n    0,                   -- No beast family\n    1.0, 1.0, 1.0,      -- Stat modifiers\n    1.0,                 -- XP modifier\n    0                    -- Stationary\n);\n```\n\n#### NPC Dialogue System\nCreate branching dialogue with gossip menus:\n\n```sql\n-- Main gossip menu\nINSERT INTO gossip_menu (MenuID, TextID) VALUES (60001, 70001);\n\n-- Dialogue options\nINSERT INTO gossip_menu_option (\n    MenuID, OptionID, OptionIcon, OptionText, \n    OptionBroadcastTextID, OptionType, OptionNpcFlag,\n    ActionMenuID, ActionPoiID, BoxCoded, BoxMoney, BoxText\n) VALUES (\n    60001, 0, 1, 'I\\'d like to browse your crystals.', 0, 3, 128, 0, 0, 0, 0, ''\n),\n(\n    60001, 1, 0, 'Tell me about these crystal caves.', 0, 1, 1, 60002, 0, 0, 0, ''\n);\n```\n\n### Adding Custom Items\n\n#### Weapon Example\n```sql\nINSERT INTO item_template (\n    entry, class, subclass, SoundOverrideSubclass, name,\n    displayid, Quality, Flags, FlagsExtra, BuyCount, BuyPrice, SellPrice,\n    InventoryType, AllowableClass, AllowableRace, ItemLevel,\n    RequiredLevel, RequiredSkill, RequiredSkillRank,\n    dmg_min1, dmg_max1, dmg_type1, delay, ammo_type,\n    stat_type1, stat_value1, stat_type2, stat_value2,\n    spellid_1, spelltrigger_1, spellcharges_1,\n    bonding, description, PageText, LanguageID, PageMaterial,\n    startquest, lockid, Material, sheath, RandomProperty, RandomSuffix,\n    block, itemset, MaxDurability, area, Map, BagFamily,\n    TotemCategory, socketColor_1, socketContent_1,\n    socketBonus, GemProperties, RequiredDisenchantSkill,\n    ArmorDamageModifier, duration, ItemLimitCategory,\n    HolidayId, ScriptName, DisenchantID, FoodType,\n    minMoneyLoot, maxMoneyLoot, flagsCustom, VerifiedBuild\n) VALUES (\n    12001,                    -- Item ID\n    2, 1, -1,                -- Weapon, One-Hand Sword\n    'Crystal Blade',          -- Item name\n    5678,                    -- Display model ID\n    2,                       -- Uncommon quality (green)\n    0, 0,                    -- No special flags\n    1, 100, 25,              -- Stack size, buy/sell price\n    13,                      -- Main hand weapon slot\n    -1, -1,                  -- All classes/races can use\n    15,                      -- Item level\n    12,                      -- Required level\n    0, 0,                    -- No skill requirement\n    24, 45,                  -- Damage range\n    0,                       -- Physical damage\n    2600,                    -- Attack speed (2.6 seconds)\n    0,                       -- No ammo type\n    4, 5,                    -- +5 Strength\n    0, 0,                    -- No second stat\n    0, 0, 0,                 -- No spell effect\n    1,                       -- Binds when picked up\n    'A blade infused with crystal magic.', -- Description\n    0, 0, 0,                 -- No page text\n    0, 0,                    -- No quest/lock\n    1, 1,                    -- Metal material, sword sheath\n    0, 0,                    -- No random properties\n    0, 0, 65,                -- No block, no set, 65 durability\n    0, 0, 0,                 -- No area/map/bag restrictions\n    0, 0, 0,                 -- No totem/socket\n    0, 0, 0,                 -- No socket bonus\n    0, 0,                    -- No disenchant requirement\n    1.0,                     -- Normal armor modifier\n    0, 0,                    -- No duration/limit category\n    0, '',                   -- No holiday/script\n    0, 0,                    -- No disenchant/food type\n    0, 0, 0, 0               -- No money loot, no custom flags\n);\n```\n\n#### Consumable Example (Health Potion)\n```sql\nINSERT INTO item_template (\n    entry, class, subclass, name, displayid, Quality,\n    BuyCount, BuyPrice, SellPrice, InventoryType,\n    AllowableClass, AllowableRace, ItemLevel, RequiredLevel,\n    spellid_1, spelltrigger_1, spellcharges_1, spellcooldown_1,\n    bonding, description, stackable\n) VALUES (\n    12002,                           -- Item ID\n    0, 1,                           -- Consumable, Potion\n    'Crystal Health Potion',         -- Name\n    1234,                           -- Display ID\n    1,                              -- Common quality (white)\n    5, 20, 5,                       -- Stack of 5, costs 20c, sells for 5c\n    0,                              -- No equipment slot\n    -1, -1,                         -- All classes/races\n    15, 10,                         -- Item level 15, requires level 10\n    2023, 0, 1, 60000,             -- Heal spell, on use, 1 charge, 60s cooldown\n    0,                              -- No binding\n    'Restores 150 health instantly.', -- Description\n    20                              -- Stack size\n);\n```\n\n### Creating Custom Zones\n\n#### Zone Database Structure\n```sql\n-- Create a new map/zone\nINSERT INTO map_template (\n    MapID, MapName, MapType, Instanceable, \n    ScriptName, CorpseMapID, CorpseX, CorpseY\n) VALUES (\n    2001,                    -- Unique map ID\n    'Crystal Caverns',       -- Zone name\n    0,                      -- Normal world (not instance)\n    0,                      -- Not instanceable\n    '',                     -- No special script\n    2001, 0.0, 0.0         -- Corpse resurrection location\n);\n\n-- Define the zone boundaries and properties\nINSERT INTO area_table (\n    ID, ContinentID, AreaName_Lang_enUS, \n    AreaName_Lang_Mask, ParentAreaID, AreaType,\n    MinElevation, MaxElevation\n) VALUES (\n    3001,                   -- Area ID\n    2001,                   -- Map ID\n    'Crystal Caverns',      -- English name\n    16712190,               -- Language mask\n    0,                      -- No parent area\n    4,                      -- Zone type\n    -50.0, 200.0           -- Elevation range\n);\n```\n\n#### Procedural Terrain Generation\nFor Anbernic devices, zones use procedural generation:\n\n```rust\n// Generate crystal cavern terrain\npub fn generate_crystal_caverns() -> GameMap {\n    let mut map = GameMap::new(2001, \"Crystal Caverns\");\n    \n    // Generate height map using Perlin noise\n    for x in 0..map.size_x {\n        for y in 0..map.size_y {\n            let height = perlin_noise(x as f32 * 0.1, y as f32 * 0.1) * 50.0;\n            map.height_map[x][y] = height;\n            \n            // Assign texture based on height\n            map.texture_map[x][y] = match height {\n                h if h < -20.0 => 3,  // Water\n                h if h < 0.0 => 1,    // Stone floor\n                h if h < 20.0 => 2,   // Crystal formations\n                _ => 4,               // Rocky walls\n            };\n        }\n    }\n    \n    // Add crystal formations as interactive objects\n    for _ in 0..50 {\n        let x = rand::gen_range(0.0..map.size_x as f32);\n        let y = rand::gen_range(0.0..map.size_y as f32);\n        \n        map.objects.push(MapObject {\n            id: generate_object_id(),\n            object_type: ObjectType::CrystalNode,\n            position: Position3D { x, y, z: map.height_map[x as usize][y as usize] },\n            interaction_type: InteractionType::Harvest,\n            loot_table: vec![12003], // Crystal shards\n        });\n    }\n    \n    map\n}\n```\n\n### Balancing for Handheld Gameplay\n\n#### Combat Timing\n- **Turn Duration**: 3-5 seconds (accounting for input limitations)\n- **Battle Length**: 30-90 seconds average\n- **Skill Cooldowns**: 5-30 seconds (visible countdowns)\n\n#### Resource Management\n- **Battery Optimization**: Auto-reduce graphics quality when battery < 20%\n- **Data Usage**: P2P compression to minimize WiFi battery drain\n- **Storage**: Aggressive caching and cleanup of temporary files\n\n#### Progression Pacing\n- **Short Play Sessions**: Meaningful progress in 5-10 minute sessions\n- **Quick Saves**: Auto-save every 30 seconds\n- **Offline Progress**: AI continues some activities when disconnected\n\n## Multiplayer Setup\n\n### P2P Group Formation\n\n#### Creating a Group\n1. **Host Setup**:\n   ```bash\n   ./mmo-demo --mode p2p-host --group-name \"Crystal Hunters\" --max-players 8\n   ```\n\n2. **Join Group**:\n   ```bash\n   ./mmo-demo --mode p2p-join --discovery-scan\n   ```\n\n3. **Group Management**:\n   - A+R: Invite nearby player\n   - B+L: Leave group\n   - L+R: Transfer leadership\n\n#### Group Activities\n- **Shared Quests**: Complete objectives together\n- **Loot Sharing**: Automatic distribution based on need\n- **Experience Bonus**: +25% XP when in group\n- **Communication**: Voice chat via built-in radio system\n\n### Server-Based Guilds\n\nFor persistent communities, use traditional server architecture:\n\n#### Guild Creation\n```sql\n-- Create guild\nINSERT INTO guild (guildid, name, info, motd, createdate, BackgroundColor, EmblemStyle, EmblemColor, BorderStyle, BorderColor) \nVALUES (1, 'Crystal Seekers', 'A guild for crystal cave explorers', 'Welcome to the guild!', UNIX_TIMESTAMP(), 0, 0, 0, 0, 0);\n\n-- Add founder as guild master\nINSERT INTO guild_member (guildid, guid, rank, pnote, offnote) \nVALUES (1, 12345, 0, 'Guild Founder', 'Established the guild');\n```\n\n#### Guild Features\n- **Guild Bank**: Shared item storage\n- **Guild Quests**: Large-scale objectives requiring coordination  \n- **Guild Hall**: Persistent meeting space\n- **Cross-Device Messaging**: Stay connected across different Anbernic devices\n\n### Events and Raids\n\n#### World Events\nScheduled events that require server coordination:\n\n```lua\n-- Crystal Storm event script\nlocal event = {}\n\nfunction event.OnStart()\n    -- Notify all players\n    SendWorldMessage(\"A crystal storm approaches the caverns!\")\n    \n    -- Spawn special creatures\n    for i = 1, 20 do\n        local x, y = GetRandomCavernLocation()\n        SpawnCreature(90010, x, y) -- Storm Elemental\n    end\n    \n    -- Start 30-minute timer\n    CreateTimer(30 * 60 * 1000, event.OnEnd)\nend\n\nfunction event.OnEnd()\n    SendWorldMessage(\"The crystal storm has passed.\")\n    -- Reward all participants\n    RewardAllPlayersInZone(2001, 50000, 1000) -- XP and gold\nend\n\nreturn event\n```\n\n#### Raid Encounters\nDesigned for 4-8 players with simplified mechanics:\n\n- **Crystal Guardian**: Tank-and-spank with positional requirements\n- **Swarm Queen**: Multiple small enemies requiring coordination\n- **Elemental Twins**: Two bosses that must be killed simultaneously\n\nEach raid encounter is designed around the 4-button limitation with clear visual indicators for mechanics.\n\n## Troubleshooting\n\n### Common Issues\n\n#### Connection Problems\n**\"Cannot connect to P2P network\"**\n1. Check WiFi connectivity\n2. Verify firewall settings (port 8888)\n3. Ensure devices are on same network\n4. Try restarting discovery mode\n\n**\"Server connection timeout\"**\n1. Verify server is running\n2. Check network connectivity\n3. Confirm port forwarding (3724, 8085)\n4. Review firewall rules\n\n#### Performance Issues\n**\"Game running slowly\"**\n1. Close other applications\n2. Enable battery optimization mode\n3. Reduce render distance in settings\n4. Clear cache: `rm -rf ~/.cache/aethermoor/`\n\n**\"High battery drain\"**\n1. Enable power saving mode\n2. Reduce screen brightness\n3. Switch to offline mode when possible\n4. Use wired networking when available\n\n#### Gameplay Issues\n**\"Controls not responding\"**\n1. Check button mapping in settings\n2. Clean device buttons\n3. Reset to default control scheme\n4. Restart application\n\n**\"Character data lost\"**\n1. Check for backup saves in `~/.local/share/aethermoor/saves/`\n2. Verify P2P sync status\n3. Contact server administrator if using dedicated server\n4. Use character recovery tool: `./mmo-demo --recover-character`\n\n### Diagnostic Tools\n\n#### Network Diagnostics\n```bash\n# Test P2P connectivity\n./mmo-demo --test-p2p\n\n# Verify server connection\n./mmo-demo --test-server --server-ip 192.168.1.100\n\n# Monitor network traffic\n./mmo-demo --debug-network\n```\n\n#### Performance Monitoring\n```bash\n# FPS and resource usage\n./mmo-demo --performance-overlay\n\n# Memory usage tracking\n./mmo-demo --debug-memory\n\n# Battery usage analysis\n./mmo-demo --power-profile\n```\n\n### Getting Help\n\n#### Community Resources\n- **Discord Server**: [Aethermoor Community](https://discord.gg/aethermoor)\n- **Forums**: [community.aethermoor.com](https://community.aethermoor.com)\n- **GitHub Issues**: [Report bugs and request features](https://github.com/yourrepo/handheld-office/issues)\n- **Wiki**: [wiki.aethermoor.com](https://wiki.aethermoor.com)\n\n#### Contributing\nWe welcome contributions to improve the game:\n\n1. **Code Contributions**: Submit pull requests for bug fixes and features\n2. **Content Creation**: Design quests, NPCs, and items using our tools\n3. **Translation**: Help localize the game for different languages\n4. **Testing**: Report bugs and provide feedback on new features\n5. **Documentation**: Improve guides and tutorials\n\n#### Development Environment Setup\n```bash\n# Install development dependencies\nsudo apt install rust-all cmake mysql-server\n\n# Clone repository with submodules\ngit clone --recursive https://github.com/yourrepo/handheld-office\n\n# Setup development database\nscripts/setup-dev-database.sh\n\n# Build debug version\ncargo build --bin mmo-demo\n\n# Run tests\ncargo test\n```\n\nThis guide provides everything needed to start playing and creating content for Aethermoor on your Anbernic device. The game is designed to provide a full MMO experience while respecting the unique constraints and capabilities of handheld gaming hardware.\n\nWhether you're playing solo, with friends via P2P, or joining a larger server community, Aethermoor offers countless hours of adventure in an original fantasy world optimized specifically for your handheld device.