#!/usr/bin/env bash
# 跑一组的一个长度（RUNBOOK 4.3 / 5.1 / 5.3 / 5.4 的评测命令，参数照抄）。
# 用法：bash run_eval.sh <日志名> <服务名> <tokenizer 目录> <api> <长度> <save_file>
#   例：bash run_eval.sh A_50 BytedTsinghua-SIA/RL-MemoryAgent-7B /root/autodl-tmp/models/RL-MemoryAgent-7B recurrent 50 MemoryAgent-7B-5k-1k-infty
# 结果文件已有的题会跳过，不足 128 行时重跑同一条命令只补缺的题（不加 --force）。
# 日志追加写到 /root/autodl-tmp/logs/<日志名>.log，含 time 的耗时。
set -u
export PATH=/root/miniconda3/bin:$PATH
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
logname=$1 model=$2 tok=$3 api=$4 L=$5 save=$6
LOG=/root/autodl-tmp/logs/$logname.log
cd /root/autodl-tmp/MemAgent/taskutils/memory_eval || exit 1     # 必须在这个目录下运行
export DATAROOT=/root/autodl-tmp/hotpotqa SERVE_HOST=127.0.0.1 SERVE_PORT=8000
unset MAX_INPUT_LEN MAX_OUTPUT_LEN RECURRENT_CHUNK_SIZE RECURRENT_MAX_NEW RECURRENT_MAX_CONTEXT_LEN
case $api in
  recurrent*) export RECURRENT_CHUNK_SIZE=5000 RECURRENT_MAX_NEW=1024 RECURRENT_MAX_CONTEXT_LEN=100000000000 ;;
esac
{
  echo "[$(date '+%F %T')] 开始 $logname：--model $model --api $api --length $L --save_file $save"
  env | grep -E '^(DATAROOT|SERVE_HOST|SERVE_PORT|RECURRENT_|MAX_INPUT_LEN|MAX_OUTPUT_LEN|VLLM_USE_V1)=' | sort
} >> "$LOG"
( time python ruler_hqa.py --model "$model" --tokenizer "$tok" --api "$api" --length "$L" \
    --save_dir "results/ruler_hqa_$L" --save_file "$save" --n_proc 256 ) >> "$LOG" 2>&1
echo "[$(date '+%F %T')] 结束 $logname：$(wc -l < "results/ruler_hqa_$L/$save.jsonl") 行" >> "$LOG"
