#!/usr/bin/env luajit

-- Corpus Splitter for Theme Analysis
-- Splits input/compiled.txt into 40 balanced slices on poem boundaries

function count_poems(filename)
    local count = 0
    local file = io.open(filename, "r")
    if not file then
        error("Cannot open " .. filename)
    end
    
    for line in file:lines() do
        if line == string.rep("-", 80) then
            count = count + 1
        end
    end
    file:close()
    return count
end

function split_corpus(input_file, output_dir, num_slices)
    local file = io.open(input_file, "r")
    if not file then
        error("Cannot open " .. input_file)
    end
    
    print("Counting total poems...")
    local total_poems = count_poems(input_file)
    print("Total poems found: " .. total_poems)
    
    local poems_per_slice = math.floor(total_poems / num_slices)
    local extra_poems = total_poems % num_slices
    
    print("Target poems per slice: " .. poems_per_slice)
    if extra_poems > 0 then
        print("Extra poems to distribute: " .. extra_poems)
    end
    
    file:seek("set", 0) -- Reset to beginning
    
    local current_slice = 1
    local poems_in_current_slice = 0
    local current_slice_target = poems_per_slice
    if current_slice <= extra_poems then
        current_slice_target = current_slice_target + 1
    end
    
    local output_file = io.open(string.format("%s/slice_%03d.txt", output_dir, current_slice), "w")
    if not output_file then
        error("Cannot create output file")
    end
    
    local current_poem = {}
    local in_poem = false
    local line_count = 0
    
    print("\nSplitting corpus...")
    
    for line in file:lines() do
        line_count = line_count + 1
        
        if line_count % 10000 == 0 then
            print("Processed " .. line_count .. " lines...")
        end
        
        if line:match("^ %-> file:") then
            -- Found next poem header - finish previous poem if any
            if #current_poem > 0 then
                -- Write complete previous poem to current slice
                for _, poem_line in ipairs(current_poem) do
                    output_file:write(poem_line .. "\n")
                end
                
                poems_in_current_slice = poems_in_current_slice + 1
                
                -- Check if we need to start a new slice
                if poems_in_current_slice >= current_slice_target and current_slice < num_slices then
                    output_file:close()
                    print(string.format("Slice %03d complete: %d poems", current_slice, poems_in_current_slice))
                    
                    current_slice = current_slice + 1
                    poems_in_current_slice = 0
                    
                    -- Calculate target for next slice
                    current_slice_target = poems_per_slice
                    if current_slice <= extra_poems then
                        current_slice_target = current_slice_target + 1
                    end
                    
                    if current_slice <= num_slices then
                        output_file = io.open(string.format("%s/slice_%03d.txt", output_dir, current_slice), "w")
                        if not output_file then
                            error("Cannot create slice file " .. current_slice)
                        end
                    end
                end
            end
            
            -- Start new poem
            current_poem = {line}
            in_poem = true
            
        elseif line == string.rep("-", 80) then
            -- Dash separator - part of poem structure
            if in_poem then
                table.insert(current_poem, line)
            end
            
        elseif in_poem then
            -- Content line within a poem
            table.insert(current_poem, line)
            
        else
            -- Content line that belongs to the last poem (after its dashes)
            if #current_poem > 0 then
                table.insert(current_poem, line)
            end
        end
    end
    
    -- Handle any remaining content
    if #current_poem > 0 then
        for _, poem_line in ipairs(current_poem) do
            output_file:write(poem_line .. "\n")
        end
        poems_in_current_slice = poems_in_current_slice + 1
    end
    
    if output_file then
        output_file:close()
        print(string.format("Slice %03d complete: %d poems", current_slice, poems_in_current_slice))
    end
    
    file:close()
    print("\nCorpus splitting complete!")
    
    -- Verify splits
    print("\nVerification:")
    local total_split_poems = 0
    for i = 1, current_slice do
        local slice_file = string.format("%s/slice_%03d.txt", output_dir, i)
        local slice_poems = count_poems(slice_file)
        print(string.format("  slice_%03d.txt: %d poems", i, slice_poems))
        total_split_poems = total_split_poems + slice_poems
    end
    
    print(string.format("\nOriginal: %d poems", total_poems))
    print(string.format("Split total: %d poems", total_split_poems))
    
    if total_poems == total_split_poems then
        print("✓ Verification successful - no poems lost!")
    else
        print("✗ Verification failed - poem count mismatch!")
    end
    
    return current_slice
end

function main()
    local input_file = "input/compiled.txt"
    local output_dir = "theme-analysis/slices"
    local num_slices = 40
    
    print("Theme Analysis Corpus Splitter")
    print("==============================")
    print("Input file: " .. input_file)
    print("Output directory: " .. output_dir)
    print("Target slices: " .. num_slices)
    print("")
    
    -- Check if input file exists
    local test_file = io.open(input_file, "r")
    if not test_file then
        error("Input file not found: " .. input_file)
    end
    test_file:close()
    
    -- Create output directory if it doesn't exist
    os.execute("mkdir -p " .. output_dir)
    
    -- Clear any existing slices
    os.execute("rm -f " .. output_dir .. "/slice_*.txt")
    
    local actual_slices = split_corpus(input_file, output_dir, num_slices)
    
    print("\n=== SPLITTING COMPLETE ===")
    print("Created " .. actual_slices .. " slice files")
    print("Ready for parallel analysis!")
    print("")
    print("Next step: lua5.2 theme-analysis/analyze_parallel.lua")
end

main()