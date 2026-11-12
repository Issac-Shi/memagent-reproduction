# MemAgent Reproduction

Final project for DATS-SHU-200 Data Mining (NYU Shanghai, Prof. Qiaoyu Tan).

We reproduce the main long-context QA result of **MemAgent** ([arXiv v1](https://arxiv.org/abs/2507.02259v1), ICLR 2026 Oral) with the released [RL-MemoryAgent-7B](https://huggingface.co/BytedTsinghua-SIA/RL-MemoryAgent-7B) weights. MemAgent reads a long document in 5K-token chunks. After each chunk it overwrites a fixed 1K-token memory, and it answers from the memory alone. The memory-update policy is trained with reinforcement learning (RL).

## Setup

| Group | Model | Reading |
| --- | --- | --- |
| A | RL-MemoryAgent-7B | MemAgent: chunked reading with memory |
| B | Qwen2.5-7B-Instruct | Same memory workflow, without RL |
| C | Qwen2.5-7B-Instruct + YaRN (128K) | Whole document in one prompt |

- **Benchmark**: RULER-HotpotQA at 7K, 14K, 28K and 56K tokens (C: up to 28K). Every length uses the same 128 questions; only the amount of distractor text changes.
- **Code**: the authors' evaluation code, unmodified ([`third_party/MemAgent`](third_party/MemAgent), commit `ef4219b`).
- **Inference**: vLLM 0.8.2 on one RTX 4090 (24 GB) with default parameters; group C adds `--max-model-len 42000`. We use the V0 engine (`VLLM_USE_V1=0`) because the default V1 engine does not fit in 24 GB ([details](docs/repro_notes.md)).
- **Metric**: sub_em, the accuracy metric in the authors' code.

## Results

Accuracy (%) on 128 questions per cell.

| Group | Source | 7K | 14K | 28K | 56K |
| --- | --- | ---: | ---: | ---: | ---: |
| A: RL-MemoryAgent-7B | Paper (v1, Table 2) | 82.03 | 79.69 | 78.91 | 77.34 |
| | **Ours** | **78.91** | **79.69** | **75.78** | **78.91** |
| B: Qwen2.5-7B, memory without RL | Paper (v1, Fig. 5)\* | 59.38 | 52.34 | 51.56 | 47.66 |
| | **Ours** | **57.81** | **53.91** | **53.12** | **50.00** |
| C: Qwen2.5-7B, full context | Paper (ICLR, Table 1) | 52.34 | 57.03 | 51.56 | 44.53 |
| | **Ours** | **53.12** | **54.69** | **48.44** | — |

\* Fig. 5 shows this curve without numbers. The values are read from the figure's vector graphics.

- **Every cell differs from the paper by at most 3.13 points.**
- **MemAgent does not degrade with length**: A scores 78.91 at both 7K and 56K, while B drops from 57.81 to 50.00.
- **RL-trained memory beats both baselines**: A is 25–27 points above C and 21–29 points above B.

Strict scoring, the answer-format check and per-question outputs are in [`results/`](results/README.md).

## Reproduce

```bash
git clone --recursive https://github.com/Issac-Shi/memagent-reproduction.git
```

The scripts assume an AutoDL GPU instance (Python 3.12, CUDA ≥ 12.4, 24 GB GPU) with the data disk at `/root/autodl-tmp`. Copy `requirements-lock.txt` and `run_all.sh` to `/root/autodl-tmp/`, and the contents of `scripts/server/` to `/root/autodl-tmp/scripts/`. Then run:

```bash
bash /root/autodl-tmp/scripts/step1_install.sh    # locked dependencies (vLLM 0.8.2)
bash /root/autodl-tmp/scripts/step2_download.sh   # authors' code at ef4219b, models, test data
bash /root/autodl-tmp/scripts/step3_make_128k.sh  # YaRN 128K config for group C
bash /root/autodl-tmp/scripts/step4_trial.sh      # group A at 7K
bash /root/autodl-tmp/run_all.sh                  # groups A → C → B at all lengths
```

`run_all.sh` writes the accuracy table to `/root/autodl-tmp/logs/summary.txt`.

## Repository

| Path | Contents |
| --- | --- |
| `results/` | One directory per run: per-question outputs, summary, manifest |
| `scripts/server/` | Scripts run on the GPU server |
| `scripts/local/verify_results.py` | Re-checks every result file against its manifest |
| `run_all.sh` | Runs groups A → C → B |
| `requirements-lock.txt` | Locked dependencies (Python 3.12, Linux x86_64) |
| `third_party/MemAgent` | Authors' code (git submodule, pinned at `ef4219b`) |
| `docs/` | [Reproduction notes](docs/repro_notes.md), [test-data statistics](docs/data_stats.md), [AI usage](docs/AI_USAGE.md) |

## Versions

| Version | Date | Changes |
| --- | --- | --- |
| v0.2.4 | 2026-11-12 | Changelog wording |
| v0.2.3 | 2026-11-12 | Local tool settings no longer tracked |
| v0.2.2 | 2026-11-12 | Whole repository in English |
| v0.2.1 | 2026-11-12 | README and results summary in English |
| v0.2.0 | 2026-11-12 | Baseline reproduction results |
| v0.1.0 | 2026-11-12 | Repository setup |

Details: [CHANGELOG.md](CHANGELOG.md).

## License

The authors' code in `third_party/MemAgent` is under its original Apache-2.0 license.
