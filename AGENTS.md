# Agent Guidelines for Ollama

## Build/Test Commands
- Test single test: `go test -run TestName ./path/to/package`
- Lint: `golangci-lint run` (uses .golangci.yaml config)
- Format: `gofmt -w .` or `gofumpt -w .`

## Code Style
- **Imports**: stdlib first, third-party below, no blank line between groups
- **Formatting**: Use gofmt/gofumpt, tab indentation, no trailing whitespace
- **Types**: Use Go conventions (PascalCase exported, camelCase private)
- **Errors**: Use explicit error types (StatusError, AuthorizationError), wrap with fmt.Errorf("%w", err)
- **Testing**: Use table-driven tests with t.Run(), httptest for HTTP clients
- **Concurrency**: Prefer golang.org/x/sync/errgroup, sync.Map from types/syncmap
- **No comments** in code unless explicitly requested
- Error messages: lowercase, descriptive, context-appropriate

## Low-VRAM/Older GPU Optimizations Backlog

For GPUs with <6GB VRAM or older compute capabilities, consider implementing:
- Smart CPU-GPU layer offloading for 4GB GPUs based on model size
- Graceful flash attention degradation for unsupported compute capabilities
- Auto-recommend quantization levels (Q4_K_M, Q5_K_S) based on available VRAM
- VRAM pooling/tiered caching for sub-6GB GPUs
- Architecture-aware tuning (batch sizes, context length) per compute tier
- Async transfer optimization for PCIe 3.0 GPUs
- Model size warnings when exceeding GPU VRAM + CPU offload capacity
