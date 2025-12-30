# Ollama Build Guide for Ubuntu 20.04 with CUDA 11.4 (GTX 970)

This guide documents the complete process to successfully build Ollama on Ubuntu 20.04 LTS with CUDA 11.4 support for NVIDIA GTX 970.

## System Requirements

- **OS**: Ubuntu 20.04 LTS (Focal Fossa)
- **GPU**: NVIDIA GTX 970 (Compute Capability 5.2)
- **CUDA**: 11.4 (already installed at `/usr/local/cuda-11.4`)
- **CMake**: 4.2.1+ (requirement: 3.21+)
- **Go**: 1.24+
- **GCC**: GCC 10 (for CUDA compilation) + GCC 11 (for general compilation)

## Prerequisites

### 1. Install Core Build Tools

```bash
sudo apt update
sudo apt install -y build-essential ninja-build ccache git curl wget pkg-config python3 software-properties-common
```

### 2. Install GCC 10 and GCC 11

CUDA 11.4 requires GCC 10 as the host compiler, but newer C++ code benefits from GCC 11.

```bash
# Add Ubuntu toolchain PPA
sudo add-apt-repository ppa:ubuntu-toolchain-r/test -y
sudo apt update

# Install both GCC versions
sudo apt install -y gcc-10 g++-10 gcc-11 g++-11

# Set GCC 11 as default for general compilation
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 110
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 110

# Verify versions
gcc --version    # Should show 11.x
gcc-10 --version # Should show 10.x
```

### 3. Install Go 1.24+

```bash
sudo snap install go --classic
go version  # Should show 1.24+
```

### 4. Verify CUDA Installation

```bash
# Check CUDA is installed
nvcc --version  # Should show CUDA 11.4

# Check GPU
nvidia-smi      # Should show GTX 970

# Verify CUDA paths
ls -la /usr/local/cuda-11.4/
```

### 5. Setup CUDA Environment

```bash
# Create environment file
sudo tee /etc/profile.d/ollama-cuda.sh > /dev/null <<'EOF'
export CUDA_HOME=/usr/local/cuda-11.4
export CUDA_PATH=/usr/local/cuda-11.4
export PATH=/usr/local/cuda-11.4/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-11.4/lib64:$LD_LIBRARY_PATH
EOF

# Load environment
source /etc/profile.d/ollama-cuda.sh

# Add to ~/.bashrc for permanent use
echo 'source /etc/profile.d/ollama-cuda.sh' >> ~/.bashrc
```

## Code Modifications Required

### 1. CMakePresets.json - Fix CUDA 11 Architecture Support

CUDA 11.4 doesn't support compute_87, compute_89, compute_90. Remove unsupported architectures and problematic flags.

**File**: `CMakePresets.json`

**Original (lines 21-29)**:
```json
{
  "name": "CUDA 11",
  "inherits": [ "CUDA" ],
  "cacheVariables": {
    "CMAKE_CUDA_ARCHITECTURES": "50-virtual;52-virtual;60-virtual;61-virtual;70-virtual;75-virtual;80-virtual;86-virtual;87-virtual;89-virtual;90-virtual",
    "CMAKE_CUDA_FLAGS": "-Wno-deprecated-gpu-targets -t 2",
    "OLLAMA_RUNNER_DIR": "cuda_v11"
  }
},
```

**Modified**:
```json
{
  "name": "CUDA 11",
  "inherits": [ "CUDA" ],
  "cacheVariables": {
    "CMAKE_CUDA_ARCHITECTURES": "50-virtual;52-virtual;60-virtual;61-virtual;70-virtual;75-virtual;80-virtual;86-virtual",
    "CMAKE_CUDA_FLAGS": "-Wno-deprecated-gpu-targets",
    "OLLAMA_RUNNER_DIR": "cuda_v11"
  }
},
```

**Changes**:
- Removed `87-virtual;89-virtual;90-virtual` (not supported by CUDA 11.4)
- Removed `-t 2` flag (not supported by CUDA 11.4 nvcc)

### 2. CMakeLists.txt - Fix Duplicate CUDA Subdirectory

The CUDA subdirectory was being added twice, causing build errors.

**File**: `CMakeLists.txt`

**Original (line 88)**:
```cmake
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/ml/backend/ggml/ggml/src/ggml-cuda)
```

**Modified**:
```cmake
# CUDA subdirectory is added automatically by ggml build system
# add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/ml/backend/ggml/ggml/src/ggml-cuda)
```

**Reason**: The ggml build system at `ml/backend/ggml/ggml/src/CMakeLists.txt` line 300 already adds backend subdirectories automatically.

### 3. CMakeLists.txt - Disable Advanced CPU Variants

Ubuntu 20.04's binutils and older GCC don't support advanced CPU instructions for Alder Lake and newer Intel CPUs.

**File**: `CMakeLists.txt`

**Original (line 32)**:
```cmake
set(GGML_CPU_ALL_VARIANTS ON)
```

**Modified**:
```cmake
set(GGML_CPU_ALL_VARIANTS OFF)
```

