#!/usr/bin/env lua

-- Manual Golden Poem Bonus Test
-- Tests the bonus system by manually marking poems as golden

package.path = package.path .. ';./?.lua;./libs/?.lua'

local utils = require("libs.utils")
local template_engine = require("src.html-generator.template-engine")
local similarity_engine = require("src.html-generator.similarity-engine")
local golden_bonus = require("src.html-generator.golden-poem-bonus")

local M = {}

-- {{{ function M.test_with_manual_golden_poems
function M.test_with_manual_golden_poems()
    utils.log_info("Testing golden poem bonus with manually flagged golden poems...")
    
    local poems_data = template_engine.load_poems_data()
    if not poems_data then
        utils.log_error("Failed to load poems data")
        return false
    end
    
    -- Find poems near 1024 characters and mark them as golden
    local golden_poem_ids = {}
    local poems_marked = 0
    
    for id, poem in pairs(poems_data.poems) do
        if poem.length and poem.length >= 1020 and poem.length <= 1030 then
            poem.is_fediverse_golden = true
            table.insert(golden_poem_ids, id)
            poems_marked = poems_marked + 1
            
            utils.log_info(string.format("Marked poem %s as golden (%d chars)", 
                                        id, poem.length))
            
            if poems_marked >= 10 then break end  -- Mark 10 poems as golden for testing
        end
    end
    
    utils.log_info(string.format("Manually marked %d poems as golden for testing", poems_marked))
    
    if poems_marked == 0 then
        utils.log_error("No poems found near 1024 characters")
        return false
    end
    
    -- Test golden poem bonus with a golden poem
    local test_poem_id = golden_poem_ids[1]
    utils.log_info(string.format("Testing recommendations for golden poem %s", test_poem_id))
    
    -- Get recommendations with bonus disabled
    local recommendations_without = similarity_engine.get_top_recommendations(
        test_poem_id, poems_data, 
        {count = 10, apply_golden_bonus = false}
    )
    
    -- Get recommendations with bonus enabled  
    local recommendations_with = similarity_engine.get_top_recommendations(
        test_poem_id, poems_data,
        {count = 10, apply_golden_bonus = true}
    )
    
    if #recommendations_without == 0 or #recommendations_with == 0 then
        utils.log_warn("No recommendations generated")
        return false
    end
    
    -- Count golden poems and analyze scores
    local golden_without = 0
    local golden_with = 0
    local bonus_applications = 0
    local avg_score_without = 0
    local avg_score_with = 0
    
    for _, rec in ipairs(recommendations_without) do
        if rec.is_golden then golden_without = golden_without + 1 end
        avg_score_without = avg_score_without + rec.score
    end
    avg_score_without = avg_score_without / #recommendations_without
    
    for _, rec in ipairs(recommendations_with) do
        if rec.is_golden then golden_with = golden_with + 1 end
        if rec.bonus_applied and rec.bonus_applied > 0 then
            bonus_applications = bonus_applications + 1
        end
        avg_score_with = avg_score_with + rec.score
    end
    avg_score_with = avg_score_with / #recommendations_with
    
    utils.log_info("Results comparison:")
    utils.log_info(string.format("  Golden poems without bonus: %d/%d", 
                                golden_without, #recommendations_without))
    utils.log_info(string.format("  Golden poems with bonus: %d/%d", 
                                golden_with, #recommendations_with))
    utils.log_info(string.format("  Bonus applications: %d", bonus_applications))
    utils.log_info(string.format("  Average similarity without: %.4f", avg_score_without))
    utils.log_info(string.format("  Average similarity with: %.4f", avg_score_with))
    
    -- Test HTML generation
    local test_poem = similarity_engine.get_poem_metadata(test_poem_id, poems_data)
    local html = template_engine.generate_poem_html(test_poem, poems_data)
    
    local html_has_golden = html:match('golden') or html:match('✨')
    
    utils.log_info(string.format("HTML contains golden indicators: %s", 
                                html_has_golden and "yes" or "no"))
    
    -- Success if we have bonus applications and improved golden representation
    local success = bonus_applications > 0 and golden_with >= golden_without
    
    if success then
        utils.log_info("✅ Golden poem bonus system working correctly")
    else
        utils.log_warn("❌ Golden poem bonus system may have issues")
    end
    
    return success
end
-- }}}

-- {{{ function M.test_golden_recommendation_ranking
function M.test_golden_recommendation_ranking()
    utils.log_info("Testing golden poem ranking in recommendations...")
    
    local poems_data = template_engine.load_poems_data()
    if not poems_data then return false end
    
    -- Mark some poems as golden
    local marked_count = 0
    for id, poem in pairs(poems_data.poems) do
        if poem.length and poem.length >= 1020 and poem.length <= 1030 and marked_count < 5 then
            poem.is_fediverse_golden = true
            marked_count = marked_count + 1
        end
    end
    
    -- Test with poem 1
    local recommendations = similarity_engine.get_top_recommendations(
        1, poems_data, {count = 15, apply_golden_bonus = true}
    )
    
    if #recommendations == 0 then
        utils.log_warn("No recommendations for ranking test")
        return false
    end
    
    -- Analyze ranking positions
    local golden_positions = {}
    local non_golden_positions = {}
    
    for i, rec in ipairs(recommendations) do
        if rec.is_golden then
            table.insert(golden_positions, i)
        else
            table.insert(non_golden_positions, i)
        end
    end
    
    utils.log_info(string.format("Golden positions: %s", 
                                table.concat(golden_positions, ", ")))
    
    local avg_golden_pos = 0
    if #golden_positions > 0 then
        for _, pos in ipairs(golden_positions) do
            avg_golden_pos = avg_golden_pos + pos
        end
        avg_golden_pos = avg_golden_pos / #golden_positions
    end
    
    utils.log_info(string.format("Average golden poem position: %.1f", avg_golden_pos))
    
    -- Generate validation report
    local validation_results = golden_bonus.validate_golden_bonus_effects(
        {}, recommendations, poems_data
    )
    
    local report = golden_bonus.generate_golden_bonus_report(validation_results)
    utils.log_info("\n" .. report)
    
    return #golden_positions > 0
end
-- }}}

-- Run manual test
utils.log_info("Running manual golden poem bonus test...")
local test1_result = M.test_with_manual_golden_poems()
local test2_result = M.test_golden_recommendation_ranking()

if test1_result and test2_result then
    utils.log_info("🎉 MANUAL GOLDEN POEM BONUS TESTS PASSED")
    os.exit(0)
else
    utils.log_error("❌ Manual golden poem bonus tests FAILED")
    os.exit(1)
end