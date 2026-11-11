# 在本地核对下载回来的 results/：每个 manifest 里列出的结果文件都要
#   1) 存在，sha256 和 manifest 一致；
#   2) 正好 128 行，_id 恰好是 0–127，没有重复或缺题；
#   3) 重新计算的 sub_em / strict / no_answer 和 manifest、summary.txt 一致。
# 计分口径与 RUNBOOK 第 6 步相同（normalize_answer 从作者代码的子模块导入，不改作者代码）。
# 用法（仓库根目录）：python -I scripts/local/verify_results.py [results 目录，默认 results]
# 全部通过退出码为 0，否则为 1。
import hashlib, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(REPO, 'third_party', 'MemAgent', 'taskutils', 'memory_eval'))
from utils import normalize_answer  # noqa: E402

N = 128
root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, 'results')


def sha256(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def score(path):
    rows = [json.loads(l) for l in open(path, encoding='utf-8')]
    n = len(rows)
    return rows, dict(
        n=n,
        sub_em=round(100 * sum(x['judge_sub_em'] for x in rows) / n, 2),
        strict=round(100 * sum(1 for x in rows if x['pred'] and normalize_answer(x['answer']) in normalize_answer(x['pred'])) / n, 2),
        no_answer=sum(1 for x in rows if not x['pred']),
    )


bad = []
checked = 0
for run in sorted(os.listdir(root)):
    d = os.path.join(root, run)
    mf = os.path.join(d, 'manifest.json')
    if not os.path.isfile(mf):
        continue
    m = json.load(open(mf, encoding='utf-8'))
    summary = {}
    sp = os.path.join(d, 'summary.txt')
    if os.path.isfile(sp):
        for line in open(sp, encoding='utf-8').read().splitlines()[1:]:
            name, L, n, sub_em, strict, no_ans = line.split()
            summary[(name, int(L))] = (int(n), float(sub_em), float(strict), int(no_ans))
    print(f'== {run}')
    for rel, exp in sorted(m['results'].items()):
        p = os.path.join(d, rel)
        tag = f'{run}/{rel}'
        if not os.path.isfile(p):
            bad.append(f'{tag}: 文件不存在')
            continue
        rows, s = score(p)
        ids = sorted(x['_id'] for x in rows)
        errs = []
        if sha256(p) != exp['sha256']:
            errs.append('sha256 不一致')
        if s['n'] != N:
            errs.append(f"行数 {s['n']} ≠ {N}")
        if ids != list(range(N)):
            errs.append(f'_id 不是 0–{N - 1}（去重后 {len(set(ids))} 个）')
        for k in ('n', 'sub_em', 'strict', 'no_answer'):
            if s[k] != exp[k]:
                errs.append(f'{k}: 重算 {s[k]} ≠ manifest {exp[k]}')
        name = os.path.basename(rel)[:-6]
        L = int(rel.split('/')[0].split('_')[-1])
        if summary and summary.get((name, L)) != (s['n'], s['sub_em'], s['strict'], s['no_answer']):
            errs.append(f'summary.txt 不一致：{summary.get((name, L))}')
        checked += 1
        flag = 'OK ' if not errs else 'BAD'
        print(f"  {flag} {rel:55s} n={s['n']} sub_em={s['sub_em']:6.2f} strict={s['strict']:6.2f} no_answer={s['no_answer']}")
        bad += [f'{tag}: {e}' for e in errs]

print(f'\n核对了 {checked} 个结果文件。')
if bad:
    print('不通过：')
    for b in bad:
        print('  ' + b)
    sys.exit(1)
print('全部通过。')
