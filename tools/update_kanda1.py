"""
Update Kanda 1 padas in amarakosha_v3.json to match amarfin1.pdf.

Key issues being fixed:
  1. IDs are wrong for padas after any missing pada (offset by # of missing padas)
  2. 224 padas have IAST (Roman) placeholder text in wrong vargas — these are discarded
  3. ~277 padas missing outright — added with PDF text and empty words list
  4. Net result: 598 Kanda-1 padas matching the PDF numbering
"""
import sys, re, json
sys.stdout.reconfigure(encoding='utf-8')

import fitz  # PyMuPDF

PDF_PATH  = r"C:\Users\srama\OneDrive\Personal\2026\Amara Kosha\amarfin1.pdf"
JSON_PATH = r"c:\data\amarakosha\assets\data\amarakosha_v3.json"
OUT_PATH  = r"c:\data\amarakosha\assets\data\amarakosha_v3.json"
LOG_PATH  = r"c:\data\amarakosha\tools\update_log.txt"

DRY_RUN = False  # flip to True to validate without writing

# ── 1. Text cleaning ───────────────────────────────────────────────────────────

_TERMINAL = 'ःंाूुेैोौँ'

# Patterns to remove font-artifact doublings.
# PAT3: any ≥3-char Devanagari sequence repeated (catches suffixes like "दशालयाःदशालयाः")
# PAT2: 2-char sequence (Devanagari + word-final mark) repeated ("यंयं","वौवौ")
# PAT_MATRA: single dependent vowel sign repeated ("аа" artefact after a word)
# PAT_VISARGA: double visarga "ःः" or double anusvara "ंं"
_PAT3       = re.compile(r'([ऀ-ॿ]{3,})\1')
_PAT2       = re.compile(r'([ऀ-ॿ][' + _TERMINAL + r'])\1')
_PAT_MATRA  = re.compile(r'([ािीुूृेैोौ])\1')      # doubled dependent vowel sign
_PAT_VSRG   = re.compile(r'([ःं])\1')              # doubled visarga or anusvara

_PAGE_HDR = re.compile(r'अमरकोश[ऀ-ॿ]*?काण्ड[ड]?[१-९०]*', re.DOTALL)
_SITE_URL = re.compile(r'sanskritdocuments?\b.*', re.IGNORECASE | re.DOTALL)

def clean_pdf_text(raw: str) -> str:
    """Remove PDF page-artifact text and font-doubling from a pada's text."""
    raw = _SITE_URL.sub('', raw)      # remove "sanskritdocuments" and everything after
    raw = _PAGE_HDR.sub('', raw)      # remove repeated page header
    # Remove English section labels (e.g. "Heaven 9", "Brahma 29")
    raw = re.sub(r'\b[A-Za-z][A-Za-z0-9 ,.\'-]*[A-Za-z0-9]', '', raw)
    raw = re.sub(r'\b\d+\b', '', raw)
    # Remove Sanskrit section-end markers at end of string
    raw = re.sub(r'\s*इति[ऀ-ॿ\s।॥]+$', '', raw.rstrip())
    raw = re.sub(r'\s+', ' ', raw).strip()

    # Iterative font-doubling removal
    prev = None
    while raw != prev:
        prev = raw
        raw = _PAT3.sub(r'\1', raw)       # ≥3-char repeat
        raw = _PAT2.sub(r'\1', raw)       # 2-char terminal repeat
        raw = _PAT_MATRA.sub(r'\1', raw)  # doubled vowel sign (ааа→а)
        raw = _PAT_VSRG.sub(r'\1', raw)   # doubled visarga/anusvara

    # Strip lone leading dependent vowel sign (artifact: matra without consonant)
    # IMPORTANT: only strip actual matras (U+093E–U+094C range), NOT consonants.
    raw = re.sub(r'^[ािीुूृेैोौ]', '', raw)

    return raw.strip()


# ── 2. Placeholder detection ──────────────────────────────────────────────────

def is_placeholder(text: str) -> bool:
    """True if text is an unusable placeholder: empty OR IAST romanisation."""
    if not text:
        return True  # empty — can't use for similarity matching
    dev_chars   = len(re.findall(r'[ऀ-ॿ]', text))
    total_chars = len(re.sub(r'\s', '', text))
    return total_chars > 3 and dev_chars / total_chars < 0.3


