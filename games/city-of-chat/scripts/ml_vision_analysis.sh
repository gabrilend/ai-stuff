#!/bin/bash

# {{{ ml_vision_analysis
# ML-powered image analysis using external APIs
DIR="${1:-/mnt/mtwo/programming/ai-stuff/games/city-of-chat}"

# {{{ encode_image_base64
encode_image_base64() {
    local image_path="$1"
    base64 -w 0 "$image_path"
}
# }}}

# {{{ analyze_with_openai_vision
analyze_with_openai_vision() {
    local image_path="$1"
    local api_key="$2"
    
    if [ -z "$api_key" ]; then
        echo "Error: OpenAI API key not provided" >&2
        return 1
    fi
    
    local base64_image=$(encode_image_base64 "$image_path")
    local filename=$(basename "$image_path")
    
    local prompt="Analyze this game design image with the following focus:

1. SCENE CONTENTS: Describe all objects, characters, UI elements, and visual components you can identify. Use specific nouns for each element.

2. ACTIONS & ATTRIBUTES: Identify any verbs (actions being performed) and adjectives (descriptive qualities) that apply to the scene elements.

3. SCENE DESCRIPTION: Provide an honest, detailed description of what you see - the layout, composition, style, and overall design intent.

4. GAME DESIGN PURPOSE: Based on the visual content, infer what game development purpose this image serves (UI mockup, character concept, level design, mechanic illustration, etc.).

5. TECHNICAL DETAILS: Note any technical aspects visible (interface elements, HUD components, game mechanics being illustrated).

Format your response as structured data that can be easily parsed for documentation generation."
    
    curl -s -X POST "https://api.openai.com/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "{
            \"model\": \"gpt-4o\",
            \"messages\": [
                {
                    \"role\": \"user\",
                    \"content\": [
                        {
                            \"type\": \"text\",
                            \"text\": \"$prompt\"
                        },
                        {
                            \"type\": \"image_url\",
                            \"image_url\": {
                                \"url\": \"data:image/jpeg;base64,$base64_image\"
                            }
                        }
                    ]
                }
            ],
            \"max_tokens\": 1500
        }"
}
# }}}

# {{{ analyze_with_local_vision
analyze_with_local_vision() {
    local image_path="$1"
    local filename=$(basename "$image_path")
    
    # Fallback analysis using our C utility + heuristics
    local image_info=$(${DIR}/libs/image_info "$image_path" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "SCENE CONTENTS: Image analysis of $filename"
        echo "$image_info" | while IFS=':' read key value; do
            case $key in
                "width"|"height"|"format")
                    echo "Technical property: $key = $value"
                    ;;
                "orientation")
                    echo "Layout orientation: $value format detected"
                    ;;
                "resolution")
                    echo "Image quality: $value resolution suitable for specific use cases"
                    ;;
            esac
        done
        
        echo ""
        echo "ACTIONS & ATTRIBUTES:"
        echo "- Static design document (noun: document, adjective: static)"
        echo "- Visual representation (noun: representation, adjective: visual)"
        
        echo ""
        echo "SCENE DESCRIPTION:"
        echo "This appears to be a game design document or concept art. The image contains visual information relevant to game development, likely created as part of the design process for a gaming project."
        
        echo ""
        echo "GAME DESIGN PURPOSE:"
        echo "Based on the file naming pattern and location, this is likely a game design asset used for documentation, concept illustration, or development reference."
        
        echo ""
        echo "TECHNICAL DETAILS:"
        echo "$image_info"
        
        return 0
    else
        echo "Error: Could not analyze image $image_path"
        return 1
    fi
}
# }}}

# {{{ get_api_key
get_api_key() {
    local api_type="$1"
    
    case $api_type in
        "openai")
            if [ -f "$HOME/.config/openai/api_key" ]; then
                cat "$HOME/.config/openai/api_key"
            elif [ ! -z "$OPENAI_API_KEY" ]; then
                echo "$OPENAI_API_KEY"
            else
                echo ""
            fi
            ;;
        *)
            echo ""
            ;;
    esac
}
# }}}

# {{{ get_available_analyzers
get_available_analyzers() {
    local analyzers=()
    
    # Check if OpenAI API is available
    local openai_key=$(get_api_key "openai")
    if [ ! -z "$openai_key" ]; then
        analyzers+=("openai")
    fi
    
    # Local analysis is always available
    analyzers+=("local")
    
    # Add more analyzers here as they become available
    # analyzers+=("google_vision")
    # analyzers+=("azure_vision")
    
    echo "${analyzers[@]}"
}
# }}}

