# AI 使用记录

课程要求在报告里写明用了哪些 AI、问了什么。本文件按时间记录，写报告时从这里整理。

## 用到的 AI

| 工具 | 用在哪里 |
| --- | --- |
| Claude（claude.ai，Project「Data Mining Final Project」里的一个长对话） | 选题、论文与代码审查、复现方案与上机手册、一键脚本、依赖锁定、改进方案 |
| Claude Code（Claude 桌面应用的 Code 标签页，模型 Claude Opus 5.5） | 通过 SSH 在 AutoDL 上执行复现、管理本仓库（提交、版本、文档）、整理结果 |

所有 AI 产出都经过人工确认；数字以服务器上实际跑出来的结果文件为准。

## 主要问题与产出

阶段 1、2 是按交接文档（`CLAUDE.md` 第 2、3 节）整理的主题；具体提问的原文以 claude.ai 上的原对话为准，写报告时从那里摘录。

### 阶段 1：选题与审查（claude.ai）

- 选题：候选有 AlphaAgent、Aider Polyglot 和 MemAgent，最后选定 MemAgent，前两个已放弃。
- 审查 MemAgent 的论文和代码：arXiv v1 与 ICLR 正式版的区别、各参考数字的出处（v1 表 2、ICLR 表 1、v1 图 5 的矢量图还原值、PI-Mem 的独立重跑）、评测代码里会影响结果的地方（截断上限、失败请求被踢出分母、计分方式）。结论写在 Project 文档 `claude/memagent-baseline-audit.md`。

### 阶段 2：复现方案（claude.ai，截至 2026-11-12）

- 写上机手册（本仓库 `RUNBOOK.md`）：保险版范围（A/B 到 56K，C 到 28K）、每一步的通过标准、结果对照表、常见问题。
- 写 `run_all.sh`（预检、按 A → C → B 换模型、补跑缺题、服务挂掉重启、汇总打包），在模拟环境里测试控制流程。
- 生成 `requirements-lock.txt`：把依赖锁在 vLLM 0.8.2 发布当天的版本，并在干净的 Python 3.12 环境里测试安装和导入。
- 改进方案（免训练的两个改进）：写在 claude.ai 的另一份 Claude Doc 里，报告第 4 部分用。

### 阶段 3：上机复现与仓库管理（Claude Code，2026-11-12 起）

- 交给 Claude Code 的任务：通读交接文档后，按手册在 AutoDL（RTX 4090）上自主完成第 1–6 步；遇到不达标、超预算、删数据、偏离已定设置时停下来问。
- 同时负责：建私有 GitHub 仓库、按分支 + tag 的规则提交、每次运行写 manifest、维护 README 和本文件。