def is_iast(text: str) -> bool:
    return is_placeholder(text)


def word_overlap(words: list, pdf_text: str) -> int:
    """Count how many words from the list appear in the PDF text."""
    norm = re.sub(r'[\s।॥]', '', pdf_text)
    return sum(1 for w in words if w.get('w', '') and w.get('w', '') in norm)


# ── 3. PDF extraction ──────────────────────────────────────────────────────────

def dev_to_int(s: str) -> int:
    d = {'०':'0','१':'1','२':'2','३':'3','४':'4','५':'5','६':'6','७':'7','८':'8','९':'9'}
    return int(''.join(d.get(c, c) for c in s))

def extract_pdf_padas(pdf_path: str):
    """Return [(id_str, clean_text), ...] for every pada in the PDF."""
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


# ── 4. Similarity ──────────────────────────────────────────────────────────────

def normalize(text: str) -> str:
    return re.sub(r'[\s।॥]', '', text)

def similarity(a: str, b: str) -> float:
    a, b = normalize(a), normalize(b)
    if not a or not b: return 0.0
    if a == b:        return 1.0
    m, n = len(a), len(b)
    if m * n > 40000:
        shorter = a if m <= n else b
        longer  = b if m <= n else a
        return sum(c in longer for c in shorter) / max(m, n)
    dp = [[0] * (n + 1) for _ in range(m + 1)]
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if a[i-1] == b[j-1]:
                dp[i][j] = dp[i-1][j-1] + 1
            else:
                dp[i][j] = max(dp[i-1][j], dp[i][j-1])
    return dp[m][n] / max(m, n)


# ── 5. Align padas within one varga ───────────────────────────────────────────

THRESHOLD = 0.55

def align_varga(pdf_padas, json_padas_all, label, log):
    """
    pdf_padas     : [(id, text), ...]  — ordered, authoritative
    json_padas_all: [pada_dict, ...]   — ordered; may contain IAST/empty fakes

    Returns new list of pada dicts with correct IDs and updated text.
    IAST and empty-text padas are filtered before alignment; missing padas are
    inserted with PDF text. For matched padas: ID is updated but text_dev is
    kept from JSON. Empty-text padas with words are recovered post-alignment.
    """
    # Filter out IAST and empty-text placeholders
    json_padas = [p for p in json_padas_all if not is_placeholder(p.get('text_dev', ''))]
    placeholders = [p for p in json_padas_all if is_placeholder(p.get('text_dev', ''))
                    and p.get('words')]  # empty-text with word data worth recovering
    placeholder_count = len(json_padas_all) - len(json_padas)
    if placeholder_count:
        log.append(f"  Filtering {placeholder_count} placeholder padas ({len(placeholders)} have words)")

    result = []
    j = 0

    for pdf_id, pdf_text in pdf_padas:
        # Find best match in next 3 JSON positions (handles slight misalignments)
        best_j, best_sim = j, 0.0
        for look in range(j, min(j + 3, len(json_padas))):
            s = similarity(pdf_text, json_padas[look].get('text_dev', ''))
            if s > best_sim:
                best_sim, best_j = s, look

        if best_sim >= THRESHOLD:
            # Skip any JSON padas before the best match (not present in this PDF edition)
            for k in range(j, best_j):
                log.append(f"  SKIP_JSON {json_padas[k]['id']} (no PDF match in this edition)")
            j = best_j
            # Match — update ID but keep the existing clean Devanagari text
            new_p = dict(json_padas[j])
            old_id = new_p['id']
            new_p['id'] = pdf_id
            result.append(new_p)
            if old_id != pdf_id:
                log.append(f"  RENUMBER  {old_id} → {pdf_id}")
            j += 1
        else:
            # Missing — insert minimal entry with PDF text
            result.append({
                'id':        pdf_id,
                'legacy_id': '',
                'text_dev':  pdf_text,
                'words':     []
            })
            log.append(f"  INSERT    {pdf_id}  \"{pdf_text[:70]}\"")

    # Skip any remaining JSON padas (tail: no PDF pada remaining)
    while j < len(json_padas):
        log.append(f"  SKIP_JSON {json_padas[j]['id']} (tail: no PDF pada remaining)")
        j += 1

    # Word recovery: for newly inserted padas with empty words, try to find a
    # matching empty-text placeholder by word overlap with the PDF text.
    if placeholders:
        used = set()
        for rp in result:
            if rp.get('words'):
                continue
            best_score, best_ep = 0, None
            for ep in placeholders:
                eid = id(ep)
                if eid in used:
                    continue
                score = word_overlap(ep['words'], rp.get('text_dev', ''))
                if score > best_score:
                    best_score, best_ep = score, ep
            if best_score >= 2 and best_ep:
                rp['words'] = best_ep['words']
                used.add(id(best_ep))
                log.append(f"  WORD_RECOVERY {rp['id']} ← {best_ep['id']} ({best_score} words matched)")

    return result


