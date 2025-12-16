#!/bin/bash
# {{{ Claude Topics Configuration
# Extensible topic framework for various analysis types

# {{{ Resume Generation Topic
declare -A TOPIC_RESUME_DETAILED=(
    [type]="resume_generation_detailed"
    [name]="Comprehensive Professional Resume"
    [description]="Full professional resume with detailed project analysis"
    [priority_weights]="10,19,28,37,46,55,64,73,82,91,100"
    [scan_patterns]="*.md,*.txt,*.lua,*.py,*.js,*.sh,*.rs,*.go,*.cpp,*.java,README*,CHANGELOG*,*.json,package.json,Cargo.toml,*.yaml,*.yml,docs/*,notes/*"
    [analysis_depth]="4"
    [context_window]="8000"
    [output_format]="comprehensive_resume"
    [sections]="contact_info,summary,experience,projects,skills,education,achievements"
    [focus_areas]="technical_skills,project_leadership,problem_solving,innovation"
)
# }}}

# {{{ Portfolio Generation Topic
declare -A TOPIC_PORTFOLIO=(
    [type]="portfolio_generation"
    [name]="Technical Portfolio"
    [description]="Showcase of technical projects and capabilities"
    [priority_weights]="15,25,35,45,55,65,75,85,95,100"
    [scan_patterns]="*.md,README*,docs/*,src/*,assets/*,examples/*,demos/*,screenshots/*,*.png,*.jpg"
    [analysis_depth]="5"
    [context_window]="6000"
    [output_format]="portfolio_website"
    [sections]="hero,about,projects,skills,contact"
    [focus_areas]="visual_presentation,project_diversity,technical_depth,user_experience"
)
# }}}

# {{{ Code Documentation Topic
declare -A TOPIC_DOCUMENTATION=(
    [type]="code_documentation"
    [name]="Technical Documentation"
    [description]="Comprehensive code and API documentation"
    [priority_weights]="20,30,40,50,60,70,80,90,100"
    [scan_patterns]="src/*,libs/*,*.lua,*.py,*.js,*.sh,*.md,docs/*,examples/*,tests/*"
    [analysis_depth]="6"
    [context_window]="10000"
    [output_format]="technical_docs"
    [sections]="overview,installation,api_reference,examples,troubleshooting"
    [focus_areas]="code_architecture,api_design,usage_patterns,best_practices"
)
# }}}

# {{{ Business Analysis Topic
declare -A TOPIC_BUSINESS=(
    [type]="business_analysis"
    [name]="Business Intelligence Report"
    [description]="Business-focused analysis of projects and capabilities"
    [priority_weights]="12,24,36,48,60,72,84,96,100"
    [scan_patterns]="*.md,README*,docs/*,notes/*,business/*,planning/*,*.csv,*.json"
    [analysis_depth]="3"
    [context_window]="5000"
    [output_format]="business_report"
    [sections]="executive_summary,market_analysis,technical_capabilities,recommendations"
    [focus_areas]="business_value,roi_potential,scalability,market_fit"
)
# }}}

# {{{ Learning Path Topic
declare -A TOPIC_LEARNING=(
    [type]="learning_path"
    [name]="Personalized Learning Path"
    [description]="Custom learning roadmap based on current skills and projects"
    [priority_weights]="18,26,34,42,50,58,66,74,82,90,98,100"
    [scan_patterns]="*.md,*.txt,src/*,docs/*,notes/*,tutorials/*,examples/*,*.py,*.js,*.lua"
    [analysis_depth]="4"
    [context_window]="7000"
    [output_format]="learning_roadmap"
    [sections]="current_skills,skill_gaps,recommended_courses,projects,timeline"
    [focus_areas]="skill_progression,practical_application,industry_relevance,career_growth"
)
# }}}

