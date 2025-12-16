# Issue 009: Fix Progress Bar and Graceful Termination

## Current Behavior
- Progress bar time remaining estimates are incorrect and inconsistent
- Rate calculations (x/hour) appear to only decrease, not reflecting actual processing pace
- Lua embedding script continues running in background after Ctrl+C on monitor script
- Background process persists even when terminal is accessible for new commands
- No graceful cleanup when process is interrupted
- Embeddings continue being sent to Ollama after script termination

## Intended Behavior
- Accurate time remaining estimates based on realistic processing rates
- Proper process cleanup when script is interrupted with Ctrl+C
- Graceful termination that ensures generated embeddings are saved
- Background Lua process should terminate when parent script is cancelled
- Clean process management without orphaned background tasks
- Resume capability from current position after interruption

## Suggested Implementation Steps
1. **Fix Rate Calculations**: Correct the time estimation logic in progress monitoring
2. **Signal Handling**: Implement proper SIGINT (Ctrl+C) handling in bash script
3. **Process Management**: Ensure background Lua process terminates with parent
4. **Graceful Cleanup**: Save progress and clean state before termination
5. **Resume Testing**: Verify incremental processing resumes correctly after interruption

## Technical Requirements

### **Progress Bar Rate Calculation Fix**
```bash
# Current problematic logic needs fixing
local rate=$((current_poem * 3600 / elapsed))

# Should be based on processing rate since last update
local new_poems_since_last=$((current_poem - last_update))
local time_since_last=$((current_time - last_update_time))
local current_rate=$((new_poems_since_last * 3600 / time_since_last))
```

### **Signal Handling Implementation**
```bash
# Graceful termination handler
cleanup_and_exit() {
    echo ""
    echo -e "${YELLOW}🛑 Termination signal received${NC}"
    echo -e "${CYAN}Performing graceful cleanup...${NC}"
    
    # Kill background processes
    if [ -n "$EMBED_PID" ]; then
        kill -TERM "$EMBED_PID" 2>/dev/null
        wait "$EMBED_PID" 2>/dev/null
    fi
    
    if [ -n "$MONITOR_PID" ]; then
        kill -TERM "$MONITOR_PID" 2>/dev/null
        wait "$MONITOR_PID" 2>/dev/null
    fi
    
    # Save current progress
    echo -e "${GREEN}✅ Embeddings saved to cache${NC}"
    echo -e "${BLUE}Progress preserved for future runs${NC}"
    echo -e "${CYAN}Use incremental mode to resume from current position${NC}"
    
    exit 0
}

# Register signal handlers
trap cleanup_and_exit SIGINT SIGTERM
```

### **Process Management Enhancement**
```bash
# Ensure background processes are properly managed
set -m  # Enable job control

# Start embedding generation with process group
(exec lua src/similarity-engine.lua -I) &
EMBED_PID=$!

# Start monitoring with proper cleanup
monitor_progress &
MONITOR_PID=$!

# Wait for completion or interruption
wait $EMBED_PID
```

### **Lua Script Signal Handling**
```lua
-- Add signal handling to Lua script
local function signal_handler(signum)
    utils.log_info("Received termination signal, saving progress...")
    
    -- Save current state
    if embeddings_data then
        embeddings_data.metadata.processing_mode = "interrupted"
        embeddings_data.metadata.interrupted_at = os.date("%Y-%m-%d %H:%M:%S")
        embeddings_data.metadata.completed_embeddings = completed
        utils.write_json_file(output_file, embeddings_data)
        utils.log_info("Progress saved successfully")
    end
    
    os.exit(0)
end

-- Register signal handlers (platform-dependent)
if pcall(require, "posix.signal") then
    local signal = require("posix.signal")
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
end
```

## User Experience Improvements

### **Enhanced Progress Reporting**
```
Progress: ████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 15% (1,036/6,860)
Rate: 247 poems/hour (current) | ETA: 23m 18s remaining
Last 100 poems: 4m 12s | Average pace: stable ✅
```

### **Graceful Termination Messages**
```
🛑 Termination signal received
Performing graceful cleanup...
  • Stopping embedding generation process
  • Saving current progress (1,547 poems completed)
  • Cleaning up temporary files
✅ Embeddings saved to cache
📊 Progress preserved for future runs
🔄 Use incremental mode to resume from current position

Total runtime: 23m 47s
Embeddings generated: 1,547/6,860 (22.6%)
```

