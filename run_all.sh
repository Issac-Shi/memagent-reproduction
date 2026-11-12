#!/usr/bin/env bash
# MemAgent reproduction: run groups A -> C -> B in one go.
# Prerequisite: steps 1-4 are done and the group A 7K run has 128 results.
# Usage: bash /root/autodl-tmp/run_all.sh
#   Runs a pre-check in the foreground, then continues in the background.
#   Progress: /root/autodl-tmp/logs/run_all.log
set -u

# ================= Settings =================
C_MAXLEN="42000"        # group C --max-model-len: longest eval_200 document + 11000, rounded up to 1000 (30832 + 11000 -> 42000)
AUTO_SHUTDOWN=0         # 1 = shut the machine down when finished; 0 = leave it running

# Lengths to run (50/100/200/400/800 = 7K/14K/28K/56K/112K).
A_LENS="50 100 200 400"     # add 800 for 112K
B_LENS="50 100 200 400"     # add 800 for 112K
C_LENS="50 100 200"         # 400 needs a larger C_MAXLEN than a 24 GB GPU allows

# vLLM engine: with default parameters, the V1 engine does not fit on a 24 GB GPU (after profiling only
# 0.85 GiB is left for the KV cache; one 32768-token request needs 1.75 GiB), so we use the V0 engine.
# All other parameters stay at their defaults.
export VLLM_USE_V1=${VLLM_USE_V1:-0}

# ================= Paths and constants =================
ROOT=${ROOT:-/root/autodl-tmp}
M=$ROOT/models
EVAL_DIR=$ROOT/MemAgent/taskutils/memory_eval
LOG=$ROOT/logs
PORT=8000
MAX_TRIES=3             # if a length has fewer than 128 results, re-run it (without --force, so only missing questions run)
SHUTDOWN_CMD=${SHUTDOWN_CMD:-/usr/bin/shutdown}
SELF=$(readlink -f "$0")

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
unset RECURRENT_CHUNK_SIZE RECURRENT_MAX_NEW RECURRENT_MAX_CONTEXT_LEN MAX_INPUT_LEN MAX_OUTPUT_LEN  # set per group below
export no_proxy=127.0.0.1,localhost NO_PROXY=127.0.0.1,localhost
export DATAROOT=$ROOT/hotpotqa SERVE_HOST=127.0.0.1 SERVE_PORT=$PORT
mkdir -p "$LOG"

