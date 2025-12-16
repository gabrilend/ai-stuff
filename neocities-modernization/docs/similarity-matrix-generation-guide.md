# Similarity Matrix Generation Guide

## Overview

This guide covers how to generate similarity matrices for the poetry collection using the parallel similarity engine. The system creates individual JSON files for each poem containing similarity scores to all other poems, optimized for efficient HTML generation.

## Current Status

- ✅ **Embeddings Complete**: 6,641/6,860 poems (96.8%)
- ✅ **Parallel Engine Ready**: Multithreaded with effil library
- ✅ **Resume Capability**: Smart restart from existing files
- ✅ **Temperature Control**: Configurable CPU cooling

## Quick Start

### Interactive Mode (Recommended)

**IMPORTANT**: Run from the project root directory:

```bash
# Make sure you're in the project root:
cd /mnt/mtwo/programming/ai-stuff/neocities-modernization/

# Then run the similarity engine:
lua src/similarity-engine-parallel.lua -I
```

**Interactive prompts:**
1. **Choose option 1**: "Calculate similarity matrix (parallel)"
2. **Force regenerate**: `n` (to resume from existing files)
3. **Sleep duration**: `0.5` (seconds between poems for temperature control)
4. **Model**: `EmbeddingGemma:latest` (or press Enter for default)

### Expected Output
```
✅ Effil threading library loaded successfully
🧵 Using 16 threads (detected 16 CPUs)
⏱️ Sleep duration per poem: 0.5 seconds
📄 Resuming from existing progress: 71/6,641 completed
📊 Remaining poems to process: 6,570

Thread 1: 411 poems (indices 1-411)
Thread 2: 411 poems (indices 412-822)
...
🚀 Starting similarity calculation...
🧵 Using effil multithreading with 16 threads
Thread 1 completed: 411 processed, 0 errors
Thread 2 completed: 411 processed, 0 errors
...
🎉 Similarity calculation completed!
```

## Advanced Usage

### Background Processing
For long-running generation, use background processing:

```bash
nohup lua src/similarity-engine-parallel.lua -I > similarity_generation.log 2>&1 &
# Then provide input when prompted:
# 1 (calculate similarity matrix)
# n (don't force regenerate)
# 0.5 (sleep duration)
# [Enter] (default model)
```

### Custom Temperature Control
Configure sleep duration based on your system:

- **Fast processing**: `0.1` seconds (higher CPU usage, faster completion)
- **Balanced**: `0.5` seconds (recommended for most systems)
- **Conservative**: `1.0` seconds (cooler operation, longer completion time)

### Force Complete Regeneration
If you need to start completely fresh:

```bash
echo -e "1\ny\n0.5\n" | lua src/similarity-engine-parallel.lua -I
```

## Monitoring Progress

### Check Current Status
```bash
echo -e "2\n" | lua src/similarity-engine-parallel.lua -I
```

### Watch File Count in Real-time
```bash
watch -n 10 'ls assets/embeddings/EmbeddingGemma_latest/similarities/ | wc -l'
```

### Monitor System Resources
```bash
# CPU usage
htop

# Disk space
df -h assets/embeddings/

# Memory usage
free -h
```

## Output Structure

### Directory Layout
```
assets/embeddings/EmbeddingGemma_latest/
├── embeddings.json (62MB - original embeddings)
└── similarities/ (NEW - individual poem similarity files)
    ├── poem_1.json (~533KB - all similarities for poem 1)
    ├── poem_2.json (~533KB - all similarities for poem 2)
    ├── poem_3.json (~533KB - all similarities for poem 3)
    └── ... (6,641 total files when complete)
```

### Individual File Format
Each `poem_X.json` file contains:

```json
{
  "metadata": {
    "poem_id": "1",
    "poem_index": 1,
    "total_comparisons": 6640,
    "calculated_at": "2025-11-03 21:45:22",
    "algorithm": "cosine_similarity"
  },
  "similarities": [
    {"id": "42", "index": 42, "similarity": 0.987},
    {"id": "156", "index": 156, "similarity": 0.954},
    {"id": "89", "index": 89, "similarity": 0.943},
    // ... ALL other poems ranked by similarity (highest first)
  ]
}
```

## Resume & Recovery Features

### Interruption Handling
The system is designed to handle interruptions gracefully:

- **Safe to interrupt**: Ctrl+C anytime without data corruption
- **Atomic operations**: Files are either complete or don't exist
- **Automatic cleanup**: Removes temporary files on restart
- **Smart resume**: Only processes poems without valid files
- **Integrity validation**: Checks existing files for completeness on startup

