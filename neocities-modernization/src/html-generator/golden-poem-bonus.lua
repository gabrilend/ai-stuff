#!/usr/bin/env lua

-- Golden Poem Similarity Bonus System
-- Implements configurable bonus scoring for golden poems in similarity calculations

package.path = package.path .. ';./?.lua;./libs/?.lua'

local utils = require("libs.utils")
local json = require("libs.json")

local M = {}
local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

M.config = nil

-- {{{ function M.get_default_golden_poem_config
function M.get_default_golden_poem_config()
    return {
        -- Similarity bonus when both poems are golden
        golden_poem_pair_bonus = 0.05,
        
        -- Similarity bonus when one poem is golden  
        golden_poem_single_bonus = 0.02,
        
        -- Minimum golden poems in Top-N recommendations
        min_golden_recommendations = 2,
        
        -- Maximum golden poems in Top-N recommendations (prevent dominance)
        max_golden_recommendations = 5,
        
        -- Enable/disable golden poem prioritization
        enable_golden_prioritization = true,
        
        -- Threshold for applying bonuses (minimum base similarity)
        golden_bonus_threshold = 0.1
    }
end
-- }}}

-- {{{ function M.load_golden_poem_config
function M.load_golden_poem_config(config_file)
    config_file = config_file or (DIR .. "/config/golden-poem-settings.json")
    
    if utils.file_exists(config_file) then
        local config_json = utils.read_file(config_file)
        local config = json.decode(config_json)
        utils.log_info("Loaded golden poem config: " .. config_file)
        return config
    else
        -- Return defaults and create config file
        local default_config = M.get_default_golden_poem_config()
        utils.write_file(config_file, json.encode(default_config))
        utils.log_info("Created default golden poem config: " .. config_file)
        return default_config
    end
end
-- }}}

-- {{{ function M.get_config
function M.get_config()
    if not M.config then
        M.config = M.load_golden_poem_config()
    end
    return M.config
end
-- }}}

-- {{{ function M.calculate_similarity_with_golden_bonus
function M.calculate_similarity_with_golden_bonus(poem_a, poem_b, base_similarity, config)
    config = config or M.get_config()
    
    if not config.enable_golden_prioritization then
        return base_similarity, 0
    end
    
    if base_similarity < config.golden_bonus_threshold then
        return base_similarity, 0
    end
    
    local bonus = 0
    
    -- Both poems are golden - highest bonus
    if poem_a.is_fediverse_golden and poem_b.is_fediverse_golden then
        bonus = config.golden_poem_pair_bonus or 0.05
        -- Debug logging (commented out for performance)
        -- utils.log_info(string.format("Golden pair bonus: +%.3f", bonus))
    -- One poem is golden - moderate bonus
    elseif poem_a.is_fediverse_golden or poem_b.is_fediverse_golden then
        bonus = config.golden_poem_single_bonus or 0.02
        -- Debug logging (commented out for performance)
        -- utils.log_info(string.format("Golden single bonus: +%.3f", bonus))
    end
    
    -- Apply bonus and ensure we don't exceed 1.0
    local enhanced_similarity = math.min(1.0, base_similarity + bonus)
    
    return enhanced_similarity, bonus
end
-- }}}

