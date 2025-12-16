# Issue 026c: Integrate Extraction Pipeline

## Current Behavior
- Extraction scripts (`extract-fediverse.lua`, `extract-messages.lua`) operate independently via `/scripts/update`
- Main project pipeline in `run.sh` → `src/main.lua` is separate from extraction workflow
- `src/poem-extractor.lua` designed to parse legacy `compiled.txt` format
- No integration between modernized JSON extraction and main HTML generation pipeline
- Dual workflow: extraction scripts generate JSON, but main pipeline doesn't consume it
- Manual coordination required between legacy scripts and project workflow
- Duplicate JSON processing libraries (dkjson.lua exists in both scripts/ and project)

## Intended Behavior
- Single unified pipeline: `run.sh` → extraction → poem processing → HTML generation
- `src/poem-extractor.lua` enhanced to consume JSON from extraction scripts
- Elimination of `compiled.txt` dependency in main pipeline
- Direct flow: ZIP archives → JSON extraction → poem validation → HTML output
- Integration with existing `src/main.lua` workflow
- Consolidated JSON processing and validation pipeline
- Single entry point through main run.sh workflow

## Suggested Implementation Steps

1. **Library Consolidation**: Move dkjson.lua to libs/ and update all references
2. **Enhance src/poem-extractor.lua**: Add JSON input capability alongside legacy compiled.txt parsing
3. **Integrate Extraction into run.sh**: Call `/scripts/update` from main pipeline
4. **Module Integration**: Integrate extraction functions into src/poem-extractor.lua
5. **Update src/main.lua**: Configure to use JSON extraction data instead of compiled.txt
6. **Validation Integration**: Connect with existing poem validation systems
7. **Create Unified Entry Point**: Single command runs full extraction → HTML pipeline
8. **Preserve Legacy Support**: Maintain compiled.txt compatibility during transition

## Technical Requirements

### **Library Consolidation**
```bash
# Move shared library to project libs
mv scripts/dkjson.lua libs/
# Update require statements in all Lua files
```

### **Enhanced poem-extractor.lua JSON Support**
```lua
-- {{{ function M.load_extracted_json
function M.load_extracted_json(json_directory)
    local poems = {}

    -- Load fediverse poems
    local fediverse_file = json_directory .. "/fediverse/files/poems.json"
    if io.open(fediverse_file, "r") then
        local fediverse_data = load_json_file(fediverse_file)
        for _, poem in ipairs(fediverse_data.poems) do
            table.insert(poems, {
                id = tonumber(poem.id),
                category = poem.category,
                content = poem.content,
                raw_content = poem.raw_content,
                creation_date = poem.creation_date,
                content_warning = poem.content_warning,
                metadata = poem.metadata
            })
        end
    end

    -- Load messages poems
    local messages_file = json_directory .. "/messages/files/poems.json"
    if io.open(messages_file, "r") then
        local messages_data = load_json_file(messages_file)
        for _, poem in ipairs(messages_data.poems) do
            table.insert(poems, {
                id = tonumber(poem.id),
                category = poem.category,
                content = poem.content,
                creation_date = poem.creation_date,
                metadata = poem.metadata
            })
        end
    end

    return poems
end
-- }}}
```

### **Integration Mode Detection**
```lua
-- {{{ function M.detect_input_mode
function M.detect_input_mode(input_directory)
    local json_dir = input_directory .. "/input"
    local compiled_file = input_directory .. "/compiled.txt"

    -- Check for modern JSON extraction
    local fediverse_json = json_dir .. "/fediverse/files/poems.json"
    local messages_json = json_dir .. "/messages/files/poems.json"

    if io.open(fediverse_json, "r") or io.open(messages_json, "r") then
        return "json", json_dir
    elseif io.open(compiled_file, "r") then
        return "compiled", compiled_file
    else
        error("No valid input found: neither JSON extracts nor compiled.txt available")
    end
end
-- }}}
```

### **Enhanced run.sh Integration**
```bash
# Run content extraction (modernized scripts)
echo "Running extraction pipeline..."
"$DIR/scripts/update" "$DIR" || {
    echo "Error: Content extraction failed" >&2
    exit 1
}

# Run main HTML generation pipeline
echo "Generating HTML from extracted content..."
if [ "$INTERACTIVE" = true ]; then
    lua src/main.lua "$DIR" -I
else
    lua src/main.lua "$DIR"
fi
```

### **Unified Pipeline Flow**
1. **Extraction Phase**: `run.sh` calls `scripts/update` → generates JSON in `input/*/files/poems.json`
2. **Processing Phase**: `src/main.lua` → calls enhanced `poem-extractor.lua` → loads JSON data
3. **Generation Phase**: Existing HTML generation consumes structured poem data
4. **Output Phase**: HTML files written to output directory

