#!/usr/bin/env lua

-- Validation Engine for Similarity Data Integrity
-- Iterative system for validating stored similarity scores against recalculated values

package.path = package.path .. ';./?.lua;./libs/?.lua'

local utils = require("libs.utils")
local json = require("libs.json")
local similarity_module = require("src.similarity-calculator")
local SimilarityCalculator = similarity_module.SimilarityCalculator

local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

local ValidationEngine = {}
ValidationEngine.__index = ValidationEngine

-- {{{ function ValidationEngine:new
function ValidationEngine:new(config)
    config = config or {}
    local obj = {
        config = config,
        calculator = nil,  -- Will be set from modular calculator
        tolerance = config.tolerance or 0.001,
        sample_size = config.sample_size or nil,  -- nil = validate all
        progress_callback = config.progress_callback or nil,
        validation_results = {
            total_comparisons = 0,
            accurate_scores = 0,
            inaccurate_scores = 0,
            missing_embeddings = 0,
            errors = {},
            discrepancies = {},
            start_time = nil,
            end_time = nil
        }
    }
    
    setmetatable(obj, ValidationEngine)
    return obj
end
-- }}}

-- {{{ function ValidationEngine:set_calculator
function ValidationEngine:set_calculator(calculator)
    self.calculator = calculator
end
-- }}}

-- {{{ function ValidationEngine:load_embeddings_by_index
-- Turn embeddings.json into a plain map: poem_index -> embedding array.
--
-- The file is { embeddings = [ {poem_index=, embedding=, ...}, ... ] }, but the
-- comparison below wants to look a poem up by number. The old code indexed the
-- decoded file DIRECTLY by id, which finds nothing at all -- so every pair was
-- counted as "missing embedding" and the accuracy figure was computed over an
-- empty set. A validator that reports on nothing, confidently, is worse than one
-- that refuses to start.
--
-- Keyed on poem_index, never id: id restarts at 1 in every source category, so
-- five different poems answer to it (Issue 8-019).
function ValidationEngine:load_embeddings_by_index(embeddings_file)
    local data = utils.read_json_file(embeddings_file)
    if not data or not data.embeddings then
        return nil, "could not read embeddings: " .. tostring(embeddings_file)
    end

    local by_index, n = {}, 0
    for _, entry in ipairs(data.embeddings) do
        if entry.poem_index and entry.embedding then
            by_index[entry.poem_index] = entry.embedding
            n = n + 1
        end
    end
    if n == 0 then
        return nil, "embeddings file contained no usable entries"
    end
    return by_index, n, data.embeddings
end
-- }}}

