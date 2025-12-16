# Issue #011: Essential Upgrades System (F008, F009)

**Priority**: Medium  
**Phase**: 2.4 (Enhanced Single-Player)  
**Estimated Effort**: 4-5 days  
**Dependencies**: #005  

## Problem Description

Implement the essential upgrades system that provides strategic choices 
every 5 waves, with a minimum of 20 different upgrade types affecting 
towers, economy, and tactical advantages as specified in the vision.

## Current Behavior

Basic game flow exists but no upgrade progression system.

## Expected Behavior

Rich upgrade system that appears every 5 waves with diverse strategic 
options, shared choices in multiplayer, and meaningful impact on gameplay.

## Implementation Approach

### Upgrade Manager
```lua
-- {{{ UpgradeManager
local UpgradeManager = {
  upgradePool = {},
  playerUpgrades = {},
  upgradeInterval = 5,
  optionsPerSelection = 3
}

-- {{{ checkForUpgradeOpportunity
function UpgradeManager:checkForUpgradeOpportunity(currentWave)
  return currentWave % self.upgradeInterval == 0
end
-- }}}

-- {{{ generateUpgradeOptions
function UpgradeManager:generateUpgradeOptions(playerId, availableUpgrades)
  local options = {}
  local pool = self:getAvailableUpgradesForPlayer(playerId, availableUpgrades)
  
  -- Randomly select 3 upgrades from available pool
  for i = 1, self.optionsPerSelection do
    if #pool > 0 then
      local index = math.random(1, #pool)
      table.insert(options, pool[index])
      table.remove(pool, index)
    end
  end
  
  return options
end
-- }}}

-- {{{ applyUpgrade
function UpgradeManager:applyUpgrade(playerId, upgradeId)
  local upgrade = self.upgradePool[upgradeId]
  if not upgrade then
    return false, "Invalid upgrade ID"
  end
  
  -- Track player's upgrades
  if not self.playerUpgrades[playerId] then
    self.playerUpgrades[playerId] = {}
  end
  
  table.insert(self.playerUpgrades[playerId], upgradeId)
  
  -- Apply upgrade effects
  return self:activateUpgrade(playerId, upgrade)
end
-- }}}
```

