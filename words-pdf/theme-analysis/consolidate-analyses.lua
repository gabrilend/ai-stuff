#!/usr/bin/env luajit

-- Analysis Consolidation System
-- Combines 40 individual analyses into unified theme taxonomy

function get_analysis_files()
    local analyses = {}
    local handle = io.popen("ls theme-analysis/analyses/analysis_*.analysis 2>/dev/null | sort")
    if handle then
        for filename in handle:lines() do
            table.insert(analyses, filename)
        end
        handle:close()
    end
    return analyses
end

function count_analysis_words()
    local total_words = 0
    local files = get_analysis_files()
    
    for _, file in ipairs(files) do
        local f = io.open(file, "r")
        if f then
            local content = f:read("*all")
            f:close()
            local words = select(2, content:gsub("%S+", ""))
            total_words = total_words + words
        end
    end
    
    return total_words, #files
end

function create_consolidation_prompt(pass_number, previous_output)
    local analyses = get_analysis_files()
    
    if #analyses == 0 then
        error("No analysis files found. Run analyze_parallel.lua first.")
    end
    
    local prompts = {}
    
    -- Pass 1: Initial consolidation focusing on Tier 1 (10 core themes)
    prompts[1] = string.format([[
I need you to consolidate %d individual theme analyses into a multi-tiered theme taxonomy for a ~550k word poetry/text corpus. This is PASS 1 of 3.

**Pass 1 Focus: Tier 1 Core Themes (10 Primary Categories)**

**Your Task:**
1. **Merge Similar Themes** - Combine related concepts across all analyses
2. **Identify 10 Core Themes** - The most prevalent and significant themes
3. **Create Detailed Specifications** - For each of the 10 core themes

**Output Format:**

# Multi-Tiered Theme Taxonomy - Pass 1: Core Themes

## Overview
- Total individual themes identified: [count all unique themes found]
- Analysis methodology: Consolidation of %d slice analyses
- Corpus characteristics: [key observations from all analyses]
- Pass 1 focus: 10 core themes with detailed specifications

## Tier 1: Core Themes (10 Primary Categories)

### [theme_name]
- **Description:** [2-3 sentences describing the theme]
- **Keywords:** [15-20 terms for embedding recognition]
- **Prevalence:** [estimated percentage of corpus]
- **Visual Style:**
  - Colors: [specific color palette]
  - Patterns: [geometric/organic patterns]  
  - Movement: [static/flowing/explosive/etc]
  - Shapes: [primary visual elements]
- **Art Implementation:**
  - Algorithm suggestions: [specific techniques]
  - Code approach: [technical guidance]
  - Parameters: [key variables to control]
- **Examples from corpus:** [brief quotes that exemplify this theme]

[Repeat for each of 10 core themes]

## Tier 1 Complete Keyword Dictionary
```lua
tier1_keywords = {
    [theme_name] = {"keyword1", "keyword2", ...},
    ...
}
```

## Analysis Notes for Pass 2
[Notes on themes that should be expanded into Tier 2, patterns observed, themes that need subdivision]

Here are the %d individual analyses to consolidate:

]], #analyses, #analyses, #analyses)

    -- Pass 2: Expand to Tier 2 (20 themes total, pyramid structure) 
    prompts[2] = string.format([[
This is PASS 2 of 3. Build on the previous analysis to create a TRUE PYRAMID STRUCTURE with 20 total themes in Tier 2.

**Pass 2 Focus: Tier 2 Extended Themes (20 Categories Total)**

**CRITICAL: PYRAMID STRUCTURE REQUIREMENTS:**
- Tier 1: 10 core themes (foundation - keep from Pass 1)
- Tier 2: 20 total themes that INCLUDE and EXPAND the 10 Tier 1 themes
- Think of it as a pyramid: Tier 2 has twice the surface area but encompasses all of Tier 1
- Each Tier 1 theme should spawn 1-3 related themes in Tier 2
- Some Tier 2 themes may bridge multiple Tier 1 themes

**Your Task:**
1. **Keep all 10 Tier 1 themes** - Include them as-is in Tier 2
2. **Add 10 additional themes** - Subdivisions, extensions, and bridges of Tier 1 themes
3. **Create True Expansion** - Tier 2 should have 20 themes total, not 10+10
4. **Maintain Centrality** - All Tier 2 themes must relate back to Tier 1 foundation

**Output Format:**

# Multi-Tiered Theme Taxonomy - Pass 2: Extended Themes (Pyramid Structure)

## Tier 1: Core Themes (10 Primary Categories) - Foundation
[Keep exact same 10 themes from Pass 1]

## Tier 2: Extended Themes (20 Categories Total - Including All Tier 1)

### [tier1_theme] (CORE - from Tier 1)
- **Description:** [same as Tier 1]
- **Keywords:** [expanded from Tier 1]
- **Prevalence:** [from Tier 1]
- **Tier Level:** Core (Tier 1)

### [subdivision_theme] (EXPANSION of [parent_tier1_theme])
- **Description:** [specific subdivision of parent theme]
- **Keywords:** [8-12 specific terms]
- **Prevalence:** [percentage within parent theme]
- **Parent Theme:** [tier1_theme]
- **Tier Level:** Extension (Tier 2)

### [bridge_theme] (BRIDGE between [theme1] + [theme2])
- **Description:** [combines aspects of multiple Tier 1 themes]
- **Keywords:** [bridging concepts]
- **Prevalence:** [estimated percentage]
- **Bridge Themes:** [theme1] + [theme2]
- **Tier Level:** Bridge (Tier 2)

[Repeat for all 20 themes: 10 core + 10 extensions/bridges]

**REQUIREMENT CHECK:** Must have exactly 20 themes total in Tier 2, with clear lineage to 10 Tier 1 themes.

## Tier 2 Complete Keyword Dictionary (20 themes)
```lua
tier2_keywords = {
    -- All 20 themes including the 10 core themes
}
```

Here are the original %d analyses plus Pass 1 results:

]], #analyses)

    -- Pass 3: Complete pyramid taxonomy with Tier 3 (40 themes total)
    prompts[3] = string.format([[
This is PASS 3 of 3 - Final comprehensive PYRAMID TAXONOMY with 40 total themes in Tier 3.

**Pass 3 Focus: Complete Pyramid Structure (40 Total Themes)**

**CRITICAL: PYRAMID STRUCTURE REQUIREMENTS:**
- Tier 1: 10 core themes (foundation)
- Tier 2: 20 total themes (includes all 10 Tier 1 + 10 extensions)
- Tier 3: 40 total themes (includes all 20 Tier 2 + 20 further extensions)
- Each tier DOUBLES in size while encompassing all previous tiers

**Your Task:**
1. **Keep all 20 Tier 2 themes** - Include them in Tier 3
2. **Add 20 additional themes** - Further subdivisions and specializations
3. **Maintain Pyramid Structure** - 40 total themes, all traceable to Tier 1 foundation
4. **Create Implementation Guide** - Technical specifications for PDF system

**Output Format:**

# Complete Multi-Tiered Theme Taxonomy - Final Pyramid

## Tier 1: Core Themes (10 Primary Categories) - Foundation
[Keep from previous passes]

## Tier 2: Extended Themes (20 Categories) - Middle Tier  
[Keep from Pass 2]

## Tier 3: Detailed Themes (40 Categories Total - Including All Tier 2)

### [tier2_theme] (CORE from Tier 2)
- **Description:** [same as Tier 2]
- **Keywords:** [from Tier 2]
- **Prevalence:** [from Tier 2]
- **Tier Level:** Core (from Tier 2)
- **Lineage:** Tier 2 → [Tier 1 parent]

### [specialization_theme] (SPECIALIZATION of [tier2_parent])
- **Description:** [specific aspect of parent theme]
- **Keywords:** [6-10 specialized terms]
- **Prevalence:** [percentage within parent theme]
- **Parent Theme:** [tier2_theme]
- **Tier Level:** Specialization (Tier 3)
- **Lineage:** Tier 3 → [Tier 2 parent] → [Tier 1 grandparent]

[Repeat for all 40 themes: 20 from Tier 2 + 20 new specializations]

**REQUIREMENT CHECK:** Must have exactly 40 themes total in Tier 3, all tracing back to 10 Tier 1 themes.

## Complete Pyramid Keyword Dictionary (40 themes)
```lua
complete_keywords = {
    tier1 = {
        -- 10 foundation themes
    },
    tier2 = {
        -- 20 extended themes (includes tier1)
    },
    tier3 = {
        -- 40 detailed themes (includes tier2)
    }
}
```

## Pyramid Structure Validation
- **Tier 1 (Foundation):** 10 themes
- **Tier 2 (Extended):** 20 themes (2x Tier 1)
- **Tier 3 (Detailed):** 40 themes (2x Tier 2)
- **Total Coverage:** All themes trace back to 10 core concepts

## Implementation Recommendations
[Technical guidance for PDF system using pyramid structure]

Here are the original %d analyses plus Pass 1 & 2 results:

]], #analyses)

    return prompts[pass_number]
end

function combine_all_analyses()
    local analyses = get_analysis_files()
    local combined = ""
    
    for i, file in ipairs(analyses) do
        local f = io.open(file, "r")
        if f then
            local content = f:read("*all")
            f:close()
            
            local slice_num = file:match("analysis_(%d+)%.analysis")
            combined = combined .. string.format("\\n=== ANALYSIS %s ===\\n", slice_num or i)
            combined = combined .. content .. "\\n"
        else
            print("Warning: Could not read " .. file)
        end
    end
    
    return combined
end

function run_single_pass(pass_number, previous_output_file)
    print(string.format("=== PASS %d of 3 ===", pass_number))
    
    local prompt = create_consolidation_prompt(pass_number, previous_output_file)
    local analyses_content = combine_all_analyses()
    
    -- Add previous output if this is pass 2 or 3
    local previous_content = ""
    if pass_number > 1 and previous_output_file then
        local prev_file = io.open(previous_output_file, "r")
        if prev_file then
            previous_content = "\n\n=== PREVIOUS PASS RESULTS ===\n" .. prev_file:read("*all")
            prev_file:close()
        end
    end
    
    local full_prompt = prompt .. analyses_content .. previous_content
    
    -- Write prompt to temporary file
    local temp_prompt = string.format("/tmp/consolidation_prompt_pass_%d.txt", pass_number)
    local prompt_file = io.open(temp_prompt, "w")
    if not prompt_file then
        error("Could not create temporary prompt file for pass " .. pass_number)
    end
    prompt_file:write(full_prompt)
    prompt_file:close()
    
    -- Run Claude Code with Opus model for better complex reasoning
    local output_file = string.format("theme-analysis/final-theme-taxonomy-%d.md", pass_number)
    local cmd = string.format("claude --model opus < %s > %s 2>&1", temp_prompt, output_file)
    
    print(string.format("Running Pass %d analysis...", pass_number))
    print(string.format("Output will be saved to: %s", output_file))
    
    local start_time = os.time()
    local exit_code = os.execute(cmd)
    local duration = os.time() - start_time
    
    -- Cleanup
    os.execute("rm -f " .. temp_prompt)
    
    -- In Lua 5.2, os.execute returns true/false, not numeric codes
    local success = (exit_code == true or exit_code == 0)
    
    if success then
        -- Check output quality
        local result_file = io.open(output_file, "r")
        if result_file then
            local content = result_file:read("*all")
            result_file:close()
            
            local lines = select(2, content:gsub("\n", ""))
            local words = select(2, content:gsub("%S+", ""))
            
            print(string.format("✓ Pass %d complete in %d seconds (%d lines, %d words)", 
                pass_number, duration, lines, words))
            
            if words > 200 then
                return true, output_file
            else
                print("⚠ Output seems short for Pass " .. pass_number)
                return false, output_file
            end
        else
            print("✗ Could not read output file for Pass " .. pass_number)
            return false, output_file
        end
    else
        print(string.format("✗ Pass %d failed", pass_number))
        return false, output_file
    end
end

function check_existing_passes()
    local passes = {}
    for pass = 1, 3 do
        local filename = string.format("theme-analysis/final-theme-taxonomy-%d.md", pass)
        local file = io.open(filename, "r")
        if file then
            local content = file:read("*all")
            file:close()
            if #content > 200 then  -- Has substantial content
                passes[pass] = filename
            end
        end
    end
    return passes
end

function run_consolidation()
    local total_words, file_count = count_analysis_words()
    print(string.format("Starting 3-pass iterative consolidation of %d analysis files (~%d words)", 
        file_count, total_words))
    print("")
    print("Pass 1: Core 10 themes with detailed specifications")
    print("Pass 2: Extended 20 themes with hierarchical mapping") 
    print("Pass 3: Complete 40 themes with implementation guide")
    print("")
    
    -- Check for existing passes
    local existing_passes = check_existing_passes()
    local start_pass = 1
    local previous_output = nil
    
    -- Determine where to start
    for pass = 3, 1, -1 do  -- Check from pass 3 down to 1
        if existing_passes[pass] then
            if pass == 3 then
                print("✓ All 3 passes already complete!")
                print("Use --restart flag to regenerate, or review existing files:")
                for p = 1, 3 do
                    if existing_passes[p] then
                        print(string.format("  Pass %d: %s", p, existing_passes[p]))
                    end
                end
                return true
            else
                start_pass = pass + 1
                previous_output = existing_passes[pass]
                print(string.format("✓ Found existing Pass %d, resuming from Pass %d", pass, start_pass))
                break
            end
        end
    end
    
    if start_pass == 1 and existing_passes[1] then
        -- Pass 1 exists but Pass 2 doesn't, so we start from Pass 2
        start_pass = 2
        previous_output = existing_passes[1]
        print("✓ Found existing Pass 1, resuming from Pass 2")
    end
    
    print(string.format("Starting from Pass %d", start_pass))
    print("")
    
    local all_passes_successful = true
    
    -- Run remaining passes sequentially
    for pass = start_pass, 3 do
        local success, output_file = run_single_pass(pass, previous_output)
        if not success then
            print(string.format("✗ Pass %d failed - stopping consolidation", pass))
            all_passes_successful = false
            break
        end
        
        previous_output = output_file
        
        -- Wait between passes to ensure file system sync
        if pass < 3 then
            print("Waiting 2 seconds before next pass...")
            os.execute("sleep 2")
            print("")
        end
    end
    
    return all_passes_successful
end

function display_results()
    print("\n" .. string.rep("=", 60))
    print("3-PASS CONSOLIDATION RESULTS")
    print(string.rep("=", 60))
    
    local pass_files = {
        "theme-analysis/final-theme-taxonomy-1.md",
        "theme-analysis/final-theme-taxonomy-2.md", 
        "theme-analysis/final-theme-taxonomy-3.md"
    }
    
    for pass = 1, 3 do
        local file = io.open(pass_files[pass], "r")
        if file then
            local content = file:read("*all")
            file:close()
            
            local lines = select(2, content:gsub("\n", ""))
            local words = select(2, content:gsub("%S+", ""))
            
            print(string.format("Pass %d: %s (%d lines, %d words)", 
                pass, pass_files[pass], lines, words))
        else
            print(string.format("Pass %d: %s (FILE NOT FOUND)", pass, pass_files[pass]))
        end
    end
    
    -- Display the final (Pass 3) results if available
    local final_file = io.open(pass_files[3], "r")
    if final_file then
        print("\n" .. string.rep("-", 60))
        print("FINAL TAXONOMY (Pass 3 - Complete 40 Themes)")
        print(string.rep("-", 60))
        
        local content = final_file:read("*all")
        final_file:close()
        
        -- Show just the overview and tier summaries, not the full content
        local lines = {}
        for line in content:gmatch("[^\n]+") do
            table.insert(lines, line)
            if #lines > 50 then  -- Show first 50 lines
                table.insert(lines, "... [truncated - see full file] ...")
                break
            end
        end
        
        print(table.concat(lines, "\n"))
    end
    
    print("\n" .. string.rep("=", 60))
    print("3-PASS CONSOLIDATION COMPLETE")
    print(string.rep("=", 60))
    print("Generated files:")
    for pass = 1, 3 do
        print(string.format("  Pass %d: %s", pass, pass_files[pass]))
    end
    print("")
    print("Next steps:")
    print("1. Review final-theme-taxonomy-3.md for complete 40-theme taxonomy")
    print("2. Update compile-pdf-ai.lua with new theme system")  
    print("3. Create new art generation functions based on themes")
    print("4. Test the enhanced PDF generation system")
end

function verify_prerequisites()
    local analyses = get_analysis_files()
    local slices = {}
    
    -- Get expected slice count
    local handle = io.popen("ls theme-analysis/slices/slice_*.txt 2>/dev/null | wc -l")
    local expected_slices = 0
    if handle then
        expected_slices = tonumber(handle:read("*l")) or 0
        handle:close()
    end
    
    print("Prerequisites check:")
    print(string.format("  Expected analyses: %d", expected_slices))
    print(string.format("  Found analyses: %d", #analyses))
    
    if #analyses == 0 then
        print("\n✗ No analysis files found!")
        print("Run: lua5.2 theme-analysis/analyze_parallel.lua")
        return false
    end
    
    if #analyses < expected_slices then
        print(string.format("\n⚠ Missing %d analyses", expected_slices - #analyses))
        print("Consider re-running: lua5.2 theme-analysis/analyze_parallel.lua")
        
        print("\nProceed anyway? (y/n)")
        local response = io.read()
        if response:lower() ~= "y" and response:lower() ~= "yes" then
            return false
        end
    else
        print("\n✓ All analysis files present")
    end
    
    return true
end

function clear_pass_files()
    local files = {
        "theme-analysis/final-theme-taxonomy-1.md",
        "theme-analysis/final-theme-taxonomy-2.md",
        "theme-analysis/final-theme-taxonomy-3.md"
    }
    
    for _, file in ipairs(files) do
        os.execute("rm -f " .. file)
    end
    
    print("✓ Cleared existing pass files for fresh start")
end

function main()
    print("Theme Analysis Consolidation System")
    print("====================================")
    print("")
    
    -- Check for restart flag
    local restart = false
    for i, arg in ipairs(arg or {}) do
        if arg == "--restart" then
            restart = true
            break
        end
    end
    
    if restart then
        print("🔄 Restart flag detected - clearing existing passes")
        clear_pass_files()
        print("")
    end
    
    if not verify_prerequisites() then
        return
    end
    
    print("\nStarting consolidation process...")
    
    if run_consolidation() then
        display_results()
    else
        print("\nConsolidation failed. Check error messages above.")
    end
end

main()