say()      { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG/run_all.log"; }
nlines()   { if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi; }
gpu_used() { nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1 | tr -d ' '; }
ready()    { curl -s --noproxy '*' "http://127.0.0.1:$PORT/v1/models" | grep -qF "\"$1\""; }

# ---------------- Pre-check (foreground) ----------------
precheck() {
  local ok=1 f
  if [ -f "$LOG/run_all.pid" ] && kill -0 "$(cat "$LOG/run_all.pid")" 2>/dev/null; then
    echo "✗ run_all is already running in the background (PID $(cat "$LOG/run_all.pid"))"
    return 1                                   # exit without touching the running server
  fi
  [[ "$C_MAXLEN" =~ ^[0-9]+$ ]] || { echo "✗ set C_MAXLEN at the top of this script"; ok=0; }
  for f in "$M/RL-MemoryAgent-7B/config.json" "$M/Qwen2.5-7B-Instruct/config.json" \
           "$M/Qwen2.5-7B-Instruct-128k/config.json" "$EVAL_DIR/ruler_hqa.py"; do
    [ -f "$f" ] || { echo "✗ missing $f"; ok=0; }
  done
  grep -q yarn "$M/Qwen2.5-7B-Instruct-128k/config.json" 2>/dev/null || { echo "✗ no yarn in the 128k config.json (step 3)"; ok=0; }
  grep -q yarn "$M/Qwen2.5-7B-Instruct/config.json" 2>/dev/null && { echo "✗ the original Qwen config.json contains yarn; group B would be wrong"; ok=0; }
  for n in $(echo $A_LENS $B_LENS $C_LENS | tr ' ' '\n' | sort -un); do
    [ -f "$DATAROOT/eval_$n.json" ] || { echo "✗ missing $DATAROOT/eval_$n.json"; ok=0; }
  done
  command -v vllm >/dev/null || { echo "✗ vllm command not found"; ok=0; }
  local vv
  vv=$(python -c 'import vllm; print(vllm.__version__)' 2>/dev/null | tail -1)
  [ "$vv" = "0.8.2" ] || { echo "✗ vllm version is '${vv:-import failed}', expected 0.8.2 (step 1)"; ok=0; }
  if ! gpu_used >/dev/null 2>&1; then
    echo "✗ no GPU visible"; ok=0
  elif [ "$(gpu_used)" -ge 1500 ]; then
    echo "… GPU memory in use (probably the server from the 7K run); stopping it"
    pkill -f "vllm serve"
    for _ in $(seq 45); do [ "$(gpu_used)" -lt 1500 ] && break; sleep 2; done
    [ "$(gpu_used)" -lt 1500 ] || { echo "✗ GPU memory still in use: $(gpu_used) MiB; check nvidia-smi"; ok=0; }
  fi
  [ "$(nlines "$EVAL_DIR/results/ruler_hqa_50/MemoryAgent-7B-5k-1k-infty.jsonl")" -ge 128 ] \
    || { echo "✗ the group A 7K run has fewer than 128 results; finish step 4 first"; ok=0; }
  [ $ok = 1 ]
}

if [ "${_RUN_ALL_BG:-0}" != 1 ]; then
  if ! precheck; then echo "Pre-check failed; nothing was started."; exit 1; fi
  _RUN_ALL_BG=1 nohup bash "$SELF" >> "$LOG/run_all.out" 2>&1 &
  echo $! > "$LOG/run_all.pid"
  echo "✓ Pre-check passed; running in the background (PID $!)."
  echo "  Progress: tail -n 30 $LOG/run_all.log"
  echo "  To stop: kill $! ; pkill -f 'vllm serve'"
  exit 0
fi

# ---------------- Background part ----------------
SPID=""
CUR=()

stop_server() {
  if [ -n "$SPID" ]; then
    kill -TERM -- "-$SPID" 2>/dev/null
    for _ in $(seq 60); do kill -0 "$SPID" 2>/dev/null || break; sleep 2; done
    kill -KILL -- "-$SPID" 2>/dev/null
    SPID=""
  fi
  pkill -f "vllm serve" 2>/dev/null
  for _ in $(seq 90); do
    [ "$(gpu_used)" -lt 1500 ] && return 0
    sleep 2
  done
  pkill -9 -f "vllm serve" 2>/dev/null
  sleep 10
  say "Warning: GPU memory still in use after stopping the server: $(gpu_used) MiB"
}

# start_server <group> <model dir> <served name> [extra vllm args...]; retries once
start_server() {
  start_server_once "$@" && return 0
  say "Group $1 server: retrying in 20 seconds"
  stop_server
  sleep 20
  start_server_once "$@"
}

start_server_once() {
  local tag=$1 dir=$2 name=$3
  shift 3
  say "Starting group $tag server: $name $*"
  cd "$ROOT" || return 1
  setsid nohup vllm serve "$dir" --served-model-name "$name" --port "$PORT" "$@" \
    >> "$LOG/serve_$tag.log" 2>&1 &
  SPID=$!
  for _ in $(seq 180); do                      # wait up to 30 minutes
    if ! kill -0 "$SPID" 2>/dev/null; then
      say "Group $tag server failed to start; see the end of $LOG/serve_$tag.log"
      SPID=""
      return 1
    fi
    if ready "$name"; then say "Group $tag server ready"; return 0; fi
    sleep 10
  done
  say "Group $tag server not ready after 30 minutes; giving up"
  stop_server
  return 1
}

ensure_server() {                              # restart the server once if it stopped responding
  ready "${CUR[2]}" && return 0
  say "Group ${CUR[0]} server not responding; restarting"
  stop_server
  start_server "${CUR[@]}"
}

# run_len <group> <served name> <tokenizer dir> <api> <length> <result file name>
run_len() {
  local tag=$1 name=$2 tok=$3 api=$4 L=$5 save=$6 try
  local f="$EVAL_DIR/results/ruler_hqa_$L/$save.jsonl"
  local envs=()
  [ "$api" = recurrent ] && envs=(RECURRENT_CHUNK_SIZE=5000 RECURRENT_MAX_NEW=1024 RECURRENT_MAX_CONTEXT_LEN=100000000000)
  for try in $(seq "$MAX_TRIES"); do
    [ "$(nlines "$f")" -ge 128 ] && break
    ensure_server || return 1
    say "Group $tag eval_$L attempt $try ($(nlines "$f") results so far)"
    cd "$EVAL_DIR" || return 1
    ( time env "${envs[@]}" python ruler_hqa.py --model "$name" --tokenizer "$tok" --api "$api" \
        --length "$L" --save_dir "results/ruler_hqa_$L" --save_file "$save" --n_proc 256 ) \
      >> "$LOG/${tag}_$L.log" 2>&1
  done
  say "Group $tag eval_$L done: $(nlines "$f")/128 results"
  return 0
}

say "===== Start: A -> C -> B ====="
stop_server                                    # stop the server left over from the 7K run

# Group A: RL-MemoryAgent-7B, memory workflow
CUR=(A "$M/RL-MemoryAgent-7B" BytedTsinghua-SIA/RL-MemoryAgent-7B)
if start_server "${CUR[@]}"; then
  for L in $A_LENS; do                         # 7K is skipped if it already has 128 results
    run_len A BytedTsinghua-SIA/RL-MemoryAgent-7B "$M/RL-MemoryAgent-7B" recurrent "$L" \
      MemoryAgent-7B-5k-1k-infty || break
  done
fi
stop_server

# Group C: Qwen2.5-7B + YaRN, whole document in one prompt
CUR=(C "$M/Qwen2.5-7B-Instruct-128k" Qwen2.5-7B-Instruct-128k --max-model-len "$C_MAXLEN")
if start_server "${CUR[@]}"; then
  for L in $C_LENS; do
    run_len C Qwen2.5-7B-Instruct-128k "$M/Qwen2.5-7B-Instruct-128k" openai "$L" Qwen-7B-120k+10k || break
  done
else
  say "Group C server could not start; skipping group C and continuing with group B (see $LOG/serve_C.log)"
fi
stop_server

# Group B: original Qwen2.5-7B-Instruct, memory workflow without RL
CUR=(B "$M/Qwen2.5-7B-Instruct" Qwen/Qwen2.5-7B-Instruct)
if start_server "${CUR[@]}"; then
  for L in $B_LENS; do
    run_len B Qwen/Qwen2.5-7B-Instruct "$M/Qwen2.5-7B-Instruct" recurrent "$L" Qwen-7B-5k-1k-infty || break
  done
fi
stop_server

# Summary (sub_em, strict, no-answer count per result file) and archive
cd "$EVAL_DIR" || exit 1
python - > "$LOG/summary.txt" 2>&1 <<'EOF'
import json, glob, os
from utils import normalize_answer
rows = []
for f in glob.glob('results/ruler_hqa_*/*.jsonl'):
    L = int(f.split('ruler_hqa_')[1].split('/')[0])
    r = [json.loads(l) for l in open(f)]
    if not r:
        continue
    lenient = 100 * sum(x['judge_sub_em'] for x in r) / len(r)
    strict = 100 * sum(1 for x in r if x['pred'] and normalize_answer(x['answer']) in normalize_answer(x['pred'])) / len(r)
    miss = sum(1 for x in r if not x['pred'])
    rows.append((os.path.basename(f)[:-6], L, len(r), round(lenient, 2), round(strict, 2), miss))
print('method  docs  n  sub_em  strict  no_answer')
for row in sorted(rows):
    print(*row)
EOF
grep -H real "$LOG"/[ABC]_*.log >> "$LOG/summary.txt" 2>/dev/null
say "Summary written to $LOG/summary.txt"
cat "$LOG/summary.txt" >> "$LOG/run_all.log"

cd "$ROOT" && tar czf "memagent_results_$(date +%m%d).tgz" MemAgent/taskutils/memory_eval/results logs
say "===== All done; results archived to $ROOT/memagent_results_$(date +%m%d).tgz ====="
rm -f "$LOG/run_all.pid"
if [ "$AUTO_SHUTDOWN" = 1 ]; then
  say "Shutting down in 1 minute"
  sync
  sleep 60
  $SHUTDOWN_CMD
fi
