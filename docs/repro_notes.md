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

## 2026-11-12 02:26–05:51 — `run_all.sh`: all three groups finished on the first attempt

**Evidence**: `results/2026-11-12_ABC_run-all/logs/run_all.log` and the manifest; vLLM service logs `serve_{A,B,C}.log` in the Release bundle `memagent_results_1112.tgz`.

- Every result file reached 128/128 rows on the first attempt. There were no refill runs and no service restarts, and group C started normally.
- **Engine**: the engine lines for all three groups read `Initializing a V0 LLM engine (v0.8.2)`.

  | | A, B | C |
  | --- | --- | --- |
  | `max_seq_len` | 32768 | 42000 |
  | `chunked_prefill_enabled` | False | True |
  | GPU KV-cache blocks | 2,913 (46,608 tokens) | 6,339 (101,424 tokens) |

  vLLM reports "Maximum concurrency for 42000 tokens per request: 2.41x" for C.
- **Sampling**: all three service logs show that vLLM 0.8.2 applied the model's Hugging Face generation config by default (`--generation-config auto`): `repetition_penalty 1.05, top_k 20`. Temperature 0.7 and top_p 0.95 are set per request by the author's code. This is default vLLM behaviour and the same for all three groups; we changed no parameter.
- **Runtime compared with the runbook estimate**. The runbook estimated about 4.5 GPU-hours in total: A 1.5 h, C 0.5 h, B 1.5–2 h. Actual:

  | Segment | Hours |
  | --- | ---: |
  | A at 14K–56K | 1.95 (56K alone: 74.7 min) |
  | A 7K trial (earlier) | about 0.1 |
  | C | 0.28 |
  | B | 1.18 |
  | `run_all.sh` total | 3.41 |

  Wall time grows faster than the number of calls. From 28K to 56K, calls grow ×1.8 while time grows ×2.6 for A and ×2.1 for B. This fits the KV cache limiting concurrency on this card, but we did not investigate further. B was faster than A at every length (about half the time at 56K); we did not verify why. Use call counts (`docs/data_stats.md`), not wall time, to support the claim that compute grows linearly.
- **Effect on results**: none.

## 2026-11-12 05:52 — Results downloaded and verified; server shut down

- `scripts/server/make_export.py` built the three run directories under `results/` with manifests. The our-repo commits recorded are `104b795` for the trial, `6420c6e` for the boxed control and `6420c6e` for run_all; these are the commits the server-side scripts came from when each run started.
- We downloaded `export_results_1112.tgz` and `memagent_results_1112.tgz` (MD5 matches the server). `scripts/local/verify_results.py` passes for all 12 result files: 128 rows each, `_id` exactly 0–127, sha256 matches the manifest, and the rescored values match. The jsonl hashes inside the full bundle also match the manifests.
- The server was shut down with `/usr/bin/shutdown` at about 05:53 (CST). It stayed in GPU mode throughout. The data disk keeps all models, data, results and logs.
