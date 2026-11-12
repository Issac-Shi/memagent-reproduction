#!/usr/bin/env bash
# Step 3: build the Qwen 128K model directory for group C. Weights are symlinks; only config.json
# is a separate copy (with YaRN). The original model's config.json is not changed.
set -euo pipefail
export PATH=/root/miniconda3/bin:$PATH
M=/root/autodl-tmp/models
mkdir -p $M/Qwen2.5-7B-Instruct-128k
for f in $M/Qwen2.5-7B-Instruct/*; do ln -sfn "$f" $M/Qwen2.5-7B-Instruct-128k/; done
rm $M/Qwen2.5-7B-Instruct-128k/config.json      # removes only the new symlink, not the original file
python /root/autodl-tmp/scripts/step3_make_128k_config.py
ls -l $M/Qwen2.5-7B-Instruct-128k | head -20
du -sh $M/Qwen2.5-7B-Instruct-128k
