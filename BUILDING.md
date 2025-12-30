# Building Ollama

This document provides platform-specific build instructions for Ollama.

## Platform-Specific Guides

### Ubuntu 20.04 with CUDA 11.4

**For Ubuntu 20.04 LTS (Focal Fossa) with NVIDIA GTX 970 and CUDA 11.4:**

See [BUILD_GUIDE_UBUNTU20.md](BUILD_GUIDE_UBUNTU20.md) for complete instructions.

**Quick Reference**: [QUICK_BUILD_REFERENCE.md](QUICK_BUILD_REFERENCE.md)

**Key Requirements**:
- GCC 10 (CUDA host compiler) + GCC 11 (general compilation)
- Code modifications required (see guide)
- Special CMake flags needed

**Quick Build**:
```bash
# Install prerequisites
sudo apt install -y gcc-10 g++-10 build-essential ninja-build ccache git

# Configure
cmake --preset "CUDA 11" -B build/ \
  -DGGML_CUDA=ON \
  -DCMAKE_CUDA_HOST_COMPILER=/usr/bin/g++-10

# Build
cmake --build build/ --config Release --parallel $(nproc)
go build -trimpath -buildmode=pie -ldflags="-w -s" -o ollama .
```

### Ubuntu 22.04

**For Ubuntu 22.04 LTS (Jammy Jellyfish):**

See [scripts/setup_ubuntu22.sh](scripts/setup_ubuntu22.sh) for automated setup.

**Manual Build**:
```bash
# Install dependencies
sudo apt update
sudo apt install -y build-essential cmake ninja-build ccache git curl wget pkg-config python3

# Install Go
sudo snap install go --classic

# Install CUDA (if needed)
# See: https://developer.nvidia.com/cuda-downloads

# Build
cmake --preset "CUDA 11" -B build/
cmake --build build/ --config Release --parallel $(nproc)
go build -trimpath -buildmode=pie -ldflags="-w -s" -o ollama .
```

## General Build Requirements

### Prerequisites

- **CMake**: >= 3.21
- **Go**: >= 1.24
- **C++ Compiler**: GCC 10+ or Clang
- **Build Tools**: ninja-build, ccache, git

### CUDA Support (Optional)

For NVIDIA GPU acceleration:
- **CUDA Toolkit**: 11.4+ or 12.x
- **NVIDIA Driver**: Latest recommended
- **Compute Capability**: >= 5.0 (Maxwell architecture and newer)

Supported GPUs include:
- GTX 900 series (Maxwell) - Compute 5.2
- GTX 10 series (Pascal) - Compute 6.1
- RTX 20 series (Turing) - Compute 7.5
- RTX 30 series (Ampere) - Compute 8.6
- RTX 40 series (Ada Lovelace) - Compute 8.9

## Build Presets

The project uses CMake presets defined in `CMakePresets.json`:

- **CPU**: CPU-only build (no GPU acceleration)
- **CUDA 11**: NVIDIA GPU support with CUDA 11.x
- **CUDA 12**: NVIDIA GPU support with CUDA 12.x
- **CUDA 13**: NVIDIA GPU support with CUDA 13.x
- **ROCm 6**: AMD GPU support with ROCm 6
- **Vulkan**: Vulkan GPU support (cross-platform)

**Usage**:
```bash
cmake --preset "PRESET_NAME" -B build/
```

## Common Build Options

### Enable CUDA
```bash
cmake --preset "CUDA 11" -B build/ -DGGML_CUDA=ON
```

### CPU-Only Build
```bash
cmake --preset "CPU" -B build/
```

### Debug Build
```bash
cmake --preset "Default" -B build/ -DCMAKE_BUILD_TYPE=Debug
```

### Custom CUDA Architectures
```bash
cmake --preset "CUDA 11" -B build/ \
  -DCMAKE_CUDA_ARCHITECTURES="52;60;70;75;80;86"
```

## Troubleshooting

### GPU Not Detected

If Ollama doesn't detect your GPU:

1. Verify CUDA backend was built:
   ```bash
   ls -lh build/lib/ollama/libggml-cuda.so
   ```

2. Set library path before running:
   ```bash
   export LD_LIBRARY_PATH=$(pwd)/build/lib/ollama:$LD_LIBRARY_PATH
   ```

3. Check GPU visibility:
   ```bash
   nvidia-smi
   ```

See [testing.md](testing.md) for detailed GPU troubleshooting.

### Build Errors

**CUDA Compilation Errors**:
- Ensure GCC version is compatible with your CUDA version
- CUDA 11.4: Use GCC 10 or earlier
- CUDA 12.x: Use GCC 11 or earlier

**CMake Errors**:
- Ensure CMake version is >= 3.21
- Clean build directory: `rm -rf build/`
- Check CMake output for missing dependencies

**Linker Errors**:
- Ensure all dependencies are installed
- Check `LD_LIBRARY_PATH` includes necessary directories

## Platform-Specific Notes

### Ubuntu 20.04
- **Required**: Code modifications for CUDA 11.4 compatibility
- **Required**: GCC 10 for CUDA host compilation
- See [BUILD_GUIDE_UBUNTU20.md](BUILD_GUIDE_UBUNTU20.md)

### Ubuntu 22.04
- Standard build process works
- No code modifications needed
- See [scripts/setup_ubuntu22.sh](scripts/setup_ubuntu22.sh)

### macOS
- See official [Ollama documentation](https://github.com/ollama/ollama)

### Windows
- See official [Ollama documentation](https://github.com/ollama/ollama)

## Additional Resources

- [Build Setup Scripts](scripts/) - Automated setup scripts
- [GPU Testing Guide](testing.md) - GPU detection troubleshooting
- [Official Documentation](https://docs.ollama.com) - General Ollama documentation

## Quick Start

For most users, the simplest approach is:

1. Choose your platform guide above
2. Follow the prerequisites section
3. Run the build commands
4. Verify GPU detection (if applicable)

For Ubuntu 20.04 users specifically, the [BUILD_GUIDE_UBUNTU20.md](BUILD_GUIDE_UBUNTU20.md) provides complete step-by-step instructions with all necessary code modifications documented.
