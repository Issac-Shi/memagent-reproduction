# Changelog

每次合并进 main 记一条，对应一个带说明的 tag：交 HW3 之前用 v0.x.y，交作业时打 v1.0.0。tag 推送后不改、不删。

## v0.2.0 — 2026-11-12

基线复现完成（保险版范围），三条判断标准都满足。

- 结果（sub_em，每格 128 题）：
  - A RL-MemAgent-7B（7K–56K）：78.91 / 79.69 / 75.78 / 78.91
  - C Qwen2.5-7B 直接读（7K–28K）：53.12 / 54.69 / 48.44
  - B Qwen2.5-7B 记忆流程、无强化学习（7K–56K）：57.81 / 53.91 / 53.12 / 50.00
  - 7K 的 `\boxed{}` 对照：78.91
- `results/`：三次运行的目录（A 7K 试跑、`\boxed{}` 对照、`run_all` 三组），各带 jsonl、`summary.txt`、`manifest.json` 和评测日志。`results/README.md` 是汇总表，包括严格计分、抓不到答案的题数、逐条判断、耗时和花费。
- `RUNBOOK.md`：填了结果对照表“我们”的行，在“报告第三部分需要写明的设置”表里加了一列实际值。
- `run_all.sh`：`C_MAXLEN="42000"`，`AUTO_SHUTDOWN=0`，`VLLM_USE_V1=0`。V1 引擎用默认参数在 24G 卡上起不来，按 RUNBOOK 4.5 改用 V0，其余参数不变。
- `scripts/server/`：第 1–4 步的脚本、服务启动和等待脚本、汇总、环境采集、导出 manifest（`make_export.py`）、等待 `run_all` 各阶段（`wait_runall.sh`）。
- `scripts/local/verify_results.py`：在本地核对结果文件，检查行数、`_id`、sha256，并重新计分。
- `docs/`：新增 `data_stats.md`（各长度 token 数和每题调用次数）和 `repro_notes.md`（与手册的出入、事件记录）；更新 `AI_USAGE.md`。
- Release 附件 `memagent_results_1112.tgz`：服务器上全部结果和日志，包括 vLLM 服务日志。

## v0.1.0 — 2026-11-12

第一个版本：交接包入库，仓库骨架搭好，尚未上机。

- 导入交接包：`CLAUDE.md`、`RUNBOOK.md`（claude.ai 上 Claude Doc rev 25 的导出）、`run_all.sh`、`requirements-lock.txt`，内容不变。
- `CLAUDE.md` 新增第 12 节"长期维护规则"（自主执行、GitHub 与版本管理）。
- 作者代码以 git submodule 引入：`third_party/MemAgent`，固定在 `ef4219b`（2026-05-12）。
- `.gitignore`：不收模型权重、eval 数据、打包文件、vLLM 大日志和任何凭据；`.gitattributes`：统一 LF。
- 新增 `README.md`、`CHANGELOG.md`、`docs/AI_USAGE.md`。
- `.claude/settings.json`：关闭 Claude Code 在提交和 PR 上的自动署名。
