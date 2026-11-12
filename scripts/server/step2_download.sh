#!/usr/bin/env bash
# Step 2: download the authors' code, the models and the test data. Run in the background on the server:
#   nohup bash /root/autodl-tmp/scripts/step2_download.sh > /root/autodl-tmp/logs/step2_download.log 2>&1 &
# Each download is retried up to 3 times (downloads resume); the two models download in parallel;
# Hugging Face / ModelScope caches live on the data disk.
set -uo pipefail
export PATH=/root/miniconda3/bin:$PATH
ROOT=/root/autodl-tmp
AUTHOR_COMMIT=ef4219b
mkdir -p "$ROOT/models" "$ROOT/hotpotqa" "$ROOT/cache" "$ROOT/logs"
export HF_HOME=$ROOT/cache/hf MODELSCOPE_CACHE=$ROOT/cache/modelscope
source /etc/network_turbo            # AutoDL network proxy, used only for downloads
cd "$ROOT"

ts() { date '+%F %T'; }
retry() {                             # retry <name> <command...>
  local name=$1; shift
  for i in 1 2 3; do
    echo "[$(ts)] $name: attempt $i"
    "$@" && { echo "[$(ts)] $name: done"; return 0; }
    sleep 20
  done
  echo "[$(ts)] $name: failed 3 times"; return 1
}

echo "[$(ts)] step2 start"

# ---- Code (pinned to the same commit as this repository's submodule) ----
[ -d MemAgent/.git ] || retry "git clone" git clone https://github.com/BytedTsinghua-SIA/MemAgent.git
git -C MemAgent log -1 --format='main HEAD: %h %ad %s' --date=short
if [ "$(git -C MemAgent rev-parse --short=7 HEAD)" != "$AUTHOR_COMMIT" ]; then
  echo "main is no longer at $AUTHOR_COMMIT; checking out $AUTHOR_COMMIT"
  git -C MemAgent checkout -q "$AUTHOR_COMMIT"
fi
git -C MemAgent log -1 --format='using: %h %ad %s' --date=short

# ---- Test data (5 files only) ----
export HF_ENDPOINT=https://hf-mirror.com
retry "data" huggingface-cli download BytedTsinghua-SIA/hotpotqa \
  eval_50.json eval_100.json eval_200.json eval_400.json eval_800.json \
  --repo-type dataset --local-dir "$ROOT/hotpotqa"

# ---- Models (in parallel) ----
dl_A() {
  retry "RL-MemoryAgent-7B (hf-mirror)" huggingface-cli download BytedTsinghua-SIA/RL-MemoryAgent-7B \
      --local-dir "$ROOT/models/RL-MemoryAgent-7B" && return 0
  # fall back to Hugging Face directly (through the proxy) if hf-mirror fails
  retry "RL-MemoryAgent-7B (direct)" env -u HF_ENDPOINT huggingface-cli download \
      BytedTsinghua-SIA/RL-MemoryAgent-7B --local-dir "$ROOT/models/RL-MemoryAgent-7B"
}
dl_Q() {
  # ModelScope is reached without the proxy
  retry "Qwen2.5-7B-Instruct (ModelScope)" env -u http_proxy -u https_proxy \
      modelscope download --model Qwen/Qwen2.5-7B-Instruct --local_dir "$ROOT/models/Qwen2.5-7B-Instruct"
}
dl_A > "$ROOT/logs/step2_dl_A.log" 2>&1 &
pA=$!
dl_Q > "$ROOT/logs/step2_dl_Q.log" 2>&1 &
pQ=$!
wait $pA; rA=$?
wait $pQ; rQ=$?
echo "[$(ts)] model download exit codes: RL-MemoryAgent-7B=$rA  Qwen2.5-7B-Instruct=$rQ"
tail -n 2 "$ROOT/logs/step2_dl_A.log" "$ROOT/logs/step2_dl_Q.log"

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY
echo "[$(ts)] ---- checks ----"
du -sh "$ROOT"/models/*
ls "$ROOT/models/RL-MemoryAgent-7B"
python "$ROOT/scripts/step2_check_data.py"
df -h / "$ROOT"
echo "[$(ts)] step2 done"