# {{{ random_select
random_select() {
    local items=("$@")
    local count=${#items[@]}
    local index=$((RANDOM % count))
    echo "${items[$index]}"
}
# }}}

# {{{ standardize_output
standardize_output() {
    local raw_output="$1"
    local analyzer_type="$2"
    
    case $analyzer_type in
        "openai")
            # Extract content from OpenAI JSON response
            echo "$raw_output" | grep -o '"content":"[^"]*"' | sed 's/"content":"\([^"]*\)"/\1/' | sed 's/\\n/\n/g'
            ;;
        "local"|*)
            # Local output is already in the right format
            echo "$raw_output"
            ;;
    esac
}
# }}}

# {{{ analyze_image
analyze_image() {
    local image_path="$1"
    local preferred_api="${2:-auto}"
    
    if [ ! -f "$image_path" ]; then
        echo "Error: Image file not found: $image_path" >&2
        return 1
    fi
    
    local analyzers=($(get_available_analyzers))
    local selected_analyzer
    
    if [ "$preferred_api" = "auto" ]; then
        # Randomly select from available analyzers
        selected_analyzer=$(random_select "${analyzers[@]}")
        echo "# Randomly selected analyzer: $selected_analyzer" >&2
    elif [[ " ${analyzers[@]} " =~ " $preferred_api " ]]; then
        selected_analyzer="$preferred_api"
        echo "# Using requested analyzer: $selected_analyzer" >&2
    else
        # Fallback to random selection if requested analyzer not available
        selected_analyzer=$(random_select "${analyzers[@]}")
        echo "# Requested analyzer '$preferred_api' not available, using: $selected_analyzer" >&2
    fi
    
    local raw_output
    local exit_code
    
    case $selected_analyzer in
        "openai")
            local api_key=$(get_api_key "openai")
            raw_output=$(analyze_with_openai_vision "$image_path" "$api_key")
            exit_code=$?
            ;;
        "local"|*)
            raw_output=$(analyze_with_local_vision "$image_path")
            exit_code=$?
            ;;
    esac
    
    if [ $exit_code -eq 0 ]; then
        # Standardize output format before returning
        standardize_output "$raw_output" "$selected_analyzer"
        return 0
    else
        # If selected analyzer fails, try random fallback
        echo "# Analyzer $selected_analyzer failed, trying random fallback" >&2
        local remaining_analyzers=()
        for analyzer in "${analyzers[@]}"; do
            if [ "$analyzer" != "$selected_analyzer" ]; then
                remaining_analyzers+=("$analyzer")
            fi
        done
        
        if [ ${#remaining_analyzers[@]} -gt 0 ]; then
            local fallback_analyzer=$(random_select "${remaining_analyzers[@]}")
            echo "# Using fallback analyzer: $fallback_analyzer" >&2
            
            case $fallback_analyzer in
                "openai")
                    local api_key=$(get_api_key "openai")
                    raw_output=$(analyze_with_openai_vision "$image_path" "$api_key")
                    exit_code=$?
                    ;;
                "local"|*)
                    raw_output=$(analyze_with_local_vision "$image_path")
                    exit_code=$?
                    ;;
            esac
            
            if [ $exit_code -eq 0 ]; then
                standardize_output "$raw_output" "$fallback_analyzer"
                return 0
            fi
        fi
        
        echo "Error: All available analyzers failed" >&2
        return 1
    fi
}
# }}}

# {{{ interactive_mode
interactive_mode() {
    echo "=== ML Vision Analysis Tool ==="
    echo ""
    echo "Available analysis methods:"
    echo "1) Auto (randomly select from available analyzers)"
    echo "2) OpenAI Vision API (requires API key)"
    echo "3) Local analysis (C utility + heuristics)"
    echo "4) Test with sample image"
    echo ""
    read -p "Enter choice (1-4): " choice
    
    case $choice in
        1)
            read -p "Enter image path: " image_path
            analyze_image "$image_path" "auto"
            ;;
        2)
            read -p "Enter image path: " image_path
            analyze_image "$image_path" "openai"
            ;;
        3)
            read -p "Enter image path: " image_path
            analyze_image "$image_path" "local"
            ;;
        4)
            # Test with first available image in pics/
            test_image=$(find "${DIR}/pics" -name "*.png" -o -name "*.jpg" | head -1)
            if [ ! -z "$test_image" ]; then
                echo "Testing with: $test_image"
                analyze_image "$test_image" "auto"
            else
                echo "No test images found in ${DIR}/pics/"
            fi
            ;;
        *)
            echo "Invalid choice"
            return 1
            ;;
    esac
}
# }}}

# Main execution
main() {
    if [ "$1" = "-I" ]; then
        shift
        DIR="${1:-/mnt/mtwo/programming/ai-stuff/games/city-of-chat}"
        interactive_mode
    elif [ $# -ge 1 ]; then
        analyze_image "$1" "${2:-local}"
    else
        echo "Usage: $0 [-I] <image_path> [api_method]"
        echo "  -I: Interactive mode"
        echo "  api_method: openai|local (default: local)"
        exit 1
    fi
}

main "$@"
# }}}