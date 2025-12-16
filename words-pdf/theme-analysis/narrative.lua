#!/usr/bin/env luajit

-- Narrative Transformation System
-- Converts poem slices into 3rd person narratives from the subject's perspective
-- Usage: luajit theme-analysis/narrative.lua [--dir PATH] [--sequential|--parallel [N]] [--restart|--refine|--skip]

-- Base directory - can be overridden via command line argument
local DIR = "/mnt/mtwo/programming/ai-stuff/words-pdf"

-- Setup initial package paths for LuaJIT compatibility
package.path = package.path .. ";" .. DIR .. "/libs/?.lua;../libs/?.lua;./libs/?.lua;libs/?.lua"

-- Global variable for dkjson (will be loaded after directory setup)
local dkjson

-- Configuration
local DEFAULT_WORKERS = 4
local TIMEOUT = 600  -- 10 mins per slice

-- Derived paths (will be updated in parse_arguments)
local BASE_DIR = DIR
local SLICES_DIR = ""
local NARRATIVES_DIR = ""
local ANALYSES_DIR = ""
local PROGRESS_FILE = ""

-- Global state
local sequential_mode = false
local max_workers = DEFAULT_WORKERS
local should_quit = false
local SPINNER_SPEED = 3  -- rotations per second
local output_filename = nil  -- Custom output filename

-- {{{ load_dkjson
function load_dkjson()
    local success, result = pcall(require, "dkjson")
    if success then
        dkjson = result
        return
    end
    
    -- Try alternative paths
    local dkjson_paths = {
        "libs/dkjson"
    }
    
    for _, path in ipairs(dkjson_paths) do
        success, result = pcall(require, path)
        if success then
            dkjson = result
            return
        end
    end
    
    print("Error: Could not find dkjson library")
    print("Last error: " .. tostring(result))
    print("Package path: " .. package.path)
    print("Make sure to run from the correct directory or use --dir option")
    os.exit(1)
end
-- }}}

-- {{{ prompt_for_output_filename
function prompt_for_output_filename()
    print("")
    print("Output filename options:")
    print("  1) Use default naming (narrative_N.txt)")
    print("  2) Specify custom filename")
    print("")
    io.write("Enter your choice (1 or 2): ")
    io.flush()
    
    local choice = io.read("*l")
    if choice == "2" then
        print("")
        io.write("Enter base filename (without extension): ")
        io.flush()
        local filename = io.read("*l")
        if filename and filename ~= "" then
            return filename
        else
            print("❌ Invalid filename, using default naming")
            return nil
        end
    else
        return nil  -- Use default naming
    end
end
-- }}}

-- {{{ resolve_filename_conflict
function resolve_filename_conflict(base_path, extension)
    local full_path = base_path .. extension
    
    -- Check if file exists
    local file = io.open(full_path, "r")
    if not file then
        return full_path  -- No conflict, use as-is
    end
    file:close()
    
    -- File exists, find next available number
    local counter = 1
    repeat
        local numbered_path = base_path .. "_" .. counter .. extension
        file = io.open(numbered_path, "r")
        if not file then
            return numbered_path
        end
        file:close()
        counter = counter + 1
    until counter > 1000  -- Safety limit
    
    -- Fallback to timestamp if too many conflicts
    local timestamp = os.date("%Y%m%d_%H%M%S")
    return base_path .. "_" .. timestamp .. extension
end
-- }}}

-- {{{ get_output_filename
function get_output_filename(slice_num)
    if output_filename then
        local base_path = NARRATIVES_DIR .. "/" .. output_filename .. "_" .. slice_num
        return resolve_filename_conflict(base_path, ".txt")
    else
        -- Use default naming
        return NARRATIVES_DIR .. "/narrative_" .. slice_num .. ".txt"
    end
end
-- }}}

-- {{{ setup_paths
function setup_paths(base_dir)
    BASE_DIR = base_dir
    SLICES_DIR = BASE_DIR .. "/theme-analysis/slices"
    NARRATIVES_DIR = BASE_DIR .. "/theme-analysis/narratives"
    ANALYSES_DIR = BASE_DIR .. "/theme-analysis/analyses"
    PROGRESS_FILE = BASE_DIR .. "/theme-analysis/narrative_progress.json"
    
    -- Update package path to use BASE_DIR
    package.path = package.path .. ";" .. BASE_DIR .. "/libs/?.lua"
    
    -- Load dkjson after setting up paths
    load_dkjson()
end
-- }}}

