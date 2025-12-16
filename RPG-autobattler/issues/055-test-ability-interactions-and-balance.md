# Issue #414: Test Ability Interactions and Balance

## Current Behavior
Individual ability systems exist but lack comprehensive testing framework and balance validation to ensure fair and engaging gameplay.

## Intended Behavior
Implement thorough testing and balance validation system that verifies ability interactions, performance metrics, and gameplay balance across all ability combinations.

## Implementation Details

### Ability Testing Framework (src/testing/ability_test_framework.lua)
```lua
-- {{{ AbilityTestFramework
local AbilityTestFramework = {}
AbilityTestFramework.__index = AbilityTestFramework

function AbilityTestFramework:new()
    local framework = {
        -- Test scenarios
        test_scenarios = {},
        test_results = {},
        
        -- Mock entities and systems
        mock_entity_manager = nil,
        mock_targeting_system = nil,
        mock_effect_system = nil,
        
        -- Test metrics
        performance_metrics = {},
        balance_metrics = {},
        interaction_matrix = {},
        
        -- Test configurations
        test_unit_configs = {},
        test_environments = {},
        
        -- Results tracking
        test_session_id = 1,
        current_test_batch = nil
    }
    setmetatable(framework, self)
    return framework
end
-- }}}

-- {{{ function AbilityTestFramework:create_test_scenario
function AbilityTestFramework:create_test_scenario(scenario_name, config)
    local scenario = {
        name = scenario_name,
        description = config.description,
        
        -- Test setup
        unit_setups = config.unit_setups or {},
        map_config = config.map_config or self:get_default_map(),
        duration = config.duration or 30, -- seconds
        
        -- Victory conditions
        victory_conditions = config.victory_conditions or {},
        
        -- Metrics to track
        tracked_metrics = config.tracked_metrics or {
            "damage_dealt", "healing_done", "abilities_used", 
            "mana_efficiency", "survival_time"
        },
        
        -- Expected outcomes
        expected_results = config.expected_results or {},
        balance_thresholds = config.balance_thresholds or {}
    }
    
    self.test_scenarios[scenario_name] = scenario
    return scenario
end
-- }}}

-- {{{ function AbilityTestFramework:create_balance_test_suite
function AbilityTestFramework:create_balance_test_suite()
    -- DPS vs Healing balance test
    self:create_test_scenario("dps_vs_healing_balance", {
        description = "Test if healing can keep up with damage output",
        unit_setups = {
            team_a = {
                {unit_type = "melee", abilities = {"primary_melee_attack", "power_strike"}, count = 3}
            },
            team_b = {
                {unit_type = "melee", abilities = {"primary_melee_attack"}, count = 2},
                {unit_type = "healer", abilities = {"primary_melee_attack", "basic_heal"}, count = 1}
            }
        },
        duration = 60,
        expected_results = {
            team_balance_ratio = {min = 0.4, max = 0.6}, -- Neither team should have >60% win rate
            average_battle_duration = {min = 20, max = 40}
        }
    })
    
    -- Mana efficiency test
    self:create_test_scenario("mana_efficiency_test", {
        description = "Validate mana generation and consumption rates",
        unit_setups = {
            team_a = {
                {unit_type = "ranged", abilities = {"primary_ranged_attack", "piercing_shot"}, count = 5}
            },
            team_b = {
                {unit_type = "melee", abilities = {"primary_melee_attack", "power_strike"}, count = 5}
            }
        },
        tracked_metrics = {"mana_generation_rate", "mana_waste", "ability_usage_frequency"},
        expected_results = {
            mana_waste_percentage = {max = 15}, -- <15% mana should be wasted
            ability_usage_frequency = {min = 0.3, max = 0.8} -- Abilities should fire regularly but not spam
        }
    })
    
    -- AoE vs Single-target balance
    self:create_test_scenario("aoe_vs_single_target_balance", {
        description = "Test area abilities vs single-target in various group sizes",
        unit_setups = {
            team_a = {
                {unit_type = "mage", abilities = {"primary_ranged_attack", "meteor_strike"}, count = 2}
            },
            team_b = {
                {unit_type = "archer", abilities = {"primary_ranged_attack", "piercing_shot"}, count = 2}
            }
        },
        expected_results = {
            damage_per_mana_efficiency = {ratio_tolerance = 0.2}, -- AoE should be ~20% more efficient with groups
        }
    })
    
    -- Buff/Debuff impact test
    self:create_test_scenario("buff_debuff_impact_test", {
        description = "Measure impact of buffs and debuffs on combat outcomes",
        unit_setups = {
            team_a = {
                {unit_type = "melee", abilities = {"primary_melee_attack"}, count = 3}
            },
            team_b = {
                {unit_type = "melee", abilities = {"primary_melee_attack"}, count = 2},
                {unit_type = "support", abilities = {"primary_melee_attack", "battle_fury"}, count = 1}
            }
        },
        expected_results = {
            buff_impact_factor = {min = 1.15, max = 1.4}, -- Buffs should provide 15-40% advantage
            battle_duration_variance = {max = 50} -- Results shouldn't be too random
        }
    })
end
-- }}}

-- {{{ function AbilityTestFramework:run_test_scenario
function AbilityTestFramework:run_test_scenario(scenario_name, iterations)
    local scenario = self.test_scenarios[scenario_name]
    if not scenario then
        error("Unknown test scenario: " .. tostring(scenario_name))
    end
    
    local results = {
        scenario_name = scenario_name,
        iterations = iterations or 10,
        individual_results = {},
        aggregate_metrics = {},
        balance_assessment = {},
        timestamp = love.timer.getTime()
    }
    
    -- Run multiple iterations for statistical significance
    for i = 1, results.iterations do
        local iteration_result = self:run_single_iteration(scenario, i)
        table.insert(results.individual_results, iteration_result)
    end
    
    -- Aggregate results
    results.aggregate_metrics = self:aggregate_test_results(results.individual_results)
    
    -- Assess balance
    results.balance_assessment = self:assess_balance(results.aggregate_metrics, scenario.expected_results)
    
    self.test_results[scenario_name] = results
    return results
end
-- }}}

-- {{{ function AbilityTestFramework:run_single_iteration
function AbilityTestFramework:run_single_iteration(scenario, iteration_number)
    -- Set up test environment
    local test_env = self:create_test_environment(scenario)
    
    -- Create units according to scenario setup
    local units = self:create_test_units(scenario.unit_setups, test_env)
    
    -- Run simulation
    local simulation_result = self:run_combat_simulation(test_env, units, scenario.duration)
    
    -- Collect metrics
    local metrics = self:collect_test_metrics(simulation_result, scenario.tracked_metrics)
    
    return {
        iteration = iteration_number,
        winner = simulation_result.winner,
        duration = simulation_result.duration,
        metrics = metrics,
        events = simulation_result.events
    }
end
-- }}}

-- {{{ function AbilityTestFramework:create_test_environment
function AbilityTestFramework:create_test_environment(scenario)
    -- Create mock systems for testing
    local entity_manager = MockEntityManager:new()
    local targeting_system = MockTargetingSystem:new()
    local effect_system = MockEffectSystem:new()
    local ability_activation_system = MockAbilityActivationSystem:new()
    
    -- Set up test map
    local map_config = scenario.map_config
    -- Map setup would go here
    
    return {
        entity_manager = entity_manager,
        targeting_system = targeting_system,
        effect_system = effect_system,
        ability_activation_system = ability_activation_system,
        map = map_config,
        time = 0,
        events = {}
    }
end
-- }}}

-- {{{ function AbilityTestFramework:create_test_units
function AbilityTestFramework:create_test_units(unit_setups, test_env)
    local all_units = {}
    
    for team_name, team_setup in pairs(unit_setups) do
        local team_id = team_name == "team_a" and 1 or 2
        local team_units = {}
        
        for _, unit_config in ipairs(team_setup) do
            for i = 1, (unit_config.count or 1) do
                local unit = self:create_test_unit(unit_config, team_id, test_env)
                table.insert(team_units, unit)
                table.insert(all_units, unit)
            end
        end
        
        all_units[team_name] = team_units
    end
    
    return all_units
end
-- }}}

-- {{{ function AbilityTestFramework:create_test_unit
function AbilityTestFramework:create_test_unit(unit_config, team_id, test_env)
    local entity_id = test_env.entity_manager:create_entity()
    
    -- Add basic components
    test_env.entity_manager:add_component(entity_id, "position", {
        value = self:get_spawn_position(team_id)
    })
    
    test_env.entity_manager:add_component(entity_id, "health", {
        current = 100,
        max = 100
    })
    
    test_env.entity_manager:add_component(entity_id, "team", {
        value = team_id
    })
    
    test_env.entity_manager:add_component(entity_id, "unit", {
        unit_type = unit_config.unit_type,
        stats = unit_config.stats or {},
        active_buffs = {}
    })
    
    -- Add abilities
    if unit_config.abilities then
        local abilities = self:create_test_abilities(unit_config.abilities)
        test_env.entity_manager:add_component(entity_id, "abilities", abilities)
    end
    
    return {
        id = entity_id,
        config = unit_config,
        team = team_id
    }
end
-- }}}

-- {{{ function AbilityTestFramework:run_combat_simulation
function AbilityTestFramework:run_combat_simulation(test_env, units, max_duration)
    local dt = 0.1 -- 100ms time steps
    local total_time = 0
    local events = {}
    
    while total_time < max_duration do
        -- Update all systems
        test_env.ability_activation_system:update(dt, test_env.entity_manager)
        test_env.effect_system:update(dt)
        
        -- Check for victory conditions
        local winner = self:check_victory_conditions(test_env, units)
        if winner then
            return {
                winner = winner,
                duration = total_time,
                events = events,
                final_state = self:capture_final_state(test_env, units)
            }
        end
        
        -- Record significant events
        self:record_simulation_events(test_env, events, total_time)
        
        total_time = total_time + dt
    end
    
    -- Timeout - determine winner by remaining health
    local winner = self:determine_winner_by_health(test_env, units)
    
    return {
        winner = winner,
        duration = total_time,
        events = events,
        timeout = true,
        final_state = self:capture_final_state(test_env, units)
    }
end
-- }}}

-- {{{ function AbilityTestFramework:collect_test_metrics
function AbilityTestFramework:collect_test_metrics(simulation_result, tracked_metrics)
    local metrics = {}
    
    for _, metric_name in ipairs(tracked_metrics) do
        if metric_name == "damage_dealt" then
            metrics.damage_dealt = self:calculate_total_damage_dealt(simulation_result)
        elseif metric_name == "healing_done" then
            metrics.healing_done = self:calculate_total_healing_done(simulation_result)
        elseif metric_name == "abilities_used" then
            metrics.abilities_used = self:count_abilities_used(simulation_result)
        elseif metric_name == "mana_efficiency" then
            metrics.mana_efficiency = self:calculate_mana_efficiency(simulation_result)
        elseif metric_name == "survival_time" then
            metrics.survival_time = self:calculate_average_survival_time(simulation_result)
        end
    end
    
    return metrics
end
-- }}}

-- {{{ function AbilityTestFramework:aggregate_test_results
function AbilityTestFramework:aggregate_test_results(individual_results)
    local aggregated = {
        total_iterations = #individual_results,
        team_a_wins = 0,
        team_b_wins = 0,
        draws = 0,
        average_duration = 0,
        metrics = {}
    }
    
    -- Count wins and calculate averages
    local total_duration = 0
    local metric_sums = {}
    
    for _, result in ipairs(individual_results) do
        if result.winner == 1 then
            aggregated.team_a_wins = aggregated.team_a_wins + 1
        elseif result.winner == 2 then
            aggregated.team_b_wins = aggregated.team_b_wins + 1
        else
            aggregated.draws = aggregated.draws + 1
        end
        
        total_duration = total_duration + result.duration
        
        for metric_name, metric_value in pairs(result.metrics) do
            metric_sums[metric_name] = (metric_sums[metric_name] or 0) + metric_value
        end
    end
    
    aggregated.average_duration = total_duration / #individual_results
    
    -- Calculate win rates
    aggregated.team_a_win_rate = aggregated.team_a_wins / #individual_results
    aggregated.team_b_win_rate = aggregated.team_b_wins / #individual_results
    aggregated.draw_rate = aggregated.draws / #individual_results
    
    -- Average metrics
    for metric_name, metric_sum in pairs(metric_sums) do
        aggregated.metrics[metric_name] = metric_sum / #individual_results
    end
    
    return aggregated
end
-- }}}

-- {{{ function AbilityTestFramework:assess_balance
function AbilityTestFramework:assess_balance(aggregated_metrics, expected_results)
    local assessment = {
        overall_balance = "unknown",
        issues_found = {},
        recommendations = {},
        balance_score = 0
    }
    
    local balance_points = 0
    local total_checks = 0
    
    -- Check win rate balance
    total_checks = total_checks + 1
    local win_rate_balance = math.abs(aggregated_metrics.team_a_win_rate - 0.5)
    if win_rate_balance <= 0.1 then -- Within 10% of 50/50
        balance_points = balance_points + 1
    else
        table.insert(assessment.issues_found, "Win rates unbalanced: " .. 
                    string.format("%.1f%% vs %.1f%%", 
                                  aggregated_metrics.team_a_win_rate * 100,
                                  aggregated_metrics.team_b_win_rate * 100))
    end
    
    -- Check expected results
    for expected_metric, expected_range in pairs(expected_results) do
        total_checks = total_checks + 1
        local actual_value = aggregated_metrics.metrics[expected_metric]
        
        if actual_value then
            local in_range = true
            
            if expected_range.min and actual_value < expected_range.min then
                in_range = false
                table.insert(assessment.issues_found, 
                            string.format("%s too low: %.2f (expected >= %.2f)", 
                                          expected_metric, actual_value, expected_range.min))
            end
            
            if expected_range.max and actual_value > expected_range.max then
                in_range = false
                table.insert(assessment.issues_found, 
                            string.format("%s too high: %.2f (expected <= %.2f)", 
                                          expected_metric, actual_value, expected_range.max))
            end
            
            if in_range then
                balance_points = balance_points + 1
            end
        end
    end
    
    -- Calculate balance score
    assessment.balance_score = balance_points / total_checks
    
    -- Determine overall balance
    if assessment.balance_score >= 0.9 then
        assessment.overall_balance = "excellent"
    elseif assessment.balance_score >= 0.7 then
        assessment.overall_balance = "good"
    elseif assessment.balance_score >= 0.5 then
        assessment.overall_balance = "acceptable"
    else
        assessment.overall_balance = "poor"
    end
    
    -- Generate recommendations
    self:generate_balance_recommendations(assessment, aggregated_metrics, expected_results)
    
    return assessment
end
-- }}}

-- {{{ function AbilityTestFramework:generate_balance_recommendations
function AbilityTestFramework:generate_balance_recommendations(assessment, metrics, expected)
    local recommendations = assessment.recommendations
    
    -- Win rate recommendations
    if math.abs(metrics.team_a_win_rate - 0.5) > 0.15 then
        if metrics.team_a_win_rate > 0.6 then
            table.insert(recommendations, "Consider nerfing team A abilities or buffing team B")
        else
            table.insert(recommendations, "Consider buffing team A abilities or nerfing team B")
        end
    end
    
    -- Mana efficiency recommendations
    if metrics.metrics.mana_efficiency and metrics.metrics.mana_efficiency < 0.7 then
        table.insert(recommendations, "Mana efficiency is low - consider increasing generation rates or reducing costs")
    end
    
    -- Ability usage frequency recommendations
    if metrics.metrics.ability_usage_frequency then
        if metrics.metrics.ability_usage_frequency < 0.3 then
            table.insert(recommendations, "Abilities fire too rarely - consider faster mana generation")
        elseif metrics.metrics.ability_usage_frequency > 0.8 then
            table.insert(recommendations, "Abilities fire too frequently - consider slower generation or higher costs")
        end
    end
end
-- }}}

return AbilityTestFramework
```

