#!/usr/bin/env luajit

-- Migration Script: Convert Full Individual Files to Triangular Format
-- Reads existing poem_*.json files and removes redundant lower-triangle entries
-- Each file will only contain similarities where other_id > this_id

local DIR = DIR or "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
package.path = DIR .. '/libs/?.lua;' .. package.path

local utils = require('utils')
local dkjson = require('dkjson')

local function migrate_files(similarities_dir, dry_run)
    dry_run = dry_run or false

    print("🔄 Migrating similarity files to triangular format")
    print("   Directory: " .. similarities_dir)
    print("   Dry run: " .. tostring(dry_run))
    print()

    -- Get list of all similarity files
    local files = {}
    local find_cmd = string.format("find '%s' -name 'poem_*.json' -type f", similarities_dir)
    local handle = io.popen(find_cmd)
    if handle then
        for filepath in handle:lines() do
            table.insert(files, filepath)
        end
        handle:close()
    end

    if #files == 0 then
        print("❌ No similarity files found in " .. similarities_dir)
        return false
    end

    print(string.format("Found %d files to migrate", #files))
    print()

    local migrated = 0
    local skipped = 0
    local errors = 0
    local total_size_before = 0
    local total_size_after = 0

    for i, filepath in ipairs(files) do
        -- Extract poem ID from filename
        local poem_id = tonumber(filepath:match("poem_(%d+)%.json$"))
        if not poem_id then
            print(string.format("⚠️  Skipping %s (can't extract poem ID)", filepath))
            skipped = skipped + 1
            goto continue
        end

        -- Read existing file
        local file_data = utils.read_json_file(filepath)
        if not file_data or not file_data.similarities then
            print(string.format("⚠️  Skipping poem %d (can't read file)", poem_id))
            skipped = skipped + 1
            goto continue
        end

        -- Check if already triangular
        if file_data.metadata and file_data.metadata.format == "triangular_upper" then
            skipped = skipped + 1
            goto continue
        end

        -- Calculate original size
        local orig_size = #file_data.similarities

        -- Filter to keep only upper triangle (other_id > poem_id)
        local triangular_similarities = {}
        for _, entry in ipairs(file_data.similarities) do
            local other_id = tonumber(entry.id)
            if other_id and other_id > poem_id then
                table.insert(triangular_similarities, entry)
            end
        end

        -- Calculate new size
        local new_size = #triangular_similarities

        -- Update metadata
        file_data.similarities = triangular_similarities
        file_data.metadata = file_data.metadata or {}
        file_data.metadata.format = "triangular_upper"
        file_data.metadata.range = string.format("%d-7797", poem_id + 1)
        file_data.metadata.total_comparisons = new_size
        file_data.metadata.migrated_at = os.date("%Y-%m-%d %H:%M:%S")

        total_size_before = total_size_before + orig_size
        total_size_after = total_size_after + new_size

        -- Write back (unless dry run)
        if not dry_run then
            local success = utils.write_json_file(filepath, file_data)
            if not success then
                print(string.format("❌ Error writing poem %d", poem_id))
                errors = errors + 1
                goto continue
            end
        end

        migrated = migrated + 1

        -- Progress indicator
        if migrated % 100 == 0 then
            local reduction_pct = ((orig_size - new_size) / orig_size) * 100
            print(string.format("Progress: %d/%d migrated (poem %d: %d → %d entries, %.1f%% reduction)",
                migrated, #files, poem_id, orig_size, new_size, reduction_pct))
        end

        ::continue::
    end

    -- Summary
    print()
    print("📊 Migration Summary:")
    print(string.format("   Total files: %d", #files))
    print(string.format("   ✅ Migrated: %d", migrated))
    print(string.format("   ⏭️  Skipped: %d (already triangular)", skipped))
    print(string.format("   ❌ Errors: %d", errors))
    print()
    print(string.format("   Entries before: %.1fM", total_size_before / 1000000))
    print(string.format("   Entries after: %.1fM", total_size_after / 1000000))
    print(string.format("   Reduction: %.1f%%",
        ((total_size_before - total_size_after) / total_size_before) * 100))
    print()

    if dry_run then
        print("🔍 DRY RUN: No files were modified")
        print("   Run without --dry-run to apply changes")
    else
        print("✅ Migration complete!")
    end

    return errors == 0
end

-- Command line execution
if arg and arg[0] then
    local similarities_dir = arg[1] or "assets/embeddings/embeddinggemma_latest/similarities"
    local dry_run = arg[2] == "--dry-run"

    print("Triangular Similarity Files Migration")
    print("=====================================")
    print()

    local success = migrate_files(similarities_dir, dry_run)
    os.exit(success and 0 or 1)
end

return {migrate_files = migrate_files}