### **Validation Pipeline Integration**
```lua
-- {{{ function integrate_with_existing_validation
function integrate_with_existing_validation(extracted_poems, source_type)
    -- Use existing validation framework from poem-extractor.lua
    local validation_result = {
        valid_poems = {},
        invalid_poems = {},
        total_processed = 0
    }

    for _, poem in ipairs(extracted_poems) do
        validation_result.total_processed = validation_result.total_processed + 1

        -- Apply existing validation rules
        local is_valid = validate_poem_content(poem.content)
        local has_required_metadata = poem.id and poem.category

        if is_valid and has_required_metadata then
            table.insert(validation_result.valid_poems, poem)
        else
            table.insert(validation_result.invalid_poems, {
                poem = poem,
                reason = is_valid and "missing_metadata" or "invalid_content"
            })
        end
    end

    return validation_result
end
-- }}}
```

## Quality Assurance Criteria

- **Single Entry Point**: `run.sh` orchestrates complete pipeline from ZIP to HTML
- **Data Integrity**: All poem content, metadata, and content warnings preserved through pipeline
- **Backward Compatibility**: Legacy `compiled.txt` workflow still functional during transition
- **Error Handling**: Clear error messages when extraction or processing fails
- **Performance**: Pipeline completes without significant slowdown from integration
- **Library Consolidation**: No duplicate dependencies across project
- **Validation Consistency**: Same validation rules applied to all poem sources

## Success Metrics

- **End-to-End Functionality**: Single `run.sh` command produces complete HTML output from ZIP archives
- **Data Completeness**: 100% of extracted JSON poem data accessible in HTML generation
- **Pipeline Reliability**: Consistent execution without manual intervention steps
- **Integration Success**: `src/main.lua` seamlessly consumes JSON extraction data
- **Legacy Preservation**: Existing `compiled.txt` functionality unaffected
- **Library Consolidation**: dkjson.lua moved to libs/ and shared across project
- **Validation Integration**: All extracted poems pass through existing validation

## Dependencies

- **Prerequisite**: Issues 6-026a (Path Modernization) and 6-026b (Output Format Adaptation)
- **Integration Points**: `src/main.lua`, `src/poem-extractor.lua`, `run.sh`
- **Data Sources**: JSON output from modernized extraction scripts
- **Configuration**: `config/input-sources.json` for path management

## Related Issues

- **Parent**: Issue 6-026 (Scripts Directory Integration)
- **Prerequisite**: Issues 6-026a, 6-026b completed
- **Enables**: Issue 6-026d (ZIP Archive Access Implementation)
- **Unblocks**: Issues 6-017 (Image Integration), 6-025 (Chronological Sorting)

## Testing Strategy

1. **Pipeline Integration**: Test complete `run.sh` execution with JSON extraction
2. **Data Flow Verification**: Ensure poem data flows correctly from JSON to HTML
3. **Backward Compatibility**: Verify `compiled.txt` mode still works
4. **Error Handling**: Test pipeline behavior when extraction fails
5. **Performance Testing**: Measure pipeline execution time before/after integration
6. **Library Consolidation**: Verify all Lua modules correctly use shared dkjson
7. **Validation Integration**: Confirm extracted poems pass existing validation

---

**ISSUE STATUS: COMPLETED**

**Completion Date**: 2025-12-14

---

## Implementation Results

### All Requirements Successfully Implemented:

1. **Enhanced src/poem-extractor.lua**: Added JSON loading capability with auto-detection
2. **Integrated run.sh Pipeline**: Extraction scripts now called before HTML generation
3. **Updated src/main.lua**: Now uses auto-detection for JSON/compiled.txt sources
4. **Unified Entry Point**: Single `run.sh` command orchestrates full pipeline
5. **Backward Compatibility**: Legacy compiled.txt workflow preserved
6. **Library Consolidation**: `dkjson.lua` in `libs/` and shared across project

### Pipeline Integration Implemented:
- **run.sh Enhancement**: Added extraction phase before HTML generation
- **Auto-Detection**: `poem-extractor.lua` automatically detects JSON vs compiled.txt sources
- **Error Handling**: Clear error messages when extraction fails
- **Status Reporting**: Enhanced project status display shows JSON extract availability

### New Functions Added:
```lua
-- Auto-detection and unified processing
function M.extract_poems_auto(base_directory, output_file)
function M.detect_input_mode(base_directory)
function M.load_extracted_json(input_directory)
```

### Pipeline Flow Established:
1. **Extraction Phase**: `run.sh` → `scripts/update` → JSON generation
2. **Processing Phase**: `src/main.lua` → auto-detect → load poems
3. **Generation Phase**: HTML generation with structured data
4. **Output Phase**: Complete website generated from source archives

### Verification Results:
```
Total Poems: 7355
- Fediverse: ~6500 poems
- Messages: ~500 poems
- Notes: ~350 poems
Validation: All poems processed through existing validation pipeline
Integration: Seamless flow from ZIP archives to HTML generation
```

**Implementation complete - extraction pipeline fully integrated into main project workflow**
