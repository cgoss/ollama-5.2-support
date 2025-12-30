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
    apt install -y build-essential ninja-build ccache git curl wget pkg-config python3 software-properties-common || { log_error "Failed to install core tools"; }
}

install_cmake() {
    local required_version="3.21"
    if command -v cmake &>/dev/null; then
        local current_version=$(cmake --version | head -n1 | awk '{print $3}')
        if [ "$(printf '%s\n' "$required_version" "$current_version" | sort -V | head -n1)" = "$required_version" ]; then
            log_info "CMake $current_version already installed (>= $required_version)"
            return
        else
            log_warn "CMake $current_version is too old (need >= $required_version), upgrading..."
        fi
    fi
    log_info "Installing CMake 3.21+ from Kitware repository..."
    wget -qO - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null || { log_error "Failed to add Kitware GPG key"; }
    echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ focal main' | tee /etc/apt/sources.list.d/kitware.list >/dev/null || { log_error "Failed to add Kitware repository"; }
    apt update || { log_error "Failed to update package lists"; }
    apt install -y cmake || { log_error "Failed to install CMake"; }
    log_info "CMake installed: $(cmake --version | head -n1)"
}

install_go() {
    local required_version="1.24"
    if command -v go &>/dev/null; then
        local current_version=$(go version | awk '{print $3}' | sed 's/go//')
        if [ "$(printf '%s\n' "$required_version" "$current_version" | sort -V | head -n1)" = "$required_version" ]; then
            log_info "Go $current_version already installed (>= $required_version)"
            return
        else
            log_warn "Go $current_version is too old (need >= $required_version), upgrading..."
        fi
    fi
    log_info "Installing Go via snap..."
    snap install go --classic || { log_error "Failed to install Go via snap"; }
    log_info "Go installed: $(go version)"
}

install_cuda() {
    if command -v nvcc &>/dev/null; then
        log_warn "CUDA already installed, skipping..."
        log_info "CUDA version: $(nvcc --version | grep release | awk '{print $5}')"
        return
    fi
    log_info "Installing CUDA 11.4..."

    # Download and install CUDA keyring using modern method
    wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-keyring_1.0-1_all.deb -O /tmp/cuda-keyring.deb || { log_error "Failed to download CUDA keyring package"; }
    dpkg -i /tmp/cuda-keyring.deb || { log_error "Failed to install CUDA keyring"; }
    rm /tmp/cuda-keyring.deb

    # Download pin file
    wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin -O /tmp/cuda.pin || { log_error "Failed to download CUDA pin file"; }
    mv /tmp/cuda.pin /etc/apt/preferences.d/cuda-repository-pin-600

    # Update and install CUDA toolkit
    apt update || { log_error "Failed to update package lists"; }
    apt install -y cuda-toolkit-11-4 cuda-compiler-11-4 cuda-cudart-dev-11-4 libcublas-dev-11-4 || { log_error "Failed to install CUDA 11.4"; }

    log_info "CUDA installed: $(nvcc --version | grep release | awk '{print $5}')"
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
    install_cmake
    install_go
    install_cuda
    setup_environment
    build_ollama
    verify_build
    test_build
    show_bashrc_instructions
}

main
