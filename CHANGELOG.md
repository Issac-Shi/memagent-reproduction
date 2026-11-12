# Changelog

One entry per merge into `main`, each with an annotated tag.

## v0.2.5 — 2026-11-12

- `README.md`: the setup table explains how each group reads the document and its role; the scope and its reason are stated; each finding names the groups it compares; the latest version is highlighted.
- `results/README.md`: the comparison with the paper is shown as tables.
- `docs/repro_notes.md`: sampling settings shown as a table.
- `docs/AI_USAGE.md`: shortened to a general summary.
- Results are unchanged.

## v0.2.4 — 2026-11-12

- Wording fixes in `CHANGELOG.md` and `.gitignore`.

## v0.2.3 — 2026-11-12

- Local tool settings are no longer tracked.

## v0.2.2 — 2026-11-12

- The whole repository is now in English:
  - script comments and printed messages;
  - the descriptive fields of each `manifest.json` (results unchanged);
  - `docs/`, `.gitignore`, `.gitattributes`.
- Script code is unchanged, except that `make_export.py` reads both the old Chinese and the new English log messages.
- `docs/repro_notes.md` lists only the differences from the authors' setup. `docs/AI_USAGE.md` is in English.
- The internal run book and project notes are no longer tracked.

## v0.2.1 — 2026-11-12

- `README.md` and `results/README.md` rewritten in English. Each group's comparison now shows only the paper row it is compared against.
- `CHANGELOG.md` translated into English.

## v0.2.0 — 2026-11-12

Baseline reproduction on one RTX 4090: groups A and B at 7K–56K, group C at 7K–28K.

- Accuracy (sub_em, %):

  | Group | 7K | 14K | 28K | 56K |
  | --- | ---: | ---: | ---: | ---: |
  | A: RL-MemoryAgent-7B | 78.91 | 79.69 | 75.78 | 78.91 |
  | B: Qwen2.5-7B, memory without RL | 57.81 | 53.91 | 53.12 | 50.00 |
  | C: Qwen2.5-7B, full context | 53.12 | 54.69 | 48.44 | — |

- `results/`: three runs (A at 7K, the `\boxed{}` answer-format check, and A/B/C at all lengths), each with per-question outputs, a summary and a manifest.
- `run_all.sh`: sets `C_MAXLEN=42000` and `AUTO_SHUTDOWN=0`, and uses the vLLM V0 engine (`VLLM_USE_V1=0`), because the default V1 engine does not fit in 24 GB.
- `scripts/server/`: scripts run on the GPU server. `scripts/local/verify_results.py`: re-checks every result file against its manifest.
- `docs/data_stats.md` (test-data lengths, calls per question) and `docs/repro_notes.md` (deviations from the plan).
- Release asset `memagent_results_1112.tgz`: all results and logs from the server.

## v0.1.0 — 2026-11-12

Repository setup: project documents, the authors' code as a git submodule pinned at `ef4219b`, `.gitignore` (no model weights, test data, archives or credentials) and `.gitattributes` (LF line endings).
