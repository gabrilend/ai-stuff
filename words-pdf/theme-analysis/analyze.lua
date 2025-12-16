#!/usr/bin/env luajit

-- Theme Analysis using Claude Code
-- Supports both parallel (default) and sequential processing modes
-- Usage: luajit theme-analysis/analyze.lua [--dir PATH] [--sequential|--parallel [N]] [--restart|--refine|--skip]

-- Setup initial package paths for LuaJIT compatibility
package.path = package.path .. ";../libs/?.lua;./libs/?.lua;libs/?.lua"

-- Global variable for dkjson (will be loaded after directory setup)
local dkjson

-- Configuration
local DEFAULT_WORKERS = 4
local TIMEOUT = 600  -- 10 mins per slice

-- Base directory - can be overridden via command line argument
local BASE_DIR = "/mnt/mtwo/programming/ai-stuff/words-pdf"

-- Derived paths (will be updated in parse_arguments)
local SLICES_DIR = ""
local ANALYSES_DIR = ""
local PROGRESS_FILE = ""

-- Global state
local sequential_mode = false
local max_workers = DEFAULT_WORKERS
local should_quit = false
local input_method = "none"  -- "socket" or "none"
local input_socket_server = nil
local input_socket_path = nil
local input_socket_client = nil
local SPINNER_SPEED = 3  -- rotations per second
local output_filename = nil  -- Custom output filename

-- Interactive prompt functions
function prompt_for_processing_mode()
    print("Select processing mode:")
    print("  1) Parallel processing (faster, uses multiple workers)")
    print("  2) Sequential processing (slower, one slice at a time)")
    print("")
    io.write("Enter your choice (1 or 2): ")
    io.flush()
    
    local choice = io.read("*l")
    if choice == "2" then
        return "sequential", DEFAULT_WORKERS
    elseif choice == "1" or choice == "" then
        -- Ask for thread count
        print("")
        print("How many parallel workers would you like to use?")
        print("  - More workers = faster processing")
        print("  - Recommended: 2-8 workers depending on your system")
        print("  - Maximum: 16 workers")
        io.write(string.format("Enter number of workers (1-16, default %d): ", DEFAULT_WORKERS))
        io.flush()
        
        local thread_input = io.read("*l")
        local thread_count = DEFAULT_WORKERS
        
        if thread_input and thread_input ~= "" then
            local num = tonumber(thread_input)
            if num and num >= 1 and num <= 16 then
                thread_count = num
            else
                print("❌ Invalid thread count, using default of " .. DEFAULT_WORKERS)
            end
        end
        
        return "parallel", thread_count
    else
        print("❌ Invalid choice, using parallel mode with default settings")
        return "parallel", DEFAULT_WORKERS
    end
end

function prompt_for_analysis_mode()
    print("")
    print("Select analysis mode:")
    print("  1) Restart - Clear all previous work and start fresh")
    print("  2) Refine - Improve existing analyses (requires previous analyses)")
    print("  3) Skip - Only process missing/incomplete slices")
    print("")
    io.write("Enter your choice (1, 2, or 3): ")
    io.flush()
    
    local choice = io.read("*l")
    if choice == "1" then
        return "restart"
    elseif choice == "2" then
        return "refine"
    elseif choice == "3" then
        return "skip"
    else
        print("❌ Invalid choice, using restart mode")
        return "restart"
    end
end

-- {{{ prompt_for_output_filename
function prompt_for_output_filename()
    print("")
    print("Output filename options:")
    print("  1) Use default naming (analysis_N.analysis)")
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
        local base_path = ANALYSES_DIR .. "/" .. output_filename .. "_" .. slice_num
        return resolve_filename_conflict(base_path, ".analysis")
    else
        -- Use default naming
        return ANALYSES_DIR .. "/analysis_" .. slice_num .. ".analysis"
    end
end
-- }}}

-- Helper function to load dkjson with error handling
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

-- Helper function to set up directory paths
function setup_paths(base_dir)
    BASE_DIR = base_dir
    SLICES_DIR = BASE_DIR .. "/theme-analysis/slices"
    ANALYSES_DIR = BASE_DIR .. "/theme-analysis/analyses"
    PROGRESS_FILE = BASE_DIR .. "/theme-analysis/analysis_progress.json"
    
    -- Update package path to use BASE_DIR
    package.path = package.path .. ";" .. BASE_DIR .. "/libs/?.lua"
    
    -- Load dkjson after setting up paths
    load_dkjson()
end

