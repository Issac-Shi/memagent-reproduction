#!/usr/bin/env bash
# MemAgent 复现：A -> C -> B 三组一次跑完（对应手册第 5、6 步）
# 前提：第 0-4 步已做完，A 组 7K 试跑已通过（128 条、sub_em 78-84）。
# 用法：bash /root/autodl-tmp/run_all.sh
#   先在前台做预检；通过后自动转到后台运行，可以关浏览器、睡觉。
#   看进度：tail -f /root/autodl-tmp/logs/run_all.log
set -u

# ================= 需要你填的 =================
C_MAXLEN="42000"        # 第 3 步算出的值：eval_200 最大值 + 11000，向上取整到千（本次 30832 + 11000 → 42000）
AUTO_SHUTDOWN=0         # 1 = 全部跑完后自动关机（停止计费，数据盘保留）；0 = 不关机（本次：下载核对后再手动关机）

# 跑哪些长度（50/100/200/400/800 = 7K/14K/28K/56K/112K）。保险版默认不跑 112K。
A_LENS="50 100 200 400"     # 想加 112K：末尾加 800（约多 1.5 小时）
B_LENS="50 100 200 400"     # 同上
C_LENS="50 100 200"         # 加 400 需要更大的 C_MAXLEN，24G 卡显存很紧，不建议

# vLLM 引擎：在 24G 卡上，V1 引擎用默认参数起不来（profile 后 KV cache 只剩 0.85 GiB，
# 不够一条 32768 长度的请求所需的 1.75 GiB），所以按 RUNBOOK 4.5 用 V0 引擎。其余参数仍全部默认。
export VLLM_USE_V1=${VLLM_USE_V1:-0}

# ================= 一般不用改 =================
ROOT=${ROOT:-/root/autodl-tmp}
M=$ROOT/models
EVAL_DIR=$ROOT/MemAgent/taskutils/memory_eval
LOG=$ROOT/logs
PORT=8000
MAX_TRIES=3             # 某个长度不足 128 条时，最多补跑几次（不加 --force，只补缺的题）
SHUTDOWN_CMD=${SHUTDOWN_CMD:-/usr/bin/shutdown}
SELF=$(readlink -f "$0")

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
unset RECURRENT_CHUNK_SIZE RECURRENT_MAX_NEW RECURRENT_MAX_CONTEXT_LEN MAX_INPUT_LEN MAX_OUTPUT_LEN  # 只在 A/B 组按需设置
export no_proxy=127.0.0.1,localhost NO_PROXY=127.0.0.1,localhost
export DATAROOT=$ROOT/hotpotqa SERVE_HOST=127.0.0.1 SERVE_PORT=$PORT
mkdir -p "$LOG"

say()      { echo "[$(date '+%m-%d %H:%M:%S')] $*" | tee -a "$LOG/run_all.log"; }
nlines()   { if [ -f "$1" ]; then wc -l < "$1" | tr -d ' '; else echo 0; fi; }
gpu_used() { nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | head -1 | tr -d ' '; }
ready()    { curl -s --noproxy '*' "http://127.0.0.1:$PORT/v1/models" | grep -qF "\"$1\""; }

