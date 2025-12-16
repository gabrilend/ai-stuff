# Issue 005a: Implement Golden Poem Similarity Bonus

## Current Behavior
- Similarity engine treats all poems equally regardless of length
- No special weighting for fediverse golden poems (1024 characters)
- Recommendation system doesn't prioritize golden poems
- No configurable bonus system for constraint-based achievements

## Intended Behavior
- Similarity calculations include configurable bonus for golden poems
- Golden-to-golden poem pairs receive highest priority boost
- Mixed golden/non-golden pairs receive moderate boost
- Configurable weighting system allows tuning of golden poem prominence

## Suggested Implementation Steps
1. **Similarity Scoring Enhancement**: Add golden poem bonus to base similarity calculations
2. **Configuration System**: Implement configurable weighting parameters
3. **Bonus Application Logic**: Apply bonuses during similarity matrix generation
4. **Testing Framework**: Validate bonus effects on recommendation quality
5. **Documentation**: Document golden poem bonus configuration options

## Technical Requirements

### **Enhanced Similarity Calculation**
```lua
-- {{{ function calculate_similarity_with_golden_bonus
function calculate_similarity_with_golden_bonus(poem_a, poem_b, base_similarity, config)
    config = config or get_golden_poem_config()
    
    local bonus = 0
    
    -- Both poems are golden - highest bonus
    if poem_a.is_fediverse_golden and poem_b.is_fediverse_golden then
        bonus = config.golden_poem_pair_bonus or 0.05
        utils.log_debug(string.format(
            "Golden pair bonus: %s (%d) <-> %s (%d) = +%.3f",
            poem_a.title or poem_a.id, poem_a.id,
            poem_b.title or poem_b.id, poem_b.id,
            bonus
        ))
    -- One poem is golden - moderate bonus
    elseif poem_a.is_fediverse_golden or poem_b.is_fediverse_golden then
        bonus = config.golden_poem_single_bonus or 0.02
        utils.log_debug(string.format(
            "Golden single bonus: %s (%d) <-> %s (%d) = +%.3f",
            poem_a.title or poem_a.id, poem_a.id,
            poem_b.title or poem_b.id, poem_b.id,
            bonus
        ))
    end
    
    -- Apply bonus and ensure we don't exceed 1.0
    local enhanced_similarity = math.min(1.0, base_similarity + bonus)
    
    return enhanced_similarity, bonus
end
-- }}}
```

### **Configuration Management**
```lua
-- {{{ function get_golden_poem_config
function get_golden_poem_config()
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

-- {{{ function load_golden_poem_config
function load_golden_poem_config(config_file)
    config_file = config_file or "config/golden-poem-settings.json"
    
    if utils.file_exists(config_file) then
        local config_json = utils.read_file(config_file)
        return json.decode(config_json)
    else
        -- Return defaults and create config file
        local default_config = get_golden_poem_config()
        utils.write_file(config_file, json.encode(default_config))
        utils.log_info("Created default golden poem config: " .. config_file)
        return default_config
    end
end
-- }}}
```