# ── 6. Rebuild varga sections ─────────────────────────────────────────────────

def rebuild_sections(old_sections, new_padas):
    old_sec_idx = {
        p['id']: si
        for si, sec in enumerate(old_sections)
        for p in sec.get('padas', [])
    }
    section_padas = [[] for _ in old_sections]
    last_si = 0
    for np in new_padas:
        if np['id'] in old_sec_idx:
            last_si = old_sec_idx[np['id']]
        section_padas[last_si].append(np)
    new_sections = []
    for si, sec in enumerate(old_sections):
        new_sec = dict(sec)
        new_sec['padas'] = section_padas[si]
        new_sections.append(new_sec)
    # Drop completely empty sections that had no padas originally
    return [s for s in new_sections if s.get('padas') or not old_sections[new_sections.index(s)].get('padas')]


# ── 7. Main ────────────────────────────────────────────────────────────────────

def main():
    log = []

    print("Extracting PDF padas...")
    pdf_padas_all = extract_pdf_padas(PDF_PATH)
    print(f"  Total PDF padas: {len(pdf_padas_all)}")

    from collections import defaultdict
    pdf_by_varga = defaultdict(list)
    for pid, pt in pdf_padas_all:
        pdf_by_varga['.'.join(pid.split('.')[:2])].append((pid, pt))

    for kv in sorted(pdf_by_varga, key=lambda x: [int(n) for n in x.split('.')]):
        print(f"  PDF varga {kv}: {len(pdf_by_varga[kv])} padas")

    print("\nLoading JSON...")
    data = json.load(open(JSON_PATH, encoding='utf-8'))
    k1   = data['kandas'][0]

    log.append("=== Kanda 1 update ===\n")
    total_before = sum(sum(len(s['padas']) for s in v['sections']) for v in k1['vargas'])
    log.append(f"Padas before: {total_before}")

    for vi, varga in enumerate(k1['vargas']):
        json_padas = [p for sec in varga['sections'] for p in sec['padas']]
        kv = '.'.join(json_padas[0]['id'].split('.')[:2]) if json_padas else f"1.{vi+1}"
        pdf_padas = pdf_by_varga.get(kv, [])
        label = f"Varga {kv}"
        log.append(f"\n--- {label}: JSON={len(json_padas)} PDF={len(pdf_padas)} ---")

        if not pdf_padas:
            log.append("  (no PDF padas found)")
            continue

        new_padas = align_varga(pdf_padas, json_padas, label, log)
        varga['sections'] = rebuild_sections(varga['sections'], new_padas)
        log.append(f"  Result: {len(new_padas)} padas")

    total_after = sum(sum(len(s['padas']) for s in v['sections']) for v in k1['vargas'])
    log.append(f"\nPadas after: {total_after}")
    print(f"\nKanda 1: {total_before} → {total_after} padas")

    with open(LOG_PATH, 'w', encoding='utf-8') as f:
        f.write('\n'.join(log))
    print(f"Log → {LOG_PATH}")

    if DRY_RUN:
        print("DRY RUN — JSON not written.")
        return

    print(f"Writing {OUT_PATH}...")
    with open(OUT_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print("Done.")

if __name__ == '__main__':
    main()
