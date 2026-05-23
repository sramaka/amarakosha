"""Dry-run: verify alignment for all Kanda 1 vargas, no JSON writes."""
import sys, re, json
sys.stdout.reconfigure(encoding='utf-8')
import fitz

PDF_PATH  = r"C:\Users\srama\OneDrive\Personal\2026\Amara Kosha\amarfin1.pdf"
JSON_PATH = r"c:\data\amarakosha\assets\data\amarakosha_v3.json"
OUT_PATH  = r"c:\data\amarakosha\tools\dryrun_out.txt"

# ── shared helpers (same as update_kanda1.py) ─────────────────────────────────

def dev_to_int(s):
    d = {'०':'0','१':'1','२':'2','३':'3','४':'4','५':'5','६':'6','७':'7','८':'8','९':'9'}
    return int(''.join(d.get(c, c) for c in s))

_TERMINAL = 'ःंाूुेैोौँ'
_PAT3       = re.compile(r'([ऀ-ॿ]{3,})\1')
_PAT2       = re.compile(r'([ऀ-ॿ][' + _TERMINAL + r'])\1')
_PAT_MATRA  = re.compile(r'([ािीुूृेैोौ])\1')
_PAT_VSRG   = re.compile(r'([ःं])\1')
_PAGE_HDR   = re.compile(r'अमरकोश[ऀ-ॿ]*?काण्ड[ड]?[१-९०]*', re.DOTALL)
_SITE_URL   = re.compile(r'sanskritdocuments?\b.*', re.IGNORECASE | re.DOTALL)

def clean_pdf_text(raw):
    raw = _SITE_URL.sub('', raw)
    raw = _PAGE_HDR.sub('', raw)
    raw = re.sub(r'\b[A-Za-z][A-Za-z0-9 ,.\'-]*[A-Za-z0-9]', '', raw)
    raw = re.sub(r'\b\d+\b', '', raw)
    raw = re.sub(r'\s*इति[ऀ-ॿ\s।॥]+$', '', raw.rstrip())
    raw = re.sub(r'\s+', ' ', raw).strip()
    prev = None
    while raw != prev:
        prev = raw
        raw = _PAT3.sub(r'\1', raw)
        raw = _PAT2.sub(r'\1', raw)
        raw = _PAT_MATRA.sub(r'\1', raw)
        raw = _PAT_VSRG.sub(r'\1', raw)
    raw = re.sub(r'^[ािीुूृेैोौ]', '', raw)
    return raw.strip()

def is_placeholder(text):
    if not text: return True  # empty
    dev_chars   = len(re.findall(r'[ऀ-ॿ]', text))
    total_chars = len(re.sub(r'\s', '', text))
    return total_chars > 3 and dev_chars / total_chars < 0.3

def is_iast(text):
    return is_placeholder(text)

def word_overlap(words, pdf_text):
    norm = re.sub(r'[\s।॥]', '', pdf_text)
    return sum(1 for w in words if w.get('w', '') and w.get('w', '') in norm)

def extract_pdf_padas(pdf_path):
    all_text = []
    with fitz.open(pdf_path) as doc:
        for page in doc:
            all_text.append(page.get_text())
    full = '\n'.join(all_text)
    pada_re = re.compile(
        r'\(([०-९]+\.[०-९]+\.[०-९]+)\)\s*(.*?)(?=\n\s*\(?[०-९]+\.[०-९]+\.[०-९]+\)|\Z)',
        re.DOTALL
    )
    result = []
    for m in pada_re.finditer(full):
        pid_dev = m.group(1)
        pid     = '.'.join(str(dev_to_int(p)) for p in pid_dev.split('.'))
        raw     = re.sub(r'\s+', ' ', m.group(2)).strip()
        raw     = re.sub(r'\s*mark\s+[ऀ-ॿ\s।॥]+$', '', raw.rstrip())
        raw     = re.sub(r'\s*mark\s*', ' ', raw)
        result.append((pid, clean_pdf_text(raw)))
    return result

def normalize(t):
    return re.sub(r'[\s।॥]', '', t)

def similarity(a, b):
    a, b = normalize(a), normalize(b)
    if not a or not b: return 0.0
    if a == b: return 1.0
    m, n = len(a), len(b)
    if m * n > 40000:
        shorter, longer = (a, b) if m <= n else (b, a)
        return sum(c in longer for c in shorter) / max(m, n)
    dp = [[0]*(n+1) for _ in range(m+1)]
    for i in range(1, m+1):
        for j in range(1, n+1):
            if a[i-1] == b[j-1]:
                dp[i][j] = dp[i-1][j-1] + 1
            else:
                dp[i][j] = max(dp[i-1][j], dp[i][j-1])
    return dp[m][n] / max(m, n)