-- {{{ parse_arguments
function parse_arguments()
    -- Use same argument parsing logic as analyze.lua but for narratives
    local custom_dir = nil
    local mode = "restart"
    local run_mode = "parallel"
    local thread_count = DEFAULT_WORKERS
    
    if arg and #arg > 0 then
        local i = 1
        while i <= #arg do
            local argument = arg[i]
            
            if argument == "--dir" then
                if i + 1 <= #arg then
                    i = i + 1
                    custom_dir = arg[i]
                end
            elseif argument:match("^%-%-dir=(.+)$") then
                custom_dir = argument:match("^%-%-dir=(.+)$")
            elseif argument == "--output" or argument == "-o" then
                -- Handle --output filename
                if i + 1 <= #arg then
                    i = i + 1
                    output_filename = arg[i]
                end
            elseif argument:match("^%-%-output=(.+)$") then
                -- Handle --output=filename
                output_filename = argument:match("^%-%-output=(.+)$")
            elseif argument == "--sequential" then
                run_mode = "sequential"
            elseif argument == "--parallel" then
                run_mode = "parallel"
                if i + 1 <= #arg and arg[i + 1]:match("^%d+$") then
                    i = i + 1
                    thread_count = tonumber(arg[i])
                end
            elseif argument == "--restart" then
                mode = "restart"
            elseif argument == "--refine" then
                mode = "refine"
            elseif argument == "--skip" then
                mode = "skip"
            end
            
            i = i + 1
        end
    end
    
    -- Set up directory paths
    if custom_dir then
        setup_paths(custom_dir)
    else
        setup_paths(BASE_DIR)
    end
    
    return mode, run_mode, thread_count
end
-- }}}

-- {{{ get_slice_files
function get_slice_files()
    local slices = {}
    local handle = io.popen("ls " .. SLICES_DIR .. "/slice_*.txt 2>/dev/null | sort")
    if handle then
        for filename in handle:lines() do
            table.insert(slices, filename)
        end
        handle:close()
    end
    return slices
end
-- }}}

-- {{{ get_completed_narratives
function get_completed_narratives()
    local completed = {}
    local handle = io.popen("ls " .. NARRATIVES_DIR .. "/narrative_*.txt 2>/dev/null")
    if handle then
        for filename in handle:lines() do
            local slice_num = filename:match("narrative_(%d+)%.txt")
            if slice_num then
                -- Check if narrative is actually complete (not failed)
                local file = io.open(filename, "r")
                if file then
                    local content = file:read("*all")
                    file:close()
                    if #content > 200 and not content:match("NARRATIVE_FAILED") then
                        completed[slice_num] = true
                    end
                end
            end
        end
        handle:close()
    end
    return completed
end
-- }}}

-- {{{ get_pending_slices
function get_pending_slices()
    local all_slices = get_slice_files()
    local completed = get_completed_narratives()
    local pending = {}
    
    for _, slice_file in ipairs(all_slices) do
        local slice_num = slice_file:match("slice_(%d+)%.txt")
        if slice_num and not completed[slice_num] then
            table.insert(pending, {file = slice_file, num = slice_num})
        end
    end
    
    return pending
end
-- }}}

-- {{{ get_analysis_context
function get_analysis_context(slice_num)
    -- Reciprocal dependency: get thematic analysis for this slice
    local analysis_file = ANALYSES_DIR .. "/analysis_" .. slice_num .. ".analysis"
    local context = ""
    
    local file = io.open(analysis_file, "r")
    if file then
        local analysis_content = file:read("*all")
        file:close()
        
        if #analysis_content > 200 then
            context = "\n\n**THEMATIC ANALYSIS CONTEXT:**\n"
            context = context .. "The following thematic analysis was performed on this same text slice:\n\n"
            context = context .. analysis_content .. "\n\n"
            context = context .. "**INSTRUCTION:** Use the above thematic analysis to inform the narrative transformation, incorporating the identified themes, emotional tones, and symbolic elements into the 3rd person perspective narrative.\n"
        end
    end
    
    return context
end
-- }}}

