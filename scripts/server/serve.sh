#!/usr/bin/env bash
# 后台启动一个 vLLM 服务（RUNBOOK 4.2 / 5.3 / 5.4 的启动命令）：参数全用默认，只有 C 组加 --max-model-len。
# 用法：bash serve.sh <组名> <模型目录> <服务名> [额外 vllm 参数...]
# 日志写到 /root/autodl-tmp/logs/serve_<组名>.log。服务名必须和评测的 --model 一字不差。
set -u
export PATH=/root/miniconda3/bin:$PATH
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY   # 本机请求不走代理
tag=$1 dir=$2 name=$3
shift 3
cd /root/autodl-tmp
mkdir -p logs
setsid nohup vllm serve "$dir" --served-model-name "$name" --port 8000 "$@" \
  > "logs/serve_$tag.log" 2>&1 < /dev/null &
echo "[$(date '+%F %T')] 已启动 $tag 组服务 $name（PID $!）$*"