### Upgrade Definitions
```lua
-- {{{ UpgradeDefinitions
local UpgradeDefinitions = {
  -- Tower Stat Improvements
  {
    id = "tower_health_boost",
    name = "Reinforced Construction",
    description = "All towers gain +25% health",
    category = "TOWER_STATS",
    effect = {
      type = "STAT_MULTIPLIER",
      target = "ALL_TOWERS",
      stat = "health",
      multiplier = 1.25
    }
  },
  
  {
    id = "tower_damage_boost",
    name = "Weapon Mastery",
    description = "All towers deal +20% damage",
    category = "TOWER_STATS",
    effect = {
      type = "STAT_MULTIPLIER",
      target = "ALL_TOWERS",
      stat = "damage",
      multiplier = 1.20
    }
  },
  
  {
    id = "tower_speed_boost",
    name = "Swift Movement",
    description = "All towers move 30% faster",
    category = "TOWER_STATS",
    effect = {
      type = "STAT_MULTIPLIER",
      target = "ALL_TOWERS",
      stat = "speed",
      multiplier = 1.30
    }
  },
  
  {
    id = "tower_range_boost",
    name = "Extended Reach",
    description = "All towers have +1 range",
    category = "TOWER_STATS",
    effect = {
      type = "STAT_ADDITION",
      target = "ALL_TOWERS",
      stat = "range",
      addition = 1
    }
  },
  
  -- Economic Bonuses
  {
    id = "income_boost",
    name = "Economic Growth",
    description = "Base income increased by 50%",
    category = "ECONOMY",
    effect = {
      type = "INCOME_MULTIPLIER",
      multiplier = 1.50
    }
  },
  
  {
    id = "bounty_boost",
    name = "Treasure Hunter",
    description = "Enemy bounty increased by 25%",
    category = "ECONOMY",
    effect = {
      type = "BOUNTY_MULTIPLIER",
      multiplier = 1.25
    }
  },
  
  {
    id = "cost_reduction",
    name = "Efficient Production",
    description = "All towers cost 20% less gold",
    category = "ECONOMY",
    effect = {
      type = "COST_MULTIPLIER",
      target = "ALL_TOWERS",
      multiplier = 0.80
    }
  },
  
  {
    id = "starting_gold",
    name = "Investment Fund",
    description = "Gain 200 bonus gold immediately",
    category = "ECONOMY",
    effect = {
      type = "IMMEDIATE_GOLD",
      amount = 200
    }
  },
  
  -- Special Abilities
  {
    id = "regeneration",
    name = "Self Repair",
    description = "Towers slowly regenerate health",
    category = "SPECIAL_ABILITY",
    effect = {
      type = "REGENERATION",
      target = "ALL_TOWERS",
      rate = 2 -- HP per tick
    }
  },
  
  {
    id = "area_damage",
    name = "Explosive Impact",
    description = "Tower attacks deal splash damage",
    category = "SPECIAL_ABILITY",
    effect = {
      type = "AREA_DAMAGE",
      radius = 1,
      damageRatio = 0.5
    }
  },
  
  {
    id = "chain_lightning",
    name = "Lightning Arc",
    description = "Attacks can chain between enemies",
    category = "SPECIAL_ABILITY",
    effect = {
      type = "CHAIN_ATTACK",
      maxTargets = 3,
      damageReduction = 0.25
    }
  },
  
  {
    id = "shield_generator",
    name = "Energy Shields",
    description = "Towers gain damage-absorbing shields",
    category = "SPECIAL_ABILITY",
    effect = {
      type = "SHIELD",
      shieldHP = 50,
      regenRate = 1
    }
  },
  
  -- Tactical Advantages
  {
    id = "placement_freedom",
    name = "Advanced Engineering",
    description = "Can place towers in enemy territory",
    category = "TACTICAL",
    effect = {
      type = "PLACEMENT_ZONE",
      allowEnemyTerritory = true
    }
  },
  
  {
    id = "vision_range",
    name = "Enhanced Sensors",
    description = "See enemies 2 waves earlier",
    category = "TACTICAL",
    effect = {
      type = "PREVIEW_WAVES",
      additionalWaves = 2
    }
  },
  
  {
    id = "instant_movement",
    name = "Teleportation",
    description = "Towers instantly reach combat positions",
    category = "TACTICAL",
    effect = {
      type = "INSTANT_MOVEMENT"
    }
  },
  
  {
    id = "dual_targeting",
    name = "Multi-Target Systems",
    description = "Towers can attack 2 enemies simultaneously",
    category = "TACTICAL",
    effect = {
      type = "MULTIPLE_TARGETS",
      maxTargets = 2
    }
  },
  
  -- Synergy Effects
  {
    id = "berserker_rage",
    name = "Berserker Protocol",
    description = "Damaged towers deal more damage",
    category = "SYNERGY",
    effect = {
      type = "CONDITIONAL_DAMAGE",
      condition = "HEALTH_BELOW_50",
      damageMultiplier = 1.75
    }
  },
  
  {
    id = "tower_networking",
    name = "Tactical Network",
    description = "Adjacent towers share 10% of their stats",
    category = "SYNERGY",
    effect = {
      type = "STAT_SHARING",
      radius = 1,
      shareRatio = 0.10
    }
  },
  
  {
    id = "swarm_tactics",
    name = "Pack Hunting",
    description = "Multiple towers attacking same enemy deal bonus damage",
    category = "SYNERGY",
    effect = {
      type = "FOCUS_FIRE_BONUS",
      bonusPerTower = 0.15
    }
  },
  
  {
    id = "resource_efficiency",
    name = "Recycling Protocol",
    description = "Destroyed towers refund 50% of their cost",
    category = "SYNERGY",
    effect = {
      type = "DEATH_REFUND",
      refundRatio = 0.50
    }
  }
}

-- {{{ loadUpgradeDefinitions
function UpgradeDefinitions:loadUpgradeDefinitions()
  local upgrades = {}
  
  for _, upgrade in ipairs(self) do
    upgrades[upgrade.id] = upgrade
  end
  
  return upgrades
end
-- }}}
```

### Upgrade Effects System
```lua
-- {{{ UpgradeEffects
local UpgradeEffects = {}

-- {{{ applyEffect
function UpgradeEffects:applyEffect(playerId, effect)
  if effect.type == "STAT_MULTIPLIER" then
    return self:applyStatMultiplier(playerId, effect)
  elseif effect.type == "STAT_ADDITION" then
    return self:applyStatAddition(playerId, effect)
  elseif effect.type == "INCOME_MULTIPLIER" then
    return self:applyIncomeMultiplier(playerId, effect)
  elseif effect.type == "IMMEDIATE_GOLD" then
    return self:applyImmediateGold(playerId, effect)
  elseif effect.type == "SPECIAL_ABILITY" then
    return self:applySpecialAbility(playerId, effect)
  end
  
  return false, "Unknown effect type"
end
-- }}}

-- {{{ applyStatMultiplier
function UpgradeEffects:applyStatMultiplier(playerId, effect)
  local player = GameEngine:getPlayer(playerId)
  if not player then
    return false, "Player not found"
  end
  
  -- Apply to existing towers
  if effect.target == "ALL_TOWERS" then
    for _, tower in pairs(player.towers) do
      tower.stats[effect.stat] = tower.stats[effect.stat] * effect.multiplier
    end
  end
  
  -- Store for future towers
  if not player.upgradeEffects then
    player.upgradeEffects = {}
  end
  
  table.insert(player.upgradeEffects, effect)
  
  return true
end
-- }}}

-- {{{ applyToNewTower
function UpgradeEffects:applyToNewTower(tower, playerUpgrades)
  for _, upgrade in ipairs(playerUpgrades) do
    local effect = upgrade.effect
    
    if effect.type == "STAT_MULTIPLIER" and effect.target == "ALL_TOWERS" then
      tower.stats[effect.stat] = tower.stats[effect.stat] * effect.multiplier
    elseif effect.type == "STAT_ADDITION" and effect.target == "ALL_TOWERS" then
      tower.stats[effect.stat] = tower.stats[effect.stat] + effect.addition
    elseif effect.type == "COST_MULTIPLIER" then
      tower.cost = tower.cost * effect.multiplier
    end
  end
  
  return tower
end
-- }}}
```

