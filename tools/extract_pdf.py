"""Extract pada text and IDs from amarfin1.pdf."""
import sys, re
sys.stdout.reconfigure(encoding='utf-8')

import pdfplumber

PDF_PATH = r"C:\Users\srama\OneDrive\Personal\2026\Amara Kosha\amarfin1.pdf"

# Collect all text from Kanda 1
all_text = []
with pdfplumber.open(PDF_PATH) as pdf:
    print(f"Total pages: {len(pdf.pages)}")
    for i, page in enumerate(pdf.pages):
        text = page.extract_text()
        if text:
            all_text.append(text)
        if i < 3:
            print(f"--- Page {i+1} ---")
            print(text[:500] if text else "(no text)")
            print()