### **Integration with Similarity Engine**
```lua
-- {{{ function M.calculate_enhanced_similarity_matrix
function M.calculate_enhanced_similarity_matrix(embeddings_file, output_file, options)
    options = options or {}
    local golden_config = load_golden_poem_config(options.golden_config_file)
    
    if not golden_config.enable_golden_prioritization then
        -- Fall back to standard similarity calculation
        return M.calculate_similarity_matrix(embeddings_file, output_file)
    end
    
    utils.log_info("Calculating similarity matrix with golden poem bonuses")
    utils.log_info(string.format("Golden pair bonus: +%.3f, Single bonus: +%.3f", 
                                golden_config.golden_poem_pair_bonus,
                                golden_config.golden_poem_single_bonus))
    
    local embeddings_data = json.decode(utils.read_file(embeddings_file))
    local poems_data = load_poems_data() -- Load poem metadata for golden status
    
    local similarity_matrix = {
        metadata = {
            created_at = os.date("%Y-%m-%d %H:%M:%S"),
            algorithm = "cosine_similarity_with_golden_bonus",
            total_poems = #embeddings_data.embeddings,
            golden_config = golden_config,
            enhancement_version = "1.0"
        },
        data = {}
    }
    
    local total_pairs = 0
    local golden_bonuses_applied = 0
    
    for i, poem_a in ipairs(embeddings_data.embeddings) do
        if not similarity_matrix.data[poem_a.id] then
            similarity_matrix.data[poem_a.id] = {}
        end
        
        for j, poem_b in ipairs(embeddings_data.embeddings) do
            if poem_a.id ~= poem_b.id then
                -- Calculate base cosine similarity
                local base_similarity = cosine_similarity(poem_a.embedding, poem_b.embedding)
                
                -- Apply golden poem bonus
                local poem_a_data = poems_data.poems[poem_a.id]
                local poem_b_data = poems_data.poems[poem_b.id]
                
                if poem_a_data and poem_b_data and base_similarity >= golden_config.golden_bonus_threshold then
                    local enhanced_similarity, bonus = calculate_similarity_with_golden_bonus(
                        poem_a_data, poem_b_data, base_similarity, golden_config
                    )
                    
                    similarity_matrix.data[poem_a.id][poem_b.id] = enhanced_similarity
                    
                    if bonus > 0 then
                        golden_bonuses_applied = golden_bonuses_applied + 1
                    end
                else
                    similarity_matrix.data[poem_a.id][poem_b.id] = base_similarity
                end
                
                total_pairs = total_pairs + 1
            end
        end
        
        -- Progress reporting
        if i % 100 == 0 then
            utils.log_info(string.format("Processed %d poems, %d golden bonuses applied", 
                                        i, golden_bonuses_applied))
        end
    end
    
    utils.log_info(string.format("Golden bonus summary: %d bonuses applied out of %d total pairs (%.2f%%)",
                                golden_bonuses_applied, total_pairs, 
                                (golden_bonuses_applied / total_pairs) * 100))
    
    -- Write enhanced similarity matrix
    utils.write_file(output_file, json.encode(similarity_matrix))
    utils.log_info("Enhanced similarity matrix saved: " .. output_file)
    
    return true
end
-- }}}
```

### **Validation and Testing**
```lua
-- {{{ function validate_golden_bonus_effects
function validate_golden_bonus_effects(similarity_file, poems_data_file)
    local similarity_data = json.decode(utils.read_file(similarity_file))
    local poems_data = json.decode(utils.read_file(poems_data_file))
    
    local golden_poems = {}
    local non_golden_poems = {}
    
    -- Identify golden and non-golden poems
    for poem_id, poem_data in pairs(poems_data.poems) do
        if poem_data.is_fediverse_golden then
            table.insert(golden_poems, poem_id)
        else
            table.insert(non_golden_poems, poem_id)
        end
    end
    
    utils.log_info(string.format("Found %d golden poems, %d non-golden poems", 
                                #golden_poems, #non_golden_poems))
    
    -- Test golden-to-golden similarities vs golden-to-non-golden
    local golden_to_golden_avg = 0
    local golden_to_non_golden_avg = 0
    local golden_to_golden_count = 0
    local golden_to_non_golden_count = 0
    
    for _, golden_id in ipairs(golden_poems) do
        if similarity_data.data[golden_id] then
            -- Check similarities to other golden poems
            for _, other_golden_id in ipairs(golden_poems) do
                if golden_id ~= other_golden_id and similarity_data.data[golden_id][other_golden_id] then
                    golden_to_golden_avg = golden_to_golden_avg + similarity_data.data[golden_id][other_golden_id]
                    golden_to_golden_count = golden_to_golden_count + 1
                end
            end
            
            -- Check similarities to non-golden poems (sample)
            for i = 1, math.min(50, #non_golden_poems) do
                local non_golden_id = non_golden_poems[i]
                if similarity_data.data[golden_id][non_golden_id] then
                    golden_to_non_golden_avg = golden_to_non_golden_avg + similarity_data.data[golden_id][non_golden_id]
                    golden_to_non_golden_count = golden_to_non_golden_count + 1
                end
            end
        end
    end
    
    if golden_to_golden_count > 0 then
        golden_to_golden_avg = golden_to_golden_avg / golden_to_golden_count
    end
    if golden_to_non_golden_count > 0 then
        golden_to_non_golden_avg = golden_to_non_golden_avg / golden_to_non_golden_count
    end
    
    utils.log_info(string.format("Average golden-to-golden similarity: %.4f (%d pairs)",
                                golden_to_golden_avg, golden_to_golden_count))
    utils.log_info(string.format("Average golden-to-non-golden similarity: %.4f (%d pairs)",
                                golden_to_non_golden_avg, golden_to_non_golden_count))
    utils.log_info(string.format("Golden poem boost effect: +%.4f average increase",
                                golden_to_golden_avg - golden_to_non_golden_avg))
    
    return {
        golden_to_golden_avg = golden_to_golden_avg,
        golden_to_non_golden_avg = golden_to_non_golden_avg,
        boost_effect = golden_to_golden_avg - golden_to_non_golden_avg
    }
end
-- }}}
```

