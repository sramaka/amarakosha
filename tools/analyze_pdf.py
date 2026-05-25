"""Analyze PDF text doubling pattern by comparing against known JSON padas."""
import sys, re, json
sys.stdout.reconfigure(encoding='utf-8')

import fitz

PDF_PATH = r"C:\Users\srama\OneDrive\Personal\2026\Amara Kosha\amarfin1.pdf"
JSON_PATH = r"c:\data\amarakosha\assets\data\amarakosha_v3.json"

data = json.load(open(JSON_PATH, encoding='utf-8'))
k1 = data['kandas'][0]
json_padas = {}
for v in k1['vargas']:
    for s in v['sections']:
        for p in s['padas']:
            json_padas[p['id']] = p.get('text_dev', '')

# Extract all text from PDF
all_text = []
with fitz.open(PDF_PATH) as doc:
    for page in doc:
        all_text.append(page.get_text())

full_text = '\n'.join(all_text)

# Find padas by their ID pattern (१.१.११) etc.
# Hindu numeral pattern
def dev_num(n):
    """Convert integer to Devanagari numeral string."""
    digits = '०१२३४५६७८९'
    return ''.join(digits[int(d)] for d in str(n))

# Extract padas matching (k.v.n) pattern
pada_pattern = re.compile(r'\(([१२३४५६७८९०]+\.[१२३४५६७८९०]+\.[१२३४५६७८९०]+)\)\s*(.*?)(?=\n|\((?:[१२३४५६७८९०]+\.)+|$)', re.DOTALL)

def parse_dev_num(s):
    """Convert Devanagari numeral string to integer."""
    digits = {'०':'0','१':'1','२':'2','३':'3','४':'4','५':'5','६':'6','७':'7','८':'8','९':'9'}
    return int(''.join(digits.get(c, c) for c in s))

matches = pada_pattern.findall(full_text)
print(f"Found {len(matches)} pada matches in PDF\n")

# Show first 20 with comparison to JSON
for i, (pid_dev, text) in enumerate(matches[:30]):
    parts = pid_dev.split('.')
    pid = '.'.join(str(parse_dev_num(p)) for p in parts)
    text_clean = text.strip().replace('\n', ' ')
    json_text = json_padas.get(pid, '[NOT IN JSON]')

    if pid in json_padas:
        # Show side by side for comparison
        match = '✓' if text_clean == json_text else '≠'
        print(f"PDF {pid}: {text_clean[:60]}")
        print(f"JSON {pid}: {json_text[:60]} {match}")
    else:
        print(f"PDF {pid}: {text_clean[:60]} [NEW]")
    print()
