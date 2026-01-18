-- {{{ Pipeline Validator Module
-- Provides validation functions for checking pipeline data completeness and freshness
-- Used by scripts to fail-fast before starting long-running operations
-- }}}

local M = {}

local dkjson = require('dkjson')

-- {{{ Configuration
M.config = {
    poems_json = "assets/poems.json",
    embeddings_dir = "assets/embeddings",
    default_model = "embeddinggemma_latest",
    output_similar_dir = "output/similar",
    output_different_dir = "output/different",
    verbose = false
}
-- }}}

-- {{{ Helper: Log functions
local function log_error(msg)
    io.stderr:write("❌ ERROR: " .. msg .. "\n")
end

local function log_warning(msg)
    io.stderr:write("⚠️  WARNING: " .. msg .. "\n")
end

local function log_info(msg)
    if M.config.verbose then
        io.stderr:write("ℹ️  " .. msg .. "\n")
    end
end
-- }}}

-- {{{ Helper: Count files matching pattern
local function count_files(directory, pattern)
    if not directory then return 0 end

    local handle = io.popen(string.format(
        "find '%s' -name '%s' -type f 2>/dev/null | wc -l",
        directory, pattern
    ))
    if not handle then return 0 end

    local result = handle:read("*a")
    handle:close()

    return tonumber(result) or 0
end
-- }}}

-- {{{ Helper: Get file modification time
local function get_mtime(filepath)
    local handle = io.popen(string.format("stat -c '%%Y' '%s' 2>/dev/null", filepath))
    if not handle then return 0 end

    local result = handle:read("*a")
    handle:close()

    return tonumber(result) or 0
end
-- }}}

-- {{{ Helper: Load JSON file
local function load_json_file(filepath)
    local file = io.open(filepath, "r")
    if not file then
        return nil, "File not found: " .. filepath
    end

    local content = file:read("*all")
    file:close()

    local data, pos, err = dkjson.decode(content)
    if not data then
        return nil, "JSON parse error at position " .. tostring(pos) .. ": " .. tostring(err)
    end

    return data
end
-- }}}

-- {{{ check_embeddings
-- Checks if embeddings are complete for all poems
-- Returns: {complete = bool, count = num, total = num, missing = num, status = string}
function M.check_embeddings(model)
    model = model or M.config.default_model
    local result = {
        complete = false,
        count = 0,
        total = 0,
        missing = 0,
        status = "UNKNOWN"
    }

    -- Count total poems
    local poems_data, err = load_json_file(M.config.poems_json)
    if not poems_data then
        result.status = "ERROR"
        result.error = "Cannot read poems.json: " .. tostring(err)
        return result
    end

    result.total = poems_data.poems and #poems_data.poems or 0

    -- Count embeddings (individual similarity files = one per poem)
    local similarities_dir = string.format("%s/%s/similarities", M.config.embeddings_dir, model)
    result.count = count_files(similarities_dir, "poem_*.json")

    result.missing = result.total - result.count
    result.complete = (result.count == result.total and result.total > 0)

    if result.complete then
        result.status = "COMPLETE"
    elseif result.count == 0 then
        result.status = "MISSING"
    else
        result.status = "INCOMPLETE"
    end

    log_info(string.format("Embeddings: %d/%d (%.1f%%)", result.count, result.total,
        result.total > 0 and (result.count / result.total * 100) or 0))

    return result
end
-- }}}

-- {{{ check_similarity_matrix
-- Checks if similarity matrix files exist for all poems
-- Returns: {complete = bool, count = num, total = num, missing = num, status = string}
function M.check_similarity_matrix(model)
    model = model or M.config.default_model
    local result = {
        complete = false,
        count = 0,
        total = 0,
        missing = 0,
        status = "UNKNOWN"
    }

    -- Count total poems
    local poems_data, err = load_json_file(M.config.poems_json)
    if not poems_data then
        result.status = "ERROR"
        result.error = "Cannot read poems.json: " .. tostring(err)
        return result
    end

    result.total = poems_data.poems and #poems_data.poems or 0

    -- Count similarity matrix files
    local similarities_dir = string.format("%s/%s/similarities", M.config.embeddings_dir, model)
    result.count = count_files(similarities_dir, "poem_*.json")

    result.missing = result.total - result.count
    result.complete = (result.count == result.total and result.total > 0)

    if result.complete then
        result.status = "COMPLETE"
    elseif result.count == 0 then
        result.status = "MISSING"
    else
        result.status = "INCOMPLETE"
    end

    log_info(string.format("Similarity Matrix: %d/%d (%.1f%%)", result.count, result.total,
        result.total > 0 and (result.count / result.total * 100) or 0))

    return result
end
-- }}}

-- {{{ check_diversity_cache
-- Checks if diversity cache exists and is complete
-- Returns: {complete = bool, count = num, total = num, status = string, exists = bool}
function M.check_diversity_cache(model)
    model = model or M.config.default_model
    local result = {
        complete = false,
        count = 0,
        total = 0,
        status = "MISSING",
        exists = false
    }

    -- Count total poems
    local poems_data, err = load_json_file(M.config.poems_json)
    if not poems_data then
        result.status = "ERROR"
        result.error = "Cannot read poems.json: " .. tostring(err)
        return result
    end

    result.total = poems_data.poems and #poems_data.poems or 0

    -- Check diversity cache
    local cache_file = string.format("%s/%s/diversity_cache.json", M.config.embeddings_dir, model)
    local cache_data, cache_err = load_json_file(cache_file)

    if cache_data then
        result.exists = true
        -- Count sequences in cache
        local count = 0
        for _ in pairs(cache_data) do
            count = count + 1
        end
        result.count = count
        result.complete = (count == result.total)
        result.status = result.complete and "COMPLETE" or "INCOMPLETE"
    else
        result.status = "MISSING"
        result.exists = false
    end

    log_info(string.format("Diversity Cache: %s (%d/%d)", result.status, result.count, result.total))

    return result
end
-- }}}

