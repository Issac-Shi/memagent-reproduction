#!/usr/bin/env bash
# RUNBOOK 第 1 步：装环境（锁定依赖，--no-deps）。在服务器后台运行：
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
  # RUNBOOK：某个包在默认镜像上找不到时，换清华源重试
  echo "[$(date '+%F %T')] 默认镜像安装失败（exit=$rc），换清华源重试"
  pip install --no-cache-dir --no-deps -r "$LOCK" -i https://pypi.tuna.tsinghua.edu.cn/simple
  rc=$?
fi
echo "[$(date '+%F %T')] pip install exit=$rc"

echo '--- pip check | grep -i vllm（只应有 xgrammar 那一行）'
pip check | grep -i vllm
echo '--- 自检'
python -c "import vllm, torch, transformers, datasets, aiohttp, uvloop, tiktoken, openai, huggingface_hub; print('vllm', vllm.__version__, '| torch', torch.__version__, '| transformers', transformers.__version__, '| openai', openai.__version__, '| hub', huggingface_hub.__version__); print('cuda', torch.cuda.is_available(), torch.cuda.get_device_name(0) if torch.cuda.is_available() else '')"
echo '--- 命令'
which vllm huggingface-cli modelscope
df -h /
echo "[$(date '+%F %T')] step1 done"
