# Build the repository's results/<date>_<group>_<description>/ directories from the server's results and logs,
# each with manifest.json and summary.txt. Run on the server from memory_eval (it imports the authors' utils):
#   cd /root/autodl-tmp/MemAgent/taskutils/memory_eval
#   python /root/autodl-tmp/scripts/make_export.py <our commit: 7K run> <our commit: boxed check> <our commit: run_all>
# Writes to /root/autodl-tmp/export/results/; the original results and logs are not modified.
import datetime, glob, hashlib, json, os, re, shutil, sys

sys.path.insert(0, os.getcwd())
from utils import normalize_answer

ROOT = '/root/autodl-tmp'
LOGS = f'{ROOT}/logs'
EVAL = f'{ROOT}/MemAgent/taskutils/memory_eval'
OUT = f'{ROOT}/export/results'
REPO = 'https://github.com/Issac-Shi/memagent-reproduction'
PRICE = 2.0          # assumed price, ¥ per GPU-hour
PRICE_NOTE = 'Evaluation time only, at an assumed price of ¥2 per GPU-hour.'
TZ = '+08:00'
commit_trial, commit_boxed, commit_runall = sys.argv[1:4]
env_info = json.load(open(f'{LOGS}/env_info.json'))
M = f'{ROOT}/models'

# Log markers. The 2026-11-12 logs were written by an earlier version of the scripts with Chinese messages;
# both forms are accepted.
EVAL_START_END = r'^\[(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)\] (开始|结束|start|end) '


def server_start(g, msg):
    return msg.startswith((f'启动 {g} 组服务', f'Starting group {g} server'))


def eval_done(g, msg):
    return re.match(fr'({g} 组 eval_\d+ 完成|Group {g} eval_\d+ done)', msg) is not None


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
    """Sum of all `time` real values in an evaluation log (several if a length was re-run)."""
    tot = 0.0
    for m in re.finditer(r'^real\s+(\d+)m([\d.]+)s', open(log, errors='replace').read(), re.M):
        tot += int(m.group(1)) * 60 + float(m.group(2))
    return round(tot, 1)


def evallog_span(log):
    """First start and last end time written by run_eval.sh."""
    ts = re.findall(EVAL_START_END, open(log, errors='replace').read(), re.M)
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
                host='AutoDL single-GPU instance')


def manifest(run_dir, **kw):
    kw.setdefault('environment', environment())
    kw['author_repo'] = dict(url=env_info['author_repo'], commit=env_info['author_commit'],
                             info=env_info['author_commit_info'])
    json.dump(kw, open(f'{run_dir}/manifest.json', 'w'), indent=2, ensure_ascii=False)


shutil.rmtree(f'{ROOT}/export', ignore_errors=True)
os.makedirs(OUT)

# ---------- 1. Group A at 7K (step 4) ----------
rid = '2026-11-12_A_trial-7k'
d = f'{OUT}/{rid}'
os.makedirs(d)
f, s = copy_result(d, 50, GROUPS['A']['save'])
st, en = evallog_span(f'{LOGS}/A_50.log')
logs = copy_logs(d, [('A_50.log', 'A_50.log'), ('step4_trial.log', 'step4_trial.log'),
                     ('step4_trial_v1_failed.log', 'step4_trial_v1_failed.log'),
                     ('serve_A_v1_failed.log', 'vllm_v1_startup_failure.log')])
write_summary(d, {f: s})
manifest(d, run_id=rid, group='A', description='Step 4: group A (RL-MemoryAgent-7B, memory workflow) at 7K',
         our_repo=dict(url=REPO, branch='repro/baseline', commit=commit_trial),
         commands=dict(cwd='MemAgent/taskutils/memory_eval', server=serve_cmd('A'), eval=[eval_cmd('A', 50)]),
         env=eval_env('recurrent'),
         start=iso(st), end=iso(en), eval_seconds={'50': real_seconds(f'{LOGS}/A_50.log')},
         cost=dict(gpu_hours=round(hours(st, en), 3), price_cny_per_hour=PRICE,
                   estimate_cny=round(hours(st, en) * PRICE, 2), note=PRICE_NOTE),
         results={f: s}, logs=logs,
         notes=['The default vLLM V1 engine failed to start: only 0.85 GiB was left for the KV cache, and one request '
                'needs 1.75 GiB (see logs/vllm_v1_startup_failure.log and docs/repro_notes.md). The run used the '
                'V0 engine with all other parameters at their defaults.',
                'Check passed: 128 results, sub_em within 78-84, fewer than 10 questions without an extracted answer.'])

