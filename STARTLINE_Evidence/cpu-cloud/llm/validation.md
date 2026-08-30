# LLM Validation

| Check | Result |
|---|---|
| Model | Gemma 4 E2B Q4_0 GGUF |
| Runtime | llama.cpp server |
| CPU server health | PASS |
| OpenAI-compatible chat completion | PASS |
| Response validation | PASS |
| Performance scope | CPU-only prevalidation |

The model artifact was verified before server startup in the captured run. The public package does not publish the model file, host model path, raw response body, request identifiers, or `reasoning_content`.

See [`inference-summary.json`](./inference-summary.json) for the sanitized API result summary.
