#!/usr/bin/env python3
"""Import an edited XLSX back into amarakosha_v3.json.

What gets updated from the Padas sheet:
  text_dev, review, review_comment
  section_title_en — if changed, sections for that varga are rebuilt so padas
                     are regrouped according to the new titles (new sections
                     are created, empty sections removed, pada order preserved).

What gets updated from the Words sheet:
  All word fields; the words list is fully replaced for each pada present.

A timestamped backup of the JSON is written before any changes.

Usage:
    python tools/import_xlsx.py tools/amarakosha_export.xlsx
    python tools/import_xlsx.py path/to/edited.xlsx [--dry-run]
"""
import json
import sys
import shutil
from collections import defaultdict
from datetime import datetime
from pathlib import Path

try:
    import openpyxl
except ImportError:
    sys.exit("Run:  pip install openpyxl")

ROOT = Path(__file__).parent.parent
JSON_PATH = ROOT / "assets" / "data" / "amarakosha_v3.json"

WORD_FIELDS = [
    "w", "artha", "linga", "vibhakti", "vacana",
    "stem_iast", "form_iast", "case_en", "form_note",
]


def _sheet_rows(ws):
    rows = list(ws.iter_rows(values_only=True))
    if not rows:
        return [], []
    hdr = [str(c) if c is not None else "" for c in rows[0]]
    return hdr, rows[1:]


def _str(v):
    return "" if v is None else str(v).strip()


