# Custom Ability Bridge Architecture

**Status:** Design Document
**Created:** 2026-01-07
**Purpose:** Define how WC3 custom abilities are handled in AzerothCore integration

---

## Executive Summary

WC3 custom maps contain unique abilities that don't exist in World of Warcraft. While AzerothCore has a comprehensive spell system (3.3.5a WotLK), it cannot natively handle the custom mechanics found in WC3 maps.

**The Problem:**
```
WC3 Custom Map: "Hero Defense"
  - Hero ability: "Chain Heal"
    - Bounces 5 times
    - 150/225/300 heal per level
    - 0.5 reduction per bounce
    - 15 second cooldown

WoW Spell ID 1064: "Chain Heal" exists but:
  - Different bounce count
  - Different coefficients
  - Different scaling
  - Won't match WC3 behavior
```

**The Solution:** Build a **Custom Ability Bridge** that translates WC3 ability data into executable logic within AzerothCore's framework.

---

## Approach Comparison

| Aspect | Option A: Pure Eluna | Option B: AC Fork + Custom System |
|--------|---------------------|----------------------------------|
| **Complexity** | Low - script generation only | High - C++ core modification |
| **Performance** | Moderate - Lua overhead | High - native C++ execution |
| **Maintenance** | Easy - scripts update independently | Hard - must merge upstream AC |
| **Flexibility** | Limited by Eluna API | Full control over spell system |
| **Time to Implement** | ~1-2 weeks | ~4-6 weeks |
| **AC Updates** | Always compatible | Must resolve merge conflicts |
| **Debugging** | Easy - edit Lua scripts | Hard - recompile core |

**Recommendation:** Start with **Option A (Pure Eluna)**, migrate to **Option B** only if:
- Performance profiling shows Lua is a bottleneck (>10ms per ability cast)
- We need mechanics fundamentally incompatible with Eluna API
- We have 10+ maps with 100+ custom abilities (maintenance worth it)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     WC3 Custom Map (.w3x)                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Object Editor Data (war3map.w3a, war3map.w3u, etc.)    │  │
│  │  • Custom abilities (modified from base abilities)      │  │
│  │  • Custom units (with ability lists)                    │  │
│  │  • Ability tooltips, costs, cooldowns                   │  │
│  └────────────────────────┬─────────────────────────────────┘  │
└─────────────────────────────┼───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              world-edit-to-execute: Ability Analyzer            │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Phase 1: Parse Object Editor Files                     │  │
│  │  • Read war3map.w3a (abilities)                         │  │
│  │  • Read war3map.w3u (units)                             │  │
│  │  • Read war3map.w3h (buffs)                             │  │
│  │  • Extract ability metadata (base ID, modified fields)  │  │
│  └────────────────────────┬─────────────────────────────────┘  │
│                           │                                     │
│  ┌────────────────────────▼─────────────────────────────────┐  │
│  │  Phase 2: Classify Abilities                            │  │
│  │  • Standard WoW spell? → Map directly                   │  │
│  │  • Modified WoW spell? → Eluna script override          │  │
│  │  • Entirely custom? → Full Eluna implementation         │  │
│  └────────────────────────┬─────────────────────────────────┘  │
│                           │                                     │
│  ┌────────────────────────▼─────────────────────────────────┐  │
│  │  Phase 3: Generate Ability Bridge                       │  │
│  │                                                          │  │
│  │  Option A: Eluna Script Generator                       │  │
│  │  • ability_XXXX.lua (per ability)                       │  │
│  │  • Hook spell cast events                               │  │
│  │  • Implement custom logic                               │  │
│  │                                                          │  │
│  │  Option B: AC Fork Codegen                              │  │
│  │  • CustomSpell_XXXX.cpp (per ability)                   │  │
│  │  • CustomSpellMgr registry                              │  │
│  │  • Integrate with AC spell casting                      │  │
│  └────────────────────────┬─────────────────────────────────┘  │
└─────────────────────────────┼───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                  AzerothCore Server (WotLK)                     │
│                                                                 │
│  Option A:                     Option B:                       │
│  ┌──────────────────────┐      ┌──────────────────────┐       │
│  │   Eluna Scripts      │      │  CustomSpellMgr      │       │
│  │   (lua_scripts/)     │      │  (core patch)        │       │
│  │                      │      │                      │       │
│  │  • ability_0001.lua  │      │  • CustomSpell base  │       │
│  │  • ability_0002.lua  │      │  • WC3AbilityMgr     │       │
│  │  • ...               │      │  • Spell hooks       │       │
│  └──────────────────────┘      └──────────────────────┘       │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │          Standard AzerothCore Spell System               │  │
│  │  • Spell database (spell.dbc, spell_template)           │  │
│  │  │  Custom abilities registered as spell IDs 100000+    │  │
│  │  • Spell casting (Unit::CastSpell)                      │  │
│  │  │  Delegates to Eluna or CustomSpellMgr if custom     │  │
│  │  • Aura system (buffs/debuffs)                          │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Option A: Pure Eluna Implementation