-- {{{ create_narrative_prompt
function create_narrative_prompt(slice_file, slice_num)
    local analysis_context = get_analysis_context(slice_num)
    
    local base_prompt = [[
Transform this poetry/text corpus slice into a cohesive 3rd person narrative from the subject's internal perspective. The narrative should feel like observing someone's thoughts and experiences as they navigate through the emotional and psychological landscape described in the poems.

**Transformation Goals:**
1. Convert first-person poetry into 3rd person narrative prose
2. Maintain the emotional intensity and psychological depth
3. Create flowing narrative continuity between disconnected poem fragments  
4. Capture the subject's internal voice, thoughts, and emotional journey
5. Preserve the visceral, raw quality while making it narratively coherent

**Narrative Perspective:**
- 3rd person limited, focused on the subject's internal experience
- "She thought..." "Her mind wandered to..." "The memory surfaced..."
- Capture both conscious thoughts and unconscious emotional undercurrents
- Bridge gaps between poem fragments with transitional narrative

**Tone and Style:**
- Dark, introspective, psychologically intense
- Sharp, cutting imagery (like lines carved in butter, blood, or stone)
- Should feel uncomfortable, unsettling - a cursed artifact quality
- Maintain poetic language but in narrative form
- Create sense of "oozing" between thoughts and memories

**Visual/Sensory Integration:**
- Incorporate imagery of milky white and bright red (nearly pink, slightly orange)
- Sharp, painful imagery - stalagmites and stalactites of thought
- Mathematical precision in the cruelty of memory
- Statistical fuzziness in the bleeding between moments

**Output Format:**
Create a continuous narrative prose piece that:
- Flows as a single story despite fragmented source material
- Maintains psychological authenticity to the original voice
- Feels like reading someone's private, unfiltered consciousness
- Creates narrative bridges where poems were disconnected
- Preserves the emotional arc while making it story-like

**Be Visceral and Uncomfortable** - This should feel like peering into someone's mind during their most vulnerable, raw moments.]] .. analysis_context .. [[

Here is the slice to transform into narrative:

]]

    return base_prompt
end
-- }}}

