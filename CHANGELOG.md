# Changelog

每次合并进 main 记一条，对应一个带说明的 tag：交 HW3 之前用 v0.x.y，交作业时打 v1.0.0。tag 推送后不改、不删。

## v0.1.0 — 2026-11-12

第一个版本：交接包入库，仓库骨架搭好，尚未上机。

- 导入交接包：`CLAUDE.md`、`RUNBOOK.md`（claude.ai 上 Claude Doc rev 25 的导出）、`run_all.sh`、`requirements-lock.txt`，内容不变。
- `CLAUDE.md` 新增第 12 节"长期维护规则"（自主执行、GitHub 与版本管理）。
- 作者代码以 git submodule 引入：`third_party/MemAgent`，固定在 `ef4219b`（2026-05-12）。
- `.gitignore`：不收模型权重、eval 数据、打包文件、vLLM 大日志和任何凭据；`.gitattributes`：统一 LF。
- 新增 `README.md`、`CHANGELOG.md`、`docs/AI_USAGE.md`。
- `.claude/settings.json`：关闭 Claude Code 在提交和 PR 上的自动署名。
