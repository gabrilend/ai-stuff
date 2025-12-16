# Issue 011: Implement Per-Model Similarity Matrices

## Current Behavior
- Single similarity matrix generated regardless of embedding model used
- No support for comparing results between different embedding models
- Matrix overwrites when different models are used for embedding generation
- No model-specific similarity analysis capabilities

## Intended Behavior
- Generate separate similarity matrix for each embedding model
- Support for model-specific similarity comparisons
- Independent similarity matrices maintained for each model
- Future HTML interface can switch between models for different analysis perspectives

## Root Cause Analysis

### **Multi-Model Benefits**
Different embedding models capture different semantic relationships:
- **EmbeddingGemma**: May excel at thematic similarity
- **nomic-embed-text**: May capture different linguistic patterns
- **Other models**: Each has unique strengths for different types of analysis

### **Current Limitation**
- Single similarity matrix at `/assets/similarity_matrix.json`
- Model information stored in metadata but not used for file separation
- No way to compare how different models perceive poem relationships

## Suggested Implementation Steps
1. **Model-Specific Storage**: Create separate similarity matrices per model
2. **Directory Structure**: Organize matrices by model name in subdirectories
3. **Model Selection**: Allow CLI tools to specify which model's matrix to use
4. **Comparative Analysis**: Future capability to compare models side-by-side

## Technical Requirements

### **Directory Structure Enhancement**
```
assets/
├── embeddings/
│   ├── EmbeddingGemma_latest/
│   │   ├── embeddings.json
│   │   └── similarity_matrix.json
│   └── nomic-embed-text_latest/
│       ├── embeddings.json
│       └── similarity_matrix.json
└── similarity_matrices/  # Legacy location for backwards compatibility
```

### **Model-Specific Matrix Generation**
```lua
-- Enhanced matrix calculation with model awareness
function M.calculate_similarity_matrix_for_model(model_name, embeddings_file, top_n, force_regenerate)
    local model_dir = get_model_directory(model_name)
    local matrix_file = model_dir .. "/similarity_matrix.json"
    
    -- Model-specific validation and generation
    local validation = validate_similarity_matrix_currency(matrix_file, embeddings_file, poems_file)
    
    if validation.valid and not force_regenerate then
        utils.log_info("✅ " .. model_name .. " similarity matrix is current")
        return true
    end
    
    -- Generate matrix specific to this model's embeddings
    return generate_matrix_for_model(model_name, embeddings_file, matrix_file, top_n)
end
```

### **CLI Enhancement for Model Selection**
```bash
# Generate similarity matrix for specific model
echo -e "2\nEmbeddingGemma:latest\n" | lua src/similarity-engine.lua -I

# Status check shows all models
./generate-embeddings.sh --model-status
# Output:
# Available Models:
#   EmbeddingGemma:latest - 6641/6860 embeddings (96.8%) - Matrix: COMPLETE
#   nomic-embed-text:latest - 5000/6860 embeddings (72.9%) - Matrix: INCOMPLETE
```

## User Experience Improvements

### **Interactive Model Selection**
```
=== Similarity Matrix Generation ===
Available embedding models:
1. EmbeddingGemma:latest (6641/6860 embeddings) - Complete dataset
2. nomic-embed-text:latest (5000/6860 embeddings) - Incomplete dataset

Select embedding model for similarity matrix (1-2): 1
Generating similarity matrix for EmbeddingGemma:latest...
```

### **Model Comparison Capability**
```bash
# Future HTML generation with model selection
./generate-html.sh --embedding-model=EmbeddingGemma:latest
./generate-html.sh --embedding-model=nomic-embed-text:latest
```

## Quality Assurance Criteria
- Each model maintains independent similarity matrix
- Matrix generation respects model-specific completeness requirements
- CLI tools clearly indicate which model's matrix is being used
- Storage structure prevents model conflicts
- Backwards compatibility maintained with existing matrix locations

## Success Metrics
- **Model Independence**: Each model generates separate similarity matrices
- **Storage Isolation**: No conflicts between model-specific matrices
- **User Clarity**: Clear indication of which model is being used for analysis
- **Future Flexibility**: HTML interface can switch between models

## Implementation Validation
1. Generate embeddings for multiple models (partial and complete datasets)
2. Create model-specific similarity matrices
3. Verify matrices are stored in correct model directories
4. Test CLI model selection functionality
5. Validate that incomplete models don't affect complete model matrices
6. Confirm backwards compatibility with existing workflows

**USER REQUEST FULFILLMENT:**
This ticket addresses the requirement for:
1. ✅ Per-model similarity matrix generation
2. ✅ Independent matrix storage per embedding model  
3. ✅ Support for model-specific analysis
4. ✅ Foundation for future HTML model switching

**ISSUE STATUS: READY FOR IMPLEMENTATION** 🚀

**DEPENDENCIES:**
- Requires Issue 010 (similarity matrix invalidation) to be completed first
- Foundation for future Phase 3 HTML multi-model interface

**RELATED ISSUES:**
- Issue 010: Implement Similarity Matrix Invalidation on Embedding Changes
- Future Phase 3: HTML interface with model selection capability