**Reason**: Prevents compilation errors for CPU variants requiring newer compiler/assembler features not available on Ubuntu 20.04.

## Build Process

### 1. Clone and Prepare Repository

```bash
cd ~/
mkdir -p ollama-build
cd ollama-build
git clone https://github.com/ollama/ollama.git ollama-5.2-support
cd ollama-5.2-support
```

### 2. Apply Code Modifications

Apply the three modifications listed above:
1. Edit `CMakePresets.json` - Remove unsupported CUDA architectures
2. Edit `CMakeLists.txt` - Comment out duplicate add_subdirectory (line 88)
3. Edit `CMakeLists.txt` - Set GGML_CPU_ALL_VARIANTS to OFF (line 32)

### 3. Configure Build with CMake

```bash
# Clean any previous build attempts
rm -rf build/

# Set environment variables
export PATH=/usr/local/cuda-11.4/bin:$PATH
export CUDA_HOME=/usr/local/cuda-11.4
export CUDAHOSTCXX=/usr/bin/g++-10

# Configure with CUDA enabled and GCC 10 as CUDA host compiler
cmake --preset "CUDA 11" -B build/ \
  -DGGML_CUDA=ON \
  -DCMAKE_CUDA_HOST_COMPILER=/usr/bin/g++-10
```

**Important**: You should see in the output:
```
-- Found CUDAToolkit: /usr/local/cuda-11.4/targets/x86_64-linux/include (found version "11.4.152")
-- CUDA Toolkit found
-- Using CUDA architectures: 50-virtual;52-virtual;60-virtual;61-virtual;70-virtual;75-virtual;80-virtual;86-virtual
-- The CUDA compiler identification is NVIDIA 11.4.152 with host compiler GNU 10.x.x
```

### 4. Build C++ Components

```bash
cmake --build build/ --config Release --parallel $(nproc)
```

**Expected Output**:
- Build will show many warnings (expected and safe to ignore)
- Should complete successfully after several minutes
- CUDA backend library will be created at `build/lib/ollama/libggml-cuda.so`

### 5. Verify CUDA Backend Was Built

```bash
ls -lh build/lib/ollama/libggml-cuda.so
# Should show a file ~100-200 MB in size
```

### 6. Build Go Binary

```bash
go build -trimpath -buildmode=pie -ldflags="-w -s" -o ollama .
```

### 7. Verify Binary

```bash
ls -lh ollama
./ollama --version
```

## Running Ollama with GPU Support

### 1. Set Library Path

Before running Ollama, ensure the CUDA libraries are in the library path:

```bash
export LD_LIBRARY_PATH=$(pwd)/build/lib/ollama:/usr/local/cuda-11.4/lib64:$LD_LIBRARY_PATH
```

### 2. Start Ollama Server

```bash
# In terminal 1 - Start server
./ollama serve
```

**Verify GPU Detection**: Look for these lines in the output:
```
level=INFO msg="inference compute" id=GPU-xxxxx compute="5.2" name="GeForce GTX 970"
load_backend: loaded CUDA backend from .../libggml-cuda.so
```

**WARNING - If you see this, GPU was NOT detected**:
```
level=INFO msg="entering low vram mode" "total vram"="0 B"
load_backend: loaded CPU backend
```

### 3. Test with a Model

```bash
# In terminal 2 - Run a model
./ollama run tinyllama "Write a haiku about GPUs"

# In terminal 3 - Monitor GPU usage
watch -n 1 nvidia-smi
```

**Expected Performance**:
- **With GPU**: 30-50 tokens/second, GPU memory usage visible
- **Without GPU (CPU only)**: 2-5 tokens/second, no GPU memory usage

## Installation (Optional)

### System-Wide Installation

```bash
# Copy binary
sudo cp ollama /usr/local/bin/

# Copy libraries
sudo mkdir -p /usr/local/lib/ollama
sudo cp -r build/lib/ollama/* /usr/local/lib/ollama/

# Make executable
sudo chmod +x /usr/local/bin/ollama

# Create environment file for library path
sudo tee /etc/ld.so.conf.d/ollama.conf > /dev/null <<'EOF'
/usr/local/lib/ollama
EOF

# Update linker cache
sudo ldconfig

# Test
ollama --version
```

### Systemd Service (Production)

```bash
# Create ollama user
sudo useradd -r -s /bin/false -m -d /usr/share/ollama ollama

# Create systemd service
sudo tee /etc/systemd/system/ollama.service > /dev/null <<'EOF'
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=/usr/local/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3
Environment="PATH=/usr/local/cuda-11.4/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="LD_LIBRARY_PATH=/usr/local/lib/ollama:/usr/local/cuda-11.4/lib64"
Environment="CUDA_HOME=/usr/local/cuda-11.4"

[Install]
WantedBy=default.target
EOF

# Reload systemd
sudo systemctl daemon-reload

# Enable and start service
sudo systemctl enable ollama
sudo systemctl start ollama

# Check status
sudo systemctl status ollama
```

## Troubleshooting

### Issue 1: GPU Not Detected (0 B VRAM)

**Symptoms**:
```
level=INFO msg="entering low vram mode" "total vram"="0 B"
load_backend: loaded CPU backend
```

