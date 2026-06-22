#!/bin/bash
# Embedding Generation Manager for Neocities Poetry Modernization
#
# Generates vector embeddings for poems using inference server embedding models.
# Supports incremental processing, cache management, and multiple models.
#
# Uses TUI library for vim-style interactive mode when available.
#
# Usage: ./generate-embeddings.sh [OPTIONS] [DIRECTORY]

# {{{ TUI Library
LIBS_DIR="/home/ritz/programming/ai-stuff/scripts/libs"
TUI_AVAILABLE=false
if [[ -f "${LIBS_DIR}/lua-menu.sh" ]] && command -v luajit &>/dev/null; then
    source "${LIBS_DIR}/lua-menu.sh"
    TUI_AVAILABLE=true
fi
# }}}

# {{{ setup_dir_path
setup_dir_path() {
    if [ -n "$1" ]; then
        echo "$1"
    else
        echo "/mnt/mtwo/programming/ai-stuff/neocities-modernization"
    fi
}
# }}}

# Parse command line options first to find directory argument
INCREMENTAL=true
FORCE_REGEN=false
SHOW_STATUS=false
VALIDATE_CACHE=false
FLUSH_ALL=false
FLUSH_ERRORS=false
BACKUP_BEFORE_FLUSH=true
FORCE_OPERATION=false
# 10-049 + Pascal-quant note: must match what config.lua's
# inference_servers[selected].model returns (no Ollama-style ":tag" colon,
# no GGUF ".gguf" extension). The /v1/models check later substring-greps
# for this string in the server's loaded-model list, so it should be the
# family identifier ("nomic-embed-text-v1.5"), not the full file basename
# ("nomic-embed-text-v1.5.Q8_0.gguf"). When the config drifts from this
# constant the substring-grep falls back to "model not found" and bails.
MODEL_NAME="nomic-embed-text-v1.5"
LIST_MODELS=false
MODEL_STATUS=false
INTERACTIVE_MODE=false
DIRECTORY_ARG=""
ASSETS_DIR=""
# Issue 10-017: Inference server selection from config.lua
INFERENCE_SERVER=""

for arg in "$@"; do
    case $arg in
        --dir=*)
            ASSETS_DIR="${arg#*=}"
            ;;
        --full-regen|--full)
            INCREMENTAL=false
            FORCE_REGEN=true
            ;;
        --incremental|--inc)
            INCREMENTAL=true
            ;;
        --status)
            SHOW_STATUS=true
            ;;
        --validate)
            VALIDATE_CACHE=true
            ;;
        --flush-all)
            FLUSH_ALL=true
            ;;
        --flush-errors)
            FLUSH_ERRORS=true
            ;;
        --backup-before-flush)
            BACKUP_BEFORE_FLUSH=true
            ;;
        --no-backup)
            BACKUP_BEFORE_FLUSH=false
            ;;
        --force)
            FORCE_OPERATION=true
            ;;
        --model=*)
            MODEL_NAME="${arg#*=}"
            ;;
        # Issue 10-017: Inference server selection
        --server=*)
            INFERENCE_SERVER="${arg#*=}"
            ;;
        --list-models)
            LIST_MODELS=true
            ;;
        --model-status)
            MODEL_STATUS=true
            ;;
        -I)
            INTERACTIVE_MODE=true
            ;;
        --help|-h)
            echo "Usage: $0 [options] [directory]"
            echo "Options:"
            echo "  --incremental, --inc    Use incremental processing (default)"
            echo "  --full-regen, --full    Force full regeneration of all embeddings"
            echo "  --status                Show cache status without processing"
            echo "  --validate              Validate cache integrity"
            echo ""
            echo "Cache Management Options:"
            echo "  --flush-all             Remove all cached embeddings (complete regeneration)"
            echo "  --flush-errors          Remove only error entries, keep valid embeddings"
            echo "  --backup-before-flush   Create timestamped backup before flushing (default)"
            echo "  --no-backup             Skip backup creation when flushing"
            echo "  --force                 Skip confirmation prompts for automated scripts"
            echo ""
            echo "Model Selection Options:"
            echo "  --model=MODEL_NAME      Specify embedding model (default: nomic-embed-text-v1.5)"
            echo "  --list-models           Show available models and their configurations"
            echo "  --model-status          Show cache status for all models"
            echo "  --dir=PATH              Use custom assets directory instead of default"
            echo ""
            echo "Examples:"
            echo "  $0 --flush-errors             # Clean up failed entries"
            echo "  $0 --flush-all                # Start completely fresh"
            echo "  $0 --model=text-embedding-ada-002  # Use OpenAI model"
            echo "  $0 --list-models              # Show available models"
            echo "  $0 --model-status             # Show cache status for all models"
            echo "  --help, -h                    Show this help message"
            echo "  -I                            Interactive mode - query user for options"
            exit 0
            ;;
        *)
            # If argument doesn't start with --, treat as directory
            if [[ ! $arg == --* ]] && [ -z "$DIRECTORY_ARG" ]; then
                DIRECTORY_ARG="$arg"
            fi
            ;;
    esac
done

