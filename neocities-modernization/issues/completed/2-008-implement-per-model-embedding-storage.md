# Issue 008: Implement Per-Model Embedding Storage

## Current Behavior
- All embeddings stored in single `assets/embeddings.json` file regardless of model
- No isolation between different embedding models (EmbeddingGemma, text-embedding-ada-002, etc.)
- Model changes require manual cache management or complete regeneration
- Risk of mixing embeddings from different models in similarity calculations

## Intended Behavior
- Separate storage directories/files for each embedding model
- Automatic model detection and appropriate cache selection
- Seamless switching between different embedding models
- Model-specific similarity matrices and results isolation

## Suggested Implementation Steps
1. **Directory Structure**: Create model-specific storage hierarchy
2. **Model Detection**: Automatic model identification and cache routing
3. **File Path Generation**: Dynamic path creation based on model name
4. **Backward Compatibility**: Handle existing cache migration
5. **Configuration**: Model-specific settings and parameters

## Technical Requirements

### **Storage Directory Structure**
```
assets/
├── embeddings/
│   ├── EmbeddingGemma-latest/
│   │   ├── embeddings.json
│   │   ├── similarity_matrix.json
│   │   └── metadata.json
│   ├── text-embedding-ada-002/
│   │   ├── embeddings.json
│   │   ├── similarity_matrix.json
│   │   └── metadata.json
│   └── all-MiniLM-L6-v2/
│       ├── embeddings.json
│       ├── similarity_matrix.json
│       └── metadata.json
└── poems.json
```

### **Model Path Generation**
```lua
-- {{{ local function get_model_storage_path
local function get_model_storage_path(base_dir, model_name)
    -- Sanitize model name for filesystem
    local safe_model_name = model_name:gsub("[^%w%-_.]", "_")
    local model_dir = base_dir .. "/embeddings/" .. safe_model_name
    
    -- Create directory if it doesn't exist
    os.execute("mkdir -p " .. model_dir)
    
    return {
        embeddings = model_dir .. "/embeddings.json",
        similarity_matrix = model_dir .. "/similarity_matrix.json",
        metadata = model_dir .. "/metadata.json"
    }
end
-- }}}
```

### **Enhanced Configuration**
```lua
local embedding_models = {
    ["EmbeddingGemma:latest"] = {
        dimensions = 768,
        endpoint_path = "/api/embed",
        timeout = 30
    },
    ["text-embedding-ada-002"] = {
        dimensions = 1536,
        endpoint_path = "/v1/embeddings",
        timeout = 60
    },
    ["all-MiniLM-L6-v2"] = {
        dimensions = 384,
        endpoint_path = "/api/embed",
        timeout = 20
    }
}
```

### **Automatic Model Detection**
```lua
function M.generate_all_embeddings(poems_file, base_output_dir, endpoint, incremental, model_name)
    model_name = model_name or "EmbeddingGemma:latest"
    
    -- Get model-specific configuration
    local model_config = embedding_models[model_name]
    if not model_config then
        utils.log_error("Unknown embedding model: " .. model_name)
        return false
    end
    
    -- Generate model-specific file paths
    local storage_paths = get_model_storage_path(base_output_dir, model_name)
    local embeddings_file = storage_paths.embeddings
    
    utils.log_info("Using embedding model: " .. model_name)
    utils.log_info("Storage location: " .. embeddings_file)
    utils.log_info("Expected dimensions: " .. model_config.dimensions)
```

## User Experience Improvements

### **Enhanced Command-Line Interface**
```bash
# Bash script options
--model MODEL_NAME      # Specify embedding model (default: EmbeddingGemma:latest)
--list-models          # Show available models and their configurations
--model-status         # Show cache status for all models

# Usage examples
./generate-embeddings.sh --model EmbeddingGemma:latest
./generate-embeddings.sh --model text-embedding-ada-002
./generate-embeddings.sh --list-models
```

### **Model Status Reporting**
```
Available Embedding Models:
  EmbeddingGemma:latest    (768 dims) - 1,274 cached embeddings (18.6%)
  text-embedding-ada-002   (1536 dims) - No cache found
  all-MiniLM-L6-v2        (384 dims) - 6,860 cached embeddings (100%)

Currently using: EmbeddingGemma:latest
Cache location: /assets/embeddings/EmbeddingGemma-latest/embeddings.json
```

### **Backward Compatibility Migration**
```lua
-- {{{ function migrate_legacy_cache
function migrate_legacy_cache(legacy_file, target_model_dir)
    if utils.file_exists(legacy_file) then
        utils.log_info("Migrating legacy cache to model-specific storage...")
        
        local backup_file = legacy_file .. ".legacy_backup"
        os.rename(legacy_file, backup_file)
        
        local legacy_data = utils.read_json_file(backup_file)
        if legacy_data then
            utils.write_json_file(target_model_dir .. "/embeddings.json", legacy_data)
            utils.log_info("Legacy cache migrated successfully")
        end
    end
end
-- }}}
```

## Quality Assurance Criteria
- Different models store embeddings in separate, isolated locations
- Model switching doesn't corrupt or mix embedding data
- Similarity calculations use only embeddings from the same model
- Legacy cache migration preserves existing work
- Clear model identification in all operations and logs

## Success Metrics
- **Isolation**: Complete separation of model-specific embeddings
- **Flexibility**: Easy switching between different embedding models
- **Safety**: No risk of mixing incompatible embeddings
- **Compatibility**: Seamless migration from existing single-file cache
- **Transparency**: Clear indication of active model and cache locations

## Edge Cases Handled
- **Model Name Sanitization**: Special characters in model names handled safely
- **Directory Creation**: Automatic creation of model-specific directories
- **Dimension Validation**: Model-specific dimension validation
- **Legacy Migration**: One-time migration of existing cache
- **Model Configuration**: Extensible configuration for new models

**USER REQUEST FULFILLMENT:**
This ticket addresses the user's requirement for:
1. ✅ Per-embedding-model storage directories
2. ✅ Recognition of different embedding models
3. ✅ Separate storage for different model's embeddings
4. ✅ Isolation of model-specific results

**ISSUE STATUS: COMPLETED** ✅

## IMPLEMENTATION COMPLETED
**Date:** November 3, 2025  
**Status:** Per-model storage implemented - embeddings stored in `/assets/embeddings/EmbeddingGemma_latest/` directory structure