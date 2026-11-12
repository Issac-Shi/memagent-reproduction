# Results

Each run has its own directory, `<date>_<group>_<description>/`, containing:

- `ruler_hqa_<length>/<method>.jsonl`: the authors' evaluation output, one line per question;
- `summary.txt`: accuracy for each result file;
- `manifest.json`: commits, software versions, GPU, commands, environment variables, and the scores and SHA-256 of each result file;
- `logs/`: evaluation logs.

To check every result file against its manifest (128 questions, SHA-256, recomputed scores):

```bash
python -I scripts/local/verify_results.py
```

## Accuracy (%)

- **sub_em** (main metric): the authors' metric. A prediction is correct if, after normalization, the prediction and the gold answer contain one another.
- **strict** (paper, Appendix A.4): a prediction is correct only if it contains the gold answer.

| Group | Source | 7K | 14K | 28K | 56K |
| --- | --- | ---: | ---: | ---: | ---: |
| A: RL-MemoryAgent-7B | Paper (v1, Table 2) | 82.03 | 79.69 | 78.91 | 77.34 |
| | Ours, sub_em | **78.91** | **79.69** | **75.78** | **78.91** |
| | Ours, strict | 72.66 | 71.09 | 68.75 | 70.31 |
| B: Qwen2.5-7B, memory without RL | Paper (v1, Fig. 5)\* | 59.38 | 52.34 | 51.56 | 47.66 |
| | Ours, sub_em | **57.81** | **53.91** | **53.12** | **50.00** |
| | Ours, strict | 51.56 | 47.66 | 48.44 | 45.31 |
| C: Qwen2.5-7B, full context | Paper (ICLR, Table 1) | 52.34 | 57.03 | 51.56 | 44.53 |
| | Ours, sub_em | **53.12** | **54.69** | **48.44** | — |
| | Ours, strict | 47.66 | 46.09 | 41.41 | — |

\* Fig. 5 shows this curve without numbers. The values are read from the figure's vector graphics.

Each cell has 128 questions. C was run up to 28K. Questions where the code could not extract an answer count as wrong: A has 0 at every length, B has 0 / 2 / 0 / 0, and C has 1 / 3 / 1.

## Comparison with the paper

- **A matches the paper and does not degrade with length.** The differences from the paper are −3.12 / 0.00 / −3.13 / +1.57, and A scores 78.91 at both 7K and 56K.
- **A beats direct full-context reading (C).** A − C is 25.79 / 25.00 / 27.34 at 7K–28K (paper: 29.69 / 22.66 / 27.35).
- **RL matters.** A − B is 21.10 / 25.78 / 22.66 / 28.91 (paper: 22.65 / 27.35 / 27.35 / 29.68). B declines with length, from 57.81 to 50.00 (paper: 59.38 to 47.66).
- **The gaps hold under strict scoring**: A − C is 25.00 / 25.00 / 27.34, and A − B is 21.10 / 23.43 / 20.31 / 25.00.

## Answer format (A, 7K)

The paper's training template asks for the answer in `\boxed{}` (Table 5). The evaluation code instead expects "the answer is" (Appendix A.4). We ran both formats at 7K:

| Answer format | sub_em | strict |
| --- | ---: | ---: |
| "the answer is" (`--api recurrent`, used for all results above) | 78.91 | 72.66 |
| `\boxed{}` (`--api recurrent-boxed`) | 78.91 | 67.97 |