## Quality Assurance Criteria
- Golden poem bonuses are applied correctly and consistently
- Similarity scores remain within valid range (0.0 to 1.0)
- Configuration system allows tuning without code changes
- Performance impact of bonus calculations is minimal
- Validation confirms expected boost effects in recommendations

## Success Metrics
- **Golden Prominence**: Golden poems appear more frequently in top recommendations
- **Bonus Application**: Bonuses applied to expected poem pairs (golden-golden, golden-mixed)
- **Performance**: Less than 10% performance impact on similarity calculations
- **Configuration**: Easy tuning of bonus parameters through config files
- **Validation**: Clear metrics showing bonus effectiveness

## Dependencies
- **Issue 003**: Character counting fix (prerequisite for accurate golden poem identification)
- Phase 2 similarity engine infrastructure
- Updated poem validation system with golden poem flags

## Related Issues
- **Issue 005b**: Golden Poem Visual Indicators (uses enhanced similarity data)
- **Issue 005c**: Golden Poem Collection Pages (benefits from prioritization)
- **Issue 001c**: Similarity Navigation (integrates golden prioritization)

## Testing Strategy
1. **Unit Testing**: Test bonus calculation functions with known golden/non-golden pairs
2. **Integration Testing**: Generate similarity matrices with and without bonuses
3. **Performance Testing**: Measure impact of bonus calculations on matrix generation time
4. **Validation Testing**: Verify golden poems appear more prominently in recommendations
5. **Configuration Testing**: Test various bonus parameter combinations

**ISSUE STATUS: COMPLETED** ✅

## Implementation Summary

**Completed on:** December 4, 2025

### ✅ Deliverables Completed:

1. **Golden Poem Configuration System** (`config/golden-poem-settings.json`):
   - Configurable bonus parameters for golden poem pairs and mixed pairs
   - Minimum/maximum golden poem limits in recommendations
   - Similarity threshold for bonus application
   - Enable/disable toggle for golden prioritization

2. **Enhanced Similarity Calculation** (`src/html-generator/golden-poem-bonus.lua`):
   - Golden-to-golden bonus: +0.05 default (configurable)
   - Golden-to-regular bonus: +0.02 default (configurable) 
   - Similarity threshold enforcement (0.1 minimum)
   - Bonus application with 1.0 max similarity cap
   - Performance-optimized calculation logic

3. **Recommendation Prioritization System**:
   - Advanced prioritization algorithm with score boosts
   - Minimum golden poem promotion (ensures 2+ golden poems in top results)
   - Golden poem position optimization
   - Re-ranking with enhanced similarity scores
   - Comprehensive validation and reporting

4. **Full Integration with Similarity Engine**:
   - Updated `similarity-engine.lua` with golden bonus integration
   - Template engine integration with automatic bonus application
   - HTML generation with enhanced similarity recommendations
   - Backward compatibility with existing recommendation system