### Performance Testing System (src/testing/ability_performance_tests.lua)
```lua
-- {{{ AbilityPerformanceTests
local AbilityPerformanceTests = {}

-- {{{ function AbilityPerformanceTests:run_performance_suite
function AbilityPerformanceTests:run_performance_suite()
    local results = {}
    
    -- Test individual ability activation performance
    results.single_ability_activation = self:test_single_ability_performance()
    
    -- Test multiple simultaneous abilities
    results.multiple_abilities = self:test_multiple_ability_performance()
    
    -- Test with many units
    results.large_scale = self:test_large_scale_performance()
    
    -- Test memory usage
    results.memory_usage = self:test_memory_usage()
    
    return results
end
-- }}}

-- {{{ function AbilityPerformanceTests:test_single_ability_performance
function AbilityPerformanceTests:test_single_ability_performance()
    local start_time = love.timer.getTime()
    local iterations = 1000
    
    for i = 1, iterations do
        -- Simulate single ability activation
        local ability = self:create_test_ability("primary_melee_attack")
        ability:update_mana(0.1, self:create_mock_unit_state(), {})
        
        if ability:get_mana_percentage() >= 1.0 then
            ability:consume_mana(100)
        end
    end
    
    local end_time = love.timer.getTime()
    local duration = end_time - start_time
    
    return {
        iterations = iterations,
        total_time = duration,
        time_per_activation = duration / iterations,
        activations_per_second = iterations / duration
    }
end
-- }}}

-- {{{ function AbilityPerformanceTests:test_large_scale_performance
function AbilityPerformanceTests:test_large_scale_performance()
    local unit_counts = {50, 100, 200, 500}
    local results = {}
    
    for _, unit_count in ipairs(unit_counts) do
        local start_time = love.timer.getTime()
        
        -- Create test scenario with many units
        local test_env = self:create_large_scale_test(unit_count)
        
        -- Run for 10 seconds of simulation time
        for i = 1, 100 do -- 100 * 0.1s = 10s
            test_env.ability_system:update(0.1)
        end
        
        local end_time = love.timer.getTime()
        
        results[unit_count] = {
            unit_count = unit_count,
            simulation_time = 10, -- seconds
            real_time = end_time - start_time,
            performance_ratio = 10 / (end_time - start_time),
            fps_equivalent = 100 / (end_time - start_time)
        }
    end
    
    return results
end
-- }}}

return AbilityPerformanceTests
```

