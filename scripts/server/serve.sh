#!/usr/bin/env bash
# Start a vLLM server in the background with default parameters (group C adds --max-model-len).
# Usage: bash serve.sh <group> <model dir> <served name> [extra vllm args...]
# Log: /root/autodl-tmp/logs/serve_<group>.log. The served name must match the evaluation's --model exactly.
set -u
export PATH=/root/miniconda3/bin:$PATH
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY   # local requests must not go through a proxy
tag=$1 dir=$2 name=$3
shift 3
cd /root/autodl-tmp
mkdir -p logs
setsid nohup vllm serve "$dir" --served-model-name "$name" --port 8000 "$@" \
  > "logs/serve_$tag.log" 2>&1 < /dev/null &
echo "[$(date '+%F %T')] Started group $tag server $name (PID $!) $*"
