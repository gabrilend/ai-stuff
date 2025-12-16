#!/usr/bin/env lua

-- {{{ local function setup_dir_path
local function setup_dir_path(provided_dir)
    if provided_dir then
        return provided_dir
    end
    return "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
end
-- }}}

-- Script configuration
local DIR = setup_dir_path()

-- Load required libraries
package.path = DIR .. "/libs/?.lua;" .. DIR .. "/src/?.lua;" .. package.path
local dkjson = require("dkjson")

-- {{{ local function relative_path
local function relative_path(absolute_path)
    if absolute_path:sub(1, #DIR) == DIR then
        local rel = absolute_path:sub(#DIR + 1)
        if rel:sub(1, 1) == "/" then rel = rel:sub(2) end
        return "./" .. rel
    end
    return absolute_path
end
-- }}}

local M = {}

-- {{{ local function generate_character_distribution_report
local function generate_character_distribution_report(validation_stats)
    local report = {
        "Character Count Distribution (Top 20 by Frequency):",
        "====================================================",
        ""
    }

    -- Collect all lengths with their counts
    local lengths = {}
    for length_str, count in pairs(validation_stats.character_distribution or {}) do
        table.insert(lengths, {length = tonumber(length_str), count = count})
    end

    -- Sort by number of occurrences (descending), not by character length
    table.sort(lengths, function(a, b) return a.count > b.count end)

    -- Show top 20 results only
    local display_count = math.min(20, #lengths)
    for i = 1, display_count do
        local item = lengths[i]
        local marker = ""
        if item.length == 1024 then
            marker = " ← GOLDEN POEMS"
        end

        table.insert(report, string.format("%d poems @ %d characters%s",
                                         item.count, item.length, marker))
    end

    -- Show how many more entries exist
    if #lengths > 20 then
        table.insert(report, string.format("... and %d more unique character counts", #lengths - 20))
    end

    -- Category breakdown if available
    if validation_stats.by_category and next(validation_stats.by_category) then
        table.insert(report, "")
        table.insert(report, "By Category:")
        table.insert(report, "------------")
        for cat, cat_stats in pairs(validation_stats.by_category) do
            local golden_info = ""
            if cat_stats.golden > 0 then
                golden_info = string.format(" (%d golden)", cat_stats.golden)
            end
            table.insert(report, string.format("  %s: %d poems%s", cat, cat_stats.total, golden_info))
        end
    end

    return table.concat(report, "\n")
end
-- }}}

-- {{{ local function analyze_poem_content
local function analyze_poem_content(poem)
    local analysis = {
        id = poem.id,
        filename = poem.filename,
        category = poem.category,
        has_content = poem.content and #poem.content > 0,
        length = poem.length,
        actual_length = poem.content and #poem.content or 0,
        length_matches = poem.length == (poem.content and #poem.content or 0),
        line_count = 0,
        word_count = 0,
        char_distribution = {},
        is_fediverse_length = false,  -- Exactly 1024 chars or less
        -- Use pre-calculated golden poem status from extraction metadata
        golden_poem_character_count = poem.metadata and poem.metadata.golden_poem_character_count or nil,
        is_golden_poem = poem.metadata and poem.metadata.is_golden_poem or false
    }
    
    if poem.content and #poem.content > 0 then
        -- Count lines
        analysis.line_count = select(2, poem.content:gsub('\n', '\n')) + 1
        
        -- Count words (simple whitespace split)
        for word in poem.content:gmatch("%S+") do
            analysis.word_count = analysis.word_count + 1
        end
        
        -- Character distribution analysis
        for char in poem.content:gmatch(".") do
            analysis.char_distribution[char] = (analysis.char_distribution[char] or 0) + 1
        end
        
        -- Check if it's fediverse-compatible length (1024 chars including content warning)
        analysis.is_fediverse_length = analysis.actual_length <= 1024
    end
    
    return analysis
end
-- }}}

-- {{{ local function detect_duplicates
local function detect_duplicates(poems)
    local content_hash = {}
    local duplicates = {}
    
    for _, poem in ipairs(poems) do
        if poem.content and #poem.content > 10 then  -- Only check non-trivial content
            local content = poem.content:gsub("%s+", " "):lower()  -- Normalize whitespace and case
            
            if content_hash[content] then
                table.insert(duplicates, {
                    original = content_hash[content],
                    duplicate = poem.id,
                    content_preview = poem.content:sub(1, 50) .. "..."
                })
            else
                content_hash[content] = poem.id
            end
        end
    end
    
    return duplicates
end
-- }}}


-- {{{ local function generate_statistics
local function generate_statistics(analyses)
    local stats = {
        total_poems = #analyses,
        empty_poems = 0,
        non_empty_poems = 0,
        total_words = 0,
        total_characters = 0,
        fediverse_compatible = 0,
        golden_poems = 0,  -- Using pre-calculated metadata from extraction
        character_distribution = {},
        length_mismatches = 0,
        average_length = 0,
        median_length = 0,
        max_length = 0,
        min_length = math.huge,
        length_distribution = {
            ["0"] = 0,           -- Empty
            ["1-100"] = 0,       -- Very short
            ["101-500"] = 0,     -- Short
            ["501-1024"] = 0,    -- Fediverse length
            ["1025-2000"] = 0,   -- Medium
            ["2000+"] = 0        -- Long
        },
        by_category = {}  -- Track stats per category
    }
    
    local lengths = {}

    for _, analysis in ipairs(analyses) do
        -- Track by category
        local cat = analysis.category or "unknown"
        if not stats.by_category[cat] then
            stats.by_category[cat] = { total = 0, golden = 0 }
        end
        stats.by_category[cat].total = stats.by_category[cat].total + 1

        if analysis.has_content then
            stats.non_empty_poems = stats.non_empty_poems + 1
            stats.total_words = stats.total_words + analysis.word_count
            stats.total_characters = stats.total_characters + analysis.actual_length

            if analysis.actual_length > stats.max_length then
                stats.max_length = analysis.actual_length
            end
            if analysis.actual_length < stats.min_length then
                stats.min_length = analysis.actual_length
            end

            table.insert(lengths, analysis.actual_length)
        else
            stats.empty_poems = stats.empty_poems + 1
        end

        if analysis.is_fediverse_length then
            stats.fediverse_compatible = stats.fediverse_compatible + 1
        end

        -- Use pre-calculated golden poem status from extraction metadata
        if analysis.is_golden_poem then
            stats.golden_poems = stats.golden_poems + 1
            stats.by_category[cat].golden = stats.by_category[cat].golden + 1
        end

        -- Track character distribution using golden_poem_character_count if available
        local char_count = analysis.golden_poem_character_count or analysis.actual_length
        local length_key = tostring(char_count)
        stats.character_distribution[length_key] = (stats.character_distribution[length_key] or 0) + 1

        if not analysis.length_matches then
            stats.length_mismatches = stats.length_mismatches + 1
        end

        -- Length distribution
        local len = analysis.actual_length
        if len == 0 then
            stats.length_distribution["0"] = stats.length_distribution["0"] + 1
        elseif len <= 100 then
            stats.length_distribution["1-100"] = stats.length_distribution["1-100"] + 1
        elseif len <= 500 then
            stats.length_distribution["101-500"] = stats.length_distribution["101-500"] + 1
        elseif len <= 1024 then
            stats.length_distribution["501-1024"] = stats.length_distribution["501-1024"] + 1
        elseif len <= 2000 then
            stats.length_distribution["1025-2000"] = stats.length_distribution["1025-2000"] + 1
        else
            stats.length_distribution["2000+"] = stats.length_distribution["2000+"] + 1
        end
    end
    
    -- Calculate averages
    if stats.non_empty_poems > 0 then
        stats.average_length = stats.total_characters / stats.non_empty_poems
        
        -- Calculate median
        table.sort(lengths)
        local mid = math.floor(#lengths / 2)
        if #lengths % 2 == 0 then
            stats.median_length = (lengths[mid] + lengths[mid + 1]) / 2
        else
            stats.median_length = lengths[mid + 1]
        end
    end
    
    if stats.min_length == math.huge then
        stats.min_length = 0
    end
    
    return stats
end
-- }}}

-- {{{ function M.validate_poems
function M.validate_poems(poems_file, output_file)
    print("Loading poems from: " .. relative_path(poems_file))
    
    -- Load poems data
    local file = io.open(poems_file, "r")
    if not file then
        error("Could not open poems file: " .. poems_file)
    end
    
    local content = file:read("*all")
    file:close()
    
    local data = dkjson.decode(content)
    if not data or not data.poems then
        error("Invalid poems file format")
    end
    
    local poems = data.poems
    print("Validating " .. #poems .. " poems...")
    
    -- Analyze each poem
    local analyses = {}
    for _, poem in ipairs(poems) do
        table.insert(analyses, analyze_poem_content(poem))
    end
    
    -- Detect duplicates
    print("Checking for duplicate content...")
    local duplicates = detect_duplicates(poems)

    -- Generate statistics
    print("Generating statistics...")
    local statistics = generate_statistics(analyses)

    -- Create validation report
    local report = {
        metadata = {
            source_file = poems_file,
            validated_at = os.date("%Y-%m-%d %H:%M:%S"),
            validation_version = "2.0"
        },
        summary = {
            total_poems = #poems,
            source_metadata = data.metadata
        },
        statistics = statistics,
        duplicates = duplicates,
        detailed_analyses = analyses
    }
    
    -- Save report
    local json_output = dkjson.encode(report, { indent = true })
    local output = io.open(output_file, "w")
    if not output then
        error("Could not create output file: " .. output_file)
    end
    
    output:write(json_output)
    output:close()
    
    -- Print summary
    print("\n=== VALIDATION SUMMARY ===")
    print("Total Poems: " .. statistics.total_poems)
    print("Non-empty Poems: " .. statistics.non_empty_poems)
    print("Empty Poems: " .. statistics.empty_poems)
    print("Average Length: " .. string.format("%.1f", statistics.average_length) .. " characters")
    print("Median Length: " .. string.format("%.1f", statistics.median_length) .. " characters")
    print("Fediverse Compatible (≤1024 chars): " .. statistics.fediverse_compatible)
    print("Golden Poems (exactly 1024 chars): " .. statistics.golden_poems)
    print("Duplicate Content: " .. #duplicates .. " pairs")
    
    -- Add character distribution report
    print("\n" .. generate_character_distribution_report(statistics))
    
    print("\nValidation report saved to: " .. relative_path(output_file))
    return report
end
-- }}}

-- {{{ function M.main
function M.main(interactive_mode)
    if interactive_mode then
        print("=== Poem Validation Tool ===")
        print("1. Validate extracted poems.json")
        print("2. Validate custom file")
        io.write("Select option (1-2): ")
        local choice = io.read()
        
        local input_file, output_file
        
        if choice == "1" then
            input_file = DIR .. "/assets/poems.json"
            output_file = DIR .. "/assets/validation-report.json"
        elseif choice == "2" then
            io.write("Enter input file path: ")
            input_file = io.read()
            io.write("Enter output file path: ")
            output_file = io.read()
        else
            print("Invalid choice")
            return
        end
        
        M.validate_poems(input_file, output_file)
    else
        -- Default non-interactive mode
        local input_file = DIR .. "/assets/poems.json"
        local output_file = DIR .. "/assets/validation-report.json"
        M.validate_poems(input_file, output_file)
    end
end
-- }}}

-- Command line execution (only when run directly, not when required as module)
if arg and arg[0] and arg[0]:match("poem%-validator%.lua$") then
    local interactive_mode = false
    for i, arg_val in ipairs(arg) do
        if arg_val == "-I" then
            interactive_mode = true
            break
        end
    end

    M.main(interactive_mode)
end

return M