#!/usr/bin/env bash
# Wait until the vLLM server lists the served name at /v1/models.
# Usage: bash wait_ready.sh <served name> [max seconds, default 1800]
name=$1
max=${2:-1800}
for ((t = 0; t <= max; t += 10)); do
  if curl -s --noproxy '*' http://127.0.0.1:8000/v1/models | grep -qF "\"$name\""; then
    echo "[$(date '+%F %T')] Server ready: $name (waited ${t}s)"
    exit 0
  fi
  if ! pgrep -f "vllm serve" > /dev/null; then
    echo "[$(date '+%F %T')] vllm serve exited before becoming ready"
    exit 1
  fi
  sleep 10
done
echo "[$(date '+%F %T')] Not ready after ${max}s"
exit 1
