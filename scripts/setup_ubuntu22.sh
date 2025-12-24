#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}>>>${NC} $*"; }
log_warn() { echo -e "${YELLOW}WARNING:${NC} $*"; }
log_error() { echo -e "${RED}ERROR:${NC} $*"; exit 1; }

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run with sudo privileges"
    fi
}

update_system() {
    log_info "Updating system packages..."
    apt update -qq || { log_error "Failed to update package lists"; }
    apt upgrade -y -qq || { log_error "Failed to upgrade packages"; }
}

install_core_tools() {
    log_info "Installing core build tools..."
    apt install -y build-essential cmake ninja-build ccache git curl wget pkg-config python3 || { log_error "Failed to install core tools"; }
}

install_go() {
    if command -v go &>/dev/null; then
        log_warn "Go already installed, skipping..."
        return
    fi
    log_info "Installing Go via snap..."
    snap install go --classic || { log_error "Failed to install Go via snap"; }
}

install_cuda() {
    if command -v nvcc &>/dev/null; then
        log_warn "CUDA already installed, skipping..."
        log_info "CUDA version: $(nvcc --version | grep release | awk '{print $5}')"
        return
    fi
    log_info "Installing CUDA 11.4..."
    wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin -O /tmp/cuda.pin || { log_error "Failed to download CUDA pin file"; }
    mv /tmp/cuda.pin /etc/apt/preferences.d/cuda-repository-pin-600
    apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/3bf863cc.pub || { log_error "Failed to fetch CUDA repository key"; }
    add-apt-repository "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/ /" || { log_error "Failed to add CUDA repository"; }
    apt update || { log_error "Failed to update package lists"; }
    apt install -y cuda-toolkit-11-4 cuda-compiler-11-4 cuda-cudart-dev-11-4 libcublas-dev-11-4 || { log_error "Failed to install CUDA 11.4"; }
}

setup_environment() {
    log_info "Setting up environment variables..."
    cat > /etc/profile.d/ollama-cuda.sh <<'EOF'
export PATH=/usr/local/cuda-11.4/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-11.4/lib64:$LD_LIBRARY_PATH
export CUDA_HOME=/usr/local/cuda-11.4
EOF
}

build_ollama() {
    log_info "Building Ollama with CUDA 11.4 preset..."
    rm -rf build/ || { log_error "Failed to clean build directory"; }
    cmake --preset "CUDA 11" -B build/ || { log_error "Failed to configure CMake"; }
    cmake --build build/ --config Release --parallel $(nproc) || { log_error "Failed to build C++ components"; }
    go build -trimpath -buildmode=pie -ldflags="-w -s" -o ollama . || { log_error "Failed to build Go binary"; }
}

verify_build() {
    log_info "Verifying build..."
    if [ -f "ollama" ]; then
        log_info "Ollama binary built successfully"
        ./ollama --version
    else
        log_error "Ollama binary not found"
    fi
}

test_build() {
    log_info "Testing with tinyllama..."
    ollama run tinyllama "GTX 970 compatibility test" --verbose || { log_error "Failed to run tinyllama test"; }
}

show_bashrc_instructions() {
    log_info "Setup complete!"
    echo ""
    log_info "To use CUDA environment in your current shell, run:"
    echo "   source /etc/profile.d/ollama-cuda.sh"
    echo ""
    log_info "To add CUDA to your bashrc permanently, add this line to ~/.bashrc:"
    echo "   source /etc/profile.d/ollama-cuda.sh"
    echo ""
    log_info "Then reload your shell: source ~/.bashrc"
}

main() {
    check_root
    update_system
    install_core_tools
    install_go
    install_cuda
    setup_environment
    build_ollama
    verify_build
    test_build
    show_bashrc_instructions
}

main
