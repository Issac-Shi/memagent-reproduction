# 把服务器上的结果整理成仓库的 results/<日期>_<组>_<说明>/ 结构，每个目录带 manifest.json 和 summary.txt。
# 在服务器上运行（要导入作者的 utils，所以在 memory_eval 目录下）：
#   cd /root/autodl-tmp/MemAgent/taskutils/memory_eval
#   python /root/autodl-tmp/scripts/make_export.py <试跑时本仓库 commit> <boxed 时 commit> <run_all 时 commit>
# 输出到 /root/autodl-tmp/export/results/，不改动原始结果和日志。
import datetime, glob, hashlib, json, os, re, shutil, sys

sys.path.insert(0, os.getcwd())
from utils import normalize_answer

ROOT = '/root/autodl-tmp'
LOGS = f'{ROOT}/logs'
EVAL = f'{ROOT}/MemAgent/taskutils/memory_eval'
OUT = f'{ROOT}/export/results'
REPO = 'https://github.com/Issac-Shi/memagent-reproduction'
PRICE = 2.0          # ¥/GPU 小时，RUNBOOK 的假设；实际以 AutoDL 账单为准
TZ = '+08:00'
commit_trial, commit_boxed, commit_runall = sys.argv[1:4]
env_info = json.load(open(f'{LOGS}/env_info.json'))
M = f'{ROOT}/models'

GROUPS = {
    'A': dict(model_dir=f'{M}/RL-MemoryAgent-7B', name='BytedTsinghua-SIA/RL-MemoryAgent-7B',
              api='recurrent', save='MemoryAgent-7B-5k-1k-infty', extra=''),
    'C': dict(model_dir=f'{M}/Qwen2.5-7B-Instruct-128k', name='Qwen2.5-7B-Instruct-128k',
              api='openai', save='Qwen-7B-120k+10k', extra=' --max-model-len 42000'),
    'B': dict(model_dir=f'{M}/Qwen2.5-7B-Instruct', name='Qwen/Qwen2.5-7B-Instruct',
              api='recurrent', save='Qwen-7B-5k-1k-infty', extra=''),
}
BASE_ENV = {'DATAROOT': f'{ROOT}/hotpotqa', 'SERVE_HOST': '127.0.0.1', 'SERVE_PORT': '8000'}
REC_ENV = {'RECURRENT_CHUNK_SIZE': '5000', 'RECURRENT_MAX_NEW': '1024', 'RECURRENT_MAX_CONTEXT_LEN': '100000000000'}


def sha256(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def score(path):
    r = [json.loads(l) for l in open(path)]
    n = len(r)
    return dict(
        n=n,
        sub_em=round(100 * sum(x['judge_sub_em'] for x in r) / n, 2),
        strict=round(100 * sum(1 for x in r if x['pred'] and normalize_answer(x['answer']) in normalize_answer(x['pred'])) / n, 2),
        no_answer=sum(1 for x in r if not x['pred']),
        sha256=sha256(path),
    )


def real_seconds(log):
    """一个评测日志里所有 time 的 real 之和（补跑时有多次）。"""
    tot = 0.0
    for m in re.finditer(r'^real\s+(\d+)m([\d.]+)s', open(log, errors='replace').read(), re.M):
        tot += int(m.group(1)) * 60 + float(m.group(2))
    return round(tot, 1)


def evallog_span(log):
    """run_eval.sh 写的 [YYYY-MM-DD HH:MM:SS] 开始 / 结束 时间。"""
    ts = re.findall(r'^\[(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)\] (开始|结束)', open(log, errors='replace').read(), re.M)
    return ts[0][0], ts[-1][0]


def runall_lines():
    out = []
    for line in open(f'{LOGS}/run_all.log', errors='replace'):
        m = re.match(r'\[(\d\d-\d\d \d\d:\d\d:\d\d)\] (.*)', line.rstrip('\n'))
        if m:
            out.append(('2026-' + m.group(1), m.group(2)))
    return out


def iso(s):
    return s.replace(' ', 'T') + TZ


def hours(a, b):
    f = '%Y-%m-%d %H:%M:%S'
    return (datetime.datetime.strptime(b, f) - datetime.datetime.strptime(a, f)).total_seconds() / 3600


def eval_cmd(g, L, api=None, save=None):
    c = GROUPS[g]
    return (f"python ruler_hqa.py --model {c['name']} --tokenizer {c['model_dir']} --api {api or c['api']} "
            f"--length {L} --save_dir results/ruler_hqa_{L} --save_file {save or c['save']} --n_proc 256")


def eval_env(api):
    e = dict(BASE_ENV)
    if api.startswith('recurrent'):
        e.update(REC_ENV)
    return e


def serve_cmd(g):
    c = GROUPS[g]
    return f"VLLM_USE_V1=0 vllm serve {c['model_dir']} --served-model-name {c['name']} --port 8000{c['extra']}"


def copy_result(run_dir, L, save):
    src = f'{EVAL}/results/ruler_hqa_{L}/{save}.jsonl'
    dst = f'{run_dir}/ruler_hqa_{L}/{save}.jsonl'
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)
    return f'ruler_hqa_{L}/{save}.jsonl', score(src)


