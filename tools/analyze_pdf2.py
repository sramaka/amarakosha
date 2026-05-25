"""Analyze PDF text doubling and extract pada IDs + text."""
import sys, re, json
import fitz

PDF_PATH = r"C:\Users\srama\OneDrive\Personal\2026\Amara Kosha\amarfin1.pdf"
JSON_PATH = r"c:\data\amarakosha\assets\data\amarakosha_v3.json"
OUT_PATH = r"c:\data\amarakosha\tools\pdf_analysis.txt"

data = json.load(open(JSON_PATH, encoding='utf-8'))
k1 = data['kandas'][0]
json_padas = {}
for v in k1['vargas']:
    for s in v['sections']:
        for p in s['padas']:
            json_padas[p['id']] = p.get('text_dev', '')

# Extract all text from PDF pages
all_text = []
with fitz.open(PDF_PATH) as doc:
    for page in doc:
        all_text.append(page.get_text())
full_text = '\n'.join(all_text)

def parse_dev_num(s):
    digits = {'०':'0','१':'1','२':'2','३':'3','४':'4','५':'5','६':'6','७':'7','८':'8','९':'9'}
    return int(''.join(digits.get(c, c) for c in s))

# Extract padas with their IDs and text
pada_pattern = re.compile(
    r'\(([०-९]+\.[०-९]+\.[०-९]+)\)\s*(.*?)(?=\n\s*\(?[०-९]+\.[०-९]+\.[०-९]+\)?|\Z)',
    re.DOTALL
)

matches = pada_pattern.findall(full_text)

out = []
out.append(f"Found {len(matches)} pada matches in PDF\n")

# Show comparison for first 40 padas
for pid_dev, text in matches[:40]:
    parts = pid_dev.split('.')
    pid = '.'.join(str(parse_dev_num(p)) for p in parts)
    text_clean = re.sub(r'\s+', ' ', text).strip()
    # Remove 'mark' artifacts
    text_clean = re.sub(r'\s*mark\s*', ' ', text_clean).strip()
    json_text = json_padas.get(pid, '[NOT IN JSON]')

    out.append(f"=== {pid} ===")
    out.append(f"PDF:  {text_clean}")
    out.append(f"JSON: {json_text}")
    out.append("")

with open(OUT_PATH, 'w', encoding='utf-8') as f:
    f.write('\n'.join(out))

print(f"Written to {OUT_PATH}")
print(f"Total PDF padas: {len(matches)}")

# Also count by kanda.varga
from collections import defaultdict
counts = defaultdict(int)
for pid_dev, _ in matches:
    parts = pid_dev.split('.')
    kv = f"{parse_dev_num(parts[0])}.{parse_dev_num(parts[1])}"
    counts[kv] += 1

for kv in sorted(counts, key=lambda x: [int(n) for n in x.split('.')]):
    print(f"  Varga {kv}: {counts[kv]} padas")
