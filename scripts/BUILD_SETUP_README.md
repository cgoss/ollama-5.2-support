# Ubuntu 22 Build Environment Setup

This directory contains scripts and documentation for setting up a complete build environment for Ollama on Ubuntu 22 with CUDA 11.4 support.

## Quick Start

### Automated Setup (Recommended)

```bash
cd /path/to/ollama
sudo bash scripts/setup_ubuntu22.sh
```

After completion, add the following to your `~/.bashrc` to make CUDA available permanently:

```bash
source /etc/profile.d/ollama-cuda.sh
```

Then reload your shell:

```bash
source ~/.bashrc
```

## Manual Setup

### 1. Install Build Tools

```bash
sudo apt update
sudo apt install -y build-essential cmake ninja-build ccache git curl wget pkg-config python3
```

### 2. Install Go (Snap)

```bash
sudo snap install go --classic
echo 'export PATH=$PATH:/snap/go/current/bin' >> ~/.bashrc
source ~/.bashrc
```

### 3. Install CUDA 11.4

Check if CUDA is installed:

```bash
nvcc --version
```

If not installed:

```bash
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
sudo mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600
sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/3bf863cc.pub
sudo add-apt-repository "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/ /"
sudo apt update
sudo apt install -y cuda-toolkit-11-4 cuda-compiler-11-4 cuda-cudart-dev-11-4 libcublas-dev-11-4
```

### 4. Setup Environment Variables

```bash
source /etc/profile.d/ollama-cuda.sh
# Or add to ~/.bashrc:
echo 'source /etc/profile.d/ollama-cuda.sh' >> ~/.bashrc
source ~/.bashrc
```

### 5. Build Ollama

```bash
cd /path/to/ollama
rm -rf build/
cmake --preset "CUDA 11" -B build/
cmake --build build/ --config Release --parallel $(nproc)
go build -trimpath -buildmode=pie -ldflags="-w -s" -o ollama .
```

### 6. Test GTX 970 Support

```bash
bash scripts/test_gtx970.sh
```

Or manually:

```bash
./ollama run tinyllama "GTX 970 test" --verbose
nvidia-smi
```

## Environment Variables Reference

| Variable | Purpose | Default |
|----------|-----------|---------|
| `PATH` | Include CUDA binaries | `/usr/local/cuda-11.4/bin:$PATH` |
| `LD_LIBRARY_PATH` | CUDA library paths | `/usr/local/cuda-11.4/lib64:$LD_LIBRARY_PATH` |
| `CUDA_HOME` | CUDA installation root | `/usr/local/cuda-11.4` |

## Troubleshooting

### CUDA not found after installation

```bash
source /etc/profile.d/ollama-cuda.sh
echo $PATH | grep cuda
echo $LD_LIBRARY_PATH | grep cuda
```

### Go not found after snap install

```bash
export PATH=$PATH:/snap/go/current/bin
go version
```

### GTX 970 not detected

```bash
nvidia-smi --query-gpu=name,compute_cap --format=csv
# Should show: GeForce GTX 970, 5.2
```

### Build fails with CUDA errors

```bash
rm -rf build/
go clean -cache
cmake --preset "CUDA 11" -B build/
cmake --build build/ --config Release --parallel $(nproc)
```

### tinyllama run fails

```bash
ollama pull tinyllama
ollama run tinyllama --verbose
```

## GTX 970 Specific Notes

### Hardware Specifications

- **Compute Capability**: 5.2 (Maxwell architecture)
- **VRAM**: 4GB (3.5GB usable due to architecture)
- **Driver Required**: 470+ (you have CUDA 11.4)

### Compute Capability 5.2 Support

GTX 970's compute capability 5.2 is now supported through the updated `CMakePresets.json`:

- CUDA 11 preset includes `52-virtual` architecture
- Compiled PTX code is JIT-compiled at runtime for GTX 970

### Recommended Models for 4GB VRAM

| Model | Quantization | Size | Fit on 4GB | Notes |
|--------|-------------|-------|-------------|-------|
| tinyllama | Q4_K_M | ~0.5GB | ✅ Yes | Fast, good for testing |
| phi4-mini | Q4_K_M | ~2.4GB | ✅ Yes | Good quality |
| llama3.2:1b | Q4_K_M | ~0.7GB | ✅ Yes | Fast, good for testing |
| llama3.2:3b | Q4_K_M | ~1.9GB | ✅ Yes | Balanced |

### Recommended Quantizations

For 4GB VRAM, use:

- **Q4_K_M**: Good balance of speed/quality
- **Q5_K_S**: Better quality, slightly slower

Avoid:

- **Q8_0**: Too large for 4GB VRAM
- Unquantized models: Far exceed 4GB capacity

### GPU Layer Offloading

Control GPU usage with `OLLAMA_NUM_GPU`:

```bash
OLLAMA_NUM_GPU=30 ollama run tinyllama  # Load 30 layers on GPU, rest on CPU
OLLAMA_NUM_GPU=-1 ollama run tinyllama   # Auto-detect optimal (default)
```

### Performance Expectations

With GTX 970 (Compute 5.2, 4GB VRAM):

- **tinyllama**: ~30-50 tokens/second
- **phi4-mini (Q4_K_M)**: ~10-15 tokens/second
- **CPU-only**: ~2-5 tokens/second

GPU offloading provides significant speedup even with 4GB VRAM.

## Script Reference

### setup_ubuntu22.sh

Main automated setup script that:

1. Updates system packages
2. Installs core build tools (cmake, gcc, git, etc.)
3. Installs Go via snap
4. Checks for existing CUDA 11.4 installation (does not force reinstall)
5. Installs CUDA 11.4 if not found
6. Sets up environment variables in `/etc/profile.d/ollama-cuda.sh`
7. Builds Ollama with CUDA 11 preset
8. Runs test with tinyllama
9. Displays bashrc setup instructions

### test_gtx970.sh

GTX 970 compatibility verification script that:

1. Checks GPU detection via nvidia-smi
2. Verifies CUDA toolkit installation
3. Checks compute capability (expects 5.2)
4. Verifies Ollama binary
5. Ensures tinyllama is available
6. Runs tinyllama inference test
7. Reports GPU memory usage
8. Provides final status report

The test script can be run from anywhere and automatically detects the Ollama binary location.

## Directory Structure

```
ollama/
├── scripts/
│   ├── setup_ubuntu22.sh          # Main automated setup script
│   ├── test_gtx970.sh             # GTX 970 verification script
│   └── BUILD_SETUP_README.md       # This documentation file
├── CMakePresets.json               # CUDA 11 preset includes 52-virtual for GTX 970
└── AGENTS.md                      # Agent guidelines with low-VRAM backlog
```

## Additional Resources

- [Ollama Documentation](https://docs.ollama.com)
- [NVIDIA CUDA Documentation](https://docs.nvidia.com/cuda/)
- [GGML CUDA Backend](https://github.com/ggerganov/ggml/blob/master/docs/gpu.md)

## Support

If you encounter issues:

1. Check NVIDIA driver: `nvidia-smi`
2. Check CUDA toolkit: `nvcc --version`
3. Check environment: `echo $PATH` and `echo $LD_LIBRARY_PATH`
4. Review build output for specific error messages
5. Run `bash scripts/test_gtx970.sh` for diagnostic information
