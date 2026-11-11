# RUNBOOK 第 6 步的汇总片段（原样）：每个结果文件的 sub_em、严格计分、抓不到答案的题数。
# 必须在 MemAgent/taskutils/memory_eval 下运行（要导入作者的 utils）。
# 可选参数：只汇总文件名含该子串的结果，例如 python summarize.py MemoryAgent-7B-5k-1k-infty
import json, glob, os, sys
sys.path.insert(0, os.getcwd())         # 手册用 python - 运行，当前目录本来就在 sys.path 里；存成文件后要手动加
from utils import normalize_answer      # 和评测代码同一个归一化函数
pat = sys.argv[1] if len(sys.argv) > 1 else ''
rows = []
for f in glob.glob('results/ruler_hqa_*/*.jsonl'):
    if pat not in f:
        continue
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
