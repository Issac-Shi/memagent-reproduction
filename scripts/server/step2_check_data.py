# Step 2: check the test data. Expected: 128 items per file,
# with fields answers / context / index / input / num_docs.
import json
def load(p):
    t = open(p).read()
    try:
        return json.loads(t)
    except json.JSONDecodeError:
        return [json.loads(l) for l in t.splitlines() if l.strip()]
for n in [50, 100, 200, 400, 800]:
    d = load(f'/root/autodl-tmp/hotpotqa/eval_{n}.json')
    print(n, len(d), sorted(d[0].keys()))
