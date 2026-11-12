# AI Usage

| Tool | Used for |
| --- | --- |
| Claude (claude.ai, Anthropic) | Understanding the MemAgent paper and code; planning the reproduction |
| Claude Code (Anthropic; model Claude Opus 5.5) | Running the experiments on the GPU server; writing the scripts in this repository; checking the results |

## Main uses

- **Understanding the paper and code**: which paper version the released weights correspond to, where the reference numbers come from, and how the evaluation code scores answers.
- **Planning**: choosing the groups and document lengths, and writing a step-by-step run plan with a check for each step.
- **Running**: setting up the environment, running the evaluations over SSH, and diagnosing problems such as the vLLM engine failing to start.
- **Checking**: verifying that every result file is complete and recomputing all scores from the model outputs.

All accuracy numbers in this repository are computed by scripts from the result files produced on the server. All code and data in this repository have been manually reviewed and verified by the author.
