"""Extract pada text using PyMuPDF."""
import sys, re
sys.stdout.reconfigure(encoding='utf-8')

import fitz  # PyMuPDF

PDF_PATH = r"C:\Users\srama\OneDrive\Personal\2026\Amara Kosha\amarfin1.pdf"

with fitz.open(PDF_PATH) as doc:
    print(f"Total pages: {len(doc)}")
    for i in range(min(4, len(doc))):
        page = doc[i]
        text = page.get_text()
        print(f"--- Page {i+1} ---")
        print(text[:800])
        print()
