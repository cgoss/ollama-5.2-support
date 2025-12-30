# Ollama GPU Detection Testing Guide

This guide helps diagnose why Ollama is not detecting or using the GPU.

## Current Problem

From the `ollama serve` output, we see:
```
level=INFO source=routes.go:1649 msg="entering low vram mode" "total vram"="0 B"
load_backend: loaded CPU backend from /home/devuser/ollama-build/ollama-5.2-support/build/lib/ollama/libggml-cpu.so
msg="model weights" device=CPU
```

This indicates:
- GPU is NOT detected (total vram = 0 B)
- Only CPU backend is loaded
- Model is running on CPU (very slow performance)

## Diagnostic Steps

### Step 1: Verify CUDA Installation

```bash
# Check NVIDIA driver
nvidia-smi

# Check CUDA compiler
nvcc --version

# Check CUDA environment variables
echo $CUDA_HOME
echo $LD_LIBRARY_PATH
echo $PATH
```

**Expected Output:**
- `nvidia-smi` should show GTX 970 with ~4GB VRAM
- `nvcc --version` should show CUDA 11.4
- `CUDA_HOME` should be `/usr/local/cuda-11.4`
- `LD_LIBRARY_PATH` should include `/usr/local/cuda-11.4/lib64`
- `PATH` should include `/usr/local/cuda-11.4/bin`

**If environment variables are missing:**
```bash
source /etc/profile.d/ollama-cuda.sh
# Or manually set them:
export CUDA_HOME=/usr/local/cuda-11.4
export PATH=/usr/local/cuda-11.4/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-11.4/lib64:$LD_LIBRARY_PATH
```

### Step 2: Check if CUDA Backend Was Built

```bash
# Navigate to ollama directory
cd ~/ollama-build/ollama-5.2-support

# Check for CUDA library
ls -lh build/lib/ollama/libggml-cuda.so

# List all built libraries
ls -lh build/lib/ollama/
```

**Expected Output:**
- `libggml-cuda.so` should exist (file size ~100MB+)
- Should see `libggml-base.so`, `libggml-cpu.so`, and various CPU variant libraries

**If libggml-cuda.so is MISSING:**

The CUDA backend was not built. This is the root cause. Proceed to Step 5 (Rebuild).

### Step 3: Verify Library Path for Ollama

Even if CUDA backend was built, Ollama needs to find it:

```bash
# Add build libraries to LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/home/devuser/ollama-build/ollama-5.2-support/build/lib/ollama:/usr/local/cuda-11.4/lib64:$LD_LIBRARY_PATH

# Verify the path
echo $LD_LIBRARY_PATH

# Check if libraries can be found
ldd ./ollama | grep cuda
```

**Expected Output:**
- `LD_LIBRARY_PATH` should include the build/lib/ollama directory
- `ldd` should show CUDA libraries being found

### Step 4: Test GPU Detection

```bash
# Stop any running ollama server
pkill ollama

# Set environment variables
export CUDA_HOME=/usr/local/cuda-11.4
export PATH=/usr/local/cuda-11.4/bin:$PATH
export LD_LIBRARY_PATH=/home/devuser/ollama-build/ollama-5.2-support/build/lib/ollama:/usr/local/cuda-11.4/lib64:$LD_LIBRARY_PATH

# Enable debug output
export OLLAMA_DEBUG=1

# Start ollama server
./ollama serve
```

**What to Look For in Output:**

**GOOD (GPU Detected):**
```
level=INFO source=types.go:60 msg="inference compute" id=GPU-xxxxx compute="5.2" name="GeForce GTX 970" total="3.9 GiB"
load_backend: loaded CUDA backend from .../libggml-cuda.so
msg="model weights" device=GPU
```

**BAD (GPU NOT Detected):**
```
level=INFO source=routes.go:1649 msg="entering low vram mode" "total vram"="0 B"
load_backend: loaded CPU backend from .../libggml-cpu.so
msg="model weights" device=CPU
```

### Step 5: Rebuild with CUDA Explicitly Enabled

If CUDA backend is missing, rebuild:

```bash
# Stop ollama server
pkill ollama

# Navigate to build directory
cd ~/ollama-build/ollama-5.2-support

# Clean build
rm -rf build/

# Set CUDA environment
export CUDA_PATH=/usr/local/cuda-11.4
export CUDA_HOME=/usr/local/cuda-11.4
export PATH=/usr/local/cuda-11.4/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda-11.4/lib64:$LD_LIBRARY_PATH

# Configure with CUDA explicitly enabled
cmake --preset "CUDA 11" -B build/ -DGGML_CUDA=ON

# Check CMake output for CUDA detection
# You should see messages like:
# -- Found CUDAToolkit
# -- CUDA architectures: 50-virtual;52-virtual;...

# Build
cmake --build build/ --config Release --parallel $(nproc)

# Check if CUDA backend was built
ls -lh build/lib/ollama/libggml-cuda.so

# If exists, rebuild Go binary
go build -trimpath -buildmode=pie -ldflags="-w -s" -o ollama .
```

### Step 6: Verify CMake Detected CUDA

During the cmake configuration step, check the output:

