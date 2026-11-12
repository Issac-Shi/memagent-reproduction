# MemAgent Reproduction

Final project for DATS-SHU-200 Data Mining.

We reproduce the main long-context QA result of **MemAgent** ([arXiv v1](https://arxiv.org/abs/2507.02259v1), ICLR 2026 Oral) with the released [RL-MemoryAgent-7B](https://huggingface.co/BytedTsinghua-SIA/RL-MemoryAgent-7B) weights. MemAgent reads a long document in 5K-token chunks. After each chunk it overwrites a fixed 1K-token memory, and it answers from the memory alone. The memory-update policy is trained with reinforcement learning (RL).

## Setup

| Group | Model | How the model reads the document | Role |
| --- | --- | --- | --- |
| A | RL-MemoryAgent-7B | Chunk by chunk, 5K tokens at a time. After each chunk it rewrites a 1K-token memory; at the end it answers from the memory alone. | The method (MemAgent) |
| B | Qwen2.5-7B-Instruct, the model A was trained from | The same chunk-by-chunk memory procedure as A | Ablation: memory without RL training |
| C | Qwen2.5-7B-Instruct, context extended to 128K with YaRN | The whole document and the question in a single prompt; no memory | Baseline: standard long-context reading |

- **Benchmark**: RULER-HotpotQA. Each multi-hop question comes with a document in which the passages needed to answer it are mixed with distractor passages. The document is 7K, 14K, 28K or 56K tokens long (50, 100, 200 or 400 passages). Every length uses the same 128 questions.
- **Scope**: our compute is a single rented RTX 4090 (24 GB), so we run a reduced scope: A and B at 7K–56K, C at 7K–28K. The paper's longer settings (112K and above) are not run.
- **Code**: the authors' evaluation code, unmodified ([`third_party/MemAgent`](third_party/MemAgent), commit `ef4219b`).
- **Inference**: vLLM 0.8.2 with default parameters; group C adds `--max-model-len 42000`. We use the V0 engine (`VLLM_USE_V1=0`) because the default V1 engine does not fit in 24 GB ([details](docs/repro_notes.md)).
- **Metric**: sub_em, the accuracy metric in the authors' code. An answer counts as correct if, after normalization, it and the gold answer contain one another.

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

- **Ours vs. paper (A, B, C)**: every cell is within 3.13 points of the paper.
- **A across lengths**: MemAgent does not degrade as documents get longer: 78.91 at 7K and 78.91 at 56K. B, which uses the same memory without RL, drops from 57.81 to 50.00.
- **A vs. C**: reading with RL-trained memory beats reading the whole document at once by 25–27 points (7K–28K).
- **A vs. B**: RL training of the memory adds 21–29 points (7K–56K).

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
| **v0.2.5 (latest)** | **2026-11-12** | **Clearer setup, comparisons and notes** |
| v0.2.4 | 2026-11-12 | Changelog wording |
| v0.2.3 | 2026-11-12 | Local tool settings no longer tracked |
| v0.2.2 | 2026-11-12 | Whole repository in English |
| v0.2.1 | 2026-11-12 | README and results summary in English |
| v0.2.0 | 2026-11-12 | Baseline reproduction results |
| v0.1.0 | 2026-11-12 | Repository setup |

Details: [CHANGELOG.md](CHANGELOG.md).

## License

The authors' code in `third_party/MemAgent` is under its original Apache-2.0 license.