THRESHOLD = 0.55

# ── main ──────────────────────────────────────────────────────────────────────
pdf_padas_all = extract_pdf_padas(PDF_PATH)
from collections import defaultdict
pdf_by_varga = defaultdict(list)
for pid, pt in pdf_padas_all:
    pdf_by_varga['.'.join(pid.split('.')[:2])].append((pid, pt))

data       = json.load(open(JSON_PATH, encoding='utf-8'))
k1         = data['kandas'][0]
out        = []
total_ins  = 0
total_ren  = 0
total_ok   = 0
total_iast = 0

for vi, varga in enumerate(k1['vargas']):
    json_padas_all = [p for sec in varga['sections'] for p in sec['padas']]
    json_padas = [p for p in json_padas_all if not is_placeholder(p.get('text_dev', ''))]
    empty_with_words = [p for p in json_padas_all
                        if is_placeholder(p.get('text_dev', '')) and p.get('words')]
    placeholder_count = len(json_padas_all) - len(json_padas)
    total_iast += placeholder_count

    kv  = '.'.join(json_padas[0]['id'].split('.')[:2]) if json_padas else \
          '.'.join(json_padas_all[0]['id'].split('.')[:2]) if json_padas_all else f"1.{vi+1}"
    pdf_padas = pdf_by_varga.get(kv, [])

    out.append(f"\n{'='*65}")
    out.append(f"VARGA {kv}: JSON={len(json_padas_all)} (placeholder={placeholder_count}) PDF={len(pdf_padas)}")
    out.append('='*65)

    j = 0
    inserted_padas = []  # track inserts for word recovery
    for pdf_id, pdf_text in pdf_padas:
        best_j, best_sim = j, 0.0
        for look in range(j, min(j+3, len(json_padas))):
            s = similarity(pdf_text, json_padas[look].get('text_dev',''))
            if s > best_sim:
                best_sim = s; best_j = look

        if best_sim >= THRESHOLD:
            for k in range(j, best_j):
                out.append(f"  [SKIP_JSON]  {json_padas[k]['id']}  {json_padas[k].get('text_dev','')[:50]}")
            j = best_j
            jid   = json_padas[j]['id']
            match = 'OK' if jid == pdf_id else f'renumber {jid}'
            out.append(f"  {pdf_id}  {match}  {pdf_text[:60]}")
            total_ok  += 1
            if jid != pdf_id: total_ren += 1
            j += 1
        else:
            jid  = json_padas[j]['id']   if j < len(json_padas) else '—'
            jtxt = json_padas[j].get('text_dev','') if j < len(json_padas) else ''
            out.append(f"  {pdf_id}  [INSERT]  {pdf_text[:60]}")
            out.append(f"          (nextJSON={jid} sim={best_sim:.2f}  {jtxt[:40]})")
            total_ins += 1
            inserted_padas.append((pdf_id, pdf_text))

    if j < len(json_padas):
        for leftover in json_padas[j:]:
            out.append(f"  [SKIP_JSON_TAIL] {leftover['id']}  {leftover.get('text_dev','')[:50]}")

    # Word recovery report
    if empty_with_words:
        used = set()
        recovered = 0
        for pid, ptext in inserted_padas:
            best_score, best_ep = 0, None
            for ep in empty_with_words:
                eid = id(ep)
                if eid in used: continue
                score = word_overlap(ep.get('words', []), ptext)
                if score > best_score:
                    best_score, best_ep = score, ep
            if best_score >= 2 and best_ep:
                used.add(id(best_ep))
                recovered += 1
                out.append(f"  [WORD_RECOVERY] {pid} ← {best_ep['id']} ({best_score} words)")
        out.append(f"  Word recovery: {recovered}/{len(empty_with_words)} empty padas matched")

out.append(f"\n{'='*65}")
out.append(f"IAST padas filtered: {total_iast}")
out.append(f"SUMMARY: {total_ok} matched ({total_ren} renumbered), {total_ins} inserted")
out.append(f"Total output padas: {total_ok + total_ins}")

with open(OUT_PATH, 'w', encoding='utf-8') as f:
    f.write('\n'.join(out))
print(f"Written to {OUT_PATH}")
print(f"IAST filtered: {total_iast}")
print(f"Matched: {total_ok} ({total_ren} renumbered), Inserted: {total_ins}")
print(f"Total: {total_ok + total_ins}")