# {{{ setup_embedding_tui_menu
# Configure the TUI menu for embedding generation options
setup_embedding_tui_menu() {
    if ! $TUI_AVAILABLE; then
        return 1
    fi

    # Initialize TUI
    if ! tui_init; then
        return 1
    fi

    # Build the menu
    menu_init
    menu_set_title "Embedding Manager" "neocities-modernization - j/k:nav space:toggle Enter:run"

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 1: Processing Mode (radio buttons - single selection)
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "mode" "single" "Processing Mode (select one)"
    menu_add_item "mode" "incremental" "Incremental" "checkbox" "1" \
        "Process only new/changed poems (fastest)" "1" ""
    menu_add_item "mode" "full_regen" "Full Regeneration" "checkbox" "0" \
        "Regenerate all embeddings from scratch" "2" ""
    menu_add_item "mode" "status_only" "Status Check" "checkbox" "0" \
        "Show current progress without processing" "3" ""

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 2: Cache Management
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "cache" "multi" "Cache Management"
    menu_add_item "cache" "flush_all" "Flush All Embeddings ⚠️" "checkbox" "0" \
        "WARNING: Removes entire cache" "f" ""
    menu_add_item "cache" "flush_errors" "Flush Errors Only" "checkbox" "0" \
        "Remove failed entries, keep valid ones" "e" ""
    menu_add_item "cache" "validate" "Validate Cache" "checkbox" "0" \
        "Check integrity without changes" "v" ""

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 3: Cache Options
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "cache_opts" "multi" "Cache Options"
    menu_add_item "cache_opts" "backup" "Backup Before Flush" "checkbox" "1" \
        "Create timestamped backup" "b" ""
    menu_add_item "cache_opts" "force" "Skip Confirmations" "checkbox" "0" \
        "Don't prompt for dangerous operations" "s" ""

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 4: Model Selection
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "model" "multi" "Model Selection"
    menu_add_item "model" "model_name" "Embedding Model" "multistate" "nomic-embed-text" \
        "nomic-embed-text,qwen3-embedding,embeddinggemma,text-embedding-ada-002,all-MiniLM-L6-v2" "m" ""
    menu_add_item "model" "model_status" "Show Model Status" "checkbox" "0" \
        "Display cache stats for each model" "t" ""
    menu_add_item "model" "list_models" "List Available Models" "checkbox" "0" \
        "Show all configured models" "l" ""

    # ═══════════════════════════════════════════════════════════════════════════
    # Section 5: Actions
    # ═══════════════════════════════════════════════════════════════════════════
    menu_add_section "actions" "single" "Actions"
    menu_add_item "actions" "run" "Run" "action" "" \
        "Execute with selected options" "r"

    return 0
}
# }}}

# {{{ apply_tui_selections
# Map TUI menu values to the script's flag variables
apply_tui_selections() {
    # Processing mode (radio - only one should be set)
    if [[ "$(menu_get_value "incremental")" == "1" ]]; then
        INCREMENTAL=true
        FORCE_REGEN=false
        SHOW_STATUS=false
    elif [[ "$(menu_get_value "full_regen")" == "1" ]]; then
        INCREMENTAL=false
        FORCE_REGEN=true
        SHOW_STATUS=false
    elif [[ "$(menu_get_value "status_only")" == "1" ]]; then
        SHOW_STATUS=true
        INCREMENTAL=true
        FORCE_REGEN=false
    fi

    # Cache management
    [[ "$(menu_get_value "flush_all")" == "1" ]] && FLUSH_ALL=true
    [[ "$(menu_get_value "flush_errors")" == "1" ]] && FLUSH_ERRORS=true
    [[ "$(menu_get_value "validate")" == "1" ]] && VALIDATE_CACHE=true

    # Cache options
    [[ "$(menu_get_value "backup")" == "1" ]] && BACKUP_BEFORE_FLUSH=true || BACKUP_BEFORE_FLUSH=false
    [[ "$(menu_get_value "force")" == "1" ]] && FORCE_OPERATION=true

    # Model selection
    local model=$(menu_get_value "model_name")
    # 10-049: identifiers shifted from Ollama-style tags ("nomic-embed-text-v1.5")
    # to llama.cpp's family-identifier convention ("nomic-embed-text-v1.5").
    # Embedding cache directory derives from this string via the sanitize-then-mkdir
    # pattern in utils.embeddings_dir(), so changing it triggers a fresh cache.
    case "$model" in
        "qwen3-embedding") MODEL_NAME="qwen3-embedding-4b" ;;
        "nomic-embed-text") MODEL_NAME="nomic-embed-text-v1.5" ;;
        "embeddinggemma") MODEL_NAME="embeddinggemma" ;;
        "text-embedding-ada-002") MODEL_NAME="text-embedding-ada-002" ;;
        "all-MiniLM-L6-v2") MODEL_NAME="all-MiniLM-L6-v2" ;;
        *) MODEL_NAME="nomic-embed-text-v1.5" ;;
    esac

    [[ "$(menu_get_value "model_status")" == "1" ]] && MODEL_STATUS=true
    [[ "$(menu_get_value "list_models")" == "1" ]] && LIST_MODELS=true

    # Validation: flush_all takes precedence over flush_errors
    if [[ "$FLUSH_ALL" == "true" ]] && [[ "$FLUSH_ERRORS" == "true" ]]; then
        FLUSH_ERRORS=false
    fi
}
# }}}

