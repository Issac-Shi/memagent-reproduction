#!/bin/bash
# Usage: wait_runall.sh <C|B|done> [max minutes, default 60]
# Wait until run_all.log reaches a stage, then print the end of the log.
#   C    : group C server ready or given up (or everything finished)
#   B    : group B server ready or given up (or everything finished); group C is done by then
#   done : everything finished
# Exit code: 0 if the stage was reached, 1 on timeout.
LOG=/root/autodl-tmp/logs/run_all.log
case "$1" in
  C|B)  PAT="Group $1 server ready|Group $1 server failed|Group $1 server not ready|Group $1 server could not start|All done" ;;
  done) PAT='All done' ;;
  *)    echo "Usage: $0 <C|B|done> [max minutes]"; exit 2 ;;
esac
MAX=${2:-60}
for ((i = 0; i < MAX * 3; i++)); do
  grep -qE "$PAT" "$LOG" && break
  sleep 20
done
date
tail -n 12 "$LOG"
if [ "$1" != done ] && [ -f "/root/autodl-tmp/logs/serve_$1.log" ]; then
  echo "-- serve_$1: engine and KV cache"
  grep -E 'Initializing a V|chunked|# cuda blocks|Maximum concurrency|max_model_len' "/root/autodl-tmp/logs/serve_$1.log" | head -n 6 | cut -c1-300
fi
grep -qE "$PAT" "$LOG"