### ✅ Key Features Implemented:

- **Configurable Bonus System**: JSON-based configuration with runtime loading
- **Dual Bonus Types**: Higher bonus for golden-golden pairs (0.05), moderate for mixed pairs (0.02)
- **Smart Threshold**: Only applies bonuses when base similarity ≥ 0.1
- **Recommendation Enhancement**: Prioritizes golden poems while maintaining quality
- **Promotion Logic**: Ensures minimum golden representation in top recommendations
- **Performance Optimized**: Efficient calculation with optional debug logging

### ✅ Test Results:
```
Golden Poem Bonus Test Suite - SYSTEM FULLY FUNCTIONAL ✅
- Bonus Calculations: 5/5 test cases passed (100%)
- Prioritization Logic: Golden poems correctly promoted in rankings
- Engine Integration: 10 bonus applications detected during testing
- HTML Generation: Full integration with template system confirmed
- Configuration System: JSON persistence and runtime loading working

Technical Validation:
- Golden-to-golden bonus: +0.050 (high similarity)
- Golden-to-regular bonus: +0.020 (high similarity)  
- Low similarity handling: +0.000 (below 0.1 threshold)
- Disabled mode: +0.000 (configuration respected)
```

### ✅ Quality Assurance Results:
- **Bonus Accuracy**: Perfect calculation precision across all test scenarios
- **Configuration Flexibility**: Easy tuning through JSON config files
- **Performance Impact**: Minimal overhead with efficient bonus calculations
- **Integration Quality**: Seamless integration with existing similarity pipeline
- **Backward Compatibility**: Works with existing recommendation system

### 🔗 Integration Results:
This golden poem bonus system successfully integrates:
- **Similarity Engine**: Enhanced recommendation scoring with configurable bonuses
- **Template Engine**: Automatic application of golden bonuses in HTML generation
- **Configuration System**: Runtime configuration loading with persistence
- **HTML Generation**: Enhanced similarity recommendations in poetry pages

### 📁 Files Created/Updated:
- **Created** `/config/golden-poem-settings.json` - Golden poem configuration with tunable parameters
- **Created** `/src/html-generator/golden-poem-bonus.lua` - Complete golden bonus calculation system with:
  - Configurable bonus calculations for golden poem pairs
  - Advanced recommendation prioritization algorithms  
  - Validation and reporting functionality
  - Configuration persistence and loading
- **Updated** `/src/html-generator/similarity-engine.lua` - Enhanced with golden bonus integration
- **Updated** `/src/html-generator/template-engine.lua` - Automatic golden bonus application
- **Created** `/src/html-generator/test-golden-poem-bonus-comprehensive.lua` - Complete testing framework

### 🎯 Core Requirements Achieved:
✅ **"Similarity calculations include configurable bonus for golden poems"**
- Configurable bonus system with golden-golden (0.05) and golden-mixed (0.02) bonuses
- Smart threshold enforcement and similarity cap protection
- Full integration with existing similarity pipeline

✅ **"Golden poems receive priority boost in recommendations"**  
- Advanced prioritization with score enhancement
- Minimum golden poem promotion to ensure representation
- Quality-preserving ranking improvements

✅ **"Configurable weighting system allows tuning"**
- JSON-based configuration with runtime loading
- Easy parameter tuning without code changes
- Enable/disable toggle for system control

### 📋 Implementation Notes:
The golden poem bonus system is fully implemented and tested. **Effectiveness in production depends on**:

1. **Golden Poem Availability**: Requires properly identified golden poems in the dataset (Issue 003 dependency)
2. **Similarity Relationships**: Most effective when golden poems have meaningful similarities to each other
3. **Configuration Tuning**: Bonus values can be adjusted based on real-world usage patterns

The system provides a foundation for golden poem prioritization that will become more effective as the golden poem identification system (Issue 003) is fully deployed and more golden poems are available in the dataset.

**IMPLEMENTATION COMPLETE** ✨