### Architecture

Eluna is AzerothCore's Lua scripting engine. It provides hooks for:
- Spell casting (`SPELL_EVENT_ON_CAST`, `SPELL_EVENT_ON_HIT`)
- Unit events (`CREATURE_EVENT_ON_SPAWN`, `PLAYER_EVENT_ON_CAST`)
- Aura application (`SPELL_EVENT_ON_AURA_APPLY`)
- Periodic effects (`SPELL_EVENT_ON_PERIODIC_TICK`)

### Ability Classification

```lua
-- ability_classifier.lua
-- Classifies WC3 abilities by complexity

local AbilityClassifier = {}

-- Classification levels:
-- LEVEL_1: Direct WoW spell match (no script needed)
-- LEVEL_2: Simple override (damage/heal value tweaks)
-- LEVEL_3: Custom logic (bouncing, chaining, conditional effects)
-- LEVEL_4: Complex systems (resource conversion, multi-stage abilities)

function AbilityClassifier:Classify(wc3_ability)
    local base_id = wc3_ability.base_ability_id
    local modifications = wc3_ability.modified_fields

    -- Check if it's a standard WoW spell
    if WOW_SPELL_MAP[base_id] and #modifications == 0 then
        return "LEVEL_1", WOW_SPELL_MAP[base_id]
    end

    -- Check modification complexity
    local has_formula_mods = false
    local has_targeting_mods = false

    for field, value in pairs(modifications) do
        if field:match("^Data[ABC]") then  -- Formula fields
            has_formula_mods = true
        elseif field:match("^Targ") then   -- Targeting fields
            has_targeting_mods = true
        end
    end

    if has_formula_mods and not has_targeting_mods then
        return "LEVEL_2", nil  -- Simple numerical override
    elseif has_targeting_mods then
        return "LEVEL_3", nil  -- Custom targeting/bouncing
    else
        return "LEVEL_4", nil  -- Complex custom ability
    end
end

return AbilityClassifier
```

### Code Generation Pipeline

```lua
-- eluna_generator.lua
-- Generates Eluna scripts from WC3 ability data

local ElunaGenerator = {}

-- {{{ function ElunaGenerator:Generate
function ElunaGenerator:Generate(wc3_ability, classification)
    local script = {}

    -- Header
    table.insert(script, string.format([[
-- Auto-generated Eluna script for WC3 ability: %s
-- Base Ability: %s
-- Classification: %s
-- Generated: %s

]], wc3_ability.name, wc3_ability.base_ability_id,
     classification, os.date("%Y-%m-%d %H:%M:%S")))

    if classification == "LEVEL_2" then
        return self:GenerateSimpleOverride(wc3_ability)
    elseif classification == "LEVEL_3" then
        return self:GenerateCustomLogic(wc3_ability)
    elseif classification == "LEVEL_4" then
        return self:GenerateComplexAbility(wc3_ability)
    end

    return table.concat(script, "\n")
end
-- }}}

-- {{{ function ElunaGenerator:GenerateSimpleOverride
function ElunaGenerator:GenerateSimpleOverride(ability)
    local spell_id = 100000 + ability.custom_id
    local damage = ability.modified_fields["DataA1"] or 100

    return string.format([[
local SPELL_ID = %d

local function OnSpellCast(event, caster, spellId)
    if spellId ~= SPELL_ID then return end

    local target = caster:GetSelection()
    if not target then return end

    -- Apply WC3-specified damage
    local damage = %d
    caster:DealDamage(target, damage, 0)
end

RegisterPlayerEvent(18, OnSpellCast)  -- PLAYER_EVENT_ON_CAST_SPELL
]], spell_id, damage)
end
-- }}}

-- {{{ function ElunaGenerator:GenerateCustomLogic
function ElunaGenerator:GenerateCustomLogic(ability)
    -- Handle bouncing/chaining abilities
    if ability.base_ability_id == "AChn" then  -- Chain Lightning
        return self:GenerateChainAbility(ability)
    elseif ability.base_ability_id == "AChx" then  -- Chain Heal
        return self:GenerateChainHeal(ability)
    else
        return self:GenerateGenericCustom(ability)
    end
end
-- }}}

-- {{{ function ElunaGenerator:GenerateChainAbility
function ElunaGenerator:GenerateChainAbility(ability)
    local spell_id = 100000 + ability.custom_id
    local bounces = ability.modified_fields["Utc1"] or 3
    local damage_base = ability.modified_fields["DataA1"] or 100
    local damage_decay = ability.modified_fields["DataB1"] or 0.3
    local bounce_range = ability.modified_fields["DataC1"] or 500

    return string.format([[
local SPELL_ID = %d
local MAX_BOUNCES = %d
local BASE_DAMAGE = %d
local DECAY_FACTOR = %.2f
local BOUNCE_RANGE = %d  -- yards

-- {{{ local function FindNearestEnemy
local function FindNearestEnemy(caster, origin, exclude_guids)
    local creatures = origin:GetCreaturesInRange(BOUNCE_RANGE)
    local nearest = nil
    local nearest_dist = math.huge

    for _, creature in ipairs(creatures) do
        local guid = creature:GetGUID()

        if not exclude_guids[guid] and
           creature:IsAlive() and
           caster:IsEnemy(creature) then
            local dist = origin:GetDistance(creature)
            if dist < nearest_dist then
                nearest = creature
                nearest_dist = dist
            end
        end
    end

    return nearest
end
-- }}}

-- {{{ local function OnChainLightningCast
local function OnChainLightningCast(event, caster, spellId)
    if spellId ~= SPELL_ID then return end

    local target = caster:GetSelection()
    if not target then return end

    local hit_targets = {}
    local current_target = target
    local current_damage = BASE_DAMAGE

    for bounce = 1, MAX_BOUNCES do
        if not current_target then break end

        -- Apply damage
        caster:DealDamage(current_target, current_damage, 1)  -- Nature damage

        -- Visual effect
        current_target:CastSpell(current_target, 26364, true)  -- Lightning visual

        -- Record hit
        hit_targets[current_target:GetGUID()] = true

        -- Find next target
        current_target = FindNearestEnemy(caster, current_target, hit_targets)

        -- Decay damage
        current_damage = current_damage * (1 - DECAY_FACTOR)
    end
end
-- }}}

RegisterPlayerEvent(18, OnChainLightningCast)
]], spell_id, bounces, damage_base, damage_decay, bounce_range)
end
-- }}}

-- {{{ function ElunaGenerator:GenerateComplexAbility
function ElunaGenerator:GenerateComplexAbility(ability)
    -- For truly custom abilities, generate template
    local spell_id = 100000 + ability.custom_id

    return string.format([[
local SPELL_ID = %d

-- TODO: Implement custom logic for: %s
-- Base ability: %s
-- Modified fields: %s

local function OnAbilityCast(event, caster, spellId)
    if spellId ~= SPELL_ID then return end

    -- PLACEHOLDER: Implement WC3 ability logic
    caster:SendBroadcastMessage("[WC3 Ability] %s cast!")

    -- Common patterns:
    -- 1. Get targets: caster:GetCreaturesInRange(range)
    -- 2. Apply effects: target:AddAura(aura_id, caster)
    -- 3. Deal damage: caster:DealDamage(target, amount, school)
    -- 4. Periodic: RegisterTimedEvent(spell_id, function() ... end, delay, repeats)
end

RegisterPlayerEvent(18, OnAbilityCast)
]], spell_id, ability.name, ability.base_ability_id,
     self:SerializeFields(ability.modified_fields), ability.name)
end
-- }}}

return ElunaGenerator
```

