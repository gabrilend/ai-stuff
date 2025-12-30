# Issue 408c: Unit Tests - Player Systems

**Phase:** 4 - Runtime
**Type:** Test
**Priority:** High
**Dependencies:** 408a (core system tests), 406 (resources), 407 (player state)

---

## Current Behavior

No unit tests exist for player-related runtime systems: resource management and player state. These systems track gold, lumber, food, alliances, and victory conditions.

---

## Intended Behavior

Comprehensive unit tests for:
- **Resources (406):** Gold/lumber storage, spending validation, food/supply limits
- **Player State (407):** Player data, alliances, victory conditions, slot management

Tests should verify correct WC3-style resource mechanics and player interactions.

---

## Suggested Implementation Steps

1. **Create test file**
   ```
   src/tests/
   └── test_phase4_player.lua
   ```

2. **Implement resource initialization test**
   ```lua
   function test_resource_init()
       local resources = require("runtime.resources")

       resources.init()

       -- Set starting resources for player 0
       resources.set(0, "gold", 500)
       resources.set(0, "lumber", 150)

       local gold = resources.get(0, "gold")
       local lumber = resources.get(0, "lumber")

       assert(gold == 500, "Gold should be 500, got " .. gold)
       assert(lumber == 150, "Lumber should be 150, got " .. lumber)

       resources.shutdown()
   end
   ```

3. **Implement resource spending test**
   ```lua
   function test_resource_spending()
       local resources = require("runtime.resources")

       resources.init()
       resources.set(0, "gold", 500)
       resources.set(0, "lumber", 150)

       -- Try to spend valid amount
       local success = resources.spend(0, {gold = 100, lumber = 50})
       assert(success, "Should be able to spend 100 gold and 50 lumber")

       local gold = resources.get(0, "gold")
       local lumber = resources.get(0, "lumber")
       assert(gold == 400, "Gold should be 400 after spending")
       assert(lumber == 100, "Lumber should be 100 after spending")

       -- Try to spend more than available
       local fail = resources.spend(0, {gold = 1000})
       assert(not fail, "Should not be able to spend more than available")

       -- Verify resources unchanged after failed spend
       assert(resources.get(0, "gold") == 400, "Gold unchanged after failed spend")

       resources.shutdown()
   end
   ```

4. **Implement resource add/check test**
   ```lua
   function test_resource_add_and_check()
       local resources = require("runtime.resources")

       resources.init()
       resources.set(0, "gold", 100)

       -- Add resources
       resources.add(0, "gold", 250)
       assert(resources.get(0, "gold") == 350, "Gold should be 350 after adding")

       -- Check affordability
       local can_afford = resources.can_afford(0, {gold = 300})
       assert(can_afford, "Should be able to afford 300 gold")

       local cannot_afford = resources.can_afford(0, {gold = 400})
       assert(not cannot_afford, "Should not be able to afford 400 gold")

       resources.shutdown()
   end
   ```

5. **Implement food/supply test**
   ```lua
   function test_food_supply()
       local resources = require("runtime.resources")

       resources.init()

       -- Set food used and supply cap
       resources.set_food(0, 5)      -- 5 food used
       resources.set_supply(0, 10)   -- 10 supply cap

       assert(resources.get_food(0) == 5, "Food used should be 5")
       assert(resources.get_supply(0) == 10, "Supply cap should be 10")

       -- Check if can train (uses food)
       local can_train = resources.can_use_food(0, 3)  -- Need 3 food
       assert(can_train, "Should be able to use 3 food (5+3 <= 10)")

       local cannot_train = resources.can_use_food(0, 6)  -- Need 6 food
       assert(not cannot_train, "Should not be able to use 6 food (5+6 > 10)")

       -- Use food
       resources.use_food(0, 3)
       assert(resources.get_food(0) == 8, "Food used should be 8")

       -- Free food (unit dies)
       resources.free_food(0, 2)
       assert(resources.get_food(0) == 6, "Food used should be 6 after freeing")

       resources.shutdown()
   end
   ```