### Balance Validation Reports (src/testing/balance_reports.lua)
```lua
-- {{{ BalanceReports
local BalanceReports = {}

-- {{{ function BalanceReports:generate_comprehensive_report
function BalanceReports:generate_comprehensive_report(test_results)
    local report = {
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        executive_summary = {},
        detailed_analysis = {},
        recommendations = {},
        balance_matrix = {}
    }
    
    -- Generate executive summary
    report.executive_summary = self:generate_executive_summary(test_results)
    
    -- Detailed analysis for each ability type
    report.detailed_analysis = self:generate_detailed_analysis(test_results)
    
    -- Balance recommendations
    report.recommendations = self:generate_recommendations(test_results)
    
    -- Ability interaction matrix
    report.balance_matrix = self:generate_balance_matrix(test_results)
    
    return report
end
-- }}}

-- {{{ function BalanceReports:export_to_markdown
function BalanceReports:export_to_markdown(report)
    local markdown = {}
    
    table.insert(markdown, "# Ability Balance Report")
    table.insert(markdown, "")
    table.insert(markdown, "Generated: " .. report.timestamp)
    table.insert(markdown, "")
    
    -- Executive Summary
    table.insert(markdown, "## Executive Summary")
    table.insert(markdown, "")
    for _, summary_point in ipairs(report.executive_summary) do
        table.insert(markdown, "- " .. summary_point)
    end
    table.insert(markdown, "")
    
    -- Detailed Analysis
    table.insert(markdown, "## Detailed Analysis")
    table.insert(markdown, "")
    for analysis_type, analysis_data in pairs(report.detailed_analysis) do
        table.insert(markdown, "### " .. analysis_type)
        table.insert(markdown, "")
        table.insert(markdown, analysis_data.description)
        table.insert(markdown, "")
        
        if analysis_data.metrics then
            table.insert(markdown, "**Metrics:**")
            for metric_name, metric_value in pairs(analysis_data.metrics) do
                table.insert(markdown, string.format("- %s: %.2f", metric_name, metric_value))
            end
            table.insert(markdown, "")
        end
    end
    
    -- Recommendations
    table.insert(markdown, "## Recommendations")
    table.insert(markdown, "")
    for _, recommendation in ipairs(report.recommendations) do
        table.insert(markdown, "- " .. recommendation)
    end
    
    return table.concat(markdown, "\n")
end
-- }}}

return BalanceReports
```