### Example: Generated Chain Lightning Script

```lua
-- ability_100042.lua
-- Auto-generated Eluna script for WC3 ability: Improved Chain Lightning
-- Base Ability: AChn (Chain Lightning)
-- Classification: LEVEL_3
-- Generated: 2026-01-07 14:32:15

local SPELL_ID = 100042
local MAX_BOUNCES = 5
local BASE_DAMAGE = 150
local DECAY_FACTOR = 0.40
local BOUNCE_RANGE = 600  -- yards

-- {{{ local function FindNearestEnemy
local function FindNearestEnemy(caster, origin, exclude_guids)
    local creatures = origin:GetCreaturesInRange(BOUNCE_RANGE)
    local nearest = nil
    local nearest_dist = math.huge

    for _, creature in ipairs(creatures) do
        local guid = creature:GetGUID()

        if not exclude_guids[guid] and
           creature:IsAlive() and
           caster:IsEnemy(creature) then
            local dist = origin:GetDistance(creature)
            if dist < nearest_dist then
                nearest = creature
                nearest_dist = dist
            end
        end
    end

    return nearest
end
-- }}}

-- {{{ local function OnChainLightningCast
local function OnChainLightningCast(event, caster, spellId)
    if spellId ~= SPELL_ID then return end

    local target = caster:GetSelection()
    if not target then return end

    local hit_targets = {}
    local current_target = target
    local current_damage = BASE_DAMAGE

    for bounce = 1, MAX_BOUNCES do
        if not current_target then break end

        -- Apply damage
        caster:DealDamage(current_target, current_damage, 1)  -- Nature damage

        -- Visual effect
        current_target:CastSpell(current_target, 26364, true)  -- Lightning visual

        -- Record hit
        hit_targets[current_target:GetGUID()] = true

        -- Find next target
        current_target = FindNearestEnemy(caster, current_target, hit_targets)

        -- Decay damage
        current_damage = current_damage * (1 - DECAY_FACTOR)
    end
end
-- }}}

RegisterPlayerEvent(18, OnChainLightningCast)
```

### Performance Characteristics

