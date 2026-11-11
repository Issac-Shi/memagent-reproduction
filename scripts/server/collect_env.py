# 采集写 manifest 要用的环境信息，存到 /root/autodl-tmp/logs/env_info.json。
#   python /root/autodl-tmp/scripts/collect_env.py
import json, platform, subprocess, datetime

def sh(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return None

import vllm, torch, transformers, openai, huggingface_hub
info = dict(
    collected_at=datetime.datetime.now().astimezone().isoformat(timespec='seconds'),
    hostname=sh('hostname'),
    python=platform.python_version(),
    vllm=vllm.__version__,
    torch=torch.__version__,
    transformers=transformers.__version__,
    openai=openai.__version__,
    huggingface_hub=huggingface_hub.__version__,
    gpu=sh('nvidia-smi --query-gpu=name,memory.total,driver_version,compute_cap --format=csv,noheader'),
    cuda_driver=sh("nvidia-smi | grep -o 'CUDA Version: [0-9.]*'"),
    author_repo='https://github.com/BytedTsinghua-SIA/MemAgent',
    author_commit=sh('git -C /root/autodl-tmp/MemAgent rev-parse HEAD'),
    author_commit_info=sh("git -C /root/autodl-tmp/MemAgent log -1 --format='%h %ad %s' --date=short"),
    vllm_engine_lines={tag: sh(f"grep -i -m3 'v1\\|engine' /root/autodl-tmp/logs/serve_{tag}.log")
                       for tag in ['A', 'B', 'C']},
)
json.dump(info, open('/root/autodl-tmp/logs/env_info.json', 'w'), indent=2, ensure_ascii=False)
print(json.dumps(info, indent=2, ensure_ascii=False))