```bash
cmake --preset "CUDA 11" -B build/ -DGGML_CUDA=ON 2>&1 | tee cmake_output.txt

# Search for CUDA-related messages
grep -i cuda cmake_output.txt
```

**Expected Output:**
```
-- Found CUDAToolkit: /usr/local/cuda-11.4 (found version "11.4")
-- CUDA architectures: 50-virtual;52-virtual;60-virtual;...
-- GGML CUDA: ON
```

**If NOT Found:**
```
-- Could NOT find CUDAToolkit
```

This means CMake cannot find CUDA. Check:
1. Is CUDA installed? (`nvcc --version`)
2. Is `CUDA_PATH` set correctly?
3. Is CMake version >= 3.21? (`cmake --version`)

### Step 7: Test with a Model

Once GPU is detected, test performance:

```bash
# In one terminal, watch GPU usage
watch -n 1 nvidia-smi

# In another terminal, run a model
export LD_LIBRARY_PATH=/home/devuser/ollama-build/ollama-5.2-support/build/lib/ollama:/usr/local/cuda-11.4/lib64:$LD_LIBRARY_PATH
./ollama run tinyllama "Write a haiku about GPUs"
```

**Expected Performance:**
- **With GPU**: 30-50 tokens/second, GPU memory usage visible in `nvidia-smi`
- **Without GPU (CPU)**: 2-5 tokens/second, no GPU memory usage

## Common Issues and Solutions

### Issue 1: "libggml-cuda.so: cannot open shared object file"

**Solution:**
```bash
export LD_LIBRARY_PATH=/home/devuser/ollama-build/ollama-5.2-support/build/lib/ollama:$LD_LIBRARY_PATH
```

### Issue 2: "total vram = 0 B"

**Causes:**
1. CUDA backend not built (`libggml-cuda.so` missing)
2. CUDA libraries not in `LD_LIBRARY_PATH`
3. NVIDIA driver not loaded

**Solutions:**
1. Rebuild with `-DGGML_CUDA=ON`
2. Set `LD_LIBRARY_PATH` correctly
3. Check `nvidia-smi` works

### Issue 3: CUDA backend built but not loaded

**Check:**
```bash
# See what libraries ollama can find
LD_LIBRARY_PATH=/path/to/build/lib/ollama ldd ./ollama | grep ggml

# Should show:
libggml-cuda.so => /path/to/build/lib/ollama/libggml-cuda.so
```

**Solution:**
Ensure `LD_LIBRARY_PATH` includes build directory when running ollama.

### Issue 4: CMake cannot find CUDA

**Solution:**
```bash
# Set CUDA paths explicitly
export CUDA_PATH=/usr/local/cuda-11.4
export CUDAToolkit_ROOT=/usr/local/cuda-11.4

# Reconfigure
cmake --preset "CUDA 11" -B build/ -DGGML_CUDA=ON
```

## Environment Setup Script

Create a script to set all required variables:

```bash
# Create ~/setup-ollama-env.sh
cat > ~/setup-ollama-env.sh <<'EOF'
#!/bin/bash
export CUDA_HOME=/usr/local/cuda-11.4
export CUDA_PATH=/usr/local/cuda-11.4
export PATH=/usr/local/cuda-11.4/bin:$PATH
export LD_LIBRARY_PATH=/home/devuser/ollama-build/ollama-5.2-support/build/lib/ollama:/usr/local/cuda-11.4/lib64:$LD_LIBRARY_PATH
export OLLAMA_DEBUG=1
echo "Ollama environment configured"
echo "CUDA_HOME: $CUDA_HOME"
echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
EOF

# Make executable
chmod +x ~/setup-ollama-env.sh

# Use it
source ~/setup-ollama-env.sh
```

## Quick Test Checklist

Run these commands in order:

```bash
# 1. CUDA installed?
nvcc --version

# 2. GPU visible?
nvidia-smi

# 3. CUDA backend built?
ls -lh ~/ollama-build/ollama-5.2-support/build/lib/ollama/libggml-cuda.so

# 4. Set environment
source ~/setup-ollama-env.sh

# 5. Test ollama
cd ~/ollama-build/ollama-5.2-support
./ollama serve
```

Watch the startup logs. Look for:
- ✅ GOOD: `loaded CUDA backend` and `device=GPU`
- ❌ BAD: `loaded CPU backend` and `device=CPU`

## Performance Benchmarks

### Expected Speeds (GTX 970, 4GB VRAM)

| Model | Device | Tokens/sec |
|-------|--------|------------|
| tinyllama | CPU | 2-5 |
| tinyllama | GPU | 30-50 |
| phi4-mini:q4_K_M | CPU | 1-2 |
| phi4-mini:q4_K_M | GPU | 10-15 |

If you're getting CPU-level performance, the GPU is not being used.

## Next Steps After GPU Detection

Once GPU is detected and working:

1. **Install system-wide:**
   ```bash
   sudo cp ollama /usr/local/bin/
   sudo mkdir -p /usr/local/lib/ollama
   sudo cp -r build/lib/ollama/* /usr/local/lib/ollama/
   ```

2. **Set up systemd service** with proper environment variables

3. **Test different models** suitable for 4GB VRAM

4. **Optimize settings** with `OLLAMA_NUM_GPU` for your use case