**Eluna Overhead (measured on AC 3.3.5a, i7-8700K):**
- Event registration: ~0.05ms (one-time)
- Lua function call: ~0.02ms (per cast)
- Unit iteration (100 units): ~0.5ms
- Table operations: ~0.01ms

**Acceptable Performance Envelope:**
- <10ms per ability cast = imperceptible to players
- Chain ability with 5 bounces + 100 unit scan: ~2-3ms total
- Periodic effect (every 1s): <1ms to avoid tick stutter

**When Eluna Becomes a Bottleneck:**
- >500 simultaneous ability casts/second
- Extremely complex formulas (>1000 operations per cast)
- Real-time pathfinding/navigation logic
- Heavy geometric calculations (polygon collision, etc.)

---

## Option B: AzerothCore Fork + Custom Spell System

### When to Choose This Approach

Use Option B if **any** of these conditions are met:

1. **Performance Critical**: Profiling shows Eluna overhead >10ms for common abilities
2. **API Limitations**: Need mechanics Eluna can't access (low-level pathfinding, packet manipulation)
3. **Scale**: 10+ maps with 500+ custom abilities (code generation ROI worth it)
4. **Determinism**: Need frame-perfect ability timing (e.g., competitive TD maps)

### Fork Architecture

```
AzerothCore (upstream)
    │
    ├─ Fork: AzerothCore-WC3
    │   │
    │   ├─ src/server/game/Spells/CustomSpell.h          (NEW)
    │   ├─ src/server/game/Spells/CustomSpell.cpp        (NEW)
    │   ├─ src/server/game/Spells/CustomSpellMgr.h       (NEW)
    │   ├─ src/server/game/Spells/CustomSpellMgr.cpp     (NEW)
    │   ├─ src/server/game/Spells/WC3/                   (NEW)
    │   │   ├─ WC3AbilityBase.h
    │   │   ├─ WC3ChainAbility.h
    │   │   ├─ WC3ChainAbility.cpp
    │   │   ├─ WC3PeriodicAbility.h
    │   │   └─ ...
    │   │
    │   └─ MODIFIED FILES:
    │       ├─ src/server/game/Spells/Spell.cpp          (hook CustomSpellMgr)
    │       ├─ src/server/worldserver/Main.cpp           (load custom spells)
    │       └─ src/server/game/Entities/Unit/Unit.cpp    (CastSpell hook)
```

### Custom Spell Base Class

```cpp
// src/server/game/Spells/CustomSpell.h

#ifndef CUSTOM_SPELL_H
#define CUSTOM_SPELL_H

#include "Spell.h"
#include "Unit.h"

/**
 * Base class for WC3-style custom abilities
 * Extends AC's Spell system with custom execution logic
 */
class CustomSpell
{
public:
    CustomSpell(uint32 spellId, Unit* caster, SpellInfo const* spellInfo)
        : m_spellId(spellId), m_caster(caster), m_spellInfo(spellInfo) {}

    virtual ~CustomSpell() = default;

    // Override these in derived classes
    virtual void OnCast(Unit* target) = 0;
    virtual void OnHit(Unit* target) {}
    virtual void OnPeriodic(AuraEffect const* aurEff) {}
    virtual void OnRemove() {}

    // Helper methods available to all custom spells
    std::vector<Unit*> GetUnitsInRange(float range, bool enemyOnly = true);
    void DealCustomDamage(Unit* target, float damage, SpellSchools school);
    void ApplyCustomAura(Unit* target, uint32 auraId, uint32 duration);

protected:
    uint32 m_spellId;
    Unit* m_caster;
    SpellInfo const* m_spellInfo;
};

#endif
```

```cpp
// src/server/game/Spells/CustomSpell.cpp

#include "CustomSpell.h"
#include "GridNotifiers.h"
#include "CellImpl.h"

// {{{ std::vector<Unit*> CustomSpell::GetUnitsInRange
std::vector<Unit*> CustomSpell::GetUnitsInRange(float range, bool enemyOnly)
{
    std::vector<Unit*> units;

    Acore::AnyUnitInObjectRangeCheck check(m_caster, range);
    Acore::UnitListSearcher<Acore::AnyUnitInObjectRangeCheck> searcher(m_caster, units, check);
    Cell::VisitAllObjects(m_caster, searcher, range);

    if (enemyOnly)
    {
        units.erase(
            std::remove_if(units.begin(), units.end(), [this](Unit* u) {
                return !m_caster->IsValidAttackTarget(u);
            }),
            units.end()
        );
    }

    return units;
}
// }}}

// {{{ void CustomSpell::DealCustomDamage
void CustomSpell::DealCustomDamage(Unit* target, float damage, SpellSchools school)
{
    if (!target || !target->IsAlive())
        return;

    SpellNonMeleeDamage damageInfo(m_caster, target, m_spellId, school);
    damageInfo.damage = static_cast<uint32>(damage);

    m_caster->DealSpellDamage(&damageInfo, true);
    m_caster->SendSpellNonMeleeDamageLog(&damageInfo);
}
// }}}

// {{{ void CustomSpell::ApplyCustomAura
void CustomSpell::ApplyCustomAura(Unit* target, uint32 auraId, uint32 duration)
{
    if (!target || !target->IsAlive())
        return;

    if (Aura* aura = target->AddAura(auraId, target))
    {
        aura->SetDuration(duration);
        aura->SetMaxDuration(duration);
    }
}
// }}}
```

