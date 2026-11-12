# AI Usage

| Tool | Used for |
| --- | --- |
| Claude (claude.ai, Anthropic) | Choosing the project; reading and auditing the MemAgent paper and code; planning the reproduction; drafting the improvement ideas |
| Claude Code (Anthropic; model Claude Opus 5.5) | Running the reproduction on the GPU server over SSH; writing the scripts in this repository; checking and summarizing the results; maintaining this repository |

## Main questions and tasks

**Choosing the project (Claude).** We considered three candidate papers (AlphaAgent, Aider Polyglot, MemAgent) and chose MemAgent.

**Auditing MemAgent (Claude).** We asked:

- how arXiv v1 and the ICLR version differ, and which version the released weights correspond to;
- where each reference number comes from (v1 Table 2, v1 Fig. 5, ICLR Table 1, an independent re-run);
- which parts of the evaluation code affect the scores: input truncation, failed requests being dropped from the denominator, and the scoring rule.

**Planning the reproduction (Claude).** Claude helped design:

- the groups and length range;
- a step-by-step run plan with a pass check for each step;
- the `run_all.sh` script;
- a locked dependency file (`requirements-lock.txt`) for vLLM 0.8.2.

**Running the reproduction (Claude Code).** Claude Code:

- installed the environment, downloaded the code, models and data, and ran all evaluations on an AutoDL RTX 4090 over SSH;
- diagnosed from the server log why the vLLM V1 engine failed to start, and switched to the V0 engine;
- exported the results with manifests and re-checked every result file locally.

All accuracy numbers in this repository are computed by scripts from the result files produced on the server.

**Improvement ideas (Claude).** Training-free improvements to MemAgent for Part 4 of the report.
