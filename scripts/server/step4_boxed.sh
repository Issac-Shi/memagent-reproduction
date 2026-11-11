#!/usr/bin/env bash
# RUNBOOK 4.5：\boxed{} 格式对照。A 组服务保持运行，同一条命令把 --api recurrent 换成 recurrent-boxed，
# --save_file 改成 MemoryAgent-7B-boxed。在服务器后台运行：
#   nohup bash /root/autodl-tmp/scripts/step4_boxed.sh > /root/autodl-tmp/logs/step4_boxed.log 2>&1 &
set -u
S=/root/autodl-tmp/scripts
M=/root/autodl-tmp/models
export PATH=/root/miniconda3/bin:$PATH
bash $S/wait_ready.sh BytedTsinghua-SIA/RL-MemoryAgent-7B 60 || exit 1
bash $S/run_eval.sh Aboxed_50 BytedTsinghua-SIA/RL-MemoryAgent-7B $M/RL-MemoryAgent-7B recurrent-boxed 50 MemoryAgent-7B-boxed
tail -n 8 /root/autodl-tmp/logs/Aboxed_50.log
cd /root/autodl-tmp/MemAgent/taskutils/memory_eval
python $S/summarize.py ruler_hqa_50/MemoryAgent-7B
echo "[$(date '+%F %T')] step4 boxed done"
