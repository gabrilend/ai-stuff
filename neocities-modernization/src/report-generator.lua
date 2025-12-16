#!/usr/bin/env lua

-- Report Generator for Similarity Validation Results
-- Creates comprehensive reports in multiple formats (HTML, JSON, Markdown)

package.path = package.path .. ';./?.lua;./libs/?.lua'

local utils = require("libs.utils")
local json = require("libs.json")

local DIR = "/mnt/mtwo/programming/ai-stuff/neocities-modernization"

local ReportGenerator = {}
ReportGenerator.__index = ReportGenerator

-- {{{ function ReportGenerator:new
function ReportGenerator:new(config)
    config = config or {}
    local obj = {
        config = config,
        format = config.format or "html",  -- html, json, markdown
        include_details = config.include_details ~= false,  -- default true
        include_recommendations = config.include_recommendations ~= false,  -- default true
        max_discrepancy_samples = config.max_discrepancy_samples or 20
    }
    
    setmetatable(obj, ReportGenerator)
    return obj
end
-- }}}

-- {{{ function ReportGenerator:generate_validation_report
function ReportGenerator:generate_validation_report(validation_result, output_file)
    if self.format == "html" then
        return self:generate_html_report(validation_result, output_file)
    elseif self.format == "markdown" then
        return self:generate_markdown_report(validation_result, output_file)
    elseif self.format == "json" then
        return self:generate_json_report(validation_result, output_file)
    else
        error("Unsupported report format: " .. self.format)
    end
end
-- }}}

-- {{{ function ReportGenerator:substitute_template_vars
function ReportGenerator:substitute_template_vars(template, result)
    local stats = result.statistics or {}
    local perf = result.performance or {}
    
    local accuracy_percent = math.floor((stats.accuracy_rate or 0) * 100 * 10) / 10
    local comparisons_per_sec = math.floor((perf.comparisons_per_second or 0) * 10) / 10
    
    local substitutions = {
        ["{ALGORITHM}"] = result.algorithm or "unknown",
        ["{TIMESTAMP}"] = result.timestamp or os.date("%Y-%m-%d %H:%M:%S"),
        ["{DURATION}"] = tostring(result.duration_seconds or 0),
        ["{TOTAL_COMPARISONS}"] = tostring(stats.total_comparisons or 0),
        ["{ACCURACY_PERCENT}"] = string.format("%.1f", accuracy_percent),
        ["{INACCURATE_SCORES}"] = tostring(stats.inaccurate_scores or 0),
        ["{COMPARISONS_PER_SEC}"] = string.format("%.1f", comparisons_per_sec),
        ["{PERFORMANCE_DETAILS}"] = self:generate_performance_details(result)
    }
    
    for placeholder, value in pairs(substitutions) do
        -- Escape the value to handle % characters safely
        local safe_value = tostring(value):gsub("%%", "%%%%")
        template = template:gsub(placeholder:gsub("([%[%]%(%)%.%+%-%*%?%^%$])", "%%%1"), safe_value)
    end
    
    return template
end
-- }}}

-- {{{ function ReportGenerator:generate_performance_details
function ReportGenerator:generate_performance_details(result)
    local details = {}
    local stats = result.statistics or {}
    local perf = result.performance or {}
    local errors = result.errors or {}
    local discrepancies = result.discrepancies or {}
    
    table.insert(details, string.format("Total Comparisons:     %d", stats.total_comparisons or 0))
    table.insert(details, string.format("Accurate Scores:       %d", stats.accurate_scores or 0))
    table.insert(details, string.format("Inaccurate Scores:     %d", stats.inaccurate_scores or 0))
    table.insert(details, string.format("Missing Embeddings:    %d", stats.missing_embeddings or 0))
    table.insert(details, string.format("Calculation Errors:    %d", errors.count or 0))
    table.insert(details, string.format(""))
    table.insert(details, string.format("Processing Time:       %d seconds", result.duration_seconds or 0))
    table.insert(details, string.format("Comparisons/Second:    %.1f", perf.comparisons_per_second or 0))
    table.insert(details, string.format("Avg Time per Compare:  %.2f ms", perf.avg_comparison_time_ms or 0))
    table.insert(details, string.format(""))
    table.insert(details, string.format("Tolerance Used:        %.6f", stats.tolerance or 0))
    
    if discrepancies.max_difference then
        table.insert(details, string.format("Max Discrepancy:       %.6f", discrepancies.max_difference))
    end
    
    if discrepancies.avg_difference then
        table.insert(details, string.format("Avg Discrepancy:       %.6f", discrepancies.avg_difference))
    end
    
    return table.concat(details, "\n")
end
-- }}}

