# Test Data Statistics

Test data: `eval_{50,100,200,400,800}.json` from [BytedTsinghua-SIA/hotpotqa](https://huggingface.co/datasets/BytedTsinghua-SIA/hotpotqa), 128 questions each.

- **Document length** is measured in Qwen2.5-7B-Instruct tokens on the `context` field only; the question and template are not counted.
- **Calls per question** = ⌈document tokens / 5000⌉ + 1: one memory update per 5K-token chunk, plus one final answer.
- Computed with [`scripts/server/step3_token_stats.py`](../scripts/server/step3_token_stats.py).

| Length | File | Min | Mean | Max | Calls per question (mean) | Calls (128 questions) |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 7K | eval_50 | 5,821 | 6,999 | 8,420 | 3.0 | ≈ 384 |
| 14K | eval_100 | 12,351 | 14,029 | 15,644 | 4.1 | ≈ 525 |
| 28K | eval_200 | 25,546 | 28,069 | 30,832 | 7.1 | ≈ 909 |
| 56K | eval_400 | 51,695 | 56,152 | 60,824 | 12.8 | ≈ 1,638 |
| 112K | eval_800 | 108,084 | 112,227 | 117,305 | 23.9 | ≈ 3,059 |

The number of calls grows linearly with document length, about one call per 5K tokens.
