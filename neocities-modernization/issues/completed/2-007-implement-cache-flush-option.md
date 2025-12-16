# Issue 007: Implement Cache Flush Option

## Current Behavior
- No option to clear existing embedding cache
- Users must manually delete embeddings.json to start fresh
- No way to force complete regeneration when needed
- Incremental system always preserves existing valid embeddings

## Intended Behavior
- Add command-line option to flush/clear existing embedding cache
- Provide safe confirmation prompts before destructive operations
- Allow selective flushing (errors only vs complete cache)
- Integrate flush option with bash script interface

## Suggested Implementation Steps
1. **Command-Line Options**: Add flush flags to bash script and Lua engine
2. **Confirmation Prompts**: Implement safety confirmations for destructive operations
3. **Selective Flushing**: Options for different flush scopes
4. **Backup Creation**: Optional backup before flushing
5. **Integration Testing**: Ensure flush options work with all processing modes

## Technical Requirements

### **Bash Script Options**
```bash
--flush-all         # Complete cache flush (all embeddings)
--flush-errors      # Flush only error entries, keep valid embeddings
--flush-model       # Flush embeddings for specific model only
--backup-before-flush # Create backup before flushing (default: true)
--force             # Skip confirmation prompts
```

### **Lua Engine Integration**
```lua
function M.flush_embeddings_cache(output_file, flush_type, backup)
    flush_type = flush_type or "all"  -- "all", "errors", "model_specific"
    backup = backup ~= false          -- Default to true
    
    if backup then
        local backup_file = output_file .. ".backup." .. os.date("%Y%m%d_%H%M%S")
        if utils.file_exists(output_file) then
            os.rename(output_file, backup_file)
            utils.log_info("Backup created: " .. backup_file)
        end
    end
    
    if flush_type == "all" then
        os.remove(output_file)
        utils.log_info("Complete embedding cache flushed")
    elseif flush_type == "errors" then
        -- Load existing, remove error entries, save clean version
        local existing_data = utils.read_json_file(output_file)
        if existing_data and existing_data.embeddings then
            local clean_embeddings = {}
            local removed_count = 0
            for i, emb in pairs(existing_data.embeddings) do
                if emb.embedding and type(emb.embedding) == "table" and #emb.embedding == 768 then
                    clean_embeddings[i] = emb
                else
                    removed_count = removed_count + 1
                end
            end
            existing_data.embeddings = clean_embeddings
            utils.write_json_file(output_file, existing_data)
            utils.log_info("Error entries flushed: " .. removed_count .. " entries removed")
        end
    end
end
```

### **Safety Confirmations**
```bash
# Interactive confirmation
if [ "$FORCE" != true ]; then
    echo -e "${YELLOW}⚠️  WARNING: This will permanently delete embedding cache${NC}"
    echo -e "${BLUE}Cache file: ${EMBEDDINGS_FILE}${NC}"
    echo -e "${BLUE}Cache size: $(du -h "$EMBEDDINGS_FILE" | cut -f1)${NC}"
    echo ""
    read -p "Are you sure you want to proceed? (yes/no): " confirmation
    if [ "$confirmation" != "yes" ]; then
        echo "Operation cancelled"
        exit 0
    fi
fi
```

## User Experience Improvements

### **Command Usage Examples**
```bash
# Complete cache flush with confirmation
./generate-embeddings.sh --flush-all

# Flush only error entries (keep valid embeddings)
./generate-embeddings.sh --flush-errors

# Force flush without confirmation
./generate-embeddings.sh --flush-all --force

# Flush with explicit backup
./generate-embeddings.sh --flush-all --backup-before-flush
```

### **Enhanced Help Documentation**
```bash
Cache Management Options:
  --flush-all              Remove all cached embeddings (complete regeneration)
  --flush-errors           Remove only error entries, keep valid embeddings
  --backup-before-flush    Create timestamped backup before flushing (default)
  --force                  Skip confirmation prompts for automated scripts

Examples:
  ./generate-embeddings.sh --flush-errors    # Clean up failed entries
  ./generate-embeddings.sh --flush-all       # Start completely fresh
```

## Quality Assurance Criteria
- Flush operations are safe with confirmation prompts
- Backups are created by default before destructive operations
- Selective flushing preserves valid embeddings when appropriate
- Integration with existing incremental processing works correctly
- Clear documentation and examples for all flush options

## Success Metrics
- **Safety**: No accidental data loss due to proper confirmations
- **Flexibility**: Multiple flush options for different use cases
- **Integration**: Seamless integration with existing workflow
- **Recovery**: Backup system allows recovery from mistakes

**USER REQUEST FULFILLMENT:**
This ticket addresses the user's requirement for:
1. ✅ Option to flush previous embedding records
2. ✅ Safe and controlled cache management
3. ✅ Integration with existing bash script interface

**ISSUE STATUS: COMPLETED** ✅

## IMPLEMENTATION COMPLETED
**Date:** November 3, 2025  
**Status:** Cache flush functionality implemented and tested via generate-embeddings.sh --flush-all/--flush-errors options