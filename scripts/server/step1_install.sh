#!/usr/bin/env bash
# Step 1: install the locked dependencies (--no-deps). Run in the background on the server:
#   nohup bash /root/autodl-tmp/scripts/step1_install.sh > /root/autodl-tmp/logs/step1_install.log 2>&1 &
set -uo pipefail
export PATH=/root/miniconda3/bin:$PATH
mkdir -p /root/autodl-tmp/tmp && export TMPDIR=/root/autodl-tmp/tmp
LOCK=/root/autodl-tmp/requirements-lock.txt

echo "[$(date '+%F %T')] step1 start"
df -h / /root/autodl-tmp
python --version

pip install --no-cache-dir --no-deps -r "$LOCK"
rc=$?
if [ $rc -ne 0 ]; then
  # retry with the Tsinghua PyPI mirror if a package is missing from the default index
  echo "[$(date '+%F %T')] install failed on the default index (exit=$rc); retrying with the Tsinghua mirror"
  pip install --no-cache-dir --no-deps -r "$LOCK" -i https://pypi.tuna.tsinghua.edu.cn/simple
  rc=$?
fi
echo "[$(date '+%F %T')] pip install exit=$rc"

echo '--- pip check | grep -i vllm (expected: only the xgrammar line)'
pip check | grep -i vllm
echo '--- self-test'
python -c "import vllm, torch, transformers, datasets, aiohttp, uvloop, tiktoken, openai, huggingface_hub; print('vllm', vllm.__version__, '| torch', torch.__version__, '| transformers', transformers.__version__, '| openai', openai.__version__, '| hub', huggingface_hub.__version__); print('cuda', torch.cuda.is_available(), torch.cuda.get_device_name(0) if torch.cuda.is_available() else '')"
echo '--- commands'
which vllm huggingface-cli modelscope
df -h /
echo "[$(date '+%F %T')] step1 done"
