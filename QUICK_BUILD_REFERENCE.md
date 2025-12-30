# Quick Build Reference - Ubuntu 20.04 + CUDA 11.4

## Prerequisites Check

```bash
cmake --version          # Need 3.21+ (have 4.2.1 ✓)
go version               # Need 1.24+
nvcc --version           # Need CUDA 11.4
nvidia-smi               # Check GTX 970 visible
gcc-10 --version         # Need GCC 10 for CUDA
gcc --version            # Can have GCC 11 for general use
```

## One-Time Setup

```bash
# Install dependencies
sudo apt install -y gcc-10 g++-10 build-essential ninja-build ccache git curl wget

# Setup environment (add to ~/.bashrc)
source /etc/profile.d/ollama-cuda.sh
```

## Code Modifications (Already Done)

Three files were modified:

1. **CMakePresets.json** (line 25-26)
   - Remove: `87-virtual;89-virtual;90-virtual`
   - Remove: `-t 2` flag

2. **CMakeLists.txt** (line 88)
   - Comment out: `add_subdirectory(...ggml-cuda)`

3. **CMakeLists.txt** (line 32)
   - Change: `GGML_CPU_ALL_VARIANTS ON` → `OFF`

## Build Commands

```bash
cd ~/ollama-build/ollama-5.2-support

# Clean
rm -rf build/

# Configure
export PATH=/usr/local/cuda-11.4/bin:$PATH
export CUDA_HOME=/usr/local/cuda-11.4
export CUDAHOSTCXX=/usr/bin/g++-10

cmake --preset "CUDA 11" -B build/ \
  -DGGML_CUDA=ON \
  -DCMAKE_CUDA_HOST_COMPILER=/usr/bin/g++-10

# Build (warnings are normal)
cmake --build build/ --config Release --parallel $(nproc)

# Build Go binary
go build -trimpath -buildmode=pie -ldflags="-w -s" -o ollama .

# Verify CUDA backend
ls -lh build/lib/ollama/libggml-cuda.so
```

## Run Ollama

```bash
# Set library path
export LD_LIBRARY_PATH=$(pwd)/build/lib/ollama:/usr/local/cuda-11.4/lib64:$LD_LIBRARY_PATH

# Start server
./ollama serve

# Test (in another terminal)
./ollama run tinyllama "Hello GPU"

# Monitor GPU (in another terminal)
watch -n 1 nvidia-smi
```

## Verify GPU is Working

**✓ GOOD** - Look for in `ollama serve` output:
```
level=INFO msg="inference compute" name="GeForce GTX 970" compute="5.2"
load_backend: loaded CUDA backend from .../libggml-cuda.so
```

**✗ BAD** - If you see this, GPU NOT detected:
```
level=INFO msg="entering low vram mode" "total vram"="0 B"
load_backend: loaded CPU backend
```

**Fix**: Set `LD_LIBRARY_PATH` before running ollama (see Run section above)

## Performance Check

| Speed | Device |
|-------|--------|
| 30-50 tokens/sec | GPU (correct) ✓ |
| 2-5 tokens/sec | CPU (wrong) ✗ |

If getting CPU speeds, GPU is not being used.

## Environment Script

Create `~/setup-ollama.sh`:
```bash
#!/bin/bash
export CUDA_HOME=/usr/local/cuda-11.4
export PATH=/usr/local/cuda-11.4/bin:$PATH
export LD_LIBRARY_PATH=$HOME/ollama-build/ollama-5.2-support/build/lib/ollama:/usr/local/cuda-11.4/lib64:$LD_LIBRARY_PATH
export CUDAHOSTCXX=/usr/bin/g++-10
```

Use: `source ~/setup-ollama.sh`

## Rebuild After Code Changes

```bash
source ~/setup-ollama.sh
cd ~/ollama-build/ollama-5.2-support
rm -rf build/
cmake --preset "CUDA 11" -B build/ -DGGML_CUDA=ON -DCMAKE_CUDA_HOST_COMPILER=/usr/bin/g++-10
cmake --build build/ --config Release --parallel $(nproc)
go build -trimpath -buildmode=pie -ldflags="-w -s" -o ollama .
```

## Key Points

- **Always use GCC 10** for CUDA compilation (`-DCMAKE_CUDA_HOST_COMPILER=/usr/bin/g++-10`)
- **Always set LD_LIBRARY_PATH** before running ollama
- **Warnings during build are normal** - errors are not
- **Check GPU detection** in server logs on startup

For full details, see `BUILD_GUIDE_UBUNTU20.md`
