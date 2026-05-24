#!/usr/bin/env python3
"""Export amarakosha_v3.json to an XLSX workbook.

Sheet 1 "Padas"  — one row per pada (text, review flags)
Sheet 2 "Words"  — one row per word, linked to Padas by pada_id

Usage:
    python tools/export_xlsx.py                        # writes tools/amarakosha_export.xlsx
    python tools/export_xlsx.py path/to/output.xlsx
"""
import json
import sys
from pathlib import Path

try:
    import openpyxl
    from openpyxl.styles import Font, PatternFill
    from openpyxl.utils import get_column_letter
except ImportError:
    sys.exit("Run:  pip install openpyxl")

ROOT = Path(__file__).parent.parent
JSON_PATH = ROOT / "assets" / "data" / "amarakosha_v3.json"

PADA_COLS = [
    "pada_id", "kanda_num", "kanda_name_dev",
    "varga_id", "varga_seq", "varga_name_dev",
    "section_title_en",
    "pada_num", "shloka_id",
    "text_dev",
    "review", "review_comment",
]

WORD_COLS = [
    "pada_id", "word_idx",
    "w", "artha", "linga", "vibhakti", "vacana",
    "stem_iast", "form_iast", "case_en", "form_note",
]

HDR_FONT = Font(bold=True)
HDR_FILL = PatternFill("solid", fgColor="D9E1F2")


def _hdr(ws, cols):
    for col, name in enumerate(cols, 1):
        c = ws.cell(1, col, name)
        c.font = HDR_FONT
        c.fill = HDR_FILL
    ws.freeze_panes = "A2"


def _autowidth(ws):
    for col_cells in ws.columns:
        max_len = max((len(str(c.value or "")) for c in col_cells), default=4)
        ws.column_dimensions[get_column_letter(col_cells[0].column)].width = min(max_len + 2, 45)


def main():
    out_path = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "tools" / "amarakosha_export.xlsx"

    print(f"Reading JSON: {JSON_PATH.resolve()}")
    data = json.loads(JSON_PATH.read_text(encoding="utf-8"))

    wb = openpyxl.Workbook()
    ws_p = wb.active
    ws_p.title = "Padas"
    ws_w = wb.create_sheet("Words")

    _hdr(ws_p, PADA_COLS)
    _hdr(ws_w, WORD_COLS)

    pr = 2  # next Padas row
    wr = 2  # next Words row

    for k in data["kandas"]:
        for v in k["vargas"]:
            for s in v["sections"]:
                for p in s["padas"]:
                    pid = p["id"]
                    pada_row = [
                        pid,
                        k["num"], k.get("name_dev", ""),
                        v["id"], v["seq"], v.get("name_dev", ""),
                        s.get("title_en", ""),
                        p.get("pada_num", ""), p.get("shloka_id", ""),
                        p.get("text_dev", ""),
                        "yes" if p.get("review") else "",
                        p.get("review_comment", ""),
                    ]
                    for col, val in enumerate(pada_row, 1):
                        ws_p.cell(pr, col, val)
                    pr += 1

                    for wi, w in enumerate(p.get("words") or []):
                        word_row = [
                            pid, wi,
                            w.get("w", ""), w.get("artha", ""), w.get("linga", ""),
                            w.get("vibhakti", ""), w.get("vacana", ""),
                            w.get("stem_iast", ""), w.get("form_iast", ""),
                            w.get("case_en", ""), w.get("form_note", ""),
                        ]
                        for col, val in enumerate(word_row, 1):
                            ws_w.cell(wr, col, val)
                        wr += 1

    _autowidth(ws_p)
    _autowidth(ws_w)

    wb.save(out_path)
    print(f"Exported {pr - 2} padas and {wr - 2} words -> {out_path}")


if __name__ == "__main__":
    main()