# ---------------- 预检（前台） ----------------
precheck() {
  local ok=1 f
  if [ -f "$LOG/run_all.pid" ] && kill -0 "$(cat "$LOG/run_all.pid")" 2>/dev/null; then
    echo "✗ 已经有一个 run_all 在后台跑（PID $(cat "$LOG/run_all.pid")），不要重复启动"
    return 1                                   # 直接退出，不碰正在跑的服务
  fi
  [[ "$C_MAXLEN" =~ ^[0-9]+$ ]] || { echo "✗ 先在脚本开头填 C_MAXLEN（第 3 步算出的值）"; ok=0; }
  for f in "$M/RL-MemoryAgent-7B/config.json" "$M/Qwen2.5-7B-Instruct/config.json" \
           "$M/Qwen2.5-7B-Instruct-128k/config.json" "$EVAL_DIR/ruler_hqa.py"; do
    [ -f "$f" ] || { echo "✗ 找不到 $f"; ok=0; }
  done
  grep -q yarn "$M/Qwen2.5-7B-Instruct-128k/config.json" 2>/dev/null || { echo "✗ 128k 目录的 config.json 里没有 yarn（第 3 步）"; ok=0; }
  grep -q yarn "$M/Qwen2.5-7B-Instruct/config.json" 2>/dev/null && { echo "✗ 原版 Qwen 的 config.json 被改成了 yarn，B 组会出错"; ok=0; }
  for n in $(echo $A_LENS $B_LENS $C_LENS | tr ' ' '\n' | sort -un); do
    [ -f "$DATAROOT/eval_$n.json" ] || { echo "✗ 找不到 $DATAROOT/eval_$n.json"; ok=0; }
  done
  command -v vllm >/dev/null || { echo "✗ 找不到 vllm 命令"; ok=0; }
  local vv
  vv=$(python -c 'import vllm; print(vllm.__version__)' 2>/dev/null | tail -1)
  [ "$vv" = "0.8.2" ] || { echo "✗ vllm 版本是 '${vv:-导入失败}'，应为 0.8.2（第 1 步）"; ok=0; }
  if ! gpu_used >/dev/null 2>&1; then
    echo "✗ 看不到 GPU（还在无卡模式？）"; ok=0
  elif [ "$(gpu_used)" -ge 1500 ]; then
    echo "… 显存已被占用（多半是试跑时的服务），先把它停掉"
    pkill -f "vllm serve"
    for _ in $(seq 45); do [ "$(gpu_used)" -lt 1500 ] && break; sleep 2; done
    [ "$(gpu_used)" -lt 1500 ] || { echo "✗ 显存仍被占用 $(gpu_used) MiB，用 nvidia-smi 看是谁占的"; ok=0; }
  fi
  [ "$(nlines "$EVAL_DIR/results/ruler_hqa_50/MemoryAgent-7B-5k-1k-infty.jsonl")" -ge 128 ] \
    || { echo "✗ A 组 7K 试跑结果不足 128 条，先完成第 4 步"; ok=0; }
  [ $ok = 1 ]
}

if [ "${_RUN_ALL_BG:-0}" != 1 ]; then
  if ! precheck; then echo "预检没通过，什么都没启动。"; exit 1; fi
  _RUN_ALL_BG=1 nohup bash "$SELF" >> "$LOG/run_all.out" 2>&1 &
  echo $! > "$LOG/run_all.pid"
  echo "✓ 预检通过，已转到后台（PID $!）。可以关浏览器了。"
  echo "  看进度：tail -f $LOG/run_all.log"
  echo "  中途停止：kill $! ; pkill -f 'vllm serve'"
  exit 0
fi

# ---------------- 以下在后台运行 ----------------
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
  say "警告：停服务后显存仍占用 $(gpu_used) MiB"
}

# start_server 组名 模型目录 服务名 [vllm 额外参数...]；起不来会再试一次
start_server() {
  start_server_once "$@" && return 0
  say "$1 组服务 20 秒后再试一次"
  stop_server
  sleep 20
  start_server_once "$@"
}

start_server_once() {
  local tag=$1 dir=$2 name=$3
  shift 3
  say "启动 $tag 组服务：$name $*"
  cd "$ROOT" || return 1
  setsid nohup vllm serve "$dir" --served-model-name "$name" --port "$PORT" "$@" \
    >> "$LOG/serve_$tag.log" 2>&1 &
  SPID=$!
  for _ in $(seq 180); do                      # 最多等 30 分钟
    if ! kill -0 "$SPID" 2>/dev/null; then
      say "$tag 组服务启动失败，看 $LOG/serve_$tag.log 末尾"
      SPID=""
      return 1
    fi
    if ready "$name"; then say "$tag 组服务就绪"; return 0; fi
    sleep 10
  done
  say "$tag 组服务 30 分钟没就绪，放弃"
  stop_server
  return 1
}

