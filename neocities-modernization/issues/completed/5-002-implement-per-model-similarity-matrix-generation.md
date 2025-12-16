# Issue 002: Implement Per-Model Similarity Matrix Generation

## Current Behavior
- Similarity matrix generation only supports single model at a time
- No automatic generation of matrices for each available embedding model
- User must manually specify model for similarity matrix calculation
- No comparison capabilities between different embedding models

## Intended Behavior
- Generate separate similarity matrices for each embedding model with sufficient data
- Automatic detection of models ready for similarity matrix generation
- Per-model matrix storage in model-specific directories
- Future HTML interface allowing users to switch between model comparisons

## Suggested Implementation Steps
1. **Multi-Model Detection**: Identify models with complete or sufficient embedding coverage
2. **Batch Matrix Generation**: Generate similarity matrices for all eligible models
3. **Model Comparison Interface**: CLI tools to compare model performance
4. **HTML Integration Planning**: Design for future model switching in web interface
5. **Performance Optimization**: Efficient processing of multiple large matrices

## Technical Requirements

### **Multi-Model Matrix Generation**
```lua
-- {{{ function M.generate_all_model_similarity_matrices
function M.generate_all_model_similarity_matrices(base_output_dir, min_completeness)
    min_completeness = min_completeness or 0.8 -- 80% minimum completeness
    
    local models = M.list_available_models()
    local results = {}
    
    for model_name, config in pairs(models) do
        local status = M.get_model_status(base_output_dir, model_name)
        
        if status.exists then
            local completeness = status.count / 6860 -- Total poem count
            
            if completeness >= min_completeness then
                utils.log_info("Generating similarity matrix for " .. model_name .. 
                             " (" .. string.format("%.1f%% complete)", completeness * 100))
                
                local storage_paths = get_model_storage_path(base_output_dir, model_name)
                local success = M.calculate_similarity_matrix(
                    storage_paths.embeddings, 
                    storage_paths.similarity_matrix
                )
                
                results[model_name] = {
                    success = success,
                    completeness = completeness,
                    embedding_count = status.count
                }
            else
                utils.log_warn("Skipping " .. model_name .. 
                             " (only " .. string.format("%.1f%% complete)", completeness * 100))
                results[model_name] = {
                    success = false,
                    reason = "insufficient_completeness",
                    completeness = completeness
                }
            end
        end
    end
    
    return results
end
-- }}}
```

### **CLI Integration**
```bash
# New bash script options
--generate-all-matrices     # Generate matrices for all eligible models
--matrix-status             # Show matrix status for all models
--compare-models            # Compare similarity results between models
--min-completeness=80       # Minimum completeness percentage for matrix generation
```

### **Model Comparison Capabilities**
```lua
-- {{{ function M.compare_model_similarities
function M.compare_model_similarities(poem_id, base_output_dir, models)
    local comparisons = {}
    
    for _, model_name in ipairs(models) do
        local storage_paths = get_model_storage_path(base_output_dir, model_name)
        if utils.file_exists(storage_paths.similarity_matrix) then
            local recommendations = M.generate_recommendations(
                poem_id, storage_paths.similarity_matrix, poems_data, 10
            )
            comparisons[model_name] = recommendations
        end
    end
    
    return comparisons
end
-- }}}
```

## Example Usage Scenarios

### **Scenario 1: Complete vs Partial Models**
```
EmbeddingGemma:latest    - 6,860/6,860 poems (100%) → Generate matrix
text-embedding-ada-002  - 5,000/6,860 poems (73%)  → Skip (below 80% threshold)
all-MiniLM-L6-v2        - 6,860/6,860 poems (100%) → Generate matrix
```

### **Scenario 2: Model Performance Comparison**
```bash
./generate-embeddings.sh --compare-models --poem-id=1234

Model Comparison for Poem #1234:
┌─────────────────────────┬──────────────────────────────────────┐
│ EmbeddingGemma:latest   │ Poem #445 (0.89), Poem #1122 (0.85) │
│ all-MiniLM-L6-v2        │ Poem #221 (0.92), Poem #445 (0.88)  │
└─────────────────────────┴──────────────────────────────────────┘
```

