# MemAgent 复现

NYU Shanghai DATS-SHU-200 Data Mining（Prof. Qiaoyu Tan）期末项目 HW3 的代码与结果仓库。

基线论文是 **MemAgent**（ICLR 2026 Oral，字节 Seed + 清华 AIR）：把长文档切成 5K token 的段，模型逐段阅读，同时覆盖式地更新一段 1K token 的记忆，最后只根据记忆作答；这个读写记忆的策略用强化学习训练。本仓库在一张 24G 显卡上，用作者 2025 年 6 月公开的 RL-MemoryAgent-7B 权重（对应 arXiv v1），复现论文主表在 RULER-HotpotQA 7K–56K 上的趋势，之后在此基础上做免训练的改进。

## 复现设计

| 组 | 模型 | 读法 | 长度 | 对照 |
| --- | --- | --- | --- | --- |
| A 方法 | RL-MemoryAgent-7B | 分段读 + 记忆（`--api recurrent`） | 7K / 14K / 28K / 56K | v1 表 2 |
| B 消融 | Qwen2.5-7B-Instruct 原版 | 同 A，但没做强化学习 | 7K–56K | v1 图 5 |
| C 对照 | Qwen2.5-7B-Instruct + YaRN 128K | 整篇直接读（`--api openai`） | 7K–28K | ICLR 表 1 |

每个长度 128 题。推理用单卡 `vllm serve`（vLLM 0.8.2，参数全默认），代替作者的 Ray Serve 多卡部署；评测代码、提示词、采样参数都用作者原版，不做任何修改。详细设置和理由见 [RUNBOOK.md](RUNBOOK.md) 和 [CLAUDE.md](CLAUDE.md) 第 4 节。

## 仓库结构

| 路径 | 内容 |
| --- | --- |
| `RUNBOOK.md` | 上机手册：第 0–6 步、结果对照表、常见问题、报告要写明的设置 |
| `CLAUDE.md` | 交接说明、已定设置、长期维护规则（第 12 节） |
| `run_all.sh` | 第 5–6 步一键脚本：A → C → B，补跑缺题，汇总、打包 |
| `requirements-lock.txt` | 锁定依赖（vLLM 0.8.2 发布当天的 140 个包，Linux x86_64 / Python 3.12） |
| `third_party/MemAgent` | 作者代码，git submodule，固定在 `ef4219b` |
| `results/` | 每次运行一个目录 `results/<日期>_<组>_<说明>/`：结果 jsonl、汇总表、manifest |
| `docs/AI_USAGE.md` | AI 使用记录（课程要求） |
| `CHANGELOG.md` | 版本记录 |

## 怎么复现

```bash
git clone --recursive https://github.com/Issac-Shi/memagent-reproduction.git
```

然后按 [RUNBOOK.md](RUNBOOK.md) 第 0–6 步在一张 24G 显卡（CUDA ≥ 12.4）上运行：装锁定依赖 → 下载代码、模型、数据 → 建 YaRN 128K 目录并统计长度 → A 组 7K 试跑 → `run_all.sh` 跑完三组并汇总。GPU 时间约 4.5 小时。

## 当前结果

复现尚未完成。结果出来后填在这里，单位是 sub_em 准确率（%）。

| 组 | 来源 | 7K | 14K | 28K | 56K |
| --- | --- | --- | --- | --- | --- |
| A RL-MemAgent-7B | v1 表 2 | 82.03 | 79.69 | 78.91 | 77.34 |
| A RL-MemAgent-7B | 我们 |  |  |  |  |
| C Qwen2.5-7B 直接读 | ICLR 表 1 | 52.34 | 57.03 | 51.56 | 44.53 |
| C Qwen2.5-7B 直接读 | 我们 |  |  |  | — |
| B Qwen2.5-7B 记忆流程、无强化学习 | v1 图 5 | 59.38 | 52.34 | 51.56 | 47.66 |
| B Qwen2.5-7B 记忆流程、无强化学习 | 我们 |  |  |  |  |

## 版本

| 版本 | 日期 | 内容 |
| --- | --- | --- |
| v0.1.0 | 2026-11-12 | 交接包、维护规则、仓库骨架 |

完整记录见 [CHANGELOG.md](CHANGELOG.md)。

## 许可

作者代码（`third_party/MemAgent`）遵循其原 Apache-2.0 许可。