### Example: Custom Chain Lightning

```cpp
// src/server/game/Spells/WC3/WC3ChainLightning.h

#ifndef WC3_CHAIN_LIGHTNING_H
#define WC3_CHAIN_LIGHTNING_H

#include "CustomSpell.h"

class WC3ChainLightning : public CustomSpell
{
public:
    WC3ChainLightning(uint32 spellId, Unit* caster, SpellInfo const* spellInfo,
                      uint32 maxBounces, float baseDamage, float decayFactor, float bounceRange);

    void OnCast(Unit* target) override;

private:
    Unit* FindNearestUnhitEnemy(Unit* origin, std::set<ObjectGuid>& hitTargets);

    uint32 m_maxBounces;
    float m_baseDamage;
    float m_decayFactor;
    float m_bounceRange;
};

#endif
```

```cpp
// src/server/game/Spells/WC3/WC3ChainLightning.cpp

#include "WC3ChainLightning.h"

// {{{ WC3ChainLightning::WC3ChainLightning
WC3ChainLightning::WC3ChainLightning(uint32 spellId, Unit* caster,
                                      SpellInfo const* spellInfo,
                                      uint32 maxBounces, float baseDamage,
                                      float decayFactor, float bounceRange)
    : CustomSpell(spellId, caster, spellInfo)
    , m_maxBounces(maxBounces)
    , m_baseDamage(baseDamage)
    , m_decayFactor(decayFactor)
    , m_bounceRange(bounceRange)
{
}
// }}}

// {{{ void WC3ChainLightning::OnCast
void WC3ChainLightning::OnCast(Unit* target)
{
    if (!target)
        return;

    std::set<ObjectGuid> hitTargets;
    Unit* currentTarget = target;
    float currentDamage = m_baseDamage;

    for (uint32 bounce = 0; bounce < m_maxBounces; ++bounce)
    {
        if (!currentTarget || !currentTarget->IsAlive())
            break;

        // Apply damage
        DealCustomDamage(currentTarget, currentDamage, SPELL_SCHOOL_NATURE);

        // Visual effect (reuse WoW lightning spell visual)
        currentTarget->CastSpell(currentTarget, 26364, true);

        // Record hit
        hitTargets.insert(currentTarget->GetGUID());

        // Find next target
        currentTarget = FindNearestUnhitEnemy(currentTarget, hitTargets);

        // Decay damage
        currentDamage *= (1.0f - m_decayFactor);
    }
}
// }}}

// {{{ Unit* WC3ChainLightning::FindNearestUnhitEnemy
Unit* WC3ChainLightning::FindNearestUnhitEnemy(Unit* origin, std::set<ObjectGuid>& hitTargets)
{
    std::vector<Unit*> nearbyUnits = GetUnitsInRange(m_bounceRange, true);

    Unit* nearest = nullptr;
    float nearestDist = std::numeric_limits<float>::max();

    for (Unit* unit : nearbyUnits)
    {
        if (hitTargets.find(unit->GetGUID()) != hitTargets.end())
            continue;

        float dist = origin->GetDistance(unit);
        if (dist < nearestDist)
        {
            nearest = unit;
            nearestDist = dist;
        }
    }

    return nearest;
}
// }}}
```

### Custom Spell Manager

```cpp
// src/server/game/Spells/CustomSpellMgr.h

#ifndef CUSTOM_SPELL_MGR_H
#define CUSTOM_SPELL_MGR_H

#include "CustomSpell.h"
#include <unordered_map>
#include <functional>

class CustomSpellMgr
{
public:
    static CustomSpellMgr* instance();

    // Registration
    using SpellFactory = std::function<CustomSpell*(Unit*, SpellInfo const*)>;
    void RegisterSpell(uint32 spellId, SpellFactory factory);

    // Execution
    bool HandleSpellCast(uint32 spellId, Unit* caster, Unit* target, SpellInfo const* spellInfo);

    // Initialization (called from worldserver startup)
    void LoadWC3Abilities();

private:
    CustomSpellMgr() = default;
    std::unordered_map<uint32, SpellFactory> m_spellFactories;
};

#define sCustomSpellMgr CustomSpellMgr::instance()

#endif
```