### Recovery Scenarios

| **Interruption Point** | **Result** | **Recovery Action** |
|------------------------|------------|---------------------|
| Before poem processing | No file created | ✅ Poem processed on restart |
| During similarity calculation | No file created | ✅ Poem processed on restart |
| During file write | Temporary file only | ✅ Cleanup removes temp, poem reprocessed |
| After successful write | Complete JSON file | ✅ Poem skipped on restart |

### Corruption Detection
On startup, the system automatically:

1. **Removes temporary files** from interrupted runs
2. **Validates existing JSON files** for completeness
3. **Checks metadata consistency** (total_comparisons vs array length)
4. **Removes corrupted files** and adds them back to processing queue

## Performance Expectations

### Processing Time
- **System**: 16 CPU cores with effil threading
- **Current progress**: 71 poems completed (test runs)
- **Remaining work**: 6,570 poems to process
- **Estimated time**: 2-3 hours with 0.5s sleep interval
- **Memory usage**: ~8GB peak during processing

### Final Output Specifications
- **Total files**: 6,641 individual JSON files
- **File size**: ~533KB per poem file
- **Total size**: ~3.5GB complete similarity matrix
- **Access pattern**: O(1) lookup for any poem's similarities
- **HTML-ready**: Direct file loading without parsing large datasets

## System Requirements

### Minimum Requirements
- **CPU**: 4+ cores (will auto-detect and use all available)
- **RAM**: 8GB+ (for loading full embedding dataset)
- **Disk**: 4GB+ free space for similarity files
- **Lua**: With effil threading library installed

### Optimal Configuration
- **CPU**: 8+ cores for parallel processing
- **RAM**: 16GB+ for smooth operation
- **SSD**: For faster file I/O operations
- **Cooling**: Adequate cooling for sustained CPU load

## Troubleshooting

### Common Issues

#### Effil Library Not Found
```
⚠️ Effil threading not available, using sequential processing
```
**Solution**: The system will fallback to sequential processing. Performance will be slower but functional.

#### Out of Memory
```
lua: not enough memory
```
**Solution**: 
- Reduce the number of threads by modifying the code
- Close other applications to free memory
- Consider processing in smaller batches

#### Disk Space Full
```
ERROR: Failed to write similarity file
```
**Solution**:
- Check available disk space: `df -h`
- Clean up old files or move to larger storage
- Resume processing will continue from where it left off

### Performance Optimization

#### CPU Temperature Management
- Monitor temperatures: `sensors` or `watch -n 5 sensors`
- Increase sleep duration if temperatures exceed safe limits
- Consider underclocking or improving cooling

#### Memory Optimization
- Close unnecessary applications
- Monitor memory usage: `watch -n 5 free -h`
- Consider processing during off-peak hours

## Integration with HTML Generation

### Benefits for Phase 3
The individual file structure provides significant advantages for HTML generation:

1. **Memory Efficiency**: Load only the specific poem's similarities
2. **Fast Access**: Direct file lookup instead of parsing large JSON
3. **Scalability**: Constant memory usage regardless of collection size
4. **Parallel HTML Generation**: Multiple processes can access different files simultaneously

### Usage in HTML Templates
```javascript
// Efficient similarity loading for poem pages
async function loadPoemSimilarities(poemId) {
    const response = await fetch(`/assets/embeddings/EmbeddingGemma_latest/similarities/poem_${poemId}.json`);
    return response.json();
}

// Get top 10 most similar poems
const similarities = await loadPoemSimilarities(42);
const topSimilar = similarities.similarities.slice(0, 10);
```

## Next Steps

Once similarity generation is complete:

1. **Verify completion**: Check that all 6,641 files are generated
2. **Validate sample files**: Ensure similarity scores look reasonable
3. **Prepare for Phase 3**: HTML generation with similarity-based recommendations
4. **Consider additional models**: Generate similarities for other embedding models if needed

## Support

For issues or questions:

1. **Check logs**: Review output for error messages
2. **Validate setup**: Ensure embeddings and effil library are available
3. **Test with small dataset**: Try force regeneration of a few files
4. **Monitor resources**: Check CPU, memory, and disk usage

---

**Last Updated**: November 3, 2025  
**Version**: 1.0  
**Related Documents**: 
- [Embedding Generation Guide](embedding-generation-guide.md)
- [Phase 2 Implementation Issues](../issues/phase-2/)