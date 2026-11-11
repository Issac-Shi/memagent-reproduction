#!/usr/bin/env bash
# 等 vLLM 服务就绪：循环查 /v1/models，返回里出现服务名就算好（代替手册里的 tail -f）。
# 用法：bash wait_ready.sh <服务名> [最长等待秒数，默认 1800]
name=$1
max=${2:-1800}
for ((t = 0; t <= max; t += 10)); do
  if curl -s --noproxy '*' http://127.0.0.1:8000/v1/models | grep -qF "\"$name\""; then
    echo "[$(date '+%F %T')] 服务就绪：$name（等了 ${t}s）"
    exit 0
  fi
  if ! pgrep -f "vllm serve" > /dev/null; then
    echo "[$(date '+%F %T')] vllm serve 进程已退出，没有就绪"
    exit 1
  fi
  sleep 10
done
echo "[$(date '+%F %T')] 等了 ${max}s 仍未就绪"
exit 1