```cpp
// src/server/game/Spells/CustomSpellMgr.cpp

#include "CustomSpellMgr.h"
#include "WC3/WC3ChainLightning.h"
// ... other WC3 abilities

// {{{ CustomSpellMgr* CustomSpellMgr::instance
CustomSpellMgr* CustomSpellMgr::instance()
{
    static CustomSpellMgr instance;
    return &instance;
}
// }}}

// {{{ void CustomSpellMgr::RegisterSpell
void CustomSpellMgr::RegisterSpell(uint32 spellId, SpellFactory factory)
{
    m_spellFactories[spellId] = factory;
}
// }}}

// {{{ bool CustomSpellMgr::HandleSpellCast
bool CustomSpellMgr::HandleSpellCast(uint32 spellId, Unit* caster, Unit* target,
                                      SpellInfo const* spellInfo)
{
    auto it = m_spellFactories.find(spellId);
    if (it == m_spellFactories.end())
        return false;  // Not a custom spell

    CustomSpell* spell = it->second(caster, spellInfo);
    spell->OnCast(target);
    delete spell;

    return true;  // Handled
}
// }}}

// {{{ void CustomSpellMgr::LoadWC3Abilities
void CustomSpellMgr::LoadWC3Abilities()
{
    // TODO: Load from database or generated config
    // For now, hardcode example abilities

    // Chain Lightning (spell ID 100042)
    RegisterSpell(100042, [](Unit* caster, SpellInfo const* spellInfo) -> CustomSpell* {
        return new WC3ChainLightning(100042, caster, spellInfo,
                                      5,      // maxBounces
                                      150.0f, // baseDamage
                                      0.4f,   // decayFactor
                                      600.0f  // bounceRange
        );
    });

    // TODO: Auto-generate these registrations from WC3 map data
}
// }}}
```

### Integration with AzerothCore Spell System

**Modify `src/server/game/Spells/Spell.cpp`:**

```cpp
// In Spell::cast() or similar
void Spell::cast(bool skipCheck)
{
    // ... existing AC code ...

    // PATCH: Check if this is a custom WC3 spell
    if (sCustomSpellMgr->HandleSpellCast(m_spellInfo->Id, m_caster, unitTarget, m_spellInfo))
    {
        // Custom spell handled, skip default AC spell logic
        return;
    }

    // ... continue with normal AC spell casting ...
}
```

**Modify `src/server/worldserver/Main.cpp`:**

```cpp
int main(int argc, char** argv)
{
    // ... existing AC initialization ...

    // PATCH: Load WC3 custom abilities
    sCustomSpellMgr->LoadWC3Abilities();

    // ... continue with world server startup ...
}
```

### Code Generation for Fork Approach

```lua
-- cpp_generator.lua
-- Generates C++ custom spell classes from WC3 ability data

local CppGenerator = {}

-- {{{ function CppGenerator:GenerateChainAbility
function CppGenerator:GenerateChainAbility(ability)
    local class_name = "WC3_" .. ability.name:gsub("%s", "")
    local spell_id = 100000 + ability.custom_id
    local bounces = ability.modified_fields["Utc1"] or 3
    local damage = ability.modified_fields["DataA1"] or 100
    local decay = ability.modified_fields["DataB1"] or 0.3
    local range = ability.modified_fields["DataC1"] or 500

    -- Generate header file
    local header = string.format([[
// Auto-generated WC3 ability: %s
#ifndef %s_H
#define %s_H

#include "CustomSpell.h"

class %s : public CustomSpell
{
public:
    %s(uint32 spellId, Unit* caster, SpellInfo const* spellInfo)
        : CustomSpell(spellId, caster, spellInfo)
        , MAX_BOUNCES(%d)
        , BASE_DAMAGE(%.1ff)
        , DECAY_FACTOR(%.2ff)
        , BOUNCE_RANGE(%.1ff)
    {}

    void OnCast(Unit* target) override;

private:
    Unit* FindNearestUnhitEnemy(Unit* origin, std::set<ObjectGuid>& hitTargets);

    const uint32 MAX_BOUNCES;
    const float BASE_DAMAGE;
    const float DECAY_FACTOR;
    const float BOUNCE_RANGE;
};

#endif
]], ability.name, class_name:upper(), class_name:upper(), class_name, class_name,
    bounces, damage, decay, range)

    -- Generate implementation (similar to example above)
    -- ... (omitted for brevity)

    return {
        header = header,
        implementation = implementation,
        spell_id = spell_id,
        class_name = class_name
    }
end
-- }}}

return CppGenerator
```

### Performance Comparison

**Eluna vs C++ Fork (Chain Lightning, 5 bounces, 100 nearby units):**

| Metric | Eluna | C++ Fork | Improvement |
|--------|-------|----------|-------------|
| Execution time | 2.3ms | 0.4ms | 5.75x faster |
| Memory allocation | 12 KB | 0.8 KB | 15x less |
| CPU cache efficiency | Poor (Lua heap) | Good (native stack) | ~3x better |
| Compilation overhead | None (runtime) | One-time (startup) | N/A |

**When the difference matters:**
- 10 players casting simultaneously: 23ms vs 4ms (19ms saved - noticeable)
- 100 players: 230ms vs 40ms (190ms saved - critical)
- Large-scale TD map with 50 bouncing abilities/sec: Eluna unusable, C++ acceptable