-- Parse command line arguments
function parse_arguments()
    local mode = nil
    local run_mode = nil
    local thread_count = DEFAULT_WORKERS
    local has_processing_arg = false
    local has_analysis_arg = false
    local has_error = false
    local error_message = ""
    local custom_dir = nil
    
    if arg and #arg > 0 then
        local i = 1
        while i <= #arg do
            local argument = arg[i]
            
            if argument == "--dir" then
                -- Handle --dir /path/to/directory
                if i + 1 <= #arg then
                    i = i + 1
                    custom_dir = arg[i]
                else
                    has_error = true
                    error_message = "--dir requires a directory path"
                    break
                end
            elseif argument:match("^%-%-dir=(.+)$") then
                -- Handle --dir=/path/to/directory
                custom_dir = argument:match("^%-%-dir=(.+)$")
            elseif argument == "--output" or argument == "-o" then
                -- Handle --output filename
                if i + 1 <= #arg then
                    i = i + 1
                    output_filename = arg[i]
                else
                    has_error = true
                    error_message = "--output requires a filename"
                    break
                end
            elseif argument:match("^%-%-output=(.+)$") then
                -- Handle --output=filename
                output_filename = argument:match("^%-%-output=(.+)$")
            elseif argument == "--sequential" then
                run_mode = "sequential"
                has_processing_arg = true
            elseif argument == "--parallel" then
                run_mode = "parallel"
                has_processing_arg = true
                -- Check if next argument is a number (thread count)
                if i + 1 <= #arg and arg[i + 1]:match("^%d+$") then
                    i = i + 1
                    thread_count = tonumber(arg[i])
                    if thread_count < 1 or thread_count > 16 then
                        has_error = true
                        error_message = "Thread count must be between 1 and 16 (got " .. thread_count .. ")"
                        break
                    end
                end
            elseif argument:match("^%-%-parallel=(%d+)$") then
                -- Handle --parallel=N format
                run_mode = "parallel"
                has_processing_arg = true
                thread_count = tonumber(argument:match("^%-%-parallel=(%d+)$"))
                if thread_count < 1 or thread_count > 16 then
                    has_error = true
                    error_message = "Thread count must be between 1 and 16 (got " .. thread_count .. ")"
                    break
                end
            elseif argument:match("^%-%-parallel=(.+)$") then
                -- Handle --parallel=invalid format
                local invalid_count = argument:match("^%-%-parallel=(.+)$")
                has_error = true
                error_message = "Invalid thread count '" .. invalid_count .. "' - must be a number between 1 and 16"
                break
            elseif argument == "--restart" or argument == "--fresh" then
                mode = "restart"
                has_analysis_arg = true
            elseif argument == "--refine" or argument == "--improve" then
                mode = "refine"
                has_analysis_arg = true
            elseif argument == "--skip" or argument == "--skip-completed" then
                mode = "skip"
                has_analysis_arg = true
            elseif argument == "--help" or argument == "-h" then
                return "help", "parallel", DEFAULT_WORKERS
            elseif argument:match("^%-%-") then
                -- Unknown flag argument
                has_error = true
                error_message = "Unknown argument: " .. argument
                break
            else
                -- Check if this is a standalone number (could be thread count after --parallel)
                if not argument:match("^%d+$") then
                    has_error = true
                    error_message = "Unknown argument: " .. argument
                    break
                end
            end
            
            i = i + 1
        end
    end
    
    -- Interactive mode if missing arguments OR if there were errors
    if not has_processing_arg or not has_analysis_arg or has_error then
        if has_error then
            print("❌ Error: " .. error_message)
            print("")
        end
        
        print("Theme Analysis System - Interactive Setup")
        print("========================================")
        if has_error then
            print("Let's fix the configuration interactively...")
        end
        print("")
        
        -- Always reset and ask for both if there was an error
        if has_error then
            has_processing_arg = false
            has_analysis_arg = false
            run_mode = nil
            mode = nil
            thread_count = DEFAULT_WORKERS
        end
        
        -- Prompt for processing mode if not provided or error occurred
        if not has_processing_arg then
            run_mode, thread_count = prompt_for_processing_mode()
        end
        
        -- Prompt for analysis mode if not provided or error occurred
        if not has_analysis_arg then
            mode = prompt_for_analysis_mode()
        end
        
        -- Prompt for output filename if not provided
        if not output_filename then
            output_filename = prompt_for_output_filename()
        end
        
        print("")
        print("Settings configured:")
        print(string.format("  Processing: %s %s", 
            run_mode == "sequential" and "Sequential" or ("Parallel (" .. thread_count .. " workers)"),
            ""))
        print(string.format("  Analysis: %s", 
            mode == "restart" and "Restart (fresh)" or 
            mode == "refine" and "Refine (improve)" or 
            mode == "skip" and "Skip (missing only)" or mode))
        print("")
        io.write("Press Enter to continue or Ctrl+C to cancel...")
        io.flush()
        io.read("*l")
        print("")
    end
    
    -- Set defaults if still not set
    if not run_mode then run_mode = "parallel" end
    if not mode then mode = "restart" end
    
    -- Set up directory paths
    if custom_dir then
        setup_paths(custom_dir)
    else
        setup_paths(BASE_DIR)
    end
    
    return mode, run_mode, thread_count
end

-- Show help
function show_help()
    print("Theme Analysis System")
    print("====================")
    print("Usage:")
    print("  luajit theme-analysis/analyze.lua [--dir PATH] [--output FILENAME] [PROCESSING_MODE] [ANALYSIS_MODE]")
    print("")
    print("Directory Option:")
    print("  --dir PATH            Set base directory (default: /mnt/mtwo/programming/ai-stuff/words-pdf)")
    print("  --dir=PATH            Alternative syntax for directory")
    print("")
    print("Output Options:")
    print("  --output FILENAME, -o FILENAME    Set custom output filename base")
    print("  --output=FILENAME     Alternative syntax for output filename")
    print("                        (without extension, conflicts resolved automatically)")
    print("")
    print("Processing Modes:")
    print("  (default)             Parallel processing with 4 workers")
    print("  --parallel [N]        Parallel processing with N workers (1-16, default 4)")
    print("  --parallel=N          Parallel processing with N workers (alternative syntax)")
    print("  --sequential          Sequential processing (one slice at a time)")
    print("")
    print("Analysis Modes:")
    print("  --restart, --fresh    Clear all previous work and start from beginning")
    print("  --refine, --improve   Refine existing analyses (heuristic improvement)")
    print("  --skip, --skip-completed  Skip already analyzed slices, only do missing ones")
    print("  --help, -h           Show this help message")
    print("")
    print("Default behavior (no arguments): Interactive setup mode")
    print("")
    print("Examples:")
    print("  # Start fresh parallel analysis with default 4 workers")
    print("  luajit theme-analysis/analyze.lua --restart")
    print("")
    print("  # Parallel analysis with 8 workers")
    print("  luajit theme-analysis/analyze.lua --parallel 8 --restart")
    print("")
    print("  # Alternative syntax for 8 workers")
    print("  luajit theme-analysis/analyze.lua --parallel=8 --restart")
    print("")
    print("  # Sequential analysis with improvement")
    print("  luajit theme-analysis/analyze.lua --sequential --refine")
    print("")
    print("  # Parallel analysis of missing slices only")
    print("  luajit theme-analysis/analyze.lua --skip")
