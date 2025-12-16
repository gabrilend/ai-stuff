#!/bin/bash

# Setup script for local LLM infrastructure
# Detects and configures available LLM backends

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

LOG_FILE="files/build/llm_setup.log"
mkdir -p files/build

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_ollama() {
    log "Checking for Ollama..."
    if command -v ollama &> /dev/null; then
        if ollama list | grep -q "llama2\|llama3\|codellama\|mistral"; then
            log "✓ Ollama found with models available"
            echo "ollama" > files/build/preferred_llm.txt
            return 0
        else
            log "! Ollama found but no models installed"
            log "  Run: ollama pull llama2"
            return 1
        fi
    else
        log "✗ Ollama not found"
        return 1
    fi
}

check_llamacpp() {
    log "Checking for LlamaCPP server..."
    if curl -s http://localhost:8000/health &> /dev/null; then
        log "✓ LlamaCPP server running on localhost:8000"
        if [[ ! -f files/build/preferred_llm.txt ]]; then
            echo "llamacpp" > files/build/preferred_llm.txt
        fi
        return 0
    else
        log "✗ LlamaCPP server not running on localhost:8000"
        return 1
    fi
}

check_koboldcpp() {
    log "Checking for KoboldCPP..."
    if curl -s http://localhost:5001/api/v1/model &> /dev/null; then
        log "✓ KoboldCPP running on localhost:5001"
        if [[ ! -f files/build/preferred_llm.txt ]]; then
            echo "koboldcpp" > files/build/preferred_llm.txt
        fi
        return 0
    else
        log "✗ KoboldCPP not running on localhost:5001"
        return 1
    fi
}

install_ollama() {
    log "Installing Ollama..."
    curl -fsSL https://ollama.ai/install.sh | sh
    
    log "Starting Ollama service..."
    ollama serve &
    sleep 5
    
    log "Pulling llama2 model (this may take a while)..."
    ollama pull llama2
    
    log "Ollama setup complete"
}

setup_llamacpp() {
    log "Setting up LlamaCPP..."
    
    if ! command -v python3 &> /dev/null; then
        log "ERROR: Python3 not found. Please install Python3."
        return 1
    fi
    
    # Create virtual environment for LlamaCPP
    python3 -m venv llamacpp_env
    source llamacpp_env/bin/activate
    
    pip install llama-cpp-python[server]
    
    # Download a small model for testing
    mkdir -p models
    if [[ ! -f models/llama-2-7b-chat.q4_0.gguf ]]; then
        log "Downloading Llama 2 7B model (this may take a while)..."
        wget -O models/llama-2-7b-chat.q4_0.gguf \
            "https://huggingface.co/TheBloke/Llama-2-7B-Chat-GGUF/resolve/main/llama-2-7b-chat.q4_0.gguf"
    fi
    
    log "LlamaCPP setup complete. Start with:"
    log "  source llamacpp_env/bin/activate"
    log "  python -m llama_cpp.server --model models/llama-2-7b-chat.q4_0.gguf --port 8000"
}

create_start_scripts() {
    log "Creating LLM start scripts..."
    
    # Ollama start script
    cat > scripts/start_ollama.sh << 'EOF'
#!/bin/bash
echo "Starting Ollama..."
ollama serve &
echo "Ollama started. Available models:"
ollama list
EOF
    chmod +x scripts/start_ollama.sh
    
    # LlamaCPP start script
    cat > scripts/start_llamacpp.sh << 'EOF'
#!/bin/bash
if [[ -f llamacpp_env/bin/activate ]]; then
    source llamacpp_env/bin/activate
    echo "Starting LlamaCPP server..."
    python -m llama_cpp.server --model models/llama-2-7b-chat.q4_0.gguf --port 8000 &
    echo "LlamaCPP server started on port 8000"
else
    echo "LlamaCPP environment not found. Run setup_llm.sh first."
fi
EOF
    chmod +x scripts/start_llamacpp.sh
    
    log "Start scripts created in scripts/ directory"
}

main() {
    log "=== LLM Infrastructure Setup ==="
    
    mkdir -p scripts models
    
    local llm_found=false
    
    # Check existing setups
    if check_ollama; then
        llm_found=true
    fi
    
    if check_llamacpp; then
        llm_found=true
    fi
    
    if check_koboldcpp; then
        llm_found=true
    fi
    
    if ! $llm_found; then
        log "No LLM backends found. Setting up Ollama as default..."
        install_ollama
    fi
    
    create_start_scripts
    
    log "=== LLM Setup Complete ==="
    
    if [[ -f files/build/preferred_llm.txt ]]; then
        local preferred=$(cat files/build/preferred_llm.txt)
        log "Preferred LLM backend: $preferred"
    fi
    
    log "The desktop LLM service will automatically detect and use available backends"
}

main "$@"