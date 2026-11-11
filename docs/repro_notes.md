# Reproduction Log: Deviations from the Runbook and Incidents

This log records, in time order, where the actual run differed from RUNBOOK.md and why. The report's Part 3 cites it. Each entry gives evidence, the cause, how it was handled, and its effect on the results.

## 2026-11-12 02:08 — V1 engine cannot start with default parameters on a 24G card; switched to V0

**Evidence**: `logs/serve_A_v1_failed.log` (included in the results bundle). vLLM 0.8.2 defaults to the V1 engine. Starting group A with all-default parameters (RUNBOOK 4.2) fails during KV cache allocation:

```
Initializing a V1 LLM engine (v0.8.2) ... max_seq_len=32768
Model loading took 14.2487 GB
ValueError: To serve at least one request with the models's max seq len (32768),
(1.75 GB KV cache is needed, which is larger than the available KV cache memory (0.85 GB).
```

**Cause**: The RTX 4090 has 24,564 MiB. With the default `gpu_memory_utilization=0.9`, about 21.6 GiB is usable. The weights take 14.25 GiB, and the V1 profiling pass takes up most of what is left, so too little remains for the KV cache.

**Handling**: Followed RUNBOOK 4.5 (engine comparison) and restarted with the V0 engine (`VLLM_USE_V1=0`). **All other parameters stay at their defaults**, and the evaluation code, sampling, and variables are unchanged. `run_all.sh` sets `VLLM_USE_V1=0` explicitly so all three groups use the same engine.

V0 memory profile (`logs/serve_A.log`):

```
model weights take 14.25GiB; non_torch_memory takes 0.08GiB;
PyTorch activation peak memory takes 4.35GiB; the rest of the memory reserved for KV Cache is 2.49GiB.
# cuda blocks: 2913   (= 46,608 tokens)
```

**Effects**:
- The report records the engine as **V0**. With default parameters on this card, V1 never started, so there is no V1-vs-V0 comparison.
- At max-model-len 32768, V0 does not enable chunked prefill by default and profiles a full 32,768-token batch, so activations take a large share of memory. The KV cache fits about 7–8 concurrent recurrent-memory requests, so runs take longer than the runbook estimate. This changes only speed, not results.
- Group C (`--max-model-len 42000` > 32K): V0 enables chunked prefill by default there, so the KV cache is larger than in groups A and B.