-- {{{ check_freshness
-- Checks if cached data is fresher than source data
-- Returns: {fresh = bool, issues = {}}
function M.check_freshness(model)
    model = model or M.config.default_model
    local result = {
        fresh = true,
        issues = {}
    }

    local poems_mtime = get_mtime(M.config.poems_json)
    local embeddings_file = string.format("%s/%s/embeddings.json", M.config.embeddings_dir, model)
    local embeddings_mtime = get_mtime(embeddings_file)

    -- Check if embeddings are stale
    if poems_mtime > embeddings_mtime then
        result.fresh = false
        table.insert(result.issues, {
            type = "STALE_EMBEDDINGS",
            message = "poems.json is newer than embeddings.json",
            fix = "./generate-embeddings.sh --incremental"
        })
    end

    -- Check if similarity matrix is stale
    local similarities_dir = string.format("%s/%s/similarities", M.config.embeddings_dir, model)
    local handle = io.popen(string.format(
        "find '%s' -name 'poem_*.json' -type f -printf '%%T@\\n' 2>/dev/null | sort -n | tail -1",
        similarities_dir
    ))
    if handle then
        local latest_sim = handle:read("*a")
        handle:close()
        local similarity_mtime = tonumber(latest_sim) or 0

        if similarity_mtime > 0 and embeddings_mtime > similarity_mtime then
            result.fresh = false
            table.insert(result.issues, {
                type = "STALE_SIMILARITY",
                message = "embeddings.json is newer than similarity matrix",
                fix = "lua src/similarity-engine-parallel.lua"
            })
        end
    end

    -- Check if diversity cache is stale
    local cache_file = string.format("%s/%s/diversity_cache.json", M.config.embeddings_dir, model)
    local cache_mtime = get_mtime(cache_file)

    if cache_mtime > 0 and embeddings_mtime > cache_mtime then
        result.fresh = false
        table.insert(result.issues, {
            type = "STALE_DIVERSITY",
            message = "embeddings.json is newer than diversity cache",
            fix = "./scripts/precompute-diversity-sequences"
        })
    end

    log_info(string.format("Freshness: %s (%d issues)", result.fresh and "FRESH" or "STALE", #result.issues))

    return result
end
-- }}}

-- {{{ validate_for_html_generation
-- Comprehensive check before HTML generation
-- Returns: {ready = bool, errors = {}, warnings = {}}
function M.validate_for_html_generation(model, require_diversity_cache)
    model = model or M.config.default_model
    require_diversity_cache = require_diversity_cache == nil and true or require_diversity_cache

    local result = {
        ready = true,
        errors = {},
        warnings = {}
    }

    -- Check embeddings
    local emb = M.check_embeddings(model)
    if not emb.complete then
        result.ready = false
        table.insert(result.errors, {
            type = "INCOMPLETE_EMBEDDINGS",
            message = string.format("Embeddings incomplete: %d/%d poems", emb.count, emb.total),
            fix = "./generate-embeddings.sh --incremental"
        })
    end

    -- Check similarity matrix
    local sim = M.check_similarity_matrix(model)
    if not sim.complete then
        result.ready = false
        table.insert(result.errors, {
            type = "INCOMPLETE_SIMILARITY",
            message = string.format("Similarity matrix incomplete: %d/%d poems", sim.count, sim.total),
            fix = "lua src/similarity-engine-parallel.lua"
        })
    end

    -- Check diversity cache (optional warning if require_diversity_cache is false)
    local div = M.check_diversity_cache(model)
    if not div.complete then
        if require_diversity_cache then
            result.ready = false
            table.insert(result.errors, {
                type = "MISSING_DIVERSITY",
                message = "Diversity cache not generated",
                fix = "./scripts/precompute-diversity-sequences"
            })
        else
            table.insert(result.warnings, {
                type = "MISSING_DIVERSITY",
                message = "Diversity cache not generated (generation will be slow)",
                fix = "./scripts/precompute-diversity-sequences"
            })
        end
    end

    -- Check freshness
    local fresh = M.check_freshness(model)
    if not fresh.fresh then
        for _, issue in ipairs(fresh.issues) do
            table.insert(result.warnings, issue)
        end
    end

    return result
end
-- }}}

-- {{{ print_validation_report
-- Prints a formatted validation report to stderr
function M.print_validation_report(validation)
    if #validation.errors > 0 then
        log_error("Pipeline validation failed:")
        for _, err in ipairs(validation.errors) do
            io.stderr:write(string.format("  • %s\n", err.message))
            io.stderr:write(string.format("    Fix: %s\n", err.fix))
        end
        io.stderr:write("\n")
    end

    if #validation.warnings > 0 then
        log_warning("Pipeline warnings:")
        for _, warn in ipairs(validation.warnings) do
            io.stderr:write(string.format("  • %s\n", warn.message))
            io.stderr:write(string.format("    Fix: %s\n", warn.fix))
        end
        io.stderr:write("\n")
    end

    if validation.ready then
        io.stderr:write("✅ Pipeline ready for HTML generation\n\n")
    else
        io.stderr:write("❌ Pipeline NOT ready - fix errors above\n\n")
    end
end
-- }}}

-- {{{ set_verbose
-- Enable/disable verbose logging
function M.set_verbose(verbose)
    M.config.verbose = verbose
end
-- }}}

return M
-- }}}