def copy_logs(run_dir, names):
    os.makedirs(f'{run_dir}/logs', exist_ok=True)
    kept = []
    for src_name, dst_name in names:
        src = f'{LOGS}/{src_name}'
        if os.path.exists(src):
            shutil.copy2(src, f'{run_dir}/logs/{dst_name}')
            kept.append(f'logs/{dst_name}')
    return kept


def write_summary(run_dir, results):
    lines = ['method  docs  n  sub_em  strict  no_answer']
    for f, s in sorted(results.items(), key=lambda kv: (kv[0].split('/')[1], int(kv[0].split('/')[0].split('_')[-1]))):
        L = int(f.split('/')[0].split('_')[-1])
        lines.append(f"{f.split('/')[1][:-6]} {L} {s['n']} {s['sub_em']} {s['strict']} {s['no_answer']}")
    open(f'{run_dir}/summary.txt', 'w').write('\n'.join(lines) + '\n')


def environment():
    return dict(vllm=env_info['vllm'], torch=env_info['torch'], transformers=env_info['transformers'],
                openai=env_info['openai'], python=env_info['python'], gpu=env_info['gpu'],
                cuda_driver=env_info['cuda_driver'], vllm_engine='V0 (VLLM_USE_V1=0)',
                host='AutoDL 单卡实例（GPU 模式）')


def manifest(run_dir, **kw):
    kw.setdefault('environment', environment())
    kw['author_repo'] = dict(url=env_info['author_repo'], commit=env_info['author_commit'],
                             info=env_info['author_commit_info'])
    json.dump(kw, open(f'{run_dir}/manifest.json', 'w'), indent=2, ensure_ascii=False)


shutil.rmtree(f'{ROOT}/export', ignore_errors=True)
os.makedirs(OUT)

# ---------- 1. A 组 7K 试跑（RUNBOOK 第 4 步）----------
rid = '2026-11-12_A_trial-7k'
d = f'{OUT}/{rid}'
os.makedirs(d)
f, s = copy_result(d, 50, GROUPS['A']['save'])
st, en = evallog_span(f'{LOGS}/A_50.log')
logs = copy_logs(d, [('A_50.log', 'A_50.log'), ('step4_trial.log', 'step4_trial.log'),
                     ('step4_trial_v1_failed.log', 'step4_trial_v1_failed.log'),
                     ('serve_A_v1_failed.log', 'vllm_v1_startup_failure.log')])
write_summary(d, {f: s})
manifest(d, run_id=rid, group='A', description='RUNBOOK 第 4 步：A 组（RL-MemoryAgent-7B，分段读 + 记忆）7K 试跑',
         our_repo=dict(url=REPO, branch='repro/baseline', commit=commit_trial),
         commands=dict(cwd='MemAgent/taskutils/memory_eval', server=serve_cmd('A'), eval=[eval_cmd('A', 50)]),
         env=eval_env('recurrent'),
         start=iso(st), end=iso(en), eval_seconds={'50': real_seconds(f'{LOGS}/A_50.log')},
         cost=dict(gpu_hours=round(hours(st, en), 3), price_cny_per_hour=PRICE,
                   estimate_cny=round(hours(st, en) * PRICE, 2),
                   note='只算评测时长；价格是 RUNBOOK 的假设（4090 约 ¥2/小时），实际以 AutoDL 账单为准'),
         results={f: s}, logs=logs,
         notes=['先用 V1 引擎（vLLM 0.8.2 默认）启动失败：KV cache 只剩 0.85 GiB < 1.75 GiB，'
                '见 logs/vllm_v1_startup_failure.log 和 docs/repro_notes.md；按 RUNBOOK 4.5 改用 V0 引擎，其余参数全默认。',
                '通过标准：128 行、sub_em 在 78–84、抓不到答案的题个位数，三条都满足。'])

