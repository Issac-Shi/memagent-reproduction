#!/usr/bin/env bash
# RUNBOOK 第 3 步前半：建 Qwen 128K 目录。权重用软链接，只有 config.json 是独立的一份（带 YaRN）；
# 原版目录里的 config.json 不动。
set -euo pipefail
export PATH=/root/miniconda3/bin:$PATH
M=/root/autodl-tmp/models
mkdir -p $M/Qwen2.5-7B-Instruct-128k
for f in $M/Qwen2.5-7B-Instruct/*; do ln -sfn "$f" $M/Qwen2.5-7B-Instruct-128k/; done
rm $M/Qwen2.5-7B-Instruct-128k/config.json      # 只删刚建的链接，原文件不动
python /root/autodl-tmp/scripts/step3_make_128k_config.py
ls -l $M/Qwen2.5-7B-Instruct-128k | head -20
du -sh $M/Qwen2.5-7B-Instruct-128k