# ---------- 2. \boxed{} answer-format check ----------
rid = '2026-11-12_A_boxed-7k'
d = f'{OUT}/{rid}'
os.makedirs(d)
f, s = copy_result(d, 50, 'MemoryAgent-7B-boxed')
st, en = evallog_span(f'{LOGS}/Aboxed_50.log')
logs = copy_logs(d, [('Aboxed_50.log', 'Aboxed_50.log'), ('step4_boxed.log', 'step4_boxed.log')])
write_summary(d, {f: s})
manifest(d, run_id=rid, group='A',
         description='Answer-format check: group A at 7K with the \\boxed{} format (--api recurrent-boxed)',
         our_repo=dict(url=REPO, branch='repro/baseline', commit=commit_boxed),
         commands=dict(cwd='MemAgent/taskutils/memory_eval', server=serve_cmd('A') + ' (same server as the 7K run)',
                       eval=[eval_cmd('A', 50, api='recurrent-boxed', save='MemoryAgent-7B-boxed')]),
         env=eval_env('recurrent-boxed'),
         start=iso(st), end=iso(en), eval_seconds={'50': real_seconds(f'{LOGS}/Aboxed_50.log')},
         cost=dict(gpu_hours=round(hours(st, en), 3), price_cny_per_hour=PRICE,
                   estimate_cny=round(hours(st, en) * PRICE, 2), note=PRICE_NOTE),
         results={f: s}, logs=logs)

# ---------- 3. run_all: A 14K-56K -> C 7K-28K -> B 7K-56K ----------
rid = '2026-11-12_ABC_run-all'
d = f'{OUT}/{rid}'
os.makedirs(d)
lines = runall_lines()
plan = dict(A=[100, 200, 400], C=[50, 100, 200], B=[50, 100, 200, 400])
results, per_group, eval_secs = {}, {}, {}
log_names = [('run_all.log', 'run_all.log'), ('summary.txt', 'run_all_summary.txt')]
for g, lens in plan.items():
    starts = [t for t, msg in lines if server_start(g, msg)]
    ends = [t for t, msg in lines if eval_done(g, msg)]
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
         description='run_all.sh: groups A -> C -> B at all lengths, re-running any length with missing results',
         our_repo=dict(url=REPO, branch='repro/baseline', commit=commit_runall),
         commands=dict(cwd='MemAgent/taskutils/memory_eval', launcher='bash /root/autodl-tmp/run_all.sh',
                       run_all_settings=dict(C_MAXLEN=42000, AUTO_SHUTDOWN=0, VLLM_USE_V1=0, MAX_TRIES=3)),
         groups=per_group,
         start=iso(t0), end=iso(t1), eval_seconds=eval_secs,
         cost=dict(gpu_hours=round(hours(t0, t1), 3), price_cny_per_hour=PRICE,
                   estimate_cny=round(hours(t0, t1) * PRICE, 2),
                   note='From the first to the last line of run_all.log, at an assumed price of ¥2 per GPU-hour.'),
         results=results, logs=logs,
         notes=['Group A at 7K is the result in 2026-11-12_A_trial-7k (run_all skips lengths that already have 128 results).',
                'logs/run_all_summary.txt is the summary run_all wrote for all result files on the server, '
                'including the 7K run and the \\boxed{} check.'])

print('exported:', sorted(os.listdir(OUT)))
for r in sorted(os.listdir(OUT)):
    print(open(f'{OUT}/{r}/summary.txt').read())