6. **Implement player state initialization test**
   ```lua
   function test_player_init()
       local player = require("runtime.player")

       player.init()

       -- Configure player slots
       player.set_slot(0, {
           type = "human",
           race = "human",
           team = 0,
           start_location = 0,
           name = "Player 1",
           color = 0,  -- Red
       })

       player.set_slot(1, {
           type = "computer",
           race = "orc",
           team = 1,
           start_location = 1,
           name = "Computer",
           color = 1,  -- Blue
       })

       local p0 = player.get(0)
       assert(p0, "Player 0 should exist")
       assert(p0.type == "human", "Player 0 should be human")
       assert(p0.race == "human", "Player 0 race should be human")

       local p1 = player.get(1)
       assert(p1.type == "computer", "Player 1 should be computer")
       assert(p1.race == "orc", "Player 1 race should be orc")

       player.shutdown()
   end
   ```

7. **Implement alliance test**
   ```lua
   function test_player_alliances()
       local player = require("runtime.player")

       player.init()

       -- Set up two players
       player.set_slot(0, {type = "human", team = 0})
       player.set_slot(1, {type = "human", team = 1})
       player.set_slot(2, {type = "human", team = 0})  -- Same team as player 0

       -- Default alliances (same team = allied)
       player.compute_default_alliances()

       -- Check alliance states
       assert(player.is_ally(0, 2), "Players 0 and 2 should be allies (same team)")
       assert(player.is_enemy(0, 1), "Players 0 and 1 should be enemies")

       -- Manually set alliance
       player.set_alliance(0, 1, "passive")  -- Player 0 won't attack player 1
       assert(player.get_alliance(0, 1) == "passive", "Alliance should be passive")

       -- Note: Passive is one-way in WC3
       assert(player.is_enemy(1, 0), "Player 1 should still consider 0 enemy")

       player.shutdown()
   end
   ```

8. **Implement player state transitions test**
   ```lua
   function test_player_state_transitions()
       local player = require("runtime.player")

       player.init()
       player.set_slot(0, {type = "human"})

       -- Initial state
       assert(player.get_state(0) == "playing", "Initial state should be 'playing'")

       -- Player leaves
       player.set_state(0, "left")
       assert(player.get_state(0) == "left", "State should be 'left'")

       -- Check if slot is active
       assert(not player.is_active(0), "Left player should not be active")

       -- Defeat player
       player.set_slot(1, {type = "human"})
       player.set_state(1, "defeated")
       assert(player.get_state(1) == "defeated", "State should be 'defeated'")

       -- Victory
       player.set_slot(2, {type = "human"})
       player.set_state(2, "victorious")
       assert(player.get_state(2) == "victorious", "State should be 'victorious'")

       player.shutdown()
   end
   ```

9. **Implement player queries test**
   ```lua
   function test_player_queries()
       local player = require("runtime.player")

       player.init()

       -- Set up multiple players
       player.set_slot(0, {type = "human", race = "human", team = 0})
       player.set_slot(1, {type = "computer", race = "orc", team = 1})
       player.set_slot(2, {type = "human", race = "nightelf", team = 0})
       player.set_slot(3, {type = "neutral", race = "neutral"})

       -- Query by type
       local humans = player.get_by_type("human")
       assert(#humans == 2, "Should find 2 human players")

       local computers = player.get_by_type("computer")
       assert(#computers == 1, "Should find 1 computer player")

       -- Query by team
       local team0 = player.get_by_team(0)
       assert(#team0 == 2, "Should find 2 players on team 0")

       -- Query active players
       player.set_state(2, "left")
       local active = player.get_active()
       assert(#active == 2, "Should find 2 active players (0, 1)")

       -- Get all (excluding neutral by default)
       local all_players = player.get_all()
       assert(#all_players == 3, "Should find 3 non-neutral players")

       player.shutdown()
   end
   ```

