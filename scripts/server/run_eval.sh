#!/usr/bin/env bash
# Evaluate one group at one length with the authors' ruler_hqa.py.
# Usage: bash run_eval.sh <log name> <served name> <tokenizer dir> <api> <length> <save_file>
#   e.g. bash run_eval.sh A_50 BytedTsinghua-SIA/RL-MemoryAgent-7B /root/autodl-tmp/models/RL-MemoryAgent-7B recurrent 50 MemoryAgent-7B-5k-1k-infty
# Questions already in the result file are skipped, so re-running the same command fills in missing ones (no --force).
# Appends to /root/autodl-tmp/logs/<log name>.log, including the `time` output.
set -u
export PATH=/root/miniconda3/bin:$PATH
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
logname=$1 model=$2 tok=$3 api=$4 L=$5 save=$6
LOG=/root/autodl-tmp/logs/$logname.log
cd /root/autodl-tmp/MemAgent/taskutils/memory_eval || exit 1     # the evaluation must run from this directory
export DATAROOT=/root/autodl-tmp/hotpotqa SERVE_HOST=127.0.0.1 SERVE_PORT=8000
unset MAX_INPUT_LEN MAX_OUTPUT_LEN RECURRENT_CHUNK_SIZE RECURRENT_MAX_NEW RECURRENT_MAX_CONTEXT_LEN
case $api in
  recurrent*) export RECURRENT_CHUNK_SIZE=5000 RECURRENT_MAX_NEW=1024 RECURRENT_MAX_CONTEXT_LEN=100000000000 ;;
esac
{
  echo "[$(date '+%F %T')] start $logname: --model $model --api $api --length $L --save_file $save"
  env | grep -E '^(DATAROOT|SERVE_HOST|SERVE_PORT|RECURRENT_|MAX_INPUT_LEN|MAX_OUTPUT_LEN|VLLM_USE_V1)=' | sort
} >> "$LOG"
( time python ruler_hqa.py --model "$model" --tokenizer "$tok" --api "$api" --length "$L" \
    --save_dir "results/ruler_hqa_$L" --save_file "$save" --n_proc 256 ) >> "$LOG" 2>&1
echo "[$(date '+%F %T')] end $logname: $(wc -l < "results/ruler_hqa_$L/$save.jsonl") results" >> "$LOG"