ensure_server() {                              # 服务中途挂了就重启一次
  ready "${CUR[2]}" && return 0
  say "${CUR[0]} 组服务没有响应，重启"
  stop_server
  start_server "${CUR[@]}"
}

# run_len 组名 服务名 tokenizer目录 api 长度 结果文件名
run_len() {
  local tag=$1 name=$2 tok=$3 api=$4 L=$5 save=$6 try
  local f="$EVAL_DIR/results/ruler_hqa_$L/$save.jsonl"
  local envs=()
  [ "$api" = recurrent ] && envs=(RECURRENT_CHUNK_SIZE=5000 RECURRENT_MAX_NEW=1024 RECURRENT_MAX_CONTEXT_LEN=100000000000)
  for try in $(seq "$MAX_TRIES"); do
    [ "$(nlines "$f")" -ge 128 ] && break
    ensure_server || return 1
    say "$tag 组 eval_$L 第 $try 次（已有 $(nlines "$f") 条）"
    cd "$EVAL_DIR" || return 1
    ( time env "${envs[@]}" python ruler_hqa.py --model "$name" --tokenizer "$tok" --api "$api" \
        --length "$L" --save_dir "results/ruler_hqa_$L" --save_file "$save" --n_proc 256 ) \
      >> "$LOG/${tag}_$L.log" 2>&1
  done
  say "$tag 组 eval_$L 完成：$(nlines "$f")/128 条"
  return 0
}

say "===== 开始：A -> C -> B ====="
stop_server                                    # 关掉试跑时留下的服务

# A 组：RL-MemAgent-7B，记忆流程
CUR=(A "$M/RL-MemoryAgent-7B" BytedTsinghua-SIA/RL-MemoryAgent-7B)
if start_server "${CUR[@]}"; then
  for L in $A_LENS; do                         # 7K 已有 128 条会直接跳过
    run_len A BytedTsinghua-SIA/RL-MemoryAgent-7B "$M/RL-MemoryAgent-7B" recurrent "$L" \
      MemoryAgent-7B-5k-1k-infty || break
  done
fi
stop_server

# C 组：Qwen2.5-7B + YaRN，整篇直接读
CUR=(C "$M/Qwen2.5-7B-Instruct-128k" Qwen2.5-7B-Instruct-128k --max-model-len "$C_MAXLEN")
if start_server "${CUR[@]}"; then
  for L in $C_LENS; do
    run_len C Qwen2.5-7B-Instruct-128k "$M/Qwen2.5-7B-Instruct-128k" openai "$L" Qwen-7B-120k+10k || break
  done
else
  say "C 组服务起不来，跳过 C 组，继续跑 B 组（看 $LOG/serve_C.log）"
fi
stop_server

# B 组：原版 Qwen2.5-7B-Instruct，记忆流程、无强化学习
CUR=(B "$M/Qwen2.5-7B-Instruct" Qwen/Qwen2.5-7B-Instruct)
if start_server "${CUR[@]}"; then
  for L in $B_LENS; do
    run_len B Qwen/Qwen2.5-7B-Instruct "$M/Qwen2.5-7B-Instruct" recurrent "$L" Qwen-7B-5k-1k-infty || break
  done
fi
stop_server

# 汇总（同手册第 6 步）+ 备份
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
say "汇总写在 $LOG/summary.txt"
cat "$LOG/summary.txt" >> "$LOG/run_all.log"

cd "$ROOT" && tar czf "memagent_results_$(date +%m%d).tgz" MemAgent/taskutils/memory_eval/results logs
say "===== 全部完成，结果已打包到 $ROOT/memagent_results_$(date +%m%d).tgz ====="
rm -f "$LOG/run_all.pid"
if [ "$AUTO_SHUTDOWN" = 1 ]; then
  say "1 分钟后自动关机"
  sync
  sleep 60
  $SHUTDOWN_CMD
fi