### Integration with Existing Systems
```lua
-- Add to main game loop for development builds
-- {{{ function GameSystem:run_balance_tests
function GameSystem:run_balance_tests()
    if DEBUG_MODE then
        local test_framework = AbilityTestFramework:new()
        test_framework:create_balance_test_suite()
        
        local results = {}
        for scenario_name, _ in pairs(test_framework.test_scenarios) do
            results[scenario_name] = test_framework:run_test_scenario(scenario_name, 20)
        end
        
        -- Generate report
        local balance_reports = BalanceReports:new()
        local report = balance_reports:generate_comprehensive_report(results)
        local markdown = balance_reports:export_to_markdown(report)
        
        -- Save report
        love.filesystem.write("balance_report.md", markdown)
        print("Balance report saved to balance_report.md")
        
        return results
    end
end
-- }}}
```

### Acceptance Criteria
- [ ] Comprehensive test framework validates all ability types and interactions
- [ ] Balance testing ensures no single strategy dominates gameplay
- [ ] Performance testing confirms system scales to 100+ units with abilities
- [ ] Statistical analysis provides confidence in balance measurements
- [ ] Automated testing can run during development builds
- [ ] Test results generate actionable balance recommendations
- [ ] Integration testing validates ability interactions work correctly
- [ ] Memory and performance profiling identifies optimization opportunities
- [ ] Test framework supports easy addition of new test scenarios
- [ ] Balance reports provide clear insights for game design decisions