# ---------- 2. \boxed{} 对照（RUNBOOK 4.5）----------
rid = '2026-11-12_A_boxed-7k'
d = f'{OUT}/{rid}'
os.makedirs(d)
f, s = copy_result(d, 50, 'MemoryAgent-7B-boxed')
st, en = evallog_span(f'{LOGS}/Aboxed_50.log')
logs = copy_logs(d, [('Aboxed_50.log', 'Aboxed_50.log'), ('step4_boxed.log', 'step4_boxed.log')])
write_summary(d, {f: s})
manifest(d, run_id=rid, group='A', description='RUNBOOK 4.5：A 组 7K 用 \\boxed{} 作答格式（--api recurrent-boxed）的对照',
         our_repo=dict(url=REPO, branch='repro/baseline', commit=commit_boxed),
         commands=dict(cwd='MemAgent/taskutils/memory_eval', server=serve_cmd('A') + '（沿用试跑的服务）',
                       eval=[eval_cmd('A', 50, api='recurrent-boxed', save='MemoryAgent-7B-boxed')]),
         env=eval_env('recurrent-boxed'),
         start=iso(st), end=iso(en), eval_seconds={'50': real_seconds(f'{LOGS}/Aboxed_50.log')},
         cost=dict(gpu_hours=round(hours(st, en), 3), price_cny_per_hour=PRICE,
                   estimate_cny=round(hours(st, en) * PRICE, 2), note='同上'),
         results={f: s}, logs=logs)

# ---------- 3. run_all：A 14K–56K → C 7K–28K → B 7K–56K（RUNBOOK 第 5–6 步）----------
rid = '2026-11-12_ABC_run-all'
d = f'{OUT}/{rid}'
os.makedirs(d)
lines = runall_lines()
plan = dict(A=[100, 200, 400], C=[50, 100, 200], B=[50, 100, 200, 400])
results, per_group, eval_secs = {}, {}, {}
log_names = [('run_all.log', 'run_all.log'), ('summary.txt', 'run_all_summary.txt')]
for g, lens in plan.items():
    starts = [t for t, msg in lines if msg.startswith(f'启动 {g} 组服务')]
    ends = [t for t, msg in lines if re.match(fr'{g} 组 eval_\d+ 完成', msg)]
    for L in lens:
        p = f"{EVAL}/results/ruler_hqa_{L}/{GROUPS[g]['save']}.jsonl"
        if os.path.exists(p):
            f, s = copy_result(d, L, GROUPS[g]['save'])
            results[f] = s
        if os.path.exists(f'{LOGS}/{g}_{L}.log'):
            log_names.append((f'{g}_{L}.log', f'{g}_{L}.log'))
            eval_secs[f'{g}_{L}'] = real_seconds(f'{LOGS}/{g}_{L}.log')
    if starts and ends:
        per_group[g] = dict(start=iso(starts[0]), end=iso(ends[-1]), gpu_hours=round(hours(starts[0], ends[-1]), 3),
                            server=serve_cmd(g), eval=[eval_cmd(g, L) for L in lens],
                            env=eval_env(GROUPS[g]['api']))
logs = copy_logs(d, log_names)
write_summary(d, results)
t0, t1 = lines[0][0], lines[-1][0]
manifest(d, run_id=rid, group='ABC',
         description='RUNBOOK 第 5–6 步：run_all.sh 按 A → C → B 依次换模型跑完保险版范围、补跑缺题、汇总',
         our_repo=dict(url=REPO, branch='repro/baseline', commit=commit_runall),
         commands=dict(cwd='MemAgent/taskutils/memory_eval', launcher='bash /root/autodl-tmp/run_all.sh',
                       run_all_settings=dict(C_MAXLEN=42000, AUTO_SHUTDOWN=0, VLLM_USE_V1=0, MAX_TRIES=3)),
         groups=per_group,
         start=iso(t0), end=iso(t1), eval_seconds=eval_secs,
         cost=dict(gpu_hours=round(hours(t0, t1), 3), price_cny_per_hour=PRICE,
                   estimate_cny=round(hours(t0, t1) * PRICE, 2), note='run_all.log 首尾时间；价格同上'),
         results=results, logs=logs,
         notes=['A 组 7K 沿用试跑结果（run_all 检查到已有 128 条直接跳过），见 2026-11-12_A_trial-7k。',
                'logs/run_all_summary.txt 是 run_all 汇总服务器上全部结果文件的总表（含试跑和 boxed 对照）。'])

print('exported:', sorted(os.listdir(OUT)))
for r in sorted(os.listdir(OUT)):
    print(open(f'{OUT}/{r}/summary.txt').read())