### Multiplayer Synchronization
```lua
-- {{{ MultiplayerUpgrades
local MultiplayerUpgrades = {}

-- {{{ generateSharedOptions
function MultiplayerUpgrades:generateSharedOptions(wave, seed)
  -- Use deterministic seed for all players
  math.randomseed(seed)
  
  local options = UpgradeManager:generateUpgradeOptions(nil, 
    UpgradeDefinitions:loadUpgradeDefinitions())
  
  -- Reset random seed
  math.randomseed(os.time())
  
  return options
end
-- }}}

-- {{{ syncUpgradeChoices
function MultiplayerUpgrades:syncUpgradeChoices(choices)
  -- Wait for all players to make their choices
  local allChoices = {}
  
  for playerId, choice in pairs(choices) do
    allChoices[playerId] = choice
    UpgradeManager:applyUpgrade(playerId, choice.upgradeId)
  end
  
  return allChoices
end
-- }}}
```

### UI Integration
```lua
-- {{{ UpgradeUI
local UpgradeUI = {}

-- {{{ showUpgradeSelection
function UpgradeUI:showUpgradeSelection(options)
  -- Display upgrade options to player
  self:clearScreen()
  self:drawTitle("Choose Your Upgrade")
  
  for i, upgrade in ipairs(options) do
    self:drawUpgradeOption(i, upgrade)
  end
  
  self:drawInstructions("Press 1-3 to select upgrade")
  
  return self:waitForUpgradeChoice(#options)
end
-- }}}

-- {{{ drawUpgradeOption
function UpgradeUI:drawUpgradeOption(index, upgrade)
  local y = 5 + index * 4
  
  -- Draw option number and name
  self:drawText(2, y, string.format("%d. %s", index, upgrade.name))
  
  -- Draw description
  self:drawText(4, y + 1, upgrade.description)
  
  -- Draw category
  self:drawText(4, y + 2, "Category: " .. upgrade.category)
end
-- }}}
```

## Acceptance Criteria

- [ ] Upgrade opportunity appears every 5 waves
- [ ] Minimum 20 different upgrade types available
- [ ] 3 random options presented each time
- [ ] Upgrades apply correctly to towers and gameplay
- [ ] Statistical upgrades modify tower stats properly
- [ ] Economic upgrades affect resource generation
- [ ] Special abilities unlock new mechanics
- [ ] Synergy effects create strategic combinations
- [ ] All players see same options in multiplayer
- [ ] Upgrade choices synchronized across players
- [ ] UI clearly displays upgrade options and effects
- [ ] Player upgrade history tracked correctly

## Technical Notes

### Balance Considerations
- Upgrades should provide meaningful choices
- No single upgrade should be dominant strategy
- Synergies encourage diverse upgrade paths
- Economic upgrades balanced against combat upgrades

### Performance Requirements
- Upgrade application < 10ms
- UI rendering < 16ms
- Effect calculations < 1ms per tower

## Test Cases

1. **Upgrade Availability**
   - Correct timing (every 5 waves)
   - Random option generation
   - Available upgrade filtering

2. **Upgrade Effects**
   - Stat modifications work correctly
   - Economic effects apply properly
   - Special abilities function as expected

3. **Multiplayer Sync**
   - Same options for all players
   - Choice synchronization
   - Effect application consistency

4. **UI Functionality**
   - Clear option display
   - Correct choice handling
   - Effect feedback

## Integration Points

- **Game Engine**: Wave tracking and effect application
- **Combat System**: Stat modifications and special abilities
- **Resource System**: Economic upgrade effects
- **Multiplayer**: Choice synchronization

## Future Considerations

- Additional upgrade categories
- Upgrade tree dependencies
- Player-specific upgrade pools
- Achievement-based unlock system