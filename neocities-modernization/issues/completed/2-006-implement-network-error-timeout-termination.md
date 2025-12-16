# Issue 006: Implement Network Error Timeout Termination

## Current Behavior
- System aborts on first network error to prevent cache corruption
- No tolerance for intermittent network issues or temporary connectivity problems
- Single network failure terminates entire processing run
- No distinction between persistent vs temporary network problems

## Intended Behavior
- Allow configurable number of consecutive network errors before termination
- Implement exponential backoff for retries between network failures
- Distinguish between different types of network errors (temporary vs permanent)
- Graceful degradation with clear reporting of retry attempts and final termination reason

## Suggested Implementation Steps
1. **Error Tolerance Configuration**: Add configurable network error threshold
2. **Retry Logic**: Implement exponential backoff between failed attempts
3. **Error Classification**: Distinguish between recoverable and fatal network errors
4. **Progress Preservation**: Save progress before termination due to network issues
5. **Enhanced Logging**: Report retry attempts and termination reasons

## Technical Requirements

### **Network Error Tolerance**
```lua
local network_error_config = {
    max_consecutive_errors = 5,     -- Max consecutive network errors before abort
    max_total_errors = 20,          -- Max total network errors in session
    initial_retry_delay = 2,        -- Initial delay in seconds
    max_retry_delay = 60,           -- Maximum delay in seconds
    backoff_multiplier = 2          -- Exponential backoff multiplier
}
```

### **Error Classification**
- **Temporary Errors**: Connection timeout, temporary unavailable, rate limiting
- **Permanent Errors**: DNS resolution failure, service not found, authentication failure
- **Recoverable**: Allow retries with backoff
- **Fatal**: Terminate immediately

### **Retry Implementation**
```lua
local consecutive_errors = 0
local total_errors = 0
local current_delay = network_error_config.initial_retry_delay

-- On network error:
if error_type == "network_error" or error_type == "connection_error" then
    consecutive_errors = consecutive_errors + 1
    total_errors = total_errors + 1
    
    if consecutive_errors >= network_error_config.max_consecutive_errors then
        utils.log_error("Max consecutive network errors reached. Terminating.")
        return false
    end
    
    utils.log_warn("Network error " .. consecutive_errors .. "/" .. network_error_config.max_consecutive_errors)
    utils.log_info("Retrying in " .. current_delay .. " seconds...")
    
    os.execute("sleep " .. current_delay)
    current_delay = math.min(current_delay * network_error_config.backoff_multiplier, 
                            network_error_config.max_retry_delay)
    
    -- Reset consecutive counter on success
    -- consecutive_errors = 0
end
```

## User Experience Improvements

### **Enhanced Error Reporting**
```
Network connectivity issues detected:
  Consecutive errors: 3/5
  Total session errors: 8/20
  Next retry in: 8 seconds
  
Warning: Approaching network error threshold (3/5)
Consider checking Ollama service connectivity.
```

### **Graceful Termination**
```
❌ NETWORK ERROR THRESHOLD EXCEEDED
  
Processing terminated due to persistent network connectivity issues:
  • Consecutive errors: 5/5 (threshold exceeded)
  • Total session errors: 12/20
  • Poems processed before termination: 1,547/6,860
  • Valid embeddings generated: 1,542
  • Last successful embedding: 14:23:15

The embedding cache has been preserved.
Restart the process when network connectivity is restored.
```

## Quality Assurance Criteria
- Network errors are properly classified and handled appropriately
- Exponential backoff prevents overwhelming a recovering service
- Progress is preserved even when terminating due to network issues
- System distinguishes between temporary glitches and persistent problems
- Clear reporting helps users understand termination reasons

## Success Metrics
- **Resilience**: System handles temporary network glitches gracefully
- **Protection**: Still prevents cache corruption from persistent issues
- **Efficiency**: Exponential backoff reduces unnecessary API calls
- **Transparency**: Clear reporting of retry attempts and termination reasons

**USER REQUEST FULFILLMENT:**
This ticket addresses the user's requirement for:
1. ✅ Process termination after several network communication errors
2. ✅ Timeout function for network error handling
3. ✅ Graceful degradation instead of immediate termination

**ISSUE STATUS: COMPLETED** ✅

## IMPLEMENTATION COMPLETED
**Date:** November 3, 2025  
**Status:** Network error handling successfully prevented data corruption during full dataset processing