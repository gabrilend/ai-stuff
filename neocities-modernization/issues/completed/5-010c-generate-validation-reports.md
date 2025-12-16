# Issue 010c: Generate Validation Reports

## Current Behavior
- No systematic reporting of similarity validation results
- Missing visual and statistical analysis of validation outcomes
- No comparison reports between different algorithms
- Limited insight into data quality and algorithm performance

## Intended Behavior
- Comprehensive validation reports with statistics and visualizations
- Comparative analysis between similarity algorithms
- Data quality assessment with actionable recommendations
- Export reports in multiple formats (JSON, HTML, markdown)

## Suggested Implementation Steps
1. **Report Generator**: Core system for creating formatted validation reports
2. **Statistical Analysis**: Calculate meaningful metrics and trends from validation data
3. **Comparative Reports**: Compare algorithm performance across multiple validations
4. **Export Formats**: Support multiple output formats for different use cases
5. **Visualization**: Create simple text-based charts and summaries

## Technical Requirements

### **Report Generator Architecture**
```lua
-- {{{ ReportGenerator class
local ReportGenerator = {}
ReportGenerator.__index = ReportGenerator

function ReportGenerator:new(config)
    local obj = {
        config = config or {},
        format = config.format or "html",  -- html, json, markdown
        include_details = config.include_details or true,
        include_recommendations = config.include_recommendations or true,
        max_discrepancy_samples = config.max_discrepancy_samples or 20
    }
    
    setmetatable(obj, ReportGenerator)
    return obj
end

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
```

### **HTML Report Generation**
```lua
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
        }
        
        .report-header {
            background: linear-gradient(135deg, #f0f8ff, #e6f3ff);
            padding: 2rem;
            border-radius: 8px;
            margin-bottom: 2rem;
            border: 1px solid #b0d4f1;
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
        
        .error-high { color: #e53e3e; }
        .error-medium { color: #dd6b20; }
        .error-low { color: #38a169; }
        
        .recommendation-box {
            background: #fef5e7;
            border-left: 4px solid #ed8936;
            padding: 1rem;
            margin: 1rem 0;
        }
        
        .performance-chart {
            background: #f7fafc;
            padding: 1rem;
            border-radius: 6px;
            font-family: monospace;
            margin: 1rem 0;
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
        <div class="performance-chart">
{PERFORMANCE_DETAILS}
        </div>
    </section>
    
    {DISCREPANCIES_SECTION}
    
    {RECOMMENDATIONS_SECTION}
    
    <footer style="margin-top: 3rem; padding: 2rem; background: #f7fafc; border-radius: 6px;">
        <p style="margin: 0; color: #4a5568; text-align: center;">
            Report generated by Similarity Validation System • {TIMESTAMP}
        </p>
    </footer>
</body>
</html>]]
    
    -- Substitute template variables
    html_template = self:substitute_template_vars(html_template, result)
    
    -- Generate discrepancies section if needed
    if self.include_details and result.discrepancies.count > 0 then
        html_template = html_template:gsub("{DISCREPANCIES_SECTION}", self:generate_discrepancies_section(result))
    else
        html_template = html_template:gsub("{DISCREPANCIES_SECTION}", "")
    end
    
    -- Generate recommendations section
    if self.include_recommendations and #result.recommendations > 0 then
        html_template = html_template:gsub("{RECOMMENDATIONS_SECTION}", self:generate_recommendations_section(result))
    else
        html_template = html_template:gsub("{RECOMMENDATIONS_SECTION}", "")
    end
    
    -- Write report
    local success = utils.write_file(output_file, html_template)
    
    if success then
        utils.log_info("HTML validation report generated: " .. output_file)
        return output_file
    else
        error("Failed to write HTML report: " .. output_file)
    end
end
-- }}}
```

### **Comparative Analysis Reports**
```lua
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
```

