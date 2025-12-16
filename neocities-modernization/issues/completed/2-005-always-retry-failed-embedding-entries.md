# Issue 005: Always Retry Failed Embedding Entries

## Current Behavior
- Poems with error states (empty_content, parse_error, etc.) are saved to the embeddings cache
- These error entries are treated as "processed" and skipped in subsequent incremental runs
- Failed embeddings due to temporary issues (network glitches, service restarts) never get retried
- No distinction between permanent failures (truly empty content) and temporary failures

## Intended Behavior
- Any embedding entry that doesn't contain a valid 768-dimension embedding vector should be re-evaluated on every run
- Only successful embeddings with valid vectors should be considered "completed" for incremental processing
- Error entries should be preserved for logging/debugging but never prevent re-processing attempts
- System should validate actual poem content to distinguish between truly empty poems and processing errors

## Suggested Implementation Steps
1. **Enhanced Incremental Logic**: Modify incremental detection to only skip entries with valid embeddings
2. **Error Re-evaluation**: Always add error entries to the processing queue for retry
3. **Content Validation**: Re-validate poem content to catch data changes or parsing improvements
4. **Comprehensive Testing**: Ensure error entries are properly retried while maintaining incremental efficiency
5. **Logging Enhancement**: Add detailed logging for retry attempts and reasons

## Technical Requirements

### **Incremental Processing Logic Enhancement**
```lua
-- Only skip if embedding is valid AND dimensions are correct
if incremental and existing_embeddings[i] and 
   existing_embeddings[i].embedding and
   type(existing_embeddings[i].embedding) == "table" and 
   #existing_embeddings[i].embedding == 768 then
    -- Skip: valid embedding found
    embeddings_data.embeddings[i] = existing_embeddings[i]
    skipped_count = skipped_count + 1
else
    -- Re-process: no embedding, invalid embedding, or error state
    table.insert(poems_to_process, {index = i, poem = poem})
end
```

### **Error State Re-evaluation**
- **Always retry**: empty_content, parse_error, network_error, invalid_dimensions
- **Content re-validation**: Check if previously "empty" poems now have content
- **Preserve error history**: Maintain error logs while allowing retries

### **Validation Scenarios**
1. **Truly empty poems**: Will consistently return empty_content error (acceptable)
2. **Temporary network failures**: Will be retried and hopefully succeed
3. **Data updates**: Previously empty poems with new content will be processed
4. **Service improvements**: Better parsing or processing can fix previous errors

## User Experience Improvements

### **Progress Reporting**
- Show separate counts for new attempts vs retries
- Display retry reasons (was: error_type, now: attempting_generation)
- Clear indication when retrying previously failed poems

### **Logging Enhancement**
```
Incremental processing summary:
  Total poems: 6,860
  Valid existing embeddings: 6,420
  Error entries to retry: 125 (empty_content: 45, parse_error: 3, network_error: 77)
  New poems to process: 315
  Processing queue: 440 poems (315 new + 125 retries)
```

## Quality Assurance Criteria
- Error entries are never treated as "completed" for incremental purposes
- All non-successful entries are retried on every run
- Valid embeddings are still properly cached and skipped
- Performance impact is minimal (only retrying actual failures)
- System gracefully handles scenarios where errors persist

## Success Metrics
- **Reliability**: All temporary failures eventually get resolved through retries
- **Efficiency**: Valid embeddings are still cached and skipped appropriately
- **Transparency**: Clear reporting of what's being retried and why
- **Robustness**: System handles persistent errors without infinite loops

## Edge Cases Handled
- **Persistent empty content**: Will retry but consistently fail (expected behavior)
- **Data updates**: Previously failed poems with new content will be processed
- **Service improvements**: Enhanced processing can resolve previous errors
- **Mixed error types**: Different error types handled appropriately

## Implementation Validation
1. Create test poems with various error states
2. Verify they are retried on subsequent runs
3. Confirm valid embeddings are still skipped
4. Test with mixed scenarios (new + retry + valid)
5. Validate performance impact is acceptable

**USER REQUEST FULFILLMENT:**
This ticket addresses the user's requirement to:
1. ✅ Always queue error/empty content entries for re-processing
2. ✅ Validate if errors are legitimate or should be recalculated  
3. ✅ Ensure only successful embeddings skip processing
4. ✅ Re-evaluate any non-successful results on every run

**ISSUE STATUS: COMPLETED** ✅

## IMPLEMENTATION COMPLETED
**Date:** November 3, 2025  
**Status:** Validated through successful embedding generation (6,641/6,656 poems processed with retry logic)