-- {{{ function ValidationEngine:collect_pairs_from_store
-- Read stored similarity scores out of the per-poem files.
--
-- Similarity used to live in ONE file holding every poem against every other,
-- and this validator read it with a nested loop. Issue 8-033 replaced that with
-- one file per poem under similarities/ -- scalable, resumable, and not requiring
-- gigabytes of RAM to answer a single question. The validator was never moved
-- across, so it has been opening a filename nothing has written since. It ran,
-- failed to find the file, and concluded the algorithm needed review.
--
-- Sampling happens WHILE reading, not after. The full store is roughly 9,000
-- files of 9,000 comparisons each -- on the order of eighty million pairs, which
-- cannot be collected first and thinned later. So: take a sample of poems, read
-- only those files, and take a sample of comparisons from each.
--
-- Returns an array of { poem_a, poem_b, stored_score }.
function ValidationEngine:collect_pairs_from_store(similarities_dir, want_pairs)
    local pairs_out = {}

    -- Which poem files exist. Listed rather than assumed contiguous: a resumed
    -- or partial generation leaves gaps, and walking 1..N blindly would report
    -- those gaps as validation failures rather than as missing files.
    local listing = io.popen(string.format(
        "find %q -name 'poem_index_*.json' -type f 2>/dev/null | sort", similarities_dir))
    if not listing then
        return nil, "could not list " .. similarities_dir
    end
    local files = {}
    for line in listing:lines() do files[#files + 1] = line end
    listing:close()

    if #files == 0 then
        return nil, string.format(
            "no per-poem similarity files in %s -- run stage 7 (--generate-similarity) first",
            similarities_dir)
    end

    -- How many files to open, and how many comparisons to take from each. Spread
    -- the budget across files rather than draining a few: a discrepancy caused by
    -- one bad file is easy to miss if the sample only ever looks at ten of them.
    local max_files = math.min(#files, 200)
    local per_file = math.max(1, math.ceil(want_pairs / max_files))
    local stride = math.max(1, math.floor(#files / max_files))

    local opened = 0
    for i = 1, #files, stride do
        if #pairs_out >= want_pairs then break end
        local data = utils.read_json_file(files[i])
        if data and data.similarities and data.metadata and data.metadata.poem_index then
            opened = opened + 1
            local a = data.metadata.poem_index
            local entries = data.similarities
            -- Sample across the whole ranked list, not just its head: the top of
            -- the list is where any scoring is most likely to look right, so
            -- checking only the top would flatter a broken one.
            local inner_stride = math.max(1, math.floor(#entries / per_file))
            for j = 1, #entries, inner_stride do
                local e = entries[j]
                if e and e.id and e.similarity then
                    pairs_out[#pairs_out + 1] = {
                        poem_a = a,
                        poem_b = tonumber(e.id),
                        stored_score = tonumber(e.similarity),
                    }
                    if #pairs_out >= want_pairs then break end
                end
            end
        end
    end

    print(string.format("Read %d stored pairs from %d of %d per-poem files",
        #pairs_out, opened, #files))
    return pairs_out
end
-- }}}

-- {{{ function ValidationEngine:validate_similarity_matrix
-- Check that the similarity scores on disk match what recomputing them gives.
--
-- similarity_source: the similarities/ DIRECTORY (a path to the retired single
--                    matrix file is rejected with a message saying so, rather
--                    than failing on "not found" and blaming the algorithm).
-- embeddings_file:   embeddings.json for the same model.
function ValidationEngine:validate_similarity_matrix(similarity_source, embeddings_file)
    if not self.calculator then
        error("Similarity calculator must be set before validation")
    end

    self.validation_results.start_time = os.time()
    print(string.format("Starting validation: %s vs %s", similarity_source, embeddings_file))

    if similarity_source:match("%.json$") then
        error(string.format(
            "validate_similarity_matrix expects the similarities/ DIRECTORY, not a file.\n"
            .. "  Got: %s\n"
            .. "  The single-file similarity matrix was retired in Issue 8-033; scores now\n"
            .. "  live as one file per poem under <model>/similarities/.", similarity_source))
    end

    local embeddings_by_index, count_or_err, raw_entries =
        self:load_embeddings_by_index(embeddings_file)
    if not embeddings_by_index then
        error("Failed to load embeddings: " .. tostring(count_or_err))
    end
    print(string.format("Loaded %d embeddings", count_or_err))

    -- Recompute in the SAME vector space the stored scores were built in.
    --
    -- Without this every score would appear wrong -- not slightly, but by more
    -- than any tolerance -- and the validator would report total corruption of a
    -- perfectly good matrix. The shared direction is subtracted before comparison
    -- everywhere else in the project (libs/embedding-space.lua); a checker that
    -- skipped it would be checking a different question than the one asked.
    local embedding_space = require("embedding-space")
    local mean, mean_detail = embedding_space.corpus_mean(raw_entries)
    if not mean then
        error("Could not centre the embedding space for validation: " .. tostring(mean_detail))
    end
    self.centered_embeddings = {}
    for idx, vec in pairs(embeddings_by_index) do
        self.centered_embeddings[idx] = embedding_space.centered(vec, mean)
    end
    print(string.format("Recomputing in the %s space", embedding_space.SPACE_VERSION))

    -- Say whether the store claims the same space. A mismatch does not stop the
    -- run -- the numbers are the real evidence -- but it explains a wall of
    -- discrepancies before the reader starts hunting for a cause.
    local store_root = similarity_source:gsub("/similarities/?$", "")
    local stamped = embedding_space.read_fingerprint(store_root)
    if stamped ~= embedding_space.SPACE_VERSION then
        print(string.format(
            "  NOTE: the stored scores are marked '%s' but this check recomputes in '%s'."
            .. " Expect discrepancies until stage 7 is re-run.",
            stamped or "unmarked", embedding_space.SPACE_VERSION))
    end

    local want = self.sample_size or 5000
    local validation_pairs, collect_err = self:collect_pairs_from_store(similarity_source, want)
    if not validation_pairs then
        error("Failed to read stored similarities: " .. tostring(collect_err))
    end

    print(string.format("Validating %d similarity pairs...", #validation_pairs))

    local progress_interval = math.max(1, math.floor(#validation_pairs / 20))
    for i, pair in ipairs(validation_pairs) do
        if i % progress_interval == 0 then
            print(string.format("Progress: %d/%d (%.1f%%)", i, #validation_pairs, (i/#validation_pairs)*100))
            if self.progress_callback then
                self.progress_callback(i, #validation_pairs)
            end
        end
        self:validate_similarity_pair(pair, self.centered_embeddings)
    end

    self.validation_results.end_time = os.time()
    return self:generate_validation_report()
end
-- }}}

-- {{{ function ValidationEngine:validate_similarity_pair
-- One stored score against one recomputed score.
--
-- embeddings_by_index is keyed by NUMBER (poem_index), matching what
-- load_embeddings_by_index builds and what the per-poem files record. The old
-- code looked up tostring(id) in the raw decoded file, which matched nothing.
function ValidationEngine:validate_similarity_pair(pair, embeddings_by_index)
    local poem_a_id, poem_b_id, stored_score = pair.poem_a, pair.poem_b, pair.stored_score

    self.validation_results.total_comparisons = self.validation_results.total_comparisons + 1

    -- A stored score that is not a number at all -- a string, a null, a missing
    -- field. tonumber() gave nil upstream and the comparison below would try
    -- arithmetic on it and take the whole run down. Recorded as a data fault and
    -- carried past: a validator that dies on the first malformed record cannot
    -- tell you how many malformed records there are, which is the one question
    -- worth asking once you know there is one.
    if type(stored_score) ~= "number" then
        table.insert(self.validation_results.errors, {
            type = "malformed_stored_score",
            poem_a = poem_a_id,
            poem_b = poem_b_id,
            error = "stored similarity is not a number"
        })
        return
    end

    local embedding_a = embeddings_by_index[poem_a_id]
    local embedding_b = embeddings_by_index[poem_b_id]

    if not embedding_a or not embedding_b then
        self.validation_results.missing_embeddings = self.validation_results.missing_embeddings + 1
        table.insert(self.validation_results.errors, {
            type = "missing_embedding",
            poem_a = poem_a_id,
            poem_b = poem_b_id,
            missing = not embedding_a and "poem_a" or "poem_b"
        })
        return
    end

    local success, calculated_score = pcall(function()
        return self.calculator:calculate(embedding_a, embedding_b)
    end)

    if not success then
        table.insert(self.validation_results.errors, {
            type = "calculation_error",
            poem_a = poem_a_id,
            poem_b = poem_b_id,
            error = calculated_score
        })
        return
    end

    local difference = math.abs(calculated_score - stored_score)

    if difference <= self.tolerance then
        self.validation_results.accurate_scores = self.validation_results.accurate_scores + 1
    else
        self.validation_results.inaccurate_scores = self.validation_results.inaccurate_scores + 1
        table.insert(self.validation_results.discrepancies, {
            poem_a = poem_a_id,
            poem_b = poem_b_id,
            stored_score = stored_score,
            calculated_score = calculated_score,
            difference = difference,
            relative_error = math.abs(stored_score) > 0 and (difference / math.abs(stored_score)) or 0
        })
    end
end
-- }}}

-- {{{ function ValidationEngine:generate_validation_report
function ValidationEngine:generate_validation_report()
    local results = self.validation_results
    local duration = results.end_time - results.start_time
    
    -- Calculate statistics
    local accuracy_rate = results.total_comparisons > 0 and 
                         (results.accurate_scores / results.total_comparisons) or 0
    
    local error_rate = results.total_comparisons > 0 and
                      (results.inaccurate_scores / results.total_comparisons) or 0
    
    local report = {
        algorithm = self.calculator and self.calculator.algorithm or "unknown",
        timestamp = os.date("%Y-%m-%d %H:%M:%S", results.start_time),
        duration_seconds = duration,
        statistics = {
            total_comparisons = results.total_comparisons,
            accurate_scores = results.accurate_scores,
            inaccurate_scores = results.inaccurate_scores,
            missing_embeddings = results.missing_embeddings,
            accuracy_rate = accuracy_rate,
            error_rate = error_rate,
            tolerance = self.tolerance
        },
        performance = {
            comparisons_per_second = duration > 0 and (results.total_comparisons / duration) or 0,
            avg_comparison_time_ms = duration > 0 and (duration * 1000 / results.total_comparisons) or 0
        },
        discrepancies = {
            count = #results.discrepancies,
            samples = self:get_worst_discrepancies(10),
            max_difference = self:get_max_discrepancy(),
            avg_difference = self:get_average_discrepancy()
        },
        errors = {
            count = #results.errors,
            by_type = self:group_errors_by_type(),
            samples = results.errors
        },
        recommendations = self:generate_recommendations()
    }
    
    return report
end
-- }}}

-- {{{ function ValidationEngine:get_worst_discrepancies
function ValidationEngine:get_worst_discrepancies(limit)
    local sorted_discrepancies = {}
    for _, disc in ipairs(self.validation_results.discrepancies) do
        table.insert(sorted_discrepancies, disc)
    end
    
    -- Sort by difference (highest first)
    table.sort(sorted_discrepancies, function(a, b)
        return a.difference > b.difference
    end)
    
    local result = {}
    for i = 1, math.min(limit, #sorted_discrepancies) do
        table.insert(result, sorted_discrepancies[i])
    end
    
    return result
end
-- }}}

-- {{{ function ValidationEngine:get_max_discrepancy
function ValidationEngine:get_max_discrepancy()
    local max_diff = 0
    for _, disc in ipairs(self.validation_results.discrepancies) do
        if disc.difference > max_diff then
            max_diff = disc.difference
        end
    end
    return max_diff > 0 and max_diff or nil
end
-- }}}

-- {{{ function ValidationEngine:get_average_discrepancy
function ValidationEngine:get_average_discrepancy()
    if #self.validation_results.discrepancies == 0 then
        return nil
    end
    
    local total_diff = 0
    for _, disc in ipairs(self.validation_results.discrepancies) do
        total_diff = total_diff + disc.difference
    end
    
    return total_diff / #self.validation_results.discrepancies
end
-- }}}

-- {{{ function ValidationEngine:group_errors_by_type
function ValidationEngine:group_errors_by_type()
    local grouped = {}
    for _, error in ipairs(self.validation_results.errors) do
        if not grouped[error.type] then
            grouped[error.type] = 0
        end
        grouped[error.type] = grouped[error.type] + 1
    end
    return grouped
end
-- }}}

-- {{{ function ValidationEngine:generate_recommendations
function ValidationEngine:generate_recommendations()
    local results = self.validation_results
    local recommendations = {}
    
    local accuracy_rate = results.total_comparisons > 0 and 
                         (results.accurate_scores / results.total_comparisons) or 0
    
    if accuracy_rate < 0.95 then
        table.insert(recommendations, "Low accuracy rate detected. Consider investigating calculation differences or updating stored similarity data.")
    end
    
    if results.missing_embeddings > 0 then
        table.insert(recommendations, string.format("%d missing embeddings found. Update embedding data or clean similarity matrix.", results.missing_embeddings))
    end
    
    if #results.errors > 0 then
        table.insert(recommendations, string.format("%d calculation errors occurred. Check embedding data quality and calculator implementation.", #results.errors))
    end
    
    local max_diff = self:get_max_discrepancy()
    if max_diff and max_diff > 0.1 then
        table.insert(recommendations, string.format("Maximum discrepancy of %.4f detected. Consider tightening tolerance or investigating calculation method.", max_diff))
    end
    
    if accuracy_rate > 0.99 then
        table.insert(recommendations, "Excellent accuracy rate. Stored similarity data appears reliable.")
    end
    
    return recommendations
end
-- }}}

-- {{{ function run_comprehensive_validation
local function run_comprehensive_validation(similarity_files, embeddings_files, algorithms, output_dir)
    local comprehensive_results = {
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        algorithms_tested = {},
        overall_statistics = {
            total_files = #similarity_files,
            total_algorithms = #algorithms,
            successful_validations = 0,
            failed_validations = 0
        },
        file_results = {}
    }
    
    for _, algorithm in ipairs(algorithms) do
        print(string.format("Testing algorithm: %s", algorithm))
        
        local calculator = SimilarityCalculator:new(algorithm, {cache_enabled = true})
        local engine = ValidationEngine:new({
            tolerance = 0.001,
            sample_size = 1000  -- Sample for large datasets
        })
        engine:set_calculator(calculator)
        
        local algorithm_results = {
            algorithm = algorithm,
            files_validated = 0,
            total_accuracy = 0,
            validations = {}
        }
        
        for i, similarity_file in ipairs(similarity_files) do
            local embeddings_file = embeddings_files[i]
            
            print(string.format("Validating file %d/%d with %s", i, #similarity_files, algorithm))
            
            local success, validation_result = pcall(function()
                return engine:validate_similarity_matrix(similarity_file, embeddings_file)
            end)
            
            if success then
                table.insert(algorithm_results.validations, validation_result)
                algorithm_results.files_validated = algorithm_results.files_validated + 1
                algorithm_results.total_accuracy = algorithm_results.total_accuracy + validation_result.statistics.accuracy_rate
                comprehensive_results.overall_statistics.successful_validations = comprehensive_results.overall_statistics.successful_validations + 1
            else
                print(string.format("Validation failed: %s", validation_result))
                comprehensive_results.overall_statistics.failed_validations = comprehensive_results.overall_statistics.failed_validations + 1
            end
        end
        
        -- Calculate average accuracy for algorithm
        algorithm_results.average_accuracy = algorithm_results.files_validated > 0 and 
                                           (algorithm_results.total_accuracy / algorithm_results.files_validated) or 0
        
        table.insert(comprehensive_results.algorithms_tested, algorithm_results)
    end
    
    -- Generate comprehensive report
    local report_file = output_dir .. "/validation_comprehensive_report.json"
    utils.write_json_file(report_file, comprehensive_results)
    
    print(string.format("Comprehensive validation complete. Report saved: %s", report_file))
    
    return comprehensive_results
end
-- }}}

-- {{{ function create_validation_engine
local function create_validation_engine(config)
    return ValidationEngine:new(config)
end
-- }}}

-- {{{ function validate_single_file
local function validate_single_file(similarity_file, embeddings_file, algorithm, config)
    local calculator = SimilarityCalculator:new(algorithm or "cosine", {})
    local engine = ValidationEngine:new(config or {})
    engine:set_calculator(calculator)
    
    return engine:validate_similarity_matrix(similarity_file, embeddings_file)
end
-- }}}

return {
    ValidationEngine = ValidationEngine,
    run_comprehensive_validation = run_comprehensive_validation,
    create_validation_engine = create_validation_engine,
    validate_single_file = validate_single_file
}