# {{{ Security Assessment Topic
declare -A TOPIC_SECURITY=(
    [type]="security_assessment"
    [name]="Security Analysis Report"
    [description]="Security-focused analysis of code and project structure"
    [priority_weights]="25,35,45,55,65,75,85,95,100"
    [scan_patterns]="src/*,*.py,*.js,*.sh,*.lua,*.rs,*.go,config/*,*.yaml,*.json,*.env*"
    [analysis_depth]="5"
    [context_window]="6000"
    [output_format]="security_report"
    [sections]="threat_assessment,vulnerability_analysis,recommendations,best_practices"
    [focus_areas]="code_security,data_protection,access_control,secure_practices"
)
# }}}

# {{{ Topic Management Functions
function list_available_topics() {
    echo "Available Topics:"
    echo "1. RESUME - Basic resume generation"
    echo "2. RESUME_DETAILED - Comprehensive resume with detailed analysis"
    echo "3. PORTFOLIO - Technical portfolio generation"
    echo "4. DOCUMENTATION - Code and API documentation"
    echo "5. BUSINESS - Business intelligence report"
    echo "6. LEARNING - Personalized learning path"
    echo "7. SECURITY - Security assessment report"
    echo "8. PROJECT - Basic project analysis"
    echo "9. SKILLS - Technical skills extraction"
}

function get_topic_description() {
    local topic="$1"
    local desc_var="TOPIC_${topic}[description]"
    eval echo "\${$desc_var}"
}

function validate_topic() {
    local topic="$1"
    local type_var="TOPIC_${topic}[type]"
    eval test -n "\${$type_var}"
}

function get_topic_sections() {
    local topic="$1"
    local sections_var="TOPIC_${topic}[sections]"
    local sections=$(eval echo "\${$sections_var}")
    echo "$sections" | tr ',' '\n'
}

function get_topic_focus_areas() {
    local topic="$1"
    local focus_var="TOPIC_${topic}[focus_areas]"
    local focus=$(eval echo "\${$focus_var}")
    echo "$focus" | tr ',' '\n'
}
# }}}

# {{{ Advanced Priority Calculation
function calculate_advanced_priority() {
    local directory_age="$1"    # Days since last modification
    local file_count="$2"       # Number of relevant files
    local content_size="$3"     # Total content size
    local position="$4"         # Position in priority list
    local base_weights="$5"     # Base priority weights
    
    local base_weight=$(calculate_priority_weight "$position" "$base_weights")
    
    # Adjust based on directory characteristics
    local age_factor=100
    if [[ $directory_age -gt 30 ]]; then
        age_factor=80
    elif [[ $directory_age -gt 7 ]]; then
        age_factor=90
    fi
    
    local file_factor=100
    if [[ $file_count -lt 5 ]]; then
        file_factor=80
    elif [[ $file_count -gt 50 ]]; then
        file_factor=110
    fi
    
    local size_factor=100
    if [[ $content_size -lt 1000 ]]; then
        size_factor=85
    elif [[ $content_size -gt 10000 ]]; then
        size_factor=105
    fi
    
    # Calculate adjusted weight
    local adjusted_weight=$((base_weight * age_factor * file_factor * size_factor / 1000000))
    echo "$adjusted_weight"
}

function get_directory_stats() {
    local dir="$1"
    local last_mod=$(find "$dir" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f1)
    local now=$(date +%s)
    local age_days=$(( (now - ${last_mod%.*}) / 86400 ))
    local file_count=$(find "$dir" -type f 2>/dev/null | wc -l)
    local content_size=$(find "$dir" -type f -exec wc -c {} + 2>/dev/null | tail -1 | cut -d' ' -f1)
    
    echo "$age_days $file_count ${content_size:-0}"
}
# }}}

# {{{ Export functions for main script
export -f list_available_topics
export -f get_topic_description
export -f validate_topic
export -f get_topic_sections
export -f get_topic_focus_areas
export -f calculate_advanced_priority
export -f get_directory_stats
# }}}
# }}}