-- {{{ transform_slice_sequential
function transform_slice_sequential(slice_info)
    local slice_file = slice_info.file
    local slice_num = slice_info.num
    local output_file = get_output_filename(slice_num)
    local temp_output = "/tmp/narrative_" .. slice_num .. "_temp.txt"
    local temp_prompt = "/tmp/narrative_prompt_" .. slice_num .. ".txt"
    
    print(string.format("Transforming slice_%s into narrative (%s)", slice_num, slice_file))
    
    -- Create the narrative prompt
    local prompt_file = io.open(temp_prompt, "w")
    if not prompt_file then
        print("Error: Could not create prompt file")
        return false
    end
    
    prompt_file:write(create_narrative_prompt(slice_file, slice_num))
    prompt_file:write("\n\n")
    
    -- Add slice content
    local content_file = io.open(slice_file, "r")
    if not content_file then
        print("Error: Could not read slice file " .. slice_file)
        prompt_file:close()
        os.execute("rm -f " .. temp_prompt)
        return false
    end
    
    prompt_file:write(content_file:read("*all"))
    content_file:close()
    prompt_file:close()
    
    -- Run Claude with extended timeout
    print(string.format("Running Claude narrative transformation (timeout: %d minutes)...", TIMEOUT / 60))
    local start_time = os.time()
    
    local cmd = string.format("timeout %d claude < %s > %s 2>&1; echo $? > /tmp/narrative_exit_code_%s", 
        TIMEOUT, temp_prompt, temp_output, slice_num)
    os.execute(cmd)
    
    local exit_code_file = io.open("/tmp/narrative_exit_code_" .. slice_num, "r")
    local exit_code = 1
    if exit_code_file then
        exit_code = tonumber(exit_code_file:read("*l")) or 1
        exit_code_file:close()
        os.execute("rm -f /tmp/narrative_exit_code_" .. slice_num)
    end
    
    local duration = os.time() - start_time
    os.execute("rm -f " .. temp_prompt)
    
    -- Check results
    if exit_code == 0 then
        local result_file = io.open(temp_output, "r")
        if result_file then
            local content = result_file:read("*all")
            result_file:close()
            
            if #content > 200 then
                local move_cmd = string.format("mv %s %s", temp_output, output_file)
                local move_result = os.execute(move_cmd)
                if move_result == true or move_result == 0 then
                    print(string.format("✓ Narrative transformation complete in %dm %ds (%d chars)", 
                        math.floor(duration / 60), duration % 60, #content))
                    return true
                else
                    print(string.format("✗ Narrative transformation failed - could not save result"))
                    os.execute("rm -f " .. temp_output)
                    return false
                end
            else
                print(string.format("✗ Narrative transformation failed - output too short"))
                os.execute("rm -f " .. temp_output)
                return false
            end
        else
            print(string.format("✗ Narrative transformation failed - no output file"))
            os.execute("rm -f " .. temp_output)
            return false
        end
    else
        print(string.format("✗ Narrative transformation failed after %dm %ds (exit code: %d)", 
            math.floor(duration / 60), duration % 60, exit_code))
        os.execute("rm -f " .. temp_output)
        return false
    end
end
-- }}}

-- {{{ table_size
function table_size(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end
-- }}}

-- {{{ clear_all_narratives
function clear_all_narratives()
    print("🗑️ Clearing all previous narrative files...")
    os.execute("rm -f " .. NARRATIVES_DIR .. "/narrative_*.txt")
    print("✓ All narrative files cleared")
end
-- }}}

-- {{{ main
function main()
    local mode, run_mode, thread_count = parse_arguments()
    sequential_mode = (run_mode == "sequential")
    max_workers = thread_count
    
    print("Narrative Transformation System")
    print("==============================")
    print("Converting poetry slices into 3rd person narratives")
    print(string.format("Mode: %s %s", 
        run_mode == "sequential" and "Sequential" or ("Parallel (" .. thread_count .. " workers)"),
        mode == "restart" and "(restart)" or mode == "refine" and "(refine)" or mode == "skip" and "(skip)" or ""))
    print("")
    
    -- Prompt for output filename if not provided via command line
    if not output_filename then
        output_filename = prompt_for_output_filename()
    end
    
    -- Handle restart mode
    if mode == "restart" then
        print("🔄 Restart mode - clearing all previous narrative work")
        clear_all_narratives()
        print("")
    end
    
    -- Create narratives directory
    os.execute("mkdir -p " .. NARRATIVES_DIR)
    
    -- Get work queue based on mode
    local work_slices = get_pending_slices()
    local total_slices = #get_slice_files()
    
    print(string.format("📋 Found %d slices to transform into narratives", #work_slices))
    
    if #work_slices == 0 then
        local completed_narratives = get_completed_narratives()
        local completed_count = table_size(completed_narratives)
        
        if completed_count == total_slices then
            print("✓ All slices already transformed into narratives!")
            print("Ready for cursed book compilation...")
            return
        else
            print("❌ No work to do - all available slices processed")
            return
        end
    end
    
    print("")
    
    -- Run transformation (currently sequential only)
    if sequential_mode then
        print("Running sequential narrative transformation...")
        print("")
        
        for i, slice_info in ipairs(work_slices) do
            print(string.format("[%d/%d] Processing %s", i, #work_slices, slice_info.file))
            
            if transform_slice_sequential(slice_info) then
                print("✓ Transformation successful")
            else
                print("✗ Transformation failed - continuing to next slice")
            end
            print("")
        end
        
        print("=== NARRATIVE TRANSFORMATION COMPLETE ===")
        local final_completed = table_size(get_completed_narratives())
        print(string.format("Completed: %d/%d narrative transformations", final_completed, total_slices))
        
        if final_completed == total_slices then
            print("✓ All slices transformed into narratives!")
            print("Ready for cursed book compilation with milky white pages and bright red text...")
        end
    else
        print("❌ Parallel processing not yet implemented for narrative transformation")
        print("Please use --sequential mode for now")
    end
end
-- }}}

main()