-- {{{ function M.apply_golden_prioritization_to_recommendations
function M.apply_golden_prioritization_to_recommendations(recommendations, options)
    local config = M.get_config()
    options = options or {}
    
    if not config.enable_golden_prioritization then
        return recommendations
    end
    
    local golden_boost = options.golden_boost or config.golden_poem_single_bonus
    local min_golden_count = options.min_golden_count or config.min_golden_recommendations
    local max_golden_count = options.max_golden_count or config.max_golden_recommendations
    
    -- Apply score boosts to golden poems
    for _, rec in ipairs(recommendations) do
        if rec.is_golden then
            rec.original_score = rec.score
            rec.score = math.min(1.0, rec.score + golden_boost)
            rec.bonus_applied = golden_boost
        end
    end
    
    -- Re-sort with boosted scores
    table.sort(recommendations, function(a, b) return a.score > b.score end)
    
    -- Count golden poems in top results
    local golden_count = 0
    local top_results = {}
    
    for i, rec in ipairs(recommendations) do
        if i <= 10 then  -- Consider top 10 for analysis
            table.insert(top_results, rec)
            if rec.is_golden then
                golden_count = golden_count + 1
            end
        end
    end
    
    -- If we don't have enough golden poems in top results, promote some
    if golden_count < min_golden_count then
        local needed_golden = min_golden_count - golden_count
        local promoted = M.promote_golden_recommendations(recommendations, top_results, needed_golden)
        
        if promoted > 0 then
            utils.log_info(string.format("Promoted %d golden poems to meet minimum requirement", promoted))
        end
    end
    
    -- If we have too many golden poems, we could demote some, but this is optional
    if golden_count > max_golden_count then
        -- utils.log_info(string.format("High golden poem density: %d/%d", golden_count, #top_results))
    end
    
    return recommendations
end
-- }}}

-- {{{ function M.promote_golden_recommendations
function M.promote_golden_recommendations(all_recommendations, top_results, needed_count)
    local promoted = 0
    
    -- Find golden poems outside the top results
    for i = 11, math.min(50, #all_recommendations) do  -- Look in positions 11-50
        if promoted >= needed_count then break end
        
        local rec = all_recommendations[i]
        if rec.is_golden then
            -- Boost this golden poem enough to enter top 10
            local min_top_score = top_results[#top_results].score
            rec.promoted_score = rec.score
            rec.score = min_top_score + 0.001 + (promoted * 0.0001)  -- Small incremental boost
            rec.promotion_applied = true
            
            utils.log_info(string.format("Promoted golden poem: %s (%.3f -> %.3f)",
                                         rec.title or rec.id, rec.promoted_score, rec.score))
            promoted = promoted + 1
        end
    end
    
    -- Re-sort after promotions
    if promoted > 0 then
        table.sort(all_recommendations, function(a, b) return a.score > b.score end)
    end
    
    return promoted
end
-- }}}

-- {{{ function M.validate_golden_bonus_effects
function M.validate_golden_bonus_effects(recommendations_before, recommendations_after, poem_metadata)
    local validation = {
        total_recommendations = #recommendations_after,
        golden_count = 0,
        average_golden_position = 0,
        average_non_golden_position = 0,
        bonus_effectiveness = 0
    }
    
    local golden_positions = {}
    local non_golden_positions = {}
    
    for i, rec in ipairs(recommendations_after) do
        if rec.is_golden then
            validation.golden_count = validation.golden_count + 1
            table.insert(golden_positions, i)
        else
            table.insert(non_golden_positions, i)
        end
    end
    
    -- Calculate average positions
    if #golden_positions > 0 then
        local sum = 0
        for _, pos in ipairs(golden_positions) do sum = sum + pos end
        validation.average_golden_position = sum / #golden_positions
    end
    
    if #non_golden_positions > 0 then
        local sum = 0
        for _, pos in ipairs(non_golden_positions) do sum = sum + pos end
        validation.average_non_golden_position = sum / #non_golden_positions
    end
    
    -- Calculate bonus effectiveness (lower position number = higher ranking)
    if validation.average_non_golden_position > 0 then
        validation.bonus_effectiveness = 
            (validation.average_non_golden_position - validation.average_golden_position) / 
            validation.average_non_golden_position
    end
    
    return validation
end
-- }}}

-- {{{ function M.generate_golden_bonus_report
function M.generate_golden_bonus_report(validation_results)
    local report = {}
    
    table.insert(report, "=== Golden Poem Bonus Validation Report ===")
    table.insert(report, string.format("Total recommendations: %d", validation_results.total_recommendations))
    table.insert(report, string.format("Golden poems found: %d", validation_results.golden_count))
    table.insert(report, string.format("Average golden position: %.2f", validation_results.average_golden_position))
    table.insert(report, string.format("Average non-golden position: %.2f", validation_results.average_non_golden_position))
    table.insert(report, string.format("Bonus effectiveness: %.1f%%", validation_results.bonus_effectiveness * 100))
    
    local config = M.get_config()
    table.insert(report, "")
    table.insert(report, "=== Configuration ===")
    table.insert(report, string.format("Golden pair bonus: +%.3f", config.golden_poem_pair_bonus))
    table.insert(report, string.format("Golden single bonus: +%.3f", config.golden_poem_single_bonus))
    table.insert(report, string.format("Min golden recommendations: %d", config.min_golden_recommendations))
    table.insert(report, string.format("Max golden recommendations: %d", config.max_golden_recommendations))
    table.insert(report, string.format("Bonus threshold: %.3f", config.golden_bonus_threshold))
    
    return table.concat(report, "\n")
end
-- }}}

return M