end

-- Quit signal checking - socket-based only
function check_for_quit_input()
    -- Check socket-based input
    if input_method == "socket" and input_socket_server then
        local client, err = input_socket_server:accept()
        if client then
            -- We have a connection from the input listener
            input_socket_client = client
            client:settimeout(0)  -- Non-blocking
            
            local data, err = client:receive()
            if data and data:match("^quit:") then
                local key = data:match("^quit:(.+)$")
                client:close()
                input_socket_client = nil
                
                if not should_quit then
                    should_quit = true
                    io.write(string.format("\n🛑 Shutdown requested ('%s' key detected)\n", key))
                    io.write("📋 Finishing current analysis, then stopping...\n")
                    io.write("💾 Progress will be saved\n\n")
                    io.flush()
                end
                return true
            end
        end
    end
    
    return false
end

function setup_input_polling()
    -- Setup Unix socket-based input listener
    local socket_loaded, unix_module = pcall(function()
        return require("socket.unix")
    end)
    
    if socket_loaded then
        -- Setup Unix socket for communication with input listener
        local socket_path = "/tmp/lua_analysis_input.sock"
        os.execute("rm -f " .. socket_path)  -- Clean up any existing socket
        
        local server = unix_module()
        if server then
            local success = server:bind(socket_path)
            if success then
                server:listen(1)
                server:settimeout(0)  -- Non-blocking mode
                
                -- Store socket for cleanup
                input_socket_server = server
                input_socket_path = socket_path
                
                -- Start hidden input listener process
                local listener_cmd = string.format("luajit %s/theme-analysis/input-listener.lua %s < /dev/tty > /dev/null 2>&1 &", BASE_DIR, socket_path)
                os.execute(listener_cmd)
                
                input_method = "socket"
                print("Using luasocket-based input monitoring")
                return
            else
                server:close()
            end
        end
    end
    
    -- No fallback - if luasocket isn't available, we'll just not have input monitoring
    input_method = "none"
    print("Warning: luasocket not available - input monitoring disabled")
    print("Use Ctrl+C to force quit if needed")
end

function restore_terminal()
    -- Clean up socket-based input system
    if input_method == "socket" then
        if input_socket_client then
            input_socket_client:close()
            input_socket_client = nil
        end
        if input_socket_server then
            input_socket_server:close()
            input_socket_server = nil
        end
        if input_socket_path then
            os.execute("rm -f " .. input_socket_path)
            input_socket_path = nil
        end
        
        -- Kill input listener process
        os.execute("pkill -f 'input-listener.lua' 2>/dev/null || true")
    end
end

-- File operations
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

function get_completed_analyses()
    local completed = {}
    local handle = io.popen("ls " .. ANALYSES_DIR .. "/analysis_*.analysis 2>/dev/null")
    if handle then
        for filename in handle:lines() do
            local slice_num = filename:match("analysis_(%d+)%.analysis")
            if slice_num then
                -- Check if analysis is actually complete (not failed)
                local file = io.open(filename, "r")
                if file then
                    local content = file:read("*all")
                    file:close()
                    if #content > 100 and not content:match("ANALYSIS_FAILED") then
                        completed[slice_num] = true
                    end
                end
            end
        end
        handle:close()
    end
    return completed
end

function get_pending_slices()
    local all_slices = get_slice_files()
    local completed = get_completed_analyses()
    local pending = {}
    
    for _, slice_file in ipairs(all_slices) do
        local slice_num = slice_file:match("slice_(%d+)%.txt")
        if slice_num and not completed[slice_num] then
            table.insert(pending, {file = slice_file, num = slice_num})
        end
    end
    
    return pending
end

function clear_all_analyses()
    print("🗑️ Clearing all previous analysis files...")
    os.execute("rm -f " .. ANALYSES_DIR .. "/analysis_*.analysis")
    print("✓ All analysis files cleared")
end

-- Progress management
function save_progress(data)
    local progress = {
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        mode = sequential_mode and "sequential" or "parallel",
        data = data
    }
    
    local file = io.open(PROGRESS_FILE, "w")
    if file then
        file:write(dkjson.encode(progress, {indent = true}))
        file:close()
    end
end

function load_progress()
    local file = io.open(PROGRESS_FILE, "r")
    if not file then
        return nil
    end
    
    local content = file:read("*all")
    file:close()
    
    return dkjson.decode(content)
end

function clear_progress()
    os.execute("rm -f " .. PROGRESS_FILE)
end

