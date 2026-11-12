#!/usr/bin/env bash
# Step 4: group A at 7K. Check the GPU -> start the group A server -> run 7K -> check the result.
# Run in the background on the server:
#   nohup bash /root/autodl-tmp/scripts/step4_trial.sh > /root/autodl-tmp/logs/step4_trial.log 2>&1 &
# The server keeps running afterwards for the \boxed{} answer-format check (step4_boxed.sh).
set -u
S=/root/autodl-tmp/scripts
M=/root/autodl-tmp/models
EVAL=/root/autodl-tmp/MemAgent/taskutils/memory_eval
export PATH=/root/miniconda3/bin:$PATH
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
mkdir -p /root/autodl-tmp/logs

echo "[$(date '+%F %T')] ==== 4.1 check GPU ===="
nvidia-smi --query-gpu=name,memory.total,memory.used,driver_version --format=csv
python -c "import torch; print(torch.cuda.is_available(), torch.cuda.get_device_name(0))"

echo "[$(date '+%F %T')] ==== 4.2 start group A server ===="
bash $S/serve.sh A $M/RL-MemoryAgent-7B BytedTsinghua-SIA/RL-MemoryAgent-7B
bash $S/wait_ready.sh BytedTsinghua-SIA/RL-MemoryAgent-7B 1800 || { tail -n 40 /root/autodl-tmp/logs/serve_A.log; exit 1; }
curl -s --noproxy '*' http://127.0.0.1:8000/v1/models; echo
echo '-- engine'
grep -i -m3 "v1\|engine" /root/autodl-tmp/logs/serve_A.log

echo "[$(date '+%F %T')] ==== 4.3 run 7K ===="
bash $S/run_eval.sh A_50 BytedTsinghua-SIA/RL-MemoryAgent-7B $M/RL-MemoryAgent-7B recurrent 50 MemoryAgent-7B-5k-1k-infty
tail -n 8 /root/autodl-tmp/logs/A_50.log

echo "[$(date '+%F %T')] ==== 4.4 check ===="
cd $EVAL
wc -l results/ruler_hqa_50/MemoryAgent-7B-5k-1k-infty.jsonl
python $S/summarize.py MemoryAgent-7B-5k-1k-infty
echo "[$(date '+%F %T')] step4 trial done"