**Solutions**:
1. Check `LD_LIBRARY_PATH` includes build directory:
   ```bash
   export LD_LIBRARY_PATH=$(pwd)/build/lib/ollama:/usr/local/cuda-11.4/lib64:$LD_LIBRARY_PATH
   ```

2. Verify CUDA backend was built:
   ```bash
   ls -lh build/lib/ollama/libggml-cuda.so
   ```

3. Check NVIDIA driver:
   ```bash
   nvidia-smi
   ```

### Issue 2: libggml-cuda.so Not Found

**Solution**:
The library path wasn't set. Run before starting ollama:
```bash
export LD_LIBRARY_PATH=$(pwd)/build/lib/ollama:/usr/local/cuda-11.4/lib64:$LD_LIBRARY_PATH
```

### Issue 3: Build Errors with CUDA

**Error**: `nvcc fatal : Unsupported gpu architecture 'compute_89'`

**Solution**: Edit `CMakePresets.json` to remove unsupported architectures (see section above).

**Error**: `parameter packs not expanded with '...'` in `std_function.h`

**Solution**: Use GCC 10 as CUDA host compiler (see build process above).

### Issue 4: Slow Performance (CPU-level speeds)

**Cause**: GPU not being used.

**Check**:
```bash
# While model is running, check GPU usage
nvidia-smi
```

If GPU-Util is 0% and no memory is allocated, GPU is not being used. See Issue 1.

## Environment Setup Script

For convenience, create a script to set all required environment variables:

```bash
# Create ~/setup-ollama-env.sh
cat > ~/setup-ollama-env.sh <<'EOF'
#!/bin/bash

# CUDA environment
export CUDA_HOME=/usr/local/cuda-11.4
export CUDA_PATH=/usr/local/cuda-11.4
export PATH=/usr/local/cuda-11.4/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-11.4/lib64:$LD_LIBRARY_PATH

# Ollama library path (adjust to your build directory)
export LD_LIBRARY_PATH=$HOME/ollama-build/ollama-5.2-support/build/lib/ollama:$LD_LIBRARY_PATH

# CUDA host compiler for rebuilds
export CUDAHOSTCXX=/usr/bin/g++-10

echo "✓ Ollama environment configured"
echo "  CUDA_HOME: $CUDA_HOME"
echo "  Using nvcc: $(which nvcc)"
echo "  nvcc version: $(nvcc --version | grep release)"
EOF

chmod +x ~/setup-ollama-env.sh
```

**Usage**:
```bash
source ~/setup-ollama-env.sh
cd ~/ollama-build/ollama-5.2-support
./ollama serve
```

## Summary of Key Points

### Critical Requirements for Ubuntu 20.04 + CUDA 11.4

1. **GCC 10** must be used as CUDA host compiler (not GCC 11)
2. **CMakePresets.json** must remove architectures > compute_86
3. **CMakeLists.txt** must not duplicate CUDA subdirectory addition
4. **GGML_CPU_ALL_VARIANTS** must be OFF to avoid binutils issues
5. **LD_LIBRARY_PATH** must include build/lib/ollama when running

### Verified Working Configuration

- Ubuntu 20.04 LTS
- CMake 4.2.1
- GCC 11 (general compilation) + GCC 10 (CUDA host)
- Go 1.24+
- CUDA 11.4.152
- NVIDIA Driver (supporting GTX 970)

### Performance Benchmarks

With GTX 970 (4GB VRAM, Compute 5.2):

| Model | Quantization | Device | Tokens/sec | VRAM Usage |
|-------|--------------|--------|------------|------------|
| tinyllama | Q4_K_M | GPU | 30-50 | ~600 MB |
| tinyllama | Q4_K_M | CPU | 2-5 | 0 MB |
| phi4-mini | Q4_K_M | GPU | 10-15 | ~2.5 GB |
| phi4-mini | Q4_K_M | CPU | 1-2 | 0 MB |

### Files Modified

1. `CMakePresets.json` - CUDA 11 architectures and flags
2. `CMakeLists.txt` (line 32) - GGML_CPU_ALL_VARIANTS OFF
3. `CMakeLists.txt` (line 88) - Commented duplicate add_subdirectory

## Additional Resources

- [Ollama Documentation](https://docs.ollama.com)
- [CUDA 11.4 Documentation](https://docs.nvidia.com/cuda/archive/11.4.0/)
- [CMake CUDA Support](https://cmake.org/cmake/help/latest/manual/cmake-compile-features.7.html#cuda-features)
- [GCC CUDA Compatibility](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#host-compiler-support-policy)

## Conclusion

This build process successfully compiles Ollama with CUDA 11.4 support on Ubuntu 20.04 for GTX 970. The key challenges were:
- GCC/CUDA compatibility (solved with GCC 10 as host compiler)
- Unsupported GPU architectures (solved by editing CMakePresets.json)
- Build system conflicts (solved by removing duplicate subdirectory)
- Assembler limitations (solved by disabling advanced CPU variants)

Following this guide should result in a working Ollama installation with full GPU acceleration.