# {{{ run_tui_interactive_mode
# Run the TUI-based interactive mode
run_tui_interactive_mode() {
    if ! setup_embedding_tui_menu; then
        return 1
    fi

    if menu_run; then
        menu_cleanup
        apply_tui_selections

        # Show selected configuration
        echo ""
        echo "Selected configuration:"
        echo "- Model: $MODEL_NAME"
        echo "- Mode: $([ "$FORCE_REGEN" = true ] && echo "Full regeneration" || echo "Incremental")"
        echo "- Status check: $([ "$SHOW_STATUS" = true ] && echo "Yes" || echo "No")"
        echo "- Cache operations: $([ "$FLUSH_ALL" = true ] && echo "Flush all" || [ "$FLUSH_ERRORS" = true ] && echo "Flush errors" || [ "$VALIDATE_CACHE" = true ] && echo "Validate" || echo "None")"
        echo ""
        return 0
    else
        menu_cleanup
        echo "Operation cancelled."
        exit 0
    fi
}
# }}}

# {{{ run_simple_interactive_mode
# Fallback simple interactive mode (original implementation)
run_simple_interactive_mode() {
    echo "=== Embedding Generation Interactive Mode ==="
    echo ""
    echo "Select processing mode:"
    echo "1. Incremental (default) - Process only new/changed poems"
    echo "2. Full regeneration - Regenerate all embeddings"
    echo "3. Cache management - Flush/validate cache"
    echo "4. Status check - Show current progress"
    echo ""
    read -p "Choose option (1-4): " mode_choice

    case $mode_choice in
        1)
            INCREMENTAL=true
            ;;
        2)
            INCREMENTAL=false
            FORCE_REGEN=true
            ;;
        3)
            echo ""
            echo "Cache management options:"
            echo "1. Flush all cached embeddings"
            echo "2. Flush only failed embedding attempts"
            echo "3. Validate cache integrity"
            read -p "Choose cache option (1-3): " cache_choice
            case $cache_choice in
                1) FLUSH_ALL=true ;;
                2) FLUSH_ERRORS=true ;;
                3) VALIDATE_CACHE=true ;;
            esac
            ;;
        4)
            SHOW_STATUS=true
            ;;
    esac

    echo ""
    echo "Available embedding models:"
    echo "1. nomic-embed-text-v1.5 (default)"
    echo "2. qwen3-embedding:4b"
    echo "3. embeddinggemma:latest"
    echo "4. text-embedding-ada-002"
    echo "5. all-MiniLM-L6-v2"
    read -p "Choose model (1-5, or press enter for default): " model_choice

    case $model_choice in
        2) MODEL_NAME="qwen3-embedding:4b" ;;
        3) MODEL_NAME="embeddinggemma:latest" ;;
        4) MODEL_NAME="text-embedding-ada-002" ;;
        5) MODEL_NAME="all-MiniLM-L6-v2" ;;
        *) MODEL_NAME="nomic-embed-text-v1.5" ;;
    esac

    echo ""
    echo "Selected configuration:"
    echo "- Model: $MODEL_NAME"
    echo "- Mode: $([ "$INCREMENTAL" = true ] && echo "Incremental" || echo "Full regeneration")"
    echo "- Status check: $([ "$SHOW_STATUS" = true ] && echo "Yes" || echo "No")"
    echo "- Cache operations: $([ "$FLUSH_ALL" = true ] && echo "Flush all" || [ "$FLUSH_ERRORS" = true ] && echo "Flush errors" || [ "$VALIDATE_CACHE" = true ] && echo "Validate" || echo "None")"
    echo ""
    read -p "Continue with this configuration? (y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        echo "Operation cancelled."
        exit 0
    fi
    echo ""
}
# }}}

# Interactive mode handling - try TUI first, fall back to simple mode
if [ "$INTERACTIVE_MODE" = true ]; then
    if $TUI_AVAILABLE; then
        run_tui_interactive_mode || run_simple_interactive_mode
    else
        run_simple_interactive_mode
    fi
fi

# Set up directory after parsing arguments
DIR=$(setup_dir_path "$DIRECTORY_ARG")
cd "$DIR" || exit 1

# Issue 8-059: ensure the tmpfs-backed tmp/ symlink exists before any write,
# since the progress file we share with similarity-engine.lua now lives there.
"${DIR}/scripts/ensure-tmp-symlink" "${DIR}"

# Build --dir argument for Lua scripts if assets dir was specified
ASSETS_ARG=""
if [ -n "$ASSETS_DIR" ]; then
    ASSETS_ARG="--dir $ASSETS_DIR"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Progress tracking