10. **Implement victory condition test**
    ```lua
    function test_victory_conditions()
        local player = require("runtime.player")

        player.init()

        -- Set up melee game (2 teams)
        player.set_slot(0, {type = "human", team = 0})
        player.set_slot(1, {type = "human", team = 0})
        player.set_slot(2, {type = "computer", team = 1})
        player.set_slot(3, {type = "computer", team = 1})

        -- Check initial state
        local winner = player.check_victory()
        assert(winner == nil, "No winner yet")

        -- Defeat one player from team 1
        player.set_state(2, "defeated")
        winner = player.check_victory()
        assert(winner == nil, "Still no winner (team 1 has player 3)")

        -- Defeat last player from team 1
        player.set_state(3, "defeated")
        winner = player.check_victory()
        assert(winner == 0, "Team 0 should win (first player on team)")

        -- Mark victory for winning team
        player.apply_victory(0)  -- Team 0 wins
        assert(player.get_state(0) == "victorious", "Player 0 should be victorious")
        assert(player.get_state(1) == "victorious", "Player 1 should be victorious")

        player.shutdown()
    end
    ```

11. **Create test runner**
    ```lua
    local function run_tests()
        local tests = {
            {"Resource init", test_resource_init},
            {"Resource spending", test_resource_spending},
            {"Resource add/check", test_resource_add_and_check},
            {"Food/supply", test_food_supply},
            {"Player init", test_player_init},
            {"Player alliances", test_player_alliances},
            {"Player state transitions", test_player_state_transitions},
            {"Player queries", test_player_queries},
            {"Victory conditions", test_victory_conditions},
        }

        local passed = 0
        local failed = 0

        for _, test in ipairs(tests) do
            local name, fn = test[1], test[2]
            local ok, err = pcall(fn)
            if ok then
                print("PASS: " .. name)
                passed = passed + 1
            else
                print("FAIL: " .. name)
                print("  " .. tostring(err))
                failed = failed + 1
            end
        end

        print(string.format("\n%d/%d tests passed", passed, passed + failed))
        return failed == 0
    end

    if not run_tests() then os.exit(1) end
    ```

---

## Related Documents

- issues/408-phase-4-integration-test.md (parent issue)
- issues/408a-unit-tests-core-systems.md (prerequisite)
- issues/408b-unit-tests-entity-systems.md (sibling - can run in parallel)
- issues/406-implement-resource-system.md
- issues/407-implement-player-state-management.md

---

## Acceptance Criteria

- [ ] Resource initialization test passes
- [ ] Resource spending test passes (valid/invalid amounts)
- [ ] Resource add/check test passes (affordability checks)
- [ ] Food/supply test passes (WC3-style population mechanics)
- [ ] Player initialization test passes (slot configuration)
- [ ] Alliance test passes (same team, enemy, passive)
- [ ] Player state transitions test passes (playing/left/defeated/victorious)
- [ ] Player queries test passes (by type, team, active status)
- [ ] Victory condition test passes (team elimination detection)
- [ ] All tests complete in under 2 seconds

---

## Notes

Player systems are mostly independent of ECS - they track metadata about players rather than in-game entities. Resources attach to player slots, not entities.

WC3-specific considerations:
- 12 player slots (0-11), with slot 12+ reserved for neutral
- Food/supply capped at 100 in standard melee
- Alliances can be asymmetric (A allies B, but B enemies A)
- Victory requires eliminating all buildings of enemy teams (melee rules)

Resource types in WC3:
- Gold (PLAYER_STATE_RESOURCE_GOLD)
- Lumber (PLAYER_STATE_RESOURCE_LUMBER)
- Food used (PLAYER_STATE_RESOURCE_FOOD_USED)
- Food cap (PLAYER_STATE_RESOURCE_FOOD_CAP)

