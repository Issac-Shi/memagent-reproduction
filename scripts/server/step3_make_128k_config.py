# Step 3: write a separate config.json with YaRN (128K context) for the 128K model directory.
import json
src = '/root/autodl-tmp/models/Qwen2.5-7B-Instruct/config.json'
dst = '/root/autodl-tmp/models/Qwen2.5-7B-Instruct-128k/config.json'
c = json.load(open(src))
c['rope_scaling'] = {'factor': 4.0, 'original_max_position_embeddings': 32768, 'type': 'yarn'}
json.dump(c, open(dst, 'w'), indent=2)
print('128k:', c['rope_scaling'])
print('original has no YaRN:', 'rope_scaling' not in json.load(open(src)) or json.load(open(src))['rope_scaling'] is None)