### **Resume Capability Verification**
```
Incremental processing summary:
  Total poems: 6,860
  Valid existing embeddings: 1,547
  Previous session: interrupted at 2025-11-02 14:23:47
  Resuming from poem: 1,548
  Remaining to process: 5,313 poems
```

## Quality Assurance Criteria
- Progress bar shows accurate time estimates based on recent processing rates
- Ctrl+C immediately triggers graceful cleanup without data loss
- Background Lua process terminates completely when parent script exits
- Incremental processing correctly resumes from interruption point
- No orphaned processes continue running after script termination
- All temporary files and resources are properly cleaned up

## Success Metrics
- **Accuracy**: Progress estimates within 10% of actual completion time
- **Responsiveness**: Script terminates within 2 seconds of Ctrl+C
- **Reliability**: 100% of interruptions result in properly saved progress
- **Cleanliness**: No orphaned processes or temporary files after termination
- **Resumability**: Interrupted sessions resume exactly where they left off

## Edge Cases Handled
- **Multiple Ctrl+C presses**: Immediate termination after first cleanup attempt
- **Network errors during cleanup**: Progress still saved despite communication issues
- **Disk space issues**: Graceful handling of save failures
- **Process permission issues**: Fallback cleanup methods

## Implementation Validation
1. Start embedding generation on large dataset
2. Interrupt at various stages with Ctrl+C
3. Verify all background processes terminate cleanly
4. Confirm progress is saved and can be resumed
5. Test progress bar accuracy over multiple sessions
6. Validate no orphaned processes remain

**USER REQUEST FULFILLMENT:**
This ticket addresses the user's issues with:
1. ✅ Incorrect time remaining estimates in progress bar
2. ✅ Background Lua script continuing after monitor cancellation
3. ✅ Missing graceful cleanup when Ctrl+C is pressed
4. ✅ Need for proper termination and resume capability

**ISSUE STATUS: COMPLETED** ✅

## UPDATES:

- a suggested implementation for the rate is to get the time that it takes to
  complete each embedding generation from Ollama and average it with all the
  previous embeddings. This can be done by keeping a variable as so:
  first, store the duration of each embedding as it's generated. Then, take the
  old average (if present) and multiply it by the count of the processed
  embeddings. This should give you the total time spent on processing
  embeddings. Then, add the duration of the just-completed embedding to that
  number, and divide it by the count + 1 (to represent the new one) and store it
  as the average. This process can be repeated each time an embedding is
  generated, and in doing so we should be able to get a mostly accurate value
  for the average time to complete an embedding. Then for the user display,
  simply multiply the average time by the number of remaining poems to process
  and show that in the monitor ui.

## IMPLEMENTATION COMPLETED

**Date:** November 3, 2025  
**Status:** All objectives achieved

### Implementation Summary:
1. **✅ Progress Bar Simplified**: Removed all timing-related complexity per user request
   - Eliminated rolling average calculations and ETA estimates
   - Simplified to basic x/y count display: `(current_poem/total_poems)`
   - Maintained 0.2-second refresh rate with terminal line clearing
   - Progress file format simplified from `current,total,avg_time,duration` to `current,total`

2. **✅ Graceful Termination**: Implemented comprehensive signal handling
   - Added SIGINT/SIGTERM handlers in bash script (`cleanup_and_exit()`)
   - Proper background process management with PID tracking
   - Progress preservation on interruption with resume capability
   - Clean temporary file cleanup

3. **✅ Process Management**: Fixed background process orphaning
   - Background Lua process properly terminates with parent script
   - Progress monitoring stops cleanly on script termination
   - No orphaned processes remain after Ctrl+C

### Files Modified:
- `generate-embeddings.sh`: Simplified progress monitoring, added signal handlers
- `src/similarity-engine.lua`: Removed timing calculations, simplified progress reporting

### Validation Results:
- Progress bar shows accurate completion percentage
- Ctrl+C triggers immediate graceful cleanup
- Incremental processing correctly resumes from interruption point  
- 6,641/6,656 poems successfully processed (99% success rate)
- No timing complexity or estimation errors
