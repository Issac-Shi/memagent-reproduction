#!/usr/bin/env bash
# RUNBOOK 第 2 步：下载代码、模型、数据。在服务器后台运行：
#   nohup bash /root/autodl-tmp/scripts/step2_download.sh > /root/autodl-tmp/logs/step2_download.log 2>&1 &
# 与手册的差别只在执行方式：每个下载失败时自动重跑同一条命令（会续传），最多 3 次；
# 两个模型并行下载；HF / ModelScope 的缓存目录放到数据盘，避免占满系统盘。
set -uo pipefail
export PATH=/root/miniconda3/bin:$PATH
ROOT=/root/autodl-tmp
AUTHOR_COMMIT=ef4219b
mkdir -p "$ROOT/models" "$ROOT/hotpotqa" "$ROOT/cache" "$ROOT/logs"
export HF_HOME=$ROOT/cache/hf MODELSCOPE_CACHE=$ROOT/cache/modelscope
source /etc/network_turbo            # 学术加速：只在下载阶段开
cd "$ROOT"

ts() { date '+%F %T'; }
retry() {                             # retry 名称 命令...
  local name=$1; shift
  for i in 1 2 3; do
    echo "[$(ts)] $name：第 $i 次"
    "$@" && { echo "[$(ts)] $name：完成"; return 0; }
    sleep 20
  done
  echo "[$(ts)] $name：3 次都失败"; return 1
}

echo "[$(ts)] step2 start"

# ---- 代码（固定在审查过的 commit，和本仓库的 submodule 一致）----
[ -d MemAgent/.git ] || retry "git clone" git clone https://github.com/BytedTsinghua-SIA/MemAgent.git
git -C MemAgent log -1 --format='main HEAD: %h %ad %s' --date=short
if [ "$(git -C MemAgent rev-parse --short=7 HEAD)" != "$AUTHOR_COMMIT" ]; then
  echo "main 已不是 $AUTHOR_COMMIT，切到 $AUTHOR_COMMIT"
  git -C MemAgent checkout -q "$AUTHOR_COMMIT"
fi
git -C MemAgent log -1 --format='使用: %h %ad %s' --date=short

# ---- 数据（只要 5 个文件）----
export HF_ENDPOINT=https://hf-mirror.com
retry "数据" huggingface-cli download BytedTsinghua-SIA/hotpotqa \
  eval_50.json eval_100.json eval_200.json eval_400.json eval_800.json \
  --repo-type dataset --local-dir "$ROOT/hotpotqa"

# ---- 模型（并行）----
dl_A() {
  retry "RL-MemoryAgent-7B (hf-mirror)" huggingface-cli download BytedTsinghua-SIA/RL-MemoryAgent-7B \
      --local-dir "$ROOT/models/RL-MemoryAgent-7B" && return 0
  # 手册：hf-mirror 很慢或失败时，去掉 HF_ENDPOINT，只靠学术加速直连 Hugging Face
  retry "RL-MemoryAgent-7B (直连)" env -u HF_ENDPOINT huggingface-cli download \
      BytedTsinghua-SIA/RL-MemoryAgent-7B --local-dir "$ROOT/models/RL-MemoryAgent-7B"
}
dl_Q() {
  # ModelScope 是国内源，不走学术加速代理
  retry "Qwen2.5-7B-Instruct (ModelScope)" env -u http_proxy -u https_proxy \
      modelscope download --model Qwen/Qwen2.5-7B-Instruct --local_dir "$ROOT/models/Qwen2.5-7B-Instruct"
}
dl_A > "$ROOT/logs/step2_dl_A.log" 2>&1 &
pA=$!
dl_Q > "$ROOT/logs/step2_dl_Q.log" 2>&1 &
pQ=$!
wait $pA; rA=$?
wait $pQ; rQ=$?
echo "[$(ts)] 模型下载退出码：RL-MemoryAgent-7B=$rA  Qwen2.5-7B-Instruct=$rQ"
tail -n 2 "$ROOT/logs/step2_dl_A.log" "$ROOT/logs/step2_dl_Q.log"

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
echo "[$(ts)] ---- 校验 ----"
du -sh "$ROOT"/models/*
ls "$ROOT/models/RL-MemoryAgent-7B"
python "$ROOT/scripts/step2_check_data.py"
df -h / "$ROOT"
echo "[$(ts)] step2 done"