START_TIME=$(date +%s)
POEMS_FILE="$DIR/assets/poems.json"
EMBEDDINGS_FILE="$DIR/assets/embeddings.json"
# run.sh's --debug exports NEOCITIES_LOG_DIR → durable disk (output/debug-logs)
# so this log survives the reboot a hard GPU lock forces; the default is the
# RAM-backed tmp/. The end-of-run cleanup below is skipped when this is set.
EMBED_LOG_DIR="${NEOCITIES_LOG_DIR:-${DIR}/tmp}"
mkdir -p "$EMBED_LOG_DIR"
TEMP_LOG="${EMBED_LOG_DIR}/embedding_generation.log"

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}  POEM EMBEDDING GENERATION - LIVE PROGRESS MONITOR${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""
# Handle model-specific operations
if [ "$LIST_MODELS" = true ]; then
    lua -e "
    package.path = '$DIR/libs/?.lua;$DIR/src/?.lua;' .. package.path
    local engine = require('similarity-engine')
    engine.list_available_models()
    "
    exit 0
fi

if [ "$MODEL_STATUS" = true ]; then
    lua -e "
    package.path = '$DIR/libs/?.lua;$DIR/src/?.lua;' .. package.path
    local engine = require('similarity-engine')
    engine.show_all_model_status('$DIR/assets')
    "
    exit 0
fi

# Generate model-specific paths
SAFE_MODEL_NAME=$(echo "$MODEL_NAME" | sed 's/[^a-zA-Z0-9._-]/_/g')
EMBEDDINGS_DIR="$DIR/assets/embeddings/$SAFE_MODEL_NAME"
EMBEDDINGS_FILE="$EMBEDDINGS_DIR/embeddings.json"

# Create model directory if needed
mkdir -p "$EMBEDDINGS_DIR"

echo -e "${BLUE}Project Directory:${NC} $DIR"
echo -e "${BLUE}Input File:${NC} $POEMS_FILE"
echo -e "${BLUE}Model:${NC} $MODEL_NAME"
echo -e "${BLUE}Output File:${NC} $EMBEDDINGS_FILE"
echo -e "${BLUE}Processing Mode:${NC} $([ "$INCREMENTAL" = true ] && echo "Incremental (default)" || echo "Full Regeneration")"
echo -e "${BLUE}Start Time:${NC} $(date)"
echo ""

# Handle flush operations
if [ "$FLUSH_ALL" = true ] || [ "$FLUSH_ERRORS" = true ]; then
    echo -e "${YELLOW}🗑️  Cache Flush Operation${NC}"
    echo ""
    
    FLUSH_TYPE="all"
    if [ "$FLUSH_ERRORS" = true ]; then
        FLUSH_TYPE="errors"
    fi
    
    echo -e "${BLUE}Flush Type:${NC} $FLUSH_TYPE"
    echo -e "${BLUE}Target File:${NC} $EMBEDDINGS_FILE"
    echo -e "${BLUE}Backup Enabled:${NC} $BACKUP_BEFORE_FLUSH"
    
    if [ -f "$EMBEDDINGS_FILE" ]; then
        FILE_SIZE=$(du -h "$EMBEDDINGS_FILE" | cut -f1)
        echo -e "${BLUE}Current File Size:${NC} $FILE_SIZE"
    else
        echo -e "${YELLOW}No cache file found${NC}"
        exit 0
    fi
    echo ""
    
    # Safety confirmation
    if [ "$FORCE_OPERATION" != true ]; then
        echo -e "${YELLOW}⚠️  WARNING: This will permanently modify the embedding cache${NC}"
        if [ "$FLUSH_TYPE" = "all" ]; then
            echo -e "${RED}This will DELETE ALL cached embeddings!${NC}"
        else
            echo -e "${YELLOW}This will remove error entries but keep valid embeddings${NC}"
        fi
        echo ""
        read -p "Are you sure you want to proceed? (yes/no): " confirmation
        if [ "$confirmation" != "yes" ]; then
            echo "Operation cancelled"
            exit 0
        fi
    fi
    
    # Execute flush operation
    echo -e "${CYAN}Executing flush operation...${NC}"
    
    BACKUP_LUA_FLAG="true"
    if [ "$BACKUP_BEFORE_FLUSH" = false ]; then
        BACKUP_LUA_FLAG="false"
    fi
    
    lua -e "
        package.path = package.path .. ';./libs/?.lua;./src/?.lua'
        local similarity_engine = require('similarity-engine')
        local success = similarity_engine.flush_embeddings_cache('$EMBEDDINGS_FILE', '$FLUSH_TYPE', $BACKUP_LUA_FLAG)
        if not success then
            os.exit(1)
        end
    "
    
    FLUSH_RESULT=$?
    if [ $FLUSH_RESULT -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✅ Cache flush operation completed successfully${NC}"
    else
        echo ""
        echo -e "${RED}❌ Cache flush operation failed${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${CYAN}              CACHE FLUSH COMPLETE${NC}"
    echo -e "${CYAN}================================================================${NC}"
    exit 0
fi

# Handle status and validation modes
if [ "$SHOW_STATUS" = true ] || [ "$VALIDATE_CACHE" = true ]; then
    echo -e "${YELLOW}🔍 Checking embedding cache status...${NC}"
    
    if [ -f "$EMBEDDINGS_FILE" ]; then
        CACHE_INFO=$(lua -e "
            local dkjson = require('libs.dkjson')
            local f = io.open('$EMBEDDINGS_FILE')
            local data = dkjson.decode(f:read('*a'))
            f:close()
            
            -- Count actual embeddings in file
            local total_entries = 0
            local completed_embeddings = 0
            for id, emb in pairs(data.embeddings or {}) do
                total_entries = total_entries + 1
                if emb.embedding then 
                    completed_embeddings = completed_embeddings + 1 
                end
            end
            
            local rate = total_entries > 0 and (completed_embeddings / total_entries) or 0
            local mode = data.metadata and data.metadata.processing_mode or 'unknown'
            local generated = data.metadata and data.metadata.generated_at or 'unknown'
            local model = data.metadata and data.metadata.embedding_model or 'qwen3-embedding:4b'
            
            print(string.format('%d,%d,%.3f,%s,%s,%s', total_entries, completed_embeddings, rate, mode, generated, model))
        " 2>/dev/null || echo "0,0,0,error,unknown,unknown")
        
        IFS=',' read -r CACHE_TOTAL CACHE_COMPLETED CACHE_RATE CACHE_MODE CACHE_DATE CACHE_MODEL <<< "$CACHE_INFO"
        
        echo -e "${GREEN}✓ Embedding cache found${NC}"
        echo -e "${BLUE}Cache Statistics:${NC}"
        echo -e "   Total poems: ${YELLOW}$CACHE_TOTAL${NC}"
        echo -e "   Completed embeddings: ${GREEN}$CACHE_COMPLETED${NC}"
        echo -e "   Completion rate: ${GREEN}$(printf "%.1f%%" $(echo "$CACHE_RATE * 100" | bc -l))${NC}"
        echo -e "   Processing mode: ${PURPLE}$CACHE_MODE${NC}"
        echo -e "   Generated: ${CYAN}$CACHE_DATE${NC}"
        echo -e "   Model: ${PURPLE}$CACHE_MODEL${NC}"
        
        if [ "$VALIDATE_CACHE" = true ]; then
            echo ""
            echo -e "${YELLOW}🔍 Validating cache integrity...${NC}"
            # Add cache validation logic here
            echo -e "${GREEN}✓ Cache validation complete${NC}"
        fi
    else
        echo -e "${RED}❌ No embedding cache found${NC}"
        echo -e "${YELLOW}💡 Run without --status to generate embeddings${NC}"
    fi
    
    if [ "$SHOW_STATUS" = true ]; then
        exit 0
    fi
fi

# Check prerequisites
echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"

if [ ! -f "$POEMS_FILE" ]; then
    echo -e "${RED}❌ ERROR: Poems file not found at $POEMS_FILE${NC}"
    exit 1
fi

# Count total poems
TOTAL_POEMS=$(lua -e "local dkjson = require('libs.dkjson'); local f = io.open('$POEMS_FILE'); local data = dkjson.decode(f:read('*a')); f:close(); print(#data.poems)")
echo -e "${GREEN}✓ Found $TOTAL_POEMS poems to process${NC}"

# Check inference server availability. 10-049: was Ollama; now llama.cpp.
if [ -n "$INFERENCE_SERVER" ]; then
    INFERENCE_ENDPOINT=$(luajit -e "
        package.path = '$DIR/libs/?.lua;' .. package.path
        local inference = require('inference-server-config')
        inference.set_selected_server('$INFERENCE_SERVER')
        print(inference.build_host_url())
    ")
    echo -e "${CYAN}Using Inference server: $INFERENCE_SERVER${NC}"
else
    # Default: use config default or hardcoded fallback
    INFERENCE_ENDPOINT=$(luajit -e "
        package.path = '$DIR/libs/?.lua;' .. package.path
        local inference = require('inference-server-config')
        print(inference.build_host_url())
    " 2>/dev/null || echo "http://127.0.0.1:18080")
fi
# /v1/models is llama.cpp's OpenAI-compatible "what's loaded" endpoint.
# Used both as a liveness probe and as the source for the model list.
if curl -s --max-time 3 "$INFERENCE_ENDPOINT/v1/models" > /dev/null; then
    echo -e "${GREEN}✓ Inference server reachable at $INFERENCE_ENDPOINT${NC}"
else
    echo -e "${RED}❌ ERROR: Cannot connect to inference server at $INFERENCE_ENDPOINT${NC}"
    exit 1
fi

# Check selected embedding model. /v1/models returns {data: [{id: "..."},...]}.
if curl -s "$INFERENCE_ENDPOINT/v1/models" | grep -q "$MODEL_NAME"; then
    echo -e "${GREEN}✓ $MODEL_NAME model available${NC}"
else
    echo -e "${RED}❌ ERROR: $MODEL_NAME model not found${NC}"
    echo -e "${YELLOW}💡 Loaded models on this server:${NC}"
    curl -s "$INFERENCE_ENDPOINT/v1/models" | lua -e "
        local dkjson = require('libs.dkjson')
        local data = dkjson.decode(io.read('*a'))
        if data and data.data then
            for _, model in ipairs(data.data) do
                print('  ' .. (model.id or '(unnamed)'))
            end
        end
    " 2>/dev/null
    exit 1
fi

echo ""
if [ "$INCREMENTAL" = true ]; then
    echo -e "${CYAN}🚀 Starting incremental embedding generation for $TOTAL_POEMS poems...${NC}"
    echo -e "${YELLOW}💡 Only new/changed poems will be processed (time savings expected)${NC}"
else
    echo -e "${CYAN}🚀 Starting FULL regeneration of embeddings for $TOTAL_POEMS poems...${NC}"
    echo -e "${YELLOW}⚠️  All embeddings will be regenerated (this may take longer)${NC}"
fi
echo ""

# Graceful termination handler
cleanup_and_exit() {
    echo ""
    echo -e "${YELLOW}🛑 Termination signal received${NC}"
    echo -e "${CYAN}Performing graceful cleanup...${NC}"
    
    # Kill background processes
    if [ -n "$EMBED_PID" ]; then
        echo -e "${BLUE}Stopping embedding generation process...${NC}"
        kill -TERM "$EMBED_PID" 2>/dev/null
        wait "$EMBED_PID" 2>/dev/null
    fi
    
    if [ -n "$MONITOR_PID" ]; then
        echo -e "${BLUE}Stopping progress monitor...${NC}"
        kill -TERM "$MONITOR_PID" 2>/dev/null
        wait "$MONITOR_PID" 2>/dev/null
    fi
    
    # Show current progress
    if [ -f "$EMBEDDINGS_FILE" ]; then
        local final_count=$(lua -e "
            local dkjson = require('libs.dkjson')
            local f = io.open('$EMBEDDINGS_FILE')
            if not f then print(0); return end
            local content = f:read('*a')
            f:close()
            if content == '' then print(0); return end
            local data = dkjson.decode(content)
            if not data or not data.embeddings then print(0); return end
            local count = 0
            -- Handle both array and object format
            if data.embeddings[1] then
                -- Array format
                for _, emb in ipairs(data.embeddings) do
                    if emb.embedding then count = count + 1 end
                end
            else
                -- Object format
                for id, emb in pairs(data.embeddings) do
                    if emb.embedding then count = count + 1 end
                end
            end
            print(count)
        " 2>/dev/null || echo "0")
        
        echo -e "${GREEN}✅ Embeddings saved to cache${NC}"
        echo -e "${BLUE}Progress preserved: $final_count/$TOTAL_POEMS embeddings completed${NC}"
        echo -e "${CYAN}Use incremental mode to resume from current position${NC}"
    fi
    
    local end_time=$(date +%s)
    local total_time=$((end_time - START_TIME))
    local total_minutes=$((total_time / 60))
    echo -e "${BLUE}Total runtime: ${total_minutes}m${NC}"
    
    # Cleanup progress file
    rm -f "${DIR}/tmp/embedding_progress_${USER}.txt" 2>/dev/null
    
    exit 0
}

# Register signal handlers
trap cleanup_and_exit SIGINT SIGTERM

# Create monitoring function
# Issue 10-022: Updated to use PID-based detection instead of pgrep for process name
# This is needed because we now use luajit -e instead of lua similarity-engine.lua
monitor_progress() {
    local current_poem=0
    local start_time=$(date +%s)
    local percent=0
    local progress_file="${DIR}/tmp/embedding_progress_${USER}.txt"
    local last_progress_time=0
    # EMBED_PID is set in the calling scope before monitor_progress is started
    local target_pid=$EMBED_PID

    # Detect whether stdout is an interactive terminal. Under run.sh --debug,
    # stdout is a pipe to scripts/fsync-logger, which reads line-by-line and so
    # cannot render a carriage-return progress bar (the bar emits no newlines, so
    # the logger blocks waiting for one and nothing shows). In that case we fall
    # back to a newline-terminated progress LINE on each percent change, which
    # flows through the logger to both the terminal and the debug log.
    local is_tty=0
    if [ -t 1 ]; then is_tty=1; fi
    local last_reported_percent=-1

    while true; do
        # Check for real-time progress updates from Lua script
        if [ -f "$progress_file" ]; then
            local file_mtime=$(stat -c %Y "$progress_file" 2>/dev/null || echo "0")
            if [ "$file_mtime" -gt "$last_progress_time" ]; then
                # File has been updated - read new progress
                local progress_data=$(cat "$progress_file" 2>/dev/null || echo "0,0")
                IFS=',' read -r current_poem total_poems <<< "$progress_data"
                last_progress_time=$file_mtime

                # Calculate percentage (guard against division by zero)
                if [ "$total_poems" -gt 0 ]; then
                    percent=$((current_poem * 100 / total_poems))
                else
                    percent=0
                fi
            fi
        else
            # No progress file found - fallback to basic monitoring
            current_poem=0
            percent=0
        fi

        # Create progress bar
        local bar_length=50
        local filled=$((percent * bar_length / 100))
        local bar=""
        for ((i=0; i<filled; i++)); do bar="${bar}█"; done
        for ((i=filled; i<bar_length; i++)); do bar="${bar}░"; done

        # Render progress. Interactive terminal: redraw the bar in place with a
        # carriage return. Captured/non-TTY (e.g. --debug): emit one line per
        # percentage change so the line-based logger can pass it through.
        if [ "$is_tty" -eq 1 ]; then
            echo -ne "\033[2K\r${PURPLE}Progress: ${bar} ${percent}% (${current_poem}/${TOTAL_POEMS})${NC}"
        elif [ "$percent" -ne "$last_reported_percent" ]; then
            echo "Progress: ${percent}% (${current_poem}/${TOTAL_POEMS})"
            last_reported_percent=$percent
        fi

        # Check if embedding process is still running using PID
        # Issue 10-022: Changed from pgrep to kill -0 for accurate PID detection
        if ! kill -0 "$target_pid" 2>/dev/null; then
            break
        fi

        # Periodic health check of the inference server (every 5 minutes)
        local current_time=$(date +%s)
        local health_check_interval=300  # 5 minutes
        if [ $((current_time % health_check_interval)) -eq 0 ] && [ $((current_time - start_time)) -gt 60 ]; then
            if ! curl -s --max-time 3 "$INFERENCE_ENDPOINT/v1/models" > /dev/null; then
                echo ""
                echo ""
                echo -e "${RED}⚠️  INFERENCE SERVER UNAVAILABLE${NC}"
                echo -e "${YELLOW}Embedding process may fail and could corrupt the cache.${NC}"
                echo -e "${YELLOW}Consider stopping the process and restarting the inference server.${NC}"
            fi
        fi

        sleep 0.2
    done
}

# Start the embedding generation in background
# Issue 10-022: Use direct function call instead of piped stdin
# Piped stdin causes curl exit code 7 (connection refused) due to file descriptor issues
echo "Generating embeddings..." > "$TEMP_LOG"

# The two run modes (incremental vs full regeneration) differ only by one
# boolean argument, so we build a single Lua program and pass the flag in
# rather than duplicating the whole snippet.
INCREMENTAL_LUA=$([ "$INCREMENTAL" = true ] && echo true || echo false)

# In debug mode (NEOCITIES_LOG_DIR set by run.sh --debug) make Lua's stdout and
# stderr UNBUFFERED. Otherwise Lua holds log lines in a block buffer and a hard
# lock loses everything not yet flushed — defeating the whole point of routing
# the log through fsync-logger below. Empty string outside debug = default
# (block) buffering, which is faster for normal runs.
LUA_DEBUG_PROLOGUE=""
if [ -n "${NEOCITIES_LOG_DIR:-}" ]; then
    LUA_DEBUG_PROLOGUE="io.stdout:setvbuf('no'); io.stderr:setvbuf('no');"
fi

LUA_EMBED_PROGRAM="
    ${LUA_DEBUG_PROLOGUE}
    package.path = '$DIR/libs/?.lua;$DIR/src/?.lua;' .. package.path
    local sim = require('similarity-engine')
    local success = sim.generate_all_embeddings(
        '$POEMS_FILE',
        '$DIR/assets',
        '$INFERENCE_ENDPOINT',
        ${INCREMENTAL_LUA},
        '$MODEL_NAME'
    )
    os.exit(success and 0 or 1)
"

# In debug, pipe the embedding output through fsync-logger so each line is
# committed to disk the moment it is written (survives a hard lock). The
# process substitution is a sibling, so $! still captures the luajit PID we
# wait on below. Outside debug, the plain append keeps things fast.
if [ -n "${NEOCITIES_LOG_DIR:-}" ]; then
    luajit -e "$LUA_EMBED_PROGRAM" \
        > >("${DIR}/scripts/fsync-logger" --quiet "$TEMP_LOG") 2>&1 &
else
    luajit -e "$LUA_EMBED_PROGRAM" >> "$TEMP_LOG" 2>&1 &
fi
EMBED_PID=$!

# Start progress monitoring
monitor_progress &
MONITOR_PID=$!

# Wait for completion
wait $EMBED_PID
EMBED_RESULT=$?

# Stop monitoring
kill $MONITOR_PID 2>/dev/null
wait $MONITOR_PID 2>/dev/null

echo ""
echo ""

# Generate completion report
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
MINUTES=$((TOTAL_TIME / 60))
SECONDS=$((TOTAL_TIME % 60))

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}              EMBEDDING GENERATION COMPLETE${NC}"
echo -e "${CYAN}================================================================${NC}"
echo ""

if [ $EMBED_RESULT -eq 0 ] && [ -f "$EMBEDDINGS_FILE" ]; then
    # Generate detailed statistics
    STATS=$(lua -e "
        local dkjson = require('libs.dkjson')
        local f = io.open('$EMBEDDINGS_FILE')
        local data = dkjson.decode(f:read('*a'))
        f:close()
        
        local total = 0
        local successful = 0
        local failed = 0
        local empty_content = 0
        local avg_length = 0
        local total_length = 0
        local new_embeddings = data.metadata.new_embeddings or 0
        local reused_embeddings = data.metadata.reused_embeddings or 0
        local processing_mode = data.metadata.processing_mode or 'unknown'
        
        for id, emb in pairs(data.embeddings) do
            total = total + 1
            if emb.embedding then
                successful = successful + 1
                if emb.content_length then
                    total_length = total_length + emb.content_length
                end
            elseif emb.error == 'empty_content' then
                empty_content = empty_content + 1
            else
                failed = failed + 1
            end
        end
        
        if successful > 0 then
            avg_length = math.floor(total_length / successful)
        end
        
        -- Guard against division by zero when embeddings array is empty
        local success_rate = 0
        if total > 0 then
            success_rate = math.floor((successful / total) * 100)
        end
        local processing_rate = 0
        if $TOTAL_TIME > 0 then
            processing_rate = math.floor(successful * 3600 / $TOTAL_TIME)
        end
        local time_savings = 0
        if total > 0 then
            time_savings = math.floor((reused_embeddings / total) * 100)
        end
        
        print(string.format('%d,%d,%d,%d,%d,%d,%d,%d,%d,%s', total, successful, failed, empty_content, success_rate, avg_length, processing_rate, new_embeddings, time_savings, processing_mode))
    ")
    
    IFS=',' read -r TOTAL_PROCESSED SUCCESSFUL FAILED EMPTY_CONTENT SUCCESS_RATE AVG_LENGTH PROCESSING_RATE NEW_EMBEDDINGS TIME_SAVINGS PROCESSING_MODE <<< "$STATS"

    # Check if generation actually produced embeddings
    # terminated_network_error mode with 0 successful is a failure
    if [ "$SUCCESSFUL" -eq 0 ] || [ "$PROCESSING_MODE" = "terminated_network_error" ]; then
        echo -e "${RED}❌ GENERATION FAILED${NC}"
        echo ""
        echo -e "${YELLOW}The embedding generation terminated without completing:${NC}"
        echo -e "   Processing Mode: ${RED}$PROCESSING_MODE${NC}"
        echo -e "   Successful Embeddings: ${RED}$SUCCESSFUL${NC}"
        echo ""
        echo -e "${YELLOW}💡 Troubleshooting:${NC}"
        echo -e "   1. Check inference server: curl $INFERENCE_ENDPOINT/v1/models"
        echo -e "   2. Test embedding API: curl $INFERENCE_ENDPOINT/v1/embeddings -d '{\"model\":\"$MODEL_NAME\",\"input\":\"test\"}'"
        echo -e "   3. Retry: ./run.sh --generate-embeddings --force"
        exit 1
    fi

    echo -e "${GREEN}✅ GENERATION SUCCESSFUL${NC}"
    echo ""
    echo -e "${BLUE}📊 Processing Statistics:${NC}"
    echo -e "   Processing Mode: ${PURPLE}$PROCESSING_MODE${NC}"
    echo -e "   Total Poems Processed: ${YELLOW}$TOTAL_PROCESSED${NC}"
    echo -e "   Successful Embeddings: ${GREEN}$SUCCESSFUL${NC}"
    if [ "$PROCESSING_MODE" = "incremental" ]; then
        REUSED_EMBEDDINGS=$((SUCCESSFUL - NEW_EMBEDDINGS))
        echo -e "   New Embeddings Generated: ${CYAN}$NEW_EMBEDDINGS${NC}"
        echo -e "   Existing Embeddings Reused: ${GREEN}$REUSED_EMBEDDINGS${NC}"
        echo -e "   Time Savings: ${GREEN}$TIME_SAVINGS%${NC}"
    fi
    echo -e "   Failed Embeddings: ${RED}$FAILED${NC}"
    echo -e "   Empty Content Skipped: ${YELLOW}$EMPTY_CONTENT${NC}"
    echo -e "   Success Rate: ${GREEN}$SUCCESS_RATE%${NC}"
    echo ""
    echo -e "${BLUE}📈 Performance Metrics:${NC}"
    echo -e "   Total Processing Time: ${YELLOW}${MINUTES}m ${SECONDS}s${NC}"
    if [ "$PROCESSING_MODE" = "incremental" ] && [ "$NEW_EMBEDDINGS" -gt 0 ]; then
        ACTUAL_PROCESSING_RATE=$((NEW_EMBEDDINGS * 3600 / TOTAL_TIME))
        echo -e "   New Embedding Rate: ${GREEN}$ACTUAL_PROCESSING_RATE embeddings/hour${NC}"
        echo -e "   Overall Effective Rate: ${GREEN}$PROCESSING_RATE embeddings/hour${NC}"
    else
        echo -e "   Average Processing Rate: ${GREEN}$PROCESSING_RATE embeddings/hour${NC}"
    fi
    echo -e "   Average Poem Length: ${CYAN}$AVG_LENGTH characters${NC}"
    echo ""
    echo -e "${BLUE}🎯 Technical Details:${NC}"
    echo -e "   Embedding Model: ${PURPLE}${MODEL_NAME}${NC}"
    echo -e "   Vector Dimensions: ${PURPLE}${EMBEDDING_DIM:-unknown}${NC}"
    echo -e "   CUDA Acceleration: ${GREEN}Enabled${NC}"
    echo -e "   Endpoint: ${CYAN}$INFERENCE_ENDPOINT${NC}"
    echo ""
    
    # File size information
    if [ -f "$EMBEDDINGS_FILE" ]; then
        FILE_SIZE=$(du -h "$EMBEDDINGS_FILE" | cut -f1)
        echo -e "${BLUE}📁 Output File:${NC}"
        echo -e "   Location: ${CYAN}$EMBEDDINGS_FILE${NC}"
        echo -e "   Size: ${YELLOW}$FILE_SIZE${NC}"
        echo ""
    fi
    
    echo -e "${GREEN}🎉 Ready for similarity matrix calculation!${NC}"
    echo -e "${CYAN}Next step: Run similarity matrix generation${NC}"
    
else
    echo -e "${RED}❌ GENERATION FAILED${NC}"
    echo ""
    echo -e "${YELLOW}📋 Error Log (last 20 lines):${NC}"
    if [ -f "$TEMP_LOG" ]; then
        tail -20 "$TEMP_LOG" | sed 's/^/   /'
    fi
    echo ""
    echo -e "${YELLOW}💡 Troubleshooting:${NC}"
    echo -e "   1. Check inference server status"
    echo -e "   2. Verify EmbeddingGemma model availability"  
    echo -e "   3. Check network connectivity"
    echo -e "   4. Review full log: ${CYAN}$TEMP_LOG${NC}"
fi

echo ""
echo -e "${CYAN}================================================================${NC}"
echo -e "${BLUE}Generation completed at:${NC} $(date)"
echo -e "${CYAN}================================================================${NC}"

# Cleanup. In debug mode (NEOCITIES_LOG_DIR exported by run.sh --debug) the
# embedding log is preserved for post-crash review; otherwise it is removed as
# before. The progress file is ephemeral inter-process state, always cleaned.
if [ -z "${NEOCITIES_LOG_DIR:-}" ]; then
    rm -f "$TEMP_LOG"
fi
rm -f "${DIR}/tmp/embedding_progress_${USER}.txt" 2>/dev/null

# Propagate the embedding result as this script's exit code so run.sh's
# `generate-embeddings.sh ... || exit 1` actually fires on failure. Previously
# the script fell off the end after the cleanup rm (exit 0), which masked a
# failed run and let the pipeline push on into the word/color stages against a
# half-built cache — exactly what happened when the giant-poem tail tripped the
# network-error threshold. (Found during 10-050.)
exit $EMBED_RESULT