-- {{{ function ReportGenerator:generate_discrepancies_section
function ReportGenerator:generate_discrepancies_section(result)
    local discrepancies = result.discrepancies or {}
    if not discrepancies.samples or #discrepancies.samples == 0 then
        return ""
    end
    
    local section = [[
    <section class="discrepancies-section">
        <h2>⚠️ Worst Discrepancies</h2>
        <p>Showing the top discrepancies found during validation:</p>
        <table class="discrepancy-table">
            <thead>
                <tr>
                    <th>Poem A</th>
                    <th>Poem B</th>
                    <th>Stored Score</th>
                    <th>Calculated Score</th>
                    <th>Difference</th>
                    <th>Relative Error</th>
                </tr>
            </thead>
            <tbody>
]]
    
    local samples = discrepancies.samples
    for i = 1, math.min(self.max_discrepancy_samples, #samples) do
        local disc = samples[i]
        local error_class = "error-low"
        if disc.difference > 0.1 then
            error_class = "error-high"
        elseif disc.difference > 0.05 then
            error_class = "error-medium"
        end
        
        local relative_error_percent = math.floor((disc.relative_error or 0) * 100 * 10) / 10
        
        section = section .. string.format([[
                <tr>
                    <td>%d</td>
                    <td>%d</td>
                    <td>%.6f</td>
                    <td>%.6f</td>
                    <td class="%s">%.6f</td>
                    <td class="%s">%.1f%%</td>
                </tr>]], 
                disc.poem_a, disc.poem_b, disc.stored_score, disc.calculated_score, 
                error_class, disc.difference, error_class, relative_error_percent)
    end
    
    section = section .. [[
            </tbody>
        </table>
    </section>
]]
    
    return section
end
-- }}}

-- {{{ function ReportGenerator:generate_recommendations_section
function ReportGenerator:generate_recommendations_section(result)
    if not result.recommendations or #result.recommendations == 0 then
        return ""
    end
    
    local section = [[
    <section class="recommendations-section">
        <h2>💡 Recommendations</h2>
]]
    
    for _, recommendation in ipairs(result.recommendations) do
        section = section .. string.format([[
        <div class="recommendation-box">
            <p>%s</p>
        </div>]], recommendation)
    end
    
    section = section .. [[
    </section>
]]
    
    return section
end
-- }}}

-- {{{ function ReportGenerator:generate_html_report
function ReportGenerator:generate_html_report(result, output_file)
    local html_template = [[<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Similarity Validation Report - {ALGORITHM}</title>
    <style>
        body {
            font-family: Georgia, serif;
            line-height: 1.6;
            max-width: 1200px;
            margin: 0 auto;
            padding: 1rem;
            color: #333;
            background-color: #fafafa;
        }
        
        .report-header {
            background: linear-gradient(135deg, #f0f8ff, #e6f3ff);
            padding: 2rem;
            border-radius: 8px;
            margin-bottom: 2rem;
            border: 1px solid #b0d4f1;
        }
        
        .report-header h1 {
            margin: 0 0 1rem 0;
            color: #1a365d;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1rem;
            margin: 2rem 0;
        }
        
        .stat-card {
            background: white;
            border: 1px solid #e2e8f0;
            border-radius: 6px;
            padding: 1.5rem;
            text-align: center;
            box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
        }
        
        .stat-value {
            font-size: 2rem;
            font-weight: bold;
            color: #2c5282;
            margin-bottom: 0.5rem;
        }
        
        .stat-label {
            color: #4a5568;
            font-size: 0.9rem;
        }
        
        .accuracy-meter {
            background: #e2e8f0;
            border-radius: 10px;
            height: 20px;
            margin: 1rem 0;
            overflow: hidden;
        }
        
        .accuracy-fill {
            height: 100%;
            background: linear-gradient(90deg, #48bb78, #38a169);
            transition: width 0.3s ease;
        }
        
        .discrepancy-table {
            width: 100%;
            border-collapse: collapse;
            margin: 1rem 0;
            background: white;
            box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
        }
        
        .discrepancy-table th,
        .discrepancy-table td {
            border: 1px solid #e2e8f0;
            padding: 0.75rem;
            text-align: left;
        }
        
        .discrepancy-table th {
            background: #f7fafc;
            font-weight: bold;
            color: #2d3748;
        }
        
        .discrepancy-table tr:nth-child(even) {
            background-color: #f8f9fa;
        }
        
        .error-high { color: #e53e3e; font-weight: bold; }
        .error-medium { color: #dd6b20; font-weight: bold; }
        .error-low { color: #38a169; }
        
        .recommendation-box {
            background: #fef5e7;
            border-left: 4px solid #ed8936;
            padding: 1rem;
            margin: 1rem 0;
            border-radius: 4px;
        }
        
        .performance-chart {
            background: #f7fafc;
            padding: 1rem;
            border-radius: 6px;
            font-family: monospace;
            margin: 1rem 0;
            white-space: pre-line;
            border: 1px solid #e2e8f0;
        }
        
        section {
            background: white;
            margin: 2rem 0;
            padding: 1.5rem;
            border-radius: 8px;
            box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
        }
        
        section h2 {
            margin-top: 0;
            color: #2d3748;
            border-bottom: 2px solid #e2e8f0;
            padding-bottom: 0.5rem;
        }
        
        .overview-section {
            border-top: 4px solid #4299e1;
        }
        
        .performance-section {
            border-top: 4px solid #38a169;
        }
        
        .discrepancies-section {
            border-top: 4px solid #ed8936;
        }
        
        .recommendations-section {
            border-top: 4px solid #9f7aea;
        }
    </style>
</head>
<body>
    <div class="report-header">
        <h1>🔍 Similarity Validation Report</h1>
        <p><strong>Algorithm:</strong> {ALGORITHM}</p>
        <p><strong>Generated:</strong> {TIMESTAMP}</p>
        <p><strong>Duration:</strong> {DURATION} seconds</p>
    </div>
    
    <section class="overview-section">
        <h2>📊 Validation Overview</h2>
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-value">{TOTAL_COMPARISONS}</div>
                <div class="stat-label">Total Comparisons</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">{ACCURACY_PERCENT}%</div>
                <div class="stat-label">Accuracy Rate</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">{INACCURATE_SCORES}</div>
                <div class="stat-label">Discrepancies Found</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">{COMPARISONS_PER_SEC}</div>
                <div class="stat-label">Comparisons/Second</div>
            </div>
        </div>
        
        <div class="accuracy-meter">
            <div class="accuracy-fill" style="width: {ACCURACY_PERCENT}%"></div>
        </div>
    </section>
    
    <section class="performance-section">
        <h2>⚡ Performance Metrics</h2>
        <div class="performance-chart">{PERFORMANCE_DETAILS}</div>
    </section>
    
    {DISCREPANCIES_SECTION}
    
    {RECOMMENDATIONS_SECTION}
    
    <footer style="margin-top: 3rem; padding: 2rem; background: #f7fafc; border-radius: 6px; text-align: center;">
        <p style="margin: 0; color: #4a5568;">
            Report generated by Similarity Validation System • {TIMESTAMP}
        </p>
    </footer>
</body>
</html>]]
    
    -- Substitute template variables
    html_template = self:substitute_template_vars(html_template, result)
    
    -- Generate discrepancies section if needed
    local discrepancies = result.discrepancies or {}
    if self.include_details and discrepancies.count and discrepancies.count > 0 then
        local disc_section = self:generate_discrepancies_section(result)
        -- Escape % characters in the replacement string
        disc_section = disc_section:gsub("%%", "%%%%")
        html_template = html_template:gsub("{DISCREPANCIES_SECTION}", disc_section)
    else
        html_template = html_template:gsub("{DISCREPANCIES_SECTION}", "")
    end
    
    -- Generate recommendations section
    local recommendations = result.recommendations or {}
    if self.include_recommendations and #recommendations > 0 then
        local rec_section = self:generate_recommendations_section(result)
        -- Escape % characters in the replacement string
        rec_section = rec_section:gsub("%%", "%%%%")
        html_template = html_template:gsub("{RECOMMENDATIONS_SECTION}", rec_section)
    else
        html_template = html_template:gsub("{RECOMMENDATIONS_SECTION}", "")
    end
    
    -- Write report
    local success = utils.write_file(output_file, html_template)
    
    if success then
        print(string.format("HTML validation report generated: %s", output_file))
        return output_file
    else
        error("Failed to write HTML report: " .. output_file)
    end
end
-- }}}

-- {{{ function ReportGenerator:generate_markdown_report
function ReportGenerator:generate_markdown_report(result, output_file)
    local markdown_content = {}
    
    -- Header
    table.insert(markdown_content, string.format("# 🔍 Similarity Validation Report"))
    table.insert(markdown_content, "")
    table.insert(markdown_content, string.format("**Algorithm:** %s", result.algorithm or "unknown"))
    table.insert(markdown_content, string.format("**Generated:** %s", result.timestamp or os.date("%Y-%m-%d %H:%M:%S")))
    table.insert(markdown_content, string.format("**Duration:** %d seconds", result.duration_seconds or 0))
    table.insert(markdown_content, "")
    
    -- Overview
    table.insert(markdown_content, "## 📊 Validation Overview")
    table.insert(markdown_content, "")
    local accuracy_percent = math.floor((result.statistics.accuracy_rate or 0) * 100 * 10) / 10
    table.insert(markdown_content, string.format("- **Total Comparisons:** %d", result.statistics.total_comparisons or 0))
    table.insert(markdown_content, string.format("- **Accuracy Rate:** %.1f%%", accuracy_percent))
    table.insert(markdown_content, string.format("- **Discrepancies Found:** %d", result.statistics.inaccurate_scores or 0))
    table.insert(markdown_content, string.format("- **Comparisons/Second:** %.1f", result.performance.comparisons_per_second or 0))
    table.insert(markdown_content, "")
    
    -- Performance
    table.insert(markdown_content, "## ⚡ Performance Metrics")
    table.insert(markdown_content, "")
    table.insert(markdown_content, "```")
    table.insert(markdown_content, self:generate_performance_details(result))
    table.insert(markdown_content, "```")
    table.insert(markdown_content, "")
    
    -- Discrepancies
    local discrepancies = result.discrepancies or {}
    if self.include_details and discrepancies.count and discrepancies.count > 0 and discrepancies.samples then
        table.insert(markdown_content, "## ⚠️ Worst Discrepancies")
        table.insert(markdown_content, "")
        table.insert(markdown_content, "| Poem A | Poem B | Stored Score | Calculated Score | Difference | Relative Error |")
        table.insert(markdown_content, "|--------|--------|--------------|------------------|------------|----------------|")
        
        local samples = discrepancies.samples
        for i = 1, math.min(self.max_discrepancy_samples, #samples) do
            local disc = samples[i]
            local relative_error_percent = math.floor((disc.relative_error or 0) * 100 * 10) / 10
            table.insert(markdown_content, string.format("| %d | %d | %.6f | %.6f | %.6f | %.1f%% |",
                disc.poem_a, disc.poem_b, disc.stored_score, disc.calculated_score, 
                disc.difference, relative_error_percent))
        end
        table.insert(markdown_content, "")
    end
    
    -- Recommendations
    local recommendations = result.recommendations or {}
    if self.include_recommendations and #recommendations > 0 then
        table.insert(markdown_content, "## 💡 Recommendations")
        table.insert(markdown_content, "")
        for i, recommendation in ipairs(recommendations) do
            table.insert(markdown_content, string.format("%d. %s", i, recommendation))
        end
        table.insert(markdown_content, "")
    end
    
    -- Footer
    table.insert(markdown_content, "---")
    table.insert(markdown_content, "")
    table.insert(markdown_content, string.format("*Report generated by Similarity Validation System • %s*", 
                                                result.timestamp or os.date("%Y-%m-%d %H:%M:%S")))
    
    local content = table.concat(markdown_content, "\n")
    local success = utils.write_file(output_file, content)
    
    if success then
        print(string.format("Markdown validation report generated: %s", output_file))
        return output_file
    else
        error("Failed to write Markdown report: " .. output_file)
    end
end
-- }}}

-- {{{ function ReportGenerator:generate_json_report
function ReportGenerator:generate_json_report(result, output_file)
    local success = utils.write_json_file(output_file, result)
    
    if success then
        print(string.format("JSON validation report generated: %s", output_file))
        return output_file
    else
        error("Failed to write JSON report: " .. output_file)
    end
end
-- }}}

-- {{{ function ReportGenerator:generate_comparative_report
function ReportGenerator:generate_comparative_report(validation_results, output_file)
    -- validation_results is array of results from different algorithms
    
    local comparison_data = {
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        algorithms_compared = {},
        performance_comparison = {},
        accuracy_comparison = {},
        recommendations = {}
    }
    
    -- Analyze each algorithm result
    for _, result in ipairs(validation_results) do
        local algorithm_summary = {
            algorithm = result.algorithm,
            accuracy_rate = result.statistics.accuracy_rate,
            total_comparisons = result.statistics.total_comparisons,
            comparisons_per_second = result.performance.comparisons_per_second,
            max_discrepancy = result.discrepancies.max_difference or 0,
            error_count = result.errors.count
        }
        
        table.insert(comparison_data.algorithms_compared, algorithm_summary)
    end
    
    -- Sort by accuracy rate
    table.sort(comparison_data.algorithms_compared, function(a, b)
        return a.accuracy_rate > b.accuracy_rate
    end)
    
    -- Generate performance comparison
    local best_accuracy = comparison_data.algorithms_compared[1]
    local fastest_algorithm = nil
    local max_speed = 0
    
    for _, algo in ipairs(comparison_data.algorithms_compared) do
        if algo.comparisons_per_second > max_speed then
            max_speed = algo.comparisons_per_second
            fastest_algorithm = algo
        end
    end
    
    comparison_data.performance_comparison = {
        most_accurate = best_accuracy,
        fastest = fastest_algorithm,
        speed_vs_accuracy_tradeoff = self:analyze_speed_accuracy_tradeoff(comparison_data.algorithms_compared)
    }
    
    -- Generate comparative recommendations
    comparison_data.recommendations = self:generate_comparative_recommendations(comparison_data)
    
    if self.format == "html" then
        return self:generate_comparative_html_report(comparison_data, output_file)
    elseif self.format == "json" then
        return self:generate_json_report(comparison_data, output_file)
    else
        return self:generate_comparative_markdown_report(comparison_data, output_file)
    end
end
-- }}}

-- {{{ function ReportGenerator:analyze_speed_accuracy_tradeoff
function ReportGenerator:analyze_speed_accuracy_tradeoff(algorithms)
    local analysis = {
        high_accuracy_high_speed = {},
        high_accuracy_low_speed = {},
        low_accuracy_high_speed = {},
        low_accuracy_low_speed = {}
    }
    
    -- Calculate median values for thresholds
    local accuracies = {}
    local speeds = {}
    
    for _, algo in ipairs(algorithms) do
        table.insert(accuracies, algo.accuracy_rate)
        table.insert(speeds, algo.comparisons_per_second)
    end
    
    table.sort(accuracies)
    table.sort(speeds)
    
    local median_accuracy = accuracies[math.ceil(#accuracies / 2)]
    local median_speed = speeds[math.ceil(#speeds / 2)]
    
    -- Categorize algorithms
    for _, algo in ipairs(algorithms) do
        local high_acc = algo.accuracy_rate >= median_accuracy
        local high_speed = algo.comparisons_per_second >= median_speed
        
        if high_acc and high_speed then
            table.insert(analysis.high_accuracy_high_speed, algo)
        elseif high_acc and not high_speed then
            table.insert(analysis.high_accuracy_low_speed, algo)
        elseif not high_acc and high_speed then
            table.insert(analysis.low_accuracy_high_speed, algo)
        else
            table.insert(analysis.low_accuracy_low_speed, algo)
        end
    end
    
    return analysis
end
-- }}}

-- {{{ function ReportGenerator:generate_comparative_recommendations
function ReportGenerator:generate_comparative_recommendations(comparison_data)
    local recommendations = {}
    
    local algorithms = comparison_data.algorithms_compared
    if #algorithms == 0 then
        return recommendations
    end
    
    local best_accuracy = algorithms[1]
    local fastest = comparison_data.performance_comparison.fastest
    
    table.insert(recommendations, string.format("Most accurate algorithm: %s (%.1f%% accuracy)", 
                best_accuracy.algorithm, best_accuracy.accuracy_rate * 100))
                
    if fastest then
        table.insert(recommendations, string.format("Fastest algorithm: %s (%.1f comparisons/second)", 
                    fastest.algorithm, fastest.comparisons_per_second))
    end
    
    -- Check for any algorithms with perfect accuracy
    for _, algo in ipairs(algorithms) do
        if algo.accuracy_rate >= 0.999 then
            table.insert(recommendations, string.format("%s shows excellent accuracy (%.1f%%) - recommended for production use", 
                        algo.algorithm, algo.accuracy_rate * 100))
        elseif algo.accuracy_rate < 0.9 then
            table.insert(recommendations, string.format("%s has low accuracy (%.1f%%) - investigate calculation differences", 
                        algo.algorithm, algo.accuracy_rate * 100))
        end
    end
    
    -- Performance recommendations
    local tradeoff = comparison_data.performance_comparison.speed_vs_accuracy_tradeoff
    if #tradeoff.high_accuracy_high_speed > 0 then
        table.insert(recommendations, "Consider algorithms in the high-accuracy, high-speed category for optimal performance")
    end
    
    return recommendations
end
-- }}}

-- {{{ function ReportGenerator:generate_comparative_markdown_report
function ReportGenerator:generate_comparative_markdown_report(comparison_data, output_file)
    local markdown_content = {}
    
    -- Header
    table.insert(markdown_content, "# 📊 Comparative Algorithm Validation Report")
    table.insert(markdown_content, "")
    table.insert(markdown_content, string.format("**Generated:** %s", comparison_data.timestamp))
    table.insert(markdown_content, string.format("**Algorithms Compared:** %d", #comparison_data.algorithms_compared))
    table.insert(markdown_content, "")
    
    -- Algorithm comparison table
    table.insert(markdown_content, "## 🏆 Algorithm Rankings")
    table.insert(markdown_content, "")
    table.insert(markdown_content, "| Rank | Algorithm | Accuracy Rate | Comparisons/Sec | Max Discrepancy | Errors |")
    table.insert(markdown_content, "|------|-----------|---------------|-----------------|-----------------|--------|")
    
    for i, algo in ipairs(comparison_data.algorithms_compared) do
        table.insert(markdown_content, string.format("| %d | %s | %.1f%% | %.1f | %.6f | %d |",
                    i, algo.algorithm, algo.accuracy_rate * 100, algo.comparisons_per_second, 
                    algo.max_discrepancy, algo.error_count))
    end
    table.insert(markdown_content, "")
    
    -- Recommendations
    if #comparison_data.recommendations > 0 then
        table.insert(markdown_content, "## 💡 Recommendations")
        table.insert(markdown_content, "")
        for i, recommendation in ipairs(comparison_data.recommendations) do
            table.insert(markdown_content, string.format("%d. %s", i, recommendation))
        end
        table.insert(markdown_content, "")
    end
    
    local content = table.concat(markdown_content, "\n")
    local success = utils.write_file(output_file, content)
    
    if success then
        print(string.format("Comparative Markdown report generated: %s", output_file))
        return output_file
    else
        error("Failed to write comparative Markdown report: " .. output_file)
    end
end
-- }}}

-- {{{ function create_report_generator
local function create_report_generator(config)
    return ReportGenerator:new(config)
end
-- }}}

-- {{{ function generate_single_report
local function generate_single_report(validation_result, output_file, format)
    local generator = ReportGenerator:new({format = format or "html"})
    return generator:generate_validation_report(validation_result, output_file)
end
-- }}}

-- {{{ function generate_comparative_report
local function generate_comparative_report(validation_results, output_file, format)
    local generator = ReportGenerator:new({format = format or "html"})
    return generator:generate_comparative_report(validation_results, output_file)
end
-- }}}

return {
    ReportGenerator = ReportGenerator,
    create_report_generator = create_report_generator,
    generate_single_report = generate_single_report,
    generate_comparative_report = generate_comparative_report
}