### **Statistical Analysis Functions**
```lua
-- {{{ function calculate_validation_statistics
function calculate_validation_statistics(validation_results)
    local stats = {
        total_algorithms = #validation_results,
        overall_statistics = {
            total_comparisons = 0,
            total_accurate = 0,
            total_inaccurate = 0,
            total_errors = 0
        },
        algorithm_rankings = {
            by_accuracy = {},
            by_speed = {},
            by_reliability = {}
        },
        quality_metrics = {
            avg_accuracy = 0,
            accuracy_variance = 0,
            avg_speed = 0,
            speed_variance = 0
        }
    }
    
    -- Aggregate overall statistics
    local accuracies = {}
    local speeds = {}
    
    for _, result in ipairs(validation_results) do
        stats.overall_statistics.total_comparisons = stats.overall_statistics.total_comparisons + result.statistics.total_comparisons
        stats.overall_statistics.total_accurate = stats.overall_statistics.total_accurate + result.statistics.accurate_scores
        stats.overall_statistics.total_inaccurate = stats.overall_statistics.total_inaccurate + result.statistics.inaccurate_scores
        stats.overall_statistics.total_errors = stats.overall_statistics.total_errors + result.errors.count
        
        table.insert(accuracies, result.statistics.accuracy_rate)
        table.insert(speeds, result.performance.comparisons_per_second)
        
        -- Build rankings
        table.insert(stats.algorithm_rankings.by_accuracy, {
            algorithm = result.algorithm,
            accuracy_rate = result.statistics.accuracy_rate
        })
        
        table.insert(stats.algorithm_rankings.by_speed, {
            algorithm = result.algorithm,
            comparisons_per_second = result.performance.comparisons_per_second
        })
        
        table.insert(stats.algorithm_rankings.by_reliability, {
            algorithm = result.algorithm,
            reliability_score = result.statistics.accuracy_rate * (1 - (result.errors.count / math.max(1, result.statistics.total_comparisons)))
        })
    end
    
    -- Sort rankings
    table.sort(stats.algorithm_rankings.by_accuracy, function(a, b) return a.accuracy_rate > b.accuracy_rate end)
    table.sort(stats.algorithm_rankings.by_speed, function(a, b) return a.comparisons_per_second > b.comparisons_per_second end)
    table.sort(stats.algorithm_rankings.by_reliability, function(a, b) return a.reliability_score > b.reliability_score end)
    
    -- Calculate quality metrics
    stats.quality_metrics.avg_accuracy = calculate_mean(accuracies)
    stats.quality_metrics.accuracy_variance = calculate_variance(accuracies)
    stats.quality_metrics.avg_speed = calculate_mean(speeds)
    stats.quality_metrics.speed_variance = calculate_variance(speeds)
    
    return stats
end
-- }}}

-- {{{ helper functions for statistics
function calculate_mean(values)
    local sum = 0
    for _, value in ipairs(values) do
        sum = sum + value
    end
    return #values > 0 and (sum / #values) or 0
end

function calculate_variance(values)
    local mean = calculate_mean(values)
    local sum_squared_diff = 0
    
    for _, value in ipairs(values) do
        local diff = value - mean
        sum_squared_diff = sum_squared_diff + (diff * diff)
    end
    
    return #values > 0 and (sum_squared_diff / #values) or 0
end
-- }}}
```

## Quality Assurance Criteria
- Reports provide clear, actionable insights into validation results
- Multiple export formats work correctly (HTML, JSON, Markdown)
- Statistical analysis accurately represents algorithm performance
- Comparative reports enable informed algorithm selection
- Reports are well-formatted and easy to understand

## Success Metrics
- **Report Generation**: Generate reports in <5 seconds for typical validation results
- **Format Support**: 3+ export formats working correctly
- **Statistical Accuracy**: Correct calculation of all metrics and rankings
- **Visual Quality**: Clear, professional-looking HTML reports
- **Actionability**: Reports contain specific recommendations for next steps

## Dependencies
- Issue 010b (validation framework - required)
- Issue 010a (modular calculator - required for algorithm names/details)
- Utility functions for file I/O and JSON handling

## Testing Strategy
1. **Format Testing**: Verify all export formats produce correct output
2. **Statistical Testing**: Validate accuracy of calculated metrics
3. **Comparative Testing**: Test with multiple algorithm results
4. **Visual Testing**: Verify HTML reports render correctly in browsers
5. **Content Testing**: Ensure reports contain expected sections and data

**ISSUE STATUS: COMPLETED** ✅📊📋

**Priority**: Medium - Completes the validation system with user-friendly reporting

## Implementation Completed

**Files Created**:
- `/src/report-generator.lua` - Core report generation system with multiple format support
- `/src/test-report-generator.lua` - Comprehensive test suite for all report formats
- `/src/run-validation-with-reports.lua` - Integrated CLI combining validation and reporting

**Features Implemented**:
- Multi-format report generation (HTML, Markdown, JSON)
- Professional HTML reports with CSS styling and responsive design
- Comprehensive statistical analysis and performance metrics
- Comparative analysis reports for multiple algorithms
- Customizable report sections (details, recommendations)
- Template-based system with variable substitution
- Interactive CLI interface with format and algorithm selection
- Batch comparative analysis across multiple similarity algorithms

**Report Formats**:
- **HTML**: Professional web-ready reports with visual styling, charts, and interactive elements
- **Markdown**: Clean, readable reports suitable for documentation and version control
- **JSON**: Machine-readable format for programmatic processing and integration

**Testing Results**: All 7 report generator tests pass successfully
- HTML report generation with professional styling ✅
- Markdown report generation with proper formatting ✅
- JSON report generation with valid structure ✅
- Comparative analysis across multiple algorithms ✅
- Report customization (include/exclude sections) ✅
- Template variable substitution ✅
- Error handling for invalid formats and missing data ✅

**Integration**: Successfully integrates Issues 010a (modular calculator) and 010b (validation framework) into complete validation workflow

**Next Steps**: Complete validation system ready for use in similarity data integrity verification and algorithm research