def main():
    args = sys.argv[1:]
    dry_run = "--dry-run" in args
    paths = [a for a in args if not a.startswith("--")]

    if not paths:
        sys.exit(f"Usage: python {Path(__file__).name} <path_to_xlsx> [--dry-run]")

    xlsx_path = Path(paths[0])
    if not xlsx_path.exists():
        sys.exit(f"Not found: {xlsx_path}")

    print(f"Reading XLSX : {xlsx_path.resolve()}")
    # data_only=True reads cached cell values; read_only=True is omitted because
    # it mis-decodes shared strings in Excel-edited files, returning None for
    # cells that have values.
    wb = openpyxl.load_workbook(xlsx_path, data_only=True)

    missing_sheets = [s for s in ("Padas", "Words") if s not in wb.sheetnames]
    if missing_sheets:
        sys.exit(f"Missing sheets: {missing_sheets}. Run export_xlsx.py first.")

    # ── Parse Padas sheet ─────────────────────────────────────────────────────
    pada_hdr, pada_rows = _sheet_rows(wb["Padas"])
    print(f"  Padas sheet headers : {pada_hdr}")
    sheet_padas = []
    seen_ids = set()
    for row in pada_rows:
        r = dict(zip(pada_hdr, row))
        pid = _str(r.get("pada_id"))
        if not pid or pid in seen_ids:
            continue
        seen_ids.add(pid)
        try:
            pada_num = int(r.get("pada_num") or 1)
        except (ValueError, TypeError):
            pada_num = 1
        sheet_padas.append({
            "pada_id":          pid,
            "varga_id":         _str(r.get("varga_id")),
            "text_dev":         _str(r.get("text_dev")),
            "section_title_en": _str(r.get("section_title_en")),
            "pada_num":         pada_num,
            "shloka_id":        _str(r.get("shloka_id")),
            "review":           _str(r.get("review")).lower() in ("yes", "true", "1"),
            "review_comment":   _str(r.get("review_comment")),
        })

    with_text = sum(1 for p in sheet_padas if p["text_dev"])
    print(f"  Padas in sheet      : {len(sheet_padas)} ({with_text} with non-empty text_dev)")

    # ── Parse Words sheet ──────────────────────────────────────────────────────
    word_hdr, word_rows = _sheet_rows(wb["Words"])
    print(f"  Words sheet headers : {word_hdr}")
    word_updates_raw = defaultdict(list)
    for row in word_rows:
        r = dict(zip(word_hdr, row))
        pid = _str(r.get("pada_id"))
        if not pid:
            continue
        try:
            wi = int(r.get("word_idx") or 0)
        except (ValueError, TypeError):
            wi = 0
        word_updates_raw[pid].append((wi, {f: _str(r.get(f)) for f in WORD_FIELDS}))

    word_updates = {
        pid: [w for _, w in sorted(pairs)]
        for pid, pairs in word_updates_raw.items()
    }

    print(f"  Word entries        : {sum(len(v) for v in word_updates.values())}")

    if dry_run:
        print("Dry-run -- no files written.")
        return

    # ── Load JSON, build indexes ──────────────────────────────────────────────
    print(f"Reading JSON: {JSON_PATH.resolve()}")
    data = json.loads(JSON_PATH.read_text(encoding="utf-8"))

    pada_obj: dict[str, dict] = {}       # pada_id → pada dict
    pada_section: dict[str, dict] = {}   # pada_id → section dict (current)
    varga_obj: dict[str, dict] = {}      # varga_id → varga dict
    for k in data["kandas"]:
        for v in k["vargas"]:
            varga_obj[v["id"]] = v
            for s in v["sections"]:
                for p in s["padas"]:
                    pada_obj[p["id"]] = p
                    pada_section[p["id"]] = s

    # ── Backup ────────────────────────────────────────────────────────────────
    backup = JSON_PATH.with_name(
        f"amarakosha_v3.bak_{datetime.now():%Y%m%d_%H%M%S}.json"
    )
    shutil.copy(JSON_PATH, backup)
    print(f"Backup -> {backup.name}")

    # ── Apply pada-level updates (text, review, words); insert new padas ────────
    updated_text = 0
    updated_words = 0
    inserted_padas = 0
    new_pada_vids: set[str] = set()  # vargas where new padas were added

    for row in sheet_padas:
        pid = row["pada_id"]
        if pid not in pada_obj:
            vid = row["varga_id"]
            if not vid or vid not in varga_obj:
                print(f"  WARNING: pada_id '{pid}' not in JSON and varga_id '{vid}' unknown -- skipped.")
                continue
            # Create a new pada object; seq=0 will be renumbered in section rebuild.
            new_p: dict = {
                "id":        pid,
                "seq":       0,
                "pada_num":  row["pada_num"],
                "shloka_id": row["shloka_id"],
                "legacyId":  "",
                "text_dev":  row["text_dev"],
                "words":     [],
            }
            if row["review"]:
                new_p["review"] = True
                if row["review_comment"]:
                    new_p["review_comment"] = row["review_comment"]
            pada_obj[pid] = new_p
            new_pada_vids.add(vid)
            inserted_padas += 1
            print(f"  New pada: {pid} (varga {vid})")
            if pid in word_updates:
                new_p["words"] = word_updates[pid]
                updated_words += len(word_updates[pid])
            continue

        p = pada_obj[pid]

        if row["text_dev"]:
            p["text_dev"] = row["text_dev"]
            updated_text += 1

        if row["review"]:
            p["review"] = True
            if row["review_comment"]:
                p["review_comment"] = row["review_comment"]
            else:
                p.pop("review_comment", None)
        else:
            p.pop("review", None)
            p.pop("review_comment", None)

        if pid in word_updates:
            p["words"] = word_updates[pid]
            updated_words += len(word_updates[pid])

    # ── Rebuild sections per varga from xlsx section_title_en grouping ─────────
    # Group xlsx rows by varga_id, preserving the order they appear in the sheet.
    varga_xlsx_rows: dict[str, list[dict]] = {}
    for row in sheet_padas:
        vid = row["varga_id"]
        if vid:
            varga_xlsx_rows.setdefault(vid, []).append(row)

    # Build a desired-section map: pada_id → section title from xlsx.
    desired_title: dict[str, str] = {
        row["pada_id"]: row["section_title_en"]
        for row in sheet_padas
        if row["section_title_en"]
    }

    updated_sections = 0
    for vid, xlsx_rows in varga_xlsx_rows.items():
        v = varga_obj.get(vid)
        if v is None:
            continue

        # Rebuild if section titles changed OR if new padas were added to this varga.
        needs_rebuild = (vid in new_pada_vids) or any(
            desired_title.get(row["pada_id"]) != pada_section.get(row["pada_id"], {}).get("title_en", "")
            for row in xlsx_rows
            if row["pada_id"] in pada_obj
        )
        if not needs_rebuild:
            continue

        # Use xlsx row order so new padas land in the position the editor intended.
        # Any JSON pada not present in the xlsx is appended at the end (safety net).
        seen: set[str] = set()
        all_pids: list[str] = []
        for row in xlsx_rows:
            rpid = row["pada_id"]
            if rpid in pada_obj and rpid not in seen:
                all_pids.append(rpid)
                seen.add(rpid)
        for s in v["sections"]:
            for p in s["padas"]:
                if p["id"] not in seen:
                    all_pids.append(p["id"])
                    seen.add(p["id"])

        # Assign each pada its new section title (xlsx wins; fall back to current).
        new_sections: list[dict] = []
        cur_title: str | None = None
        cur_sec: dict | None = None
        for pid in all_pids:
            title = desired_title.get(pid) or pada_section.get(pid, {}).get("title_en", "")
            if title != cur_title:
                cur_sec = {"title_en": title, "padas": []}
                new_sections.append(cur_sec)
                cur_title = title
            cur_sec["padas"].append(pada_obj[pid])  # type: ignore[union-attr]

        # Renumber seq within each new section so Dart navigation stays correct.
        for new_sec in new_sections:
            for i, p in enumerate(new_sec["padas"]):
                p["seq"] = i + 1

        old_count = len(v["sections"])
        v["sections"] = new_sections
        updated_sections += 1
        print(f"  Rebuilt varga {vid}: {old_count} → {len(new_sections)} sections")

    # ── Write ─────────────────────────────────────────────────────────────────
    JSON_PATH.write_text(
        json.dumps(data, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print(f"Written JSON     : {JSON_PATH.resolve()}")
    print(f"Inserted padas   : {inserted_padas} new")
    print(f"Text updates     : {updated_text} padas")
    print(f"Section updates  : {updated_sections} sections")
    print(f"Word updates     : {updated_words} words across {len(word_updates)} padas")


if __name__ == "__main__":
    main()
