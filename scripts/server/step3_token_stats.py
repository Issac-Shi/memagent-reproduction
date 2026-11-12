# Step 3: document length in tokens and model calls per question for each test file; also prints C_MAXLEN.
# Group C --max-model-len = longest eval_200 document + 1,000 (question and template) + 10,000 (output), rounded up to 1,000.
import json, math
from transformers import AutoTokenizer
tok = AutoTokenizer.from_pretrained('/root/autodl-tmp/models/Qwen2.5-7B-Instruct')
def load(p):
    t = open(p).read()
    try:
        return json.loads(t)
    except json.JSONDecodeError:
        return [json.loads(l) for l in t.splitlines() if l.strip()]
print('docs  min  mean  max  calls/q(mean)')
stats = {}
for n in [50, 100, 200, 400, 800]:
    d = load(f'/root/autodl-tmp/hotpotqa/eval_{n}.json')
    L = [len(tok(x['context']).input_ids) for x in d]
    calls = sum(math.ceil(l / 5000) + 1 for l in L) / len(L)
    print(n, min(L), sum(L) // len(L), max(L), round(calls, 1))
    stats[n] = dict(min=min(L), mean=sum(L) // len(L), max=max(L), calls_per_q=round(calls, 2))
MAX200 = stats[200]['max']
C_MAXLEN = math.ceil((MAX200 + 11000) / 1000) * 1000
print('MAX200 =', MAX200, ' C_MAXLEN =', C_MAXLEN)
json.dump(dict(stats=stats, MAX200=MAX200, C_MAXLEN=C_MAXLEN),
          open('/root/autodl-tmp/logs/step3_token_stats.json', 'w'), indent=2)