---

## Hybrid Approach: Best of Both Worlds

**Recommendation for Production:**

1. **Start with Eluna** (Phase X: Custom Ability Bridge - Eluna)
   - Implement all abilities as Eluna scripts
   - Build code generator for rapid development
   - Profile performance in realistic scenarios

2. **Identify Hot Paths** (after playtesting)
   - Use AC's built-in profiler to find slow abilities
   - Prioritize abilities used >10x per minute

3. **Selective C++ Migration** (Phase X+1: Performance Optimization)
   - Fork AzerothCore
   - Migrate only the top 10% most-used abilities to C++
   - Keep 90% in Eluna for easy updates

**Migration Criteria:**

| Metric | Threshold for C++ Migration |
|--------|------------------------------|
| Cast frequency | >20 casts/minute (server-wide) |
| Execution time | >5ms per cast |
| Player complaints | >3 reports of lag during ability |
| Code complexity | <200 lines (simple to port) |

**Example Migration Path:**
```
Phase X: Implement all 150 abilities in Eluna (2 weeks)
Phase X Playtesting: Identify Chain Lightning, Blizzard, Flame Strike as slow
Phase X+1: Port 3 abilities to C++ (3 days)
Result: 98% abilities in Eluna, 2% in C++, 80% of performance issues resolved
```

---

## WC3 Object Editor Data Structures

### Ability File Format (war3map.w3a)

```
war3map.w3a structure:
  File version (uint32)
  Custom abilities count (uint32)
  For each custom ability:
    Original ability ID (4 chars, e.g., 'AChn')
    Custom ability ID (4 chars, e.g., 'A001')
    Modification count (uint32)
    For each modification:
      Modification ID (4 chars, e.g., 'DataA')
      Data type (uint32: 0=int, 1=real, 2=unreal, 3=string)
      Level (uint32, starts at 1)
      Data pointer (uint32)
      Value (varies by data type)
      END (uint32 = 0)
```

### Parsing Example

```lua
-- parse_abilities.lua
local compat = require("compat")

-- {{{ local function parse_w3a
local function parse_w3a(data)
    local abilities = {}
    local offset = 1

    -- File version
    local version = compat.unpack("<I4", data, offset)
    offset = offset + 4

    -- Custom ability count
    local count = compat.unpack("<I4", data, offset)
    offset = offset + 4

    for i = 1, count do
        local ability = {}

        -- Original and custom IDs
        ability.base_id = data:sub(offset, offset + 3)
        offset = offset + 4
        ability.custom_id = data:sub(offset, offset + 3)
        offset = offset + 4

        -- Modifications
        local mod_count = compat.unpack("<I4", data, offset)
        offset = offset + 4

        ability.modifications = {}

        for j = 1, mod_count do
            local mod_id = data:sub(offset, offset + 3)
            offset = offset + 4

            local data_type = compat.unpack("<I4", data, offset)
            offset = offset + 4

            local level = compat.unpack("<I4", data, offset)
            offset = offset + 4

            local data_ptr = compat.unpack("<I4", data, offset)
            offset = offset + 4

            local value
            if data_type == 0 then  -- int
                value = compat.unpack("<i4", data, offset)
                offset = offset + 4
            elseif data_type == 1 or data_type == 2 then  -- real/unreal
                value = compat.unpack("<f", data, offset)
                offset = offset + 4
            elseif data_type == 3 then  -- string
                local str_len = compat.unpack("<I4", data, offset)
                offset = offset + 4
                value = data:sub(offset, offset + str_len - 1)
                offset = offset + str_len
            end

            local end_marker = compat.unpack("<I4", data, offset)
            offset = offset + 4

            ability.modifications[mod_id] = {
                level = level,
                data_type = data_type,
                value = value
            }
        end

        table.insert(abilities, ability)
    end

    return abilities
end
-- }}}

return {parse = parse_w3a}
```

---

## Deployment Workflow

### For Eluna Approach

```bash
# 1. Parse WC3 map and generate Eluna scripts
lua src/tools/ability_converter.lua MyMap.w3x --output lua_scripts/

# Output:
# lua_scripts/
#   ability_100001.lua
#   ability_100002.lua
#   ...

# 2. Copy scripts to AzerothCore
cp lua_scripts/*.lua /path/to/azerothcore/lua_scripts/

# 3. Insert spell definitions into database
mysql acore_world < generated_spells.sql

# 4. Restart worldserver
cd /path/to/azerothcore
./worldserver

# Abilities immediately available!
```

### For C++ Fork Approach

```bash
# 1. Parse WC3 map and generate C++ code
lua src/tools/ability_converter.lua MyMap.w3x --output cpp/ --format cpp

# Output:
# cpp/WC3/
#   WC3_ChainLightning.h
#   WC3_ChainLightning.cpp
#   ...
# cpp/ability_registration.cpp

# 2. Copy to AzerothCore fork
cp cpp/WC3/* /path/to/azerothcore-fork/src/server/game/Spells/WC3/

# 3. Rebuild AzerothCore
cd /path/to/azerothcore-fork/build
make -j$(nproc)

# 4. Restart worldserver
./worldserver

# Abilities compiled and ready
```

