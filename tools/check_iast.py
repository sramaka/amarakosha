"""Find padas with IAST (romanized) text instead of Devanagari in Kanda 1."""
import sys, re, json
sys.stdout.reconfigure(encoding='utf-8')

JSON_PATH = r"c:\data\amarakosha\assets\data\amarakosha_v3.json"
OUT_PATH  = r"c:\data\amarakosha\tools\iast_padas.txt"

def is_iast(text):
    dev = len(re.findall(r'[ऀ-ॿ]', text))
    total = len(re.sub(r'\s', '', text))
    return total > 3 and dev / total < 0.3

data = json.load(open(JSON_PATH, encoding='utf-8'))
k1 = data['kandas'][0]

out = []
for vi, varga in enumerate(k1['vargas']):
    iast_in_varga = []
    for sec in varga['sections']:
        for p in sec['padas']:
            if is_iast(p.get('text_dev', '')):
                iast_in_varga.append((p['id'], p.get('text_dev', '')[:80]))
    if iast_in_varga:
        out.append(f"\nVarga {vi+1} (1.{vi+1}.*):")
        for pid, txt in iast_in_varga:
            out.append(f"  {pid}: {txt}")

with open(OUT_PATH, 'w', encoding='utf-8') as f:
    f.write('\n'.join(out))
print('Written to', OUT_PATH)
print(f"Total IAST padas: {sum(1 for v in k1['vargas'] for s in v['sections'] for p in s['padas'] if is_iast(p.get('text_dev','')))}")
