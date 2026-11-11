# Test Data Length Statistics (RUNBOOK Step 3)

Data: the `eval_{50,100,200,400,800}.json` files from [BytedTsinghua-SIA/hotpotqa](https://huggingface.co/datasets/BytedTsinghua-SIA/hotpotqa), 128 questions each. Lengths are measured with the Qwen2.5-7B-Instruct tokenizer on the `context` field (the document only; question and template are not included). Calls per question = ceil(document tokens / 5000) + 1: one memory update per 5K-token chunk, plus one final answer. Computed on 2026-11-12 with `scripts/server/step3_token_stats.py`.

| Length | Data file | Min | Mean | Max | Calls per question (mean) | Calls total (128 questions) |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 7K | eval_50 | 5,821 | 6,999 | 8,420 | 3.0 | ≈ 384 |
| 14K | eval_100 | 12,351 | 14,029 | 15,644 | 4.1 | ≈ 525 |
| 28K | eval_200 | 25,546 | 28,069 | 30,832 | 7.1 | ≈ 909 |
| 56K | eval_400 | 51,695 | 56,152 | 60,824 | 12.8 | ≈ 1,638 |
| 112K | eval_800 | 108,084 | 112,227 | 117,305 | 23.9 | ≈ 3,059 |

- Calls per question grow linearly with document length, roughly one call per 5K tokens. This supports the paper's claim that compute grows linearly with length; the measured runtime for each length is in each run's manifest.
- `--max-model-len` for group C = MAX200 + 1,000 (question and template) + 10,000 (reserved for output), rounded up to the next thousand = 30,832 + 11,000 → **42000**. The safe-version run of group C only goes up to 28K (eval_200), so every request fits.