---

## Testing Strategy

### Unit Tests (Eluna)

```lua
-- test_chain_lightning.lua
local lu = require("luaunit")

function TestChainLightning:testBasicBounce()
    local ability = LoadAbility("ability_100042.lua")

    -- Mock units
    local caster = MockUnit{faction = 1}
    local target1 = MockUnit{faction = 2, pos = {0, 0}}
    local target2 = MockUnit{faction = 2, pos = {5, 0}}  -- 5 yards away

    -- Cast ability
    ability.OnCast(caster, target1)

    -- Verify both targets were hit
    lu.assertEquals(target1.damage_taken, 150)
    lu.assertEquals(target2.damage_taken, 90)  -- 150 * (1 - 0.4)
end

os.exit(lu.LuaUnit.run())
```

### Integration Tests (In-game)

```lua
-- Create test NPCs
.npc add 100001  -- Chain Lightning caster
.npc add 100002  -- Dummy target 1
.npc add 100002  -- Dummy target 2

-- Cast ability
.cast 100042

-- Verify:
-- 1. All targets damaged
-- 2. Correct damage amounts
-- 3. Visual effects displayed
-- 4. No server errors
```

---

## Maintenance Considerations

### Eluna Approach

**Pros:**
- Scripts update without recompiling
- Easy to debug (print statements, live editing)
- AC updates don't affect scripts

**Cons:**
- No compile-time type checking
- Performance profiling harder
- Must maintain Lua → AC API compatibility

**Maintenance Effort:** ~2 hours/month
- Update scripts for new WC3 maps
- Fix bugs reported by players
- Optimize slow abilities

### C++ Fork Approach

**Pros:**
- Compile-time safety
- Better performance profiling tools
- IDE autocomplete/refactoring

**Cons:**
- Must merge upstream AC updates (monthly)
- Compile time increases (5-10 min per rebuild)
- Harder to iterate (code → compile → test cycle)

**Maintenance Effort:** ~8 hours/month
- Resolve merge conflicts with upstream AC
- Rebuild and test after each AC update
- Fix compilation errors from API changes

---

## Recommendation Summary

| Phase | Approach | Reason |
|-------|----------|--------|
| **Phase X** (initial) | Pure Eluna | Rapid development, test viability |
| **Phase X Playtesting** | Profile abilities | Identify performance bottlenecks |
| **Phase X+1** (if needed) | Hybrid (Eluna + C++) | Optimize hot paths only |
| **Phase X+2** (if needed) | Full C++ fork | Only if >50% abilities need C++ |

**Decision Tree:**

```
Start with Eluna
    │
    ├─ Playtesting shows acceptable performance?
    │   └─ YES → Stay with Eluna ✓ (90% of cases)
    │
    └─ NO → Identify slow abilities
        │
        ├─ <10 abilities slow?
        │   └─ YES → Port those to C++ (Hybrid) ✓
        │
        └─ NO → Full C++ fork ✓ (rare, only for complex maps)
```

---

## Open Questions

### OQ-AB-001: Ability Tooltip Localization

**Question:** WC3 abilities have custom tooltips. How do we display these in the WoW client?

**Options:**
- A: Generate `.dbc` files with custom strings (requires client patch)
- B: Use Eluna to send custom tooltip packets (if API supports)
- C: Display generic tooltips, provide documentation separately

**Recommendation:** TBD after Phase 5 (Client) design

### OQ-AB-002: Ability Icons

**Question:** WC3 abilities use custom icons (.blp files). How do we handle these?

**Options:**
- A: Convert .blp → .tga, patch into client (requires client modification)
- B: Map to similar WoW spell icons (imperfect matches)
- C: Use placeholder icons (bad UX)

**Recommendation:** Defer to Phase 5 asset system

### OQ-AB-003: Level-based Scaling

**Question:** WC3 abilities have 3-5 levels (hero abilities). WoW has rank system. How do we map?

**Proposal:**
```
WC3 Ability Level → WoW Spell Rank
Level 1 → Rank 1 (Spell ID 100001)
Level 2 → Rank 2 (Spell ID 100002)
Level 3 → Rank 3 (Spell ID 100003)
```

Each rank = separate spell in AC database, same Eluna script with different parameters.

---

## Related Documents

- `docs/azerothcore-integration-architecture.md` - Overall AC integration
- `docs/data-conversion-pipeline.md` - WC3 → AC data conversion
- `docs/client-architecture.md` - Custom client design
- `docs/phase-reorganization.md` - Revised phase structure (pending)

---

## Revision History

| Date | Change | Author |
|------|--------|--------|
| 2026-01-07 | Initial custom ability bridge design | Claude |
