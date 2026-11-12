# Accuracy table for every result file: sub_em, strict, and the number of questions with no extracted answer.
# Run from MemAgent/taskutils/memory_eval (it imports the authors' utils).
# Optional argument: only include files whose path contains this substring, e.g. python summarize.py MemoryAgent-7B-5k-1k-infty
import json, glob, os, sys
sys.path.insert(0, os.getcwd())         # make the authors' utils importable when run as a file
from utils import normalize_answer      # same normalization as the evaluation code
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