## User Experience Improvements

### **Enhanced Status Reporting**
```bash
./generate-embeddings.sh --matrix-status

Per-Model Similarity Matrix Status:
  EmbeddingGemma:latest (768 dims)
    ✅ Embeddings: 6,860/6,860 (100%)
    ✅ Matrix: Generated (47M comparisons)
    📊 Last updated: 2025-11-02 15:30:42
    
  text-embedding-ada-002 (1536 dims)  
    ⚠️  Embeddings: 5,000/6,860 (73%)
    ❌ Matrix: Not generated (below 80% threshold)
    🔄 Recommendation: Complete 1,860 more embeddings
    
  all-MiniLM-L6-v2 (384 dims)
    ✅ Embeddings: 6,860/6,860 (100%)
    ✅ Matrix: Generated (47M comparisons)
    📊 Last updated: 2025-11-02 16:15:21
```

### **Batch Generation Progress**
```bash
./generate-embeddings.sh --generate-all-matrices

🔄 Generating similarity matrices for eligible models...

[1/2] EmbeddingGemma:latest (100% complete)
      Progress: ████████████████████ 100% (47M/47M comparisons)
      ✅ Matrix generation complete

[2/2] all-MiniLM-L6-v2 (100% complete)  
      Progress: ████████████████████ 100% (47M/47M comparisons)
      ✅ Matrix generation complete

Skipped models:
  ⚠️  text-embedding-ada-002 (73% complete - below threshold)
```

## Future HTML Interface Integration

### **Model Switching Capability**
```html
<!-- Future Phase 3/4 feature -->
<div class="model-selector">
    <label>Similarity Model:</label>
    <select onchange="switchSimilarityModel(this.value)">
        <option value="EmbeddingGemma:latest">EmbeddingGemma (768d)</option>
        <option value="all-MiniLM-L6-v2">all-MiniLM-L6-v2 (384d)</option>
    </select>
</div>

<div class="similar-poems" data-model="EmbeddingGemma:latest">
    <!-- Similarity recommendations from EmbeddingGemma model -->
</div>
```

## Quality Assurance Criteria
- Each model with sufficient completeness gets its own similarity matrix
- Matrices are generated only when model has adequate poem coverage
- CLI tools clearly indicate which models are ready for matrix generation
- Model comparison functionality works across different embedding dimensions
- Performance remains acceptable when processing multiple large matrices

## Success Metrics
- **Model Coverage**: All models with >80% embedding completeness have matrices
- **Performance**: Multiple matrix generation completes within reasonable time
- **Accuracy**: Each model produces distinct, model-specific similarity rankings
- **Usability**: Clear status reporting for multi-model similarity states

## Edge Cases Handled
- **Mixed Completeness**: Some models complete while others remain partial
- **Different Dimensions**: Matrices handle models with different embedding sizes
- **Storage Isolation**: Each model's matrix stored in correct per-model directory
- **Memory Management**: Large matrix generation doesn't overwhelm system resources

## Implementation Validation
1. Generate embeddings for multiple models at different completion levels
2. Run batch matrix generation and verify only eligible models processed
3. Compare similarity results between different models for same poems
4. Verify per-model storage isolation works correctly
5. Test CLI status reporting shows accurate multi-model information

**USER REQUEST FULFILLMENT:**
This ticket addresses the requirement for:
1. ✅ Per-model similarity matrix generation
2. ✅ Separate similarity matrices for each embedding model
3. ✅ Future capability for HTML interface model switching
4. ✅ Comparison analysis between different embedding models

**ISSUE STATUS: READY FOR IMPLEMENTATION** 🚀

**Dependencies:**
- Requires Issue 010 (similarity matrix invalidation) to be completed first
- Builds on existing per-model embedding storage system
- Foundation for future HTML interface model switching capabilities