# Issue 5-026: Optimize Chronological HTML Generation Performance

## Current Behavior
- The chronological.html file generation is extremely slow (times out after 2 minutes)
- Generated file is 12MB with 93,751 lines containing what appears to be PDF binary data mixed with HTML
- Browser performance is severely impacted when loading the page
- The flat-html-generator.lua script processes 6,580+ poems synchronously
- Generation of complete site (13,680+ pages) times out and cannot complete

## Intended Behavior
- Generate chronological.html efficiently within 30 seconds
- Produce clean HTML output without embedded binary data or PDF content
- Create browser-friendly HTML that loads quickly
- Support incremental/parallel generation for better performance
- Generate all required pages (chronological, similar, unique) successfully

## Suggested Implementation Steps

### 1. **Fix Content Corruption Issue**
The current output contains PDF binary data instead of poem content:
```lua
-- Check format_content_with_warnings function
-- Ensure poem.content is properly extracted text, not binary data
-- Verify apply_markdown_formatting doesn't corrupt content
```

### 2. **Implement Chunked/Paginated Generation**
```lua
-- {{{ function generate_chronological_chunks
local function generate_chronological_chunks(poems_data, chunk_size)
    chunk_size = chunk_size or 100
    local chunks = {}
    
    for i = 1, #poems_data.poems, chunk_size do
        local chunk_end = math.min(i + chunk_size - 1, #poems_data.poems)
        table.insert(chunks, {
            start = i,
            finish = chunk_end,
            poems = {table.unpack(poems_data.poems, i, chunk_end)}
        })
    end
    
    return chunks
end
-- }}}
```

### 3. **Add Progress Tracking and Logging**
```lua
-- {{{ function generate_with_progress
local function generate_with_progress(poems_data, output_dir)
    local total = #poems_data.poems
    local processed = 0
    
    for i, poem in ipairs(poems_data.poems) do
        -- Process poem
        processed = processed + 1
        
        -- Log progress every 100 poems
        if processed % 100 == 0 then
            utils.log_info(string.format("Progress: %d/%d poems (%.1f%%)", 
                processed, total, (processed/total)*100))
        end
    end
end
-- }}}
```

### 4. **Optimize Memory Usage**
```lua
-- Stream writing instead of concatenating huge strings
local function write_chronological_streaming(poems_data, output_file)
    local file = io.open(output_file, "w")
    
    -- Write header
    file:write(HTML_HEADER)
    
    -- Stream poem content
    for _, poem in ipairs(poems_data) do
        local poem_html = format_single_poem(poem)
        file:write(poem_html)
        file:flush() -- Periodic flush to free memory
    end
    
    -- Write footer
    file:write(HTML_FOOTER)
    file:close()
end
```

### 5. **Implement Parallel Generation**
```lua
-- Generate similarity/unique pages in parallel using coroutines
local function generate_pages_parallel(poems_data, output_dir)
    local tasks = {}
    
    -- Create tasks for each poem's pages
    for _, poem in ipairs(poems_data.poems) do
        table.insert(tasks, coroutine.create(function()
            generate_similarity_page(poem, output_dir)
            generate_unique_page(poem, output_dir)
        end))
    end
    
    -- Execute tasks with controlled concurrency
    local max_concurrent = 10
    execute_tasks_with_limit(tasks, max_concurrent)
end
```

### 6. **Add Caching Layer**
```lua
-- Cache processed poem HTML to avoid reprocessing
local poem_html_cache = {}

local function get_poem_html_cached(poem)
    local cache_key = tostring(poem.id)
    
    if not poem_html_cache[cache_key] then
        poem_html_cache[cache_key] = format_poem_html(poem)
    end
    
    return poem_html_cache[cache_key]
end
```

### 7. **Create Minimal Test Mode**
```lua
-- Add option to generate with subset for testing
local function generate_test_site(poem_limit)
    poem_limit = poem_limit or 100
    
    local test_poems = {
        poems = {table.unpack(poems_data.poems, 1, poem_limit)}
    }
    
    return generate_site(test_poems)
end
```

## Performance Targets
- **Chronological index generation**: < 30 seconds for 7,000 poems
- **Complete site generation**: < 5 minutes for all 13,680+ pages
- **Memory usage**: < 500MB during generation
- **File sizes**: Chronological.html < 2MB (currently 12MB)
- **Browser load time**: < 3 seconds for chronological.html

## Files to Modify
- `/src/flat-html-generator.lua` - Main generation logic
- `/src/html-generator/template-engine.lua` - Template processing
- `/libs/utils.lua` - Add streaming/chunking utilities
- Create new `/src/parallel-generator.lua` for concurrent generation

## Testing Requirements
- Verify generated HTML contains actual poem text, not binary data
- Confirm all navigation links work correctly
- Test browser performance with generated pages
- Validate generation completes within time limits
- Check memory usage stays within constraints
- Ensure incremental generation produces identical output

## Priority
**HIGH** - Site generation is currently broken and unusable due to performance issues

## Dependencies
- poems.json data file must be properly formatted
- Similarity matrices must be pre-calculated
- System must have sufficient memory for caching

## Related Issues
- 5-025: Similarity matrix optimization (may help with memory usage)
- 5-013: Flat HTML recreation (related to output format)

## Notes
The core issue appears to be that the generator is including raw PDF/binary data in the HTML output instead of extracted poem text. This needs to be fixed first before optimizing performance. The 12MB file size and browser crashes are symptoms of this data corruption issue.