#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}>>>${NC} $*"; }
log_warn() { echo -e "${YELLOW}WARNING:${NC} $*"; }
log_error() { echo -e "${RED}ERROR:${NC} $*"; }

find_ollama() {
    if command -v ollama &>/dev/null; then
        which ollama
        return 0
    fi
    
    local dir=$(pwd)
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/ollama" ]; then
            echo "$dir/ollama"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    log_error "ollama binary not found in current directory or PATH"
}

echo "=== GTX 970 Compatibility Test ==="

echo ""
echo "1. Checking GPU detection..."
if ! command -v nvidia-smi &>/dev/null; then
    log_error "nvidia-smi not found. Is NVIDIA driver installed?"
fi

GPU_INFO=$(nvidia-smi --query-gpu=name,compute_cap --format=csv,noheader)
echo "   GPU: $GPU_INFO"

echo ""
echo "2. Checking CUDA toolkit..."
if ! command -v nvcc &>/dev/null; then
    log_error "nvcc not found. Is CUDA toolkit installed?"
fi

CUDA_VERSION=$(nvcc --version | grep release | awk '{print $5}' | sed 's/,//')
echo "   CUDA Version: $CUDA_VERSION"

echo ""
echo "3. Checking CUDA environment..."
CUDA_PATH=$(echo $PATH | grep -o '/usr/local/cuda[^:]*')
if [ -n "$CUDA_PATH" ]; then
    log_info "CUDA is in PATH"
else
    log_warn "CUDA not in PATH. Run: source /etc/profile.d/ollama-cuda.sh"
fi

echo ""
echo "4. Checking compute capability..."
COMPUTE_CAP=$(echo $GPU_INFO | cut -d',' -f2)
if [ "$COMPUTE_CAP" = "5.2" ]; then
    log_info "Compute capability 5.2 detected (GTX 970 supported)"
else
    log_warn "Unexpected compute capability: $COMPUTE_CAP"
fi

echo ""
echo "5. Checking Ollama binary..."
OLLAMA_BIN=$(find_ollama)
OLLAMA_VERSION=$($OLLAMA_BIN --version)
echo "   Ollama: $OLLAMA_VERSION"

echo ""
echo "6. Checking tinyllama model..."
if ! command -v ollama &>/dev/null; then
    log_error "ollama not in PATH"
fi

if ollama list 2>/dev/null | grep -q tinyllama; then
    log_info "tinyllama already downloaded"
else
    log_info "Pulling tinyllama..."
    ollama pull tinyllama || { log_error "Failed to pull tinyllama"; }
fi

echo ""
echo "7. Running tinyllama inference test..."
log_info "Testing GTX 970 with tinyllama..."
echo ""
ollama run tinyllama "GTX 970 compatibility test" --verbose || { log_error "Test inference failed"; }
EXIT_CODE=$?
echo ""

echo ""
echo "8. Checking GPU memory usage..."
nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits

if [ $EXIT_CODE -eq 0 ]; then
    log_info "=== Test Complete ==="
    log_info "GTX 970 is working correctly with Ollama"
else
    log_error "Test failed with exit code: $EXIT_CODE"
fi
