# Reproduction Notes

Where our setup differs from the authors', and why.

## Inference server

The authors serve models with Ray Serve on multiple GPUs. We run a single `vllm serve` (vLLM 0.8.2) on one RTX 4090 (24 GB) with default parameters. The evaluation code, prompts and sampling parameters are the authors', unmodified.

## vLLM V0 engine

vLLM 0.8.2 defaults to the V1 engine, which fails to start on a 24 GB GPU with default parameters ([log](../results/2026-11-12_A_trial-7k/logs/vllm_v1_startup_failure.log)):

```
Model loading took 14.2487 GB
ValueError: To serve at least one request with the models's max seq len (32768),
(1.75 GB KV cache is needed, which is larger than the available KV cache memory (0.85 GB).
```

All runs therefore use the V0 engine (`VLLM_USE_V1=0`). Every other parameter stays at its default. The engine changes scheduling and speed. The model, prompts and sampling parameters do not change.

## Sampling

The authors' code sets temperature 0.7 and top_p 0.95 in each request. By default, vLLM 0.8.2 also applies the model's generation config: `repetition_penalty 1.05` and `top_k 20` (confirmed in the server logs of all three groups).

## Group C context length

The paper configures the full-context baseline for 120K input and 10K output tokens (Table 6). A 24 GB GPU cannot hold that context, so we set `--max-model-len 42000`: the longest 28K document (30,832 tokens) plus 1,000 tokens for the question and template and 10,000 for the output, rounded up to the next 1,000. Every request fits. Above 32K tokens vLLM enables chunked prefill automatically.

## Scope

- Groups A and B run at 7K–56K, group C at 7K–28K.
- Nothing at 112K or above.
- No other RULER tasks, LongBench, or RL training.