-- Error reporting
function get_failure_details(slice_num, exit_code)
    local temp_output = "/tmp/analysis_" .. slice_num .. "_temp.analysis"
    local temp_prompt = sequential_mode and 
        "/tmp/sequential_prompt_" .. slice_num .. ".txt" or 
        "/tmp/analysis_prompt_" .. slice_num .. ".txt"
    
    local details = {}
    
    -- Analyze exit code
    if exit_code == 124 then
        table.insert(details, "Timeout after 2 hours")
    elseif exit_code == 130 then
        table.insert(details, "Interrupted (Ctrl+C)")
    elseif exit_code ~= 0 then
        table.insert(details, "Exit code " .. exit_code)
    end
    
    -- Check temporary output for error patterns
    local temp_file = io.open(temp_output, "r")
    if temp_file then
        local content = temp_file:read("*all")
        temp_file:close()
        
        if #content == 0 then
            table.insert(details, "No output generated")
        elseif content:match("rate.?limit") or content:match("too many requests") then
            table.insert(details, "Rate limit exceeded")
        elseif content:match("authentication") or content:match("API key") then
            table.insert(details, "Authentication error")
        elseif content:match("network") or content:match("connection") then
            table.insert(details, "Network error")
        elseif content:match("timeout") then
            table.insert(details, "Claude timeout")
        elseif content:match("ANALYSIS_FAILED") then
            table.insert(details, "Analysis process failed")
        elseif #content < 100 then
            table.insert(details, "Output too short (" .. #content .. " chars)")
        else
            -- Check first few lines for error indicators
            local first_lines = {}
            for line in content:gmatch("[^\r\n]+") do
                table.insert(first_lines, line)
                if #first_lines >= 3 then break end
            end
            local preview = table.concat(first_lines, " ")
            if preview:match("error") or preview:match("failed") then
                table.insert(details, "Error in output: " .. preview:sub(1, 50) .. "...")
            end
        end
    else
        table.insert(details, "No output file created")
    end
    
    -- Check if prompt file exists
    local prompt_file = io.open(temp_prompt, "r")
    if not prompt_file then
        table.insert(details, "Prompt file missing")
    else
        prompt_file:close()
    end
    
    if #details > 0 then
        return table.concat(details, ", ")
    else
        return "Unknown error"
    end
end

-- Analysis functions
function get_previous_analysis_context(slice_num)
    local context = ""
    local analysis_file = ANALYSES_DIR .. "/analysis_" .. slice_num .. ".analysis"
    
    local file = io.open(analysis_file, "r")
    if file then
        local previous_analysis = file:read("*all")
        file:close()
        
        if #previous_analysis > 200 then
            context = "\n\n**PREVIOUS ANALYSIS OF THIS SLICE:**\n"
            context = context .. "Here is the previous analysis of this same text slice. Please refine and improve upon it:\n\n"
            context = context .. previous_analysis .. "\n\n"
            context = context .. "**INSTRUCTION:** Refine the above analysis - improve theme identification, clarify descriptions, enhance keywords, and provide better artistic guidance. Do not mention this previous version.\n"
        end
    end
    
    return context
end

function create_analysis_prompt(slice_file, slice_num)
    local previous_context = get_previous_analysis_context(slice_num)
    
    local base_prompt = [[
I need you to analyze this poetry/text corpus slice for thematic content. This slice is part of a larger ~550k word corpus that will be analyzed and consolidated.

**Analysis Goals:**
1. Identify 3-8 dominant themes in this slice
2. Extract key concepts and vocabulary for each theme  
3. Describe emotional tone and intensity
4. Suggest artistic/visual representations for generative art
5. Note unique or distinctive elements]]

    if previous_context ~= "" then
        base_prompt = base_prompt .. "\n6. **REFINE PREVIOUS ANALYSIS** - Improve upon the existing analysis of this same text"
    end

    base_prompt = base_prompt .. [[

**Focus Areas:**
- Themes that translate well to procedural/generative art
- Visual qualities: colors, patterns, movements, shapes
- Emotional/atmospheric qualities  
- Symbolic representations
- Geometric vs organic forms

**Output Format:**
For each theme provide:
- **Theme Name:** (single word, lowercase)
- **Description:** (2-3 sentences)
- **Keywords:** (8-12 relevant terms)
- **Visual Style:** (colors, patterns, movement suggestions)
- **Prevalence:** (rough estimate in this slice)
- **Art Notes:** (specific techniques/algorithms that could represent this theme)

**Be Specific and Actionable** - Focus on themes that can be translated into concrete visual algorithms for PDF art generation.]] .. previous_context .. [[

Here is the slice to analyze:

]] .. slice_file

    return base_prompt
end

function analyze_slice_sequential(slice_info)
    local slice_file = slice_info.file
    local slice_num = slice_info.num
    local output_file = get_output_filename(slice_num)
    local temp_output = "/tmp/analysis_" .. slice_num .. "_temp.analysis"
    local temp_prompt = "/tmp/sequential_prompt_" .. slice_num .. ".txt"
    
    print(string.format("Analyzing slice_%s (%s)", slice_num, slice_file))
    
    -- Create the analysis prompt
    local prompt_file = io.open(temp_prompt, "w")
    if not prompt_file then
        print("Error: Could not create prompt file")
        return false
    end
    
    prompt_file:write(create_analysis_prompt(slice_file, slice_num))
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
    print(string.format("Running Claude analysis (timeout: %d minutes)...", TIMEOUT / 60))
    local start_time = os.time()
    
    local cmd = string.format("timeout %d claude < %s > %s 2>&1; echo $? > /tmp/exit_code_%s", 
        TIMEOUT, temp_prompt, temp_output, slice_num)
    os.execute(cmd)
    
    local exit_code_file = io.open("/tmp/exit_code_" .. slice_num, "r")
    local exit_code = 1
    if exit_code_file then
        exit_code = tonumber(exit_code_file:read("*l")) or 1
        exit_code_file:close()
        os.execute("rm -f /tmp/exit_code_" .. slice_num)
    end
    
    local duration = os.time() - start_time
    os.execute("rm -f " .. temp_prompt)
    
    -- Check results
    if exit_code == 0 then
        local result_file = io.open(temp_output, "r")
        if result_file then
            local content = result_file:read("*all")
            result_file:close()
            
            if #content > 100 then
                local move_cmd = string.format("mv %s %s", temp_output, output_file)
                local move_result = os.execute(move_cmd)
                if move_result == true or move_result == 0 then
                    print(string.format("✓ Analysis complete in %dm %ds (%d chars)", 
                        math.floor(duration / 60), duration % 60, #content))
                    return true
                else
                    local error_details = get_failure_details(slice_num, exit_code)
                    print(string.format("✗ Analysis failed - could not save result (%s)", error_details))
                    os.execute("rm -f " .. temp_output)
                    return false
                end
            else
                local error_details = get_failure_details(slice_num, exit_code)
                print(string.format("✗ Analysis failed - output too short (%s)", error_details))
                os.execute("rm -f " .. temp_output)
                return false
            end
        else
            local error_details = get_failure_details(slice_num, exit_code)
            print(string.format("✗ Analysis failed - no output file (%s)", error_details))
            os.execute("rm -f " .. temp_output)
            return false
        end
    else
        local error_details = get_failure_details(slice_num, exit_code)
        print(string.format("✗ Analysis failed after %dm %ds (%s)", 
            math.floor(duration / 60), duration % 60, error_details))
        os.execute("rm -f " .. temp_output)
        return false
    end
end

-- Parallel worker management
function create_worker_script(slice_info)
    local slice_file = slice_info.file
    local slice_num = slice_info.num
    
    local script_content = string.format([[
#!/bin/bash

SLICE_FILE="%s"
SLICE_NUM="%s"
OUTPUT_FILE="%s"
TEMP_OUTPUT="/tmp/analysis_${SLICE_NUM}_temp.analysis"
TEMP_PROMPT="/tmp/analysis_prompt_${SLICE_NUM}.txt"

echo "Worker ${SLICE_NUM}: Starting analysis of ${SLICE_FILE}"

# Create the analysis prompt
cat > "${TEMP_PROMPT}" << 'PROMPT_EOF'
%s
PROMPT_EOF

# Add the slice content to the prompt
echo "" >> "${TEMP_PROMPT}"
cat "${SLICE_FILE}" >> "${TEMP_PROMPT}"

# Run Claude Code with the prompt, write to temp file first
echo "Worker ${SLICE_NUM}: Launching Claude Code..."
timeout %d claude < "${TEMP_PROMPT}" > "${TEMP_OUTPUT}" 2>&1
EXIT_CODE=$?
echo $EXIT_CODE > "/tmp/exit_code_${SLICE_NUM}"

# Check if analysis was successful and move temp to final location
if [ $EXIT_CODE -eq 0 ] && [ -s "${TEMP_OUTPUT}" ]; then
    CONTENT_SIZE=$(wc -c < "${TEMP_OUTPUT}")
    if [ $CONTENT_SIZE -gt 100 ]; then
        mv "${TEMP_OUTPUT}" "${OUTPUT_FILE}"
        echo "Worker ${SLICE_NUM}: Analysis complete - ${CONTENT_SIZE} chars written"
    else
        echo "Worker ${SLICE_NUM}: Analysis failed - output too short"
        echo "ANALYSIS_FAILED" > "${OUTPUT_FILE}"
        rm -f "${TEMP_OUTPUT}"
    fi
else
    echo "Worker ${SLICE_NUM}: Analysis failed - exit code $EXIT_CODE"
    echo "ANALYSIS_FAILED" > "${OUTPUT_FILE}"
    rm -f "${TEMP_OUTPUT}"
fi

# Cleanup
rm -f "${TEMP_PROMPT}"

echo "Worker ${SLICE_NUM}: Finished"
]], slice_file, slice_num, get_output_filename(slice_num), create_analysis_prompt(slice_file, slice_num), TIMEOUT)
    
    local script_file = "/tmp/worker_" .. slice_num .. ".sh"
    local file = io.open(script_file, "w")
    if file then
        file:write(script_content)
        file:close()
        os.execute("chmod +x " .. script_file)
        return script_file
    end
    return nil
end

function start_worker(slice_info)
    local script_file = create_worker_script(slice_info)
    if not script_file then
        print("Error: Could not create worker script for slice " .. slice_info.num)
        return nil
    end
    
    local handle = io.popen("echo $(nohup " .. script_file .. " > /dev/null 2>&1 & echo $!)")
    local pid_line = handle:read("*l")
    handle:close()
    
    if pid_line then
        local pid = pid_line:match("%d+")
        if pid then
            return {
                pid = pid,
                slice_num = slice_info.num,
                slice_file = slice_info.file,
                script_file = script_file,
                start_time = os.time()
            }
        end
    end
    
    return {
        slice_num = slice_info.num,
        slice_file = slice_info.file,
        script_file = script_file,
        start_time = os.time()
    }
end

function is_worker_running(worker)
    if not worker.pid then return false end
    local handle = io.popen("ps -p " .. worker.pid .. " > /dev/null 2>&1; echo $?")
    local result = handle:read("*l")
    handle:close()
    return result == "0"
end

function cleanup_worker(worker)
    if worker.script_file then
        os.execute("rm -f " .. worker.script_file)
    end
end

function get_analysis_status()
    local all_slices = get_slice_files()
    local completed = get_completed_analyses()
    
    local total = #all_slices
    local done = 0
    for _ in pairs(completed) do
        done = done + 1
    end
    
    return done, total
end

-- Main execution functions
function run_sequential_analysis(work_slices, mode)
    print("Sequential Theme Analysis")
    print("========================")
    print("Processing one slice at a time with extended timeouts")
    print("")
    
    local progress = load_progress()
    local start_index = 1
    local completed = {}
    local failed = {}
    
    if progress and progress.mode == "sequential" then
        local data = progress.data or {}
        start_index = data.current_index or 1
        completed = data.completed or {}
        failed = data.failed or {}
        print("Resuming from previous session...")
    end
    
    local total_slices = #get_slice_files()
    print(string.format("Status: %d/%d complete, %d to process", 
        total_slices - #work_slices, total_slices, #work_slices))
    print(string.format("Timeout per slice: %d minutes", TIMEOUT / 60))
    if input_method == "socket" then
        print("💡 Press 'q' or 'c' (no Enter needed) to quit gracefully")
    else
        print("💡 Use Ctrl+C to quit")
    end
    print("")
    
    setup_input_polling()
    
    for i = start_index, #work_slices do
        check_for_quit_input()
        if should_quit then
            print("🛑 Graceful shutdown - stopping before next slice")
            save_progress({current_index = i, completed = completed, failed = failed})
            break
        end
        
        local slice_info = work_slices[i]
        print(string.format("[%d/%d] Processing %s", i, #work_slices, slice_info.file))
        
        if analyze_slice_sequential(slice_info) then
            completed[slice_info.num] = true
            print("")
        else
            local exit_code_file = io.open("/tmp/exit_code_" .. slice_info.num, "r")
            local exit_code = 1
            if exit_code_file then
                exit_code = tonumber(exit_code_file:read("*l")) or 1
                exit_code_file:close()
            end
            local error_details = get_failure_details(slice_info.num, exit_code)
            table.insert(failed, {slice = slice_info.num, reason = error_details})
            print("Continuing to next slice...")
            print("")
        end
        
        save_progress({current_index = i + 1, completed = completed, failed = failed})
    end
    
    restore_terminal()
    
    if should_quit then
        print("=== GRACEFUL SHUTDOWN COMPLETE ===")
        print("🛑 Shutdown requested - current analysis completed safely")
    else
        print("=== SEQUENTIAL ANALYSIS COMPLETE ===")
    end
    
    local final_completed = table_size(get_completed_analyses())
    print(string.format("Completed: %d/%d analyses", final_completed, total_slices))
    
    if #failed > 0 then
        print(string.format("Failed: %d analyses", #failed))
        for i, failure in ipairs(failed) do
            if type(failure) == "table" then
                print(string.format("  • slice_%s: %s", failure.slice, failure.reason))
            else
                print(string.format("  • slice_%s", failure))
            end
        end
    end
    
    if should_quit then
        print(string.format("🔄 Interrupted: %d/%d slices processed", final_completed, total_slices))
        print("💾 All progress saved - no work lost")
        print("🚀 Re-run with same arguments to continue where left off")
    elseif final_completed == total_slices then
        print("✓ All slices analyzed successfully!")
        clear_progress()
        
        -- Trigger narrative transformation
        trigger_narrative_transformation()
        
        print("")
        print("Next step: luajit " .. BASE_DIR .. "/theme-analysis/consolidate-analyses.lua")
    else
        print("Re-run this script to retry failed analyses")
    end
end

function run_parallel_analysis(work_slices, mode)
    print("Parallel Theme Analysis")
    print("=======================")
    print(string.format("Processing with %d parallel workers", max_workers))
    print("")
    
    -- Load socket module for parallel processing (fallback to os-based sleep)
    local socket
    local function safe_sleep(seconds)
        if socket and socket.sleep then
            socket.sleep(seconds)
        else
            -- Use standard sleep with proper formatting
            os.execute("sleep " .. seconds)
        end
    end
    
    -- Try to load socket module, fall back to os.execute sleep if not available
    local socket_loaded, socket_module = pcall(function()
        -- Add paths for both source and compiled luasocket
        package.path = package.path .. ";../libs/luasocket/src/?.lua;../libs/luasocket/?.lua;./libs/luasocket/src/?.lua;./libs/luasocket/?.lua"
        package.cpath = package.cpath .. ";../libs/luasocket/src/?.so;../libs/luasocket/socket/?.so;../libs/luasocket/mime/?.so;./libs/luasocket/src/?.so;./libs/luasocket/socket/?.so;./libs/luasocket/mime/?.so"
        return require("socket")
    end)
    
    if socket_loaded then
        socket = socket_module
        print("Using luasocket for timing")
    else
        print("Socket library not available, using system sleep fallback")
    end
    
    local progress = load_progress()
    local processed_slices = {}
    local failed_analyses = {}
    
    if progress and progress.mode == "parallel" then
        local data = progress.data or {}
        processed_slices = data.processed or {}
        failed_analyses = data.failed or {}
        print("Resuming from previous session...")
    end
    
    local total_slices = #get_slice_files()
    print(string.format("Status: %d/%d complete, %d to process", 
        total_slices - #work_slices, total_slices, #work_slices))
    if input_method == "socket" then
        print("💡 Press 'q' or 'c' (no Enter needed) to quit gracefully")
    else
        print("💡 Use Ctrl+C to quit")
    end
    print("")
    
    setup_input_polling()
    
    local workers = {}
    local slice_index = 1
    local last_spinner_update = 0
    local last_progress_content = ""
    local progress_line_written = false
    
    -- Start initial workers
    for i = 1, math.min(max_workers, #work_slices) do
        if slice_index <= #work_slices and not should_quit then
            local worker = start_worker(work_slices[slice_index])
            if worker then
                workers[i] = worker
                io.write(string.format("Started worker %d: slice_%s (%s)\n", 
                    i, worker.slice_num, worker.slice_file))
                io.flush()
                slice_index = slice_index + 1
            end
        end
    end
    
    print("")
    
    -- Main monitoring loop
    while slice_index <= #work_slices or table_size_array(workers) > 0 do
        check_for_quit_input()
        
        -- Calculate current progress state
        local running = 0
        for _, worker in pairs(workers) do
            if worker and is_worker_running(worker) then
                running = running + 1
            end
        end
        
        local current_run_completed = 0
        for _, slice_info in ipairs(work_slices) do
            if processed_slices[slice_info.num] then
                current_run_completed = current_run_completed + 1
            end
        end
        local remaining_in_run = #work_slices - current_run_completed
        
        -- Progress content (excluding time/spinner)
        local progress_content = string.format("Progress: %d/%d slices, %d remaining, %d workers active", 
            current_run_completed, #work_slices, remaining_in_run, running)
        
        -- Simple timing using os.clock() 
        local current_time = os.clock()
        
        -- Calculate spinner character (rotations per second controlled by SPINNER_SPEED)
        local spinner_chars = {"|", "\\", "—", "/"}
        local spinner_index = (math.floor(current_time * SPINNER_SPEED * #spinner_chars) % #spinner_chars) + 1
        local spinner = running > 0 and spinner_chars[spinner_index] or " "
        
        -- Check if progress content has changed (thread finished, new worker, etc.)
        if progress_content ~= last_progress_content then
            -- Content changed - print new line with full status
            if progress_line_written then
                io.write("\n")  -- Move to new line
            end
            
            local full_line = string.format("[%s] %s %s", os.date("%H:%M:%S"), spinner, progress_content)
            io.write(full_line)
            io.flush()
            
            last_progress_content = progress_content
            last_spinner_update = current_time
            progress_line_written = true
            
        elseif current_time - last_spinner_update >= (1.0 / SPINNER_SPEED) then  -- Update display 3x per second
            -- Only timestamp and spinner changed - overwrite current line
            local timestamp_and_spinner = string.format("[%s] %s ", os.date("%H:%M:%S"), spinner)
            
            -- Move cursor to start of line and write just timestamp + spinner
            io.write("\r" .. timestamp_and_spinner .. progress_content)
            io.flush()
            
            last_spinner_update = current_time
        end
        
        -- Check for completed workers
        for i = 1, max_workers do
            local worker = workers[i]
            if worker and not is_worker_running(worker) then
                local duration = os.time() - worker.start_time
                
                -- Check if analysis succeeded
                local analysis_file = get_output_filename(worker.slice_num)
                local success_file = io.open(analysis_file, "r")
                if success_file then
                    local content = success_file:read("*all")
                    success_file:close()
                    
                    if #content > 100 and not content:match("ANALYSIS_FAILED") then
                        local content_size = #content
                        io.write(string.format("\n✓ Worker completed slice_%s in %dm %ds (%d chars)\n", 
                            worker.slice_num, math.floor(duration / 60), duration % 60, content_size))
                        io.flush()
                        processed_slices[worker.slice_num] = true
                        progress_line_written = false  -- Force new progress line
                    else
                        local error_details = get_failure_details(worker.slice_num, 1)
                        io.write(string.format("\n✗ Worker failed on slice_%s after %dm %ds\n", 
                            worker.slice_num, math.floor(duration / 60), duration % 60))
                        io.write(string.format("   Reason: %s\n", error_details))
                        io.flush()
                        table.insert(failed_analyses, {slice = worker.slice_num, reason = error_details})
                        progress_line_written = false  -- Force new progress line
                    end
                else
                    local error_details = get_failure_details(worker.slice_num, 1)
                    io.write(string.format("\n✗ Worker failed on slice_%s after %dm %ds\n", 
                        worker.slice_num, math.floor(duration / 60), duration % 60))
                    io.write(string.format("   Reason: %s\n", error_details))
                    io.flush()
                    table.insert(failed_analyses, {slice = worker.slice_num, reason = error_details})
                    progress_line_written = false  -- Force new progress line
                end
                
                cleanup_worker(worker)
                workers[i] = nil
                
                -- Start new worker if more slices available and not shutting down
                if slice_index <= #work_slices and not should_quit then
                    local new_worker = start_worker(work_slices[slice_index])
                    if new_worker then
                        workers[i] = new_worker
                        io.write(string.format("\nStarted worker %d: slice_%s (%s)\n", 
                            i, new_worker.slice_num, new_worker.slice_file))
                        io.flush()
                        slice_index = slice_index + 1
                        progress_line_written = false  -- Force new progress line
                    end
                end
                
                -- Save progress
                save_progress({processed = processed_slices, failed = failed_analyses})
            end
        end
        
        if should_quit then
            io.write("\n🛑 Shutdown requested - waiting for active workers to finish...\n")
            io.flush()
            progress_line_written = false  -- Force new progress line
            -- Stop starting new workers, let existing ones complete
            slice_index = #work_slices + 1
        end
        
        -- Sleep for slightly faster than spinner update rate to ensure smooth display
        os.execute("sleep 0.2")
    end
    
    restore_terminal()
    
    if should_quit then
        print("\n\n=== GRACEFUL SHUTDOWN COMPLETE ===")
        print("🛑 Shutdown requested - all active work completed safely")
    else
        print("\n\n=== PARALLEL ANALYSIS COMPLETE ===")
    end
    
    local final_done, final_total = get_analysis_status()
    print(string.format("Completed: %d/%d analyses", final_done, final_total))
    
    if #failed_analyses > 0 then
        print(string.format("Failed: %d analyses", #failed_analyses))
        for i, failure in ipairs(failed_analyses) do
            if type(failure) == "table" then
                print(string.format("  • slice_%s: %s", failure.slice, failure.reason))
            else
                print(string.format("  • slice_%s", failure))
            end
        end
    end
    
    if should_quit then
        print(string.format("🔄 Interrupted: %d/%d slices processed", final_done, final_total))
        print("💾 All progress saved - no work lost")
        print("🚀 Re-run with same arguments to continue where left off")
    elseif final_done == final_total then
        print("✓ All slices analyzed successfully!")
        clear_progress()
        
        -- Trigger narrative transformation
        trigger_narrative_transformation()
        
        print("")
        print("Next step: luajit " .. BASE_DIR .. "/theme-analysis/consolidate-analyses.lua")
    else
        print(string.format("⚠ %d slices still need analysis", final_total - final_done))
        print("Re-run this script to retry failed analyses")
    end
end

-- Utility functions
function table_size(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

function table_size_array(t)
    local count = 0
    for _, v in pairs(t) do
        if v then count = count + 1 end
    end
    return count
end

-- {{{ trigger_narrative_transformation
function trigger_narrative_transformation()
    print("")
    print("🔄 Triggering narrative transformation...")
    print("Converting analyses into 3rd person narratives...")
    
    local narrative_script = BASE_DIR .. "/theme-analysis/narrative.lua"
    local cmd = string.format("luajit %s --dir %s --sequential --skip", narrative_script, BASE_DIR)
    
    -- Pass along output filename if specified
    if output_filename then
        cmd = cmd .. " --output " .. output_filename .. "_narrative"
    end
    
    print("Running: " .. cmd)
    local result = os.execute(cmd)
    
    if result == true or result == 0 then
        print("✓ Narrative transformation completed successfully")
    else
        print("✗ Narrative transformation failed")
    end
end
-- }}}

-- Main function
function main()
    local mode, run_mode, thread_count = parse_arguments()
    sequential_mode = (run_mode == "sequential")
    max_workers = thread_count
    
    -- Handle help
    if mode == "help" then
        show_help()
        return
    end
    
    print("Theme Analysis System")
    print("====================")
    print(string.format("Mode: %s %s", 
        run_mode == "sequential" and "Sequential" or ("Parallel (" .. thread_count .. " workers)"),
        mode == "restart" and "(restart)" or mode == "refine" and "(refine)" or mode == "skip" and "(skip)" or ""))
    print("")
    
    -- Handle restart mode
    if mode == "restart" then
        print("🔄 Restart mode - clearing all previous work")
        clear_all_analyses()
        clear_progress()
        print("")
    end
    
    -- Create analyses directory
    os.execute("mkdir -p " .. ANALYSES_DIR)
    
    -- Get work queue based on mode
    local work_slices = {}
    local total_slices = #get_slice_files()
    
    if mode == "skip" then
        work_slices = get_pending_slices()
        print("📋 Skip mode - only processing missing slices")
        
        -- Debug information
        local all_slices = get_slice_files()
        local completed_analyses = get_completed_analyses()
        local completed_count = 0
        for _ in pairs(completed_analyses) do completed_count = completed_count + 1 end
        
        print(string.format("🔍 Debug: Found %d slice files, %d completed analyses, %d pending slices", 
            #all_slices, completed_count, #work_slices))
        
        if #work_slices == 0 then
            if #all_slices == 0 then
                print("❌ Error: No slice files found in " .. SLICES_DIR .. "/")
                print("Please run the slice preparation script first")
                return
            else
                print("✓ All slices already analyzed!")
                print("Run: luajit " .. BASE_DIR .. "/theme-analysis/consolidate-analyses.lua")
                return
            end
        end
        
    elseif mode == "refine" then
        local all_slice_files = get_slice_files()
        local existing_analyses = get_completed_analyses()
        
        for _, slice_file in ipairs(all_slice_files) do
            local slice_num = slice_file:match("slice_(%d+)%.txt")
            if slice_num and existing_analyses[slice_num] then
                table.insert(work_slices, {file = slice_file, num = slice_num})
            end
        end
        
        print("🔄 Refine mode - improving existing analyses heuristically")
        
        if #work_slices == 0 then
            print("❌ No existing analyses found to refine!")
            print("Run with --restart first to create initial analyses")
            return
        end
        
    else -- restart mode
        work_slices = get_pending_slices()
        print("🆕 Fresh analysis - processing all slices")
    end
    
    -- Run analysis
    if sequential_mode then
        run_sequential_analysis(work_slices, mode)
    else
        run_parallel_analysis(work_slices, mode)
    end
end

main()
