# अमरकोशः — Amarakosha Practice

A Sanskrit recitation studio for memorizing the *Nāmaliṅgānuśāsana* of Amarasiṃha — a classical thesaurus of 2,865 pādas (half-verse lines) composed entirely in verse and organized by topic.

**Live site:** https://shashiramaka.github.io/amarakosha/

---

## What it does

- **Browse** the full corpus: Kāṇḍa → Varga → Section → Pāda
- **Listen** to bundled or teacher-recorded audio for any pāda
- **Practice Sets** — curated playlists with configurable repeat counts and guided teacher/student cycles
- **Recording Studio** (`recorder.html`) — teachers record pādas and export a Varga ZIP for students to import
- **Grammar chips** — long-press any word for case, gender, and vibhakti detail
- Five themes: Parchment, Night, Slate, Minimal, Forest

---

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel, ≥ 3.x)
- Chrome (primary test target for web)

---

## Running locally

```bash
# Get dependencies
flutter pub get

# Run in Chrome
flutter run -d chrome
```

The app opens at `http://localhost:PORT`. Hot-reload works normally.

---

## Building for production

```bash
flutter build web --release --base-href /amarakosha/
```

Output is written to `build/web/`. The `--base-href` flag is required because the app is served from a GitHub Pages subdirectory.

---

## Deploying to GitHub Pages

```powershell
# Windows
.\deploy.ps1
```

```bash
# macOS / Linux
./deploy.sh
```

Both scripts build the app and push `build/web/` to the `gh-pages` branch. Make sure you have write access to the remote before running.

---

## Static analysis and tests

```bash
flutter analyze
flutter test
```

---

## Project structure

```
lib/
  main.dart                     App entry, shell, manual nav stack
  domain/entities/entities.dart Data model (Kanda → Varga → Section → Pada → AWord)
  data/repositories/            Audio, recording, and corpus data services
  core/                         Theme tokens (AC/AT/AD) and AppSettings
  presentation/screens/         HomeScreen, PracticeScreen, RecordingScreen
  presentation/widgets/         Shared widgets and display settings sheet

assets/
  data/amarakosha_v3.json       Full corpus (GRETIL-based)
  audio/<gretilId>.wav          Bundled reference audio

web/
  recorder.html                 Teacher recording studio (standalone HTML)
  help.html                     User help page
  landing.html                  Overview / marketing page

tools/
  editor.html                   Offline corpus data editor
  update_kanda1.py              Rebuilds Kanda 1 pādas from reference PDF
```

For a full architecture walkthrough see [docs/architecture.md](docs/architecture.md).

---

## Data pipeline

The corpus lives in `assets/data/amarakosha_v3.json`. To rebuild Kanda 1 pādas from the reference PDF:

```bash
pip install pymupdf
python tools/update_kanda1.py
```

Run `python tools/dryrun_align.py` first to preview alignment without writing the JSON.

---

## Spreadsheet editing (export / import)

Bulk-edit the corpus in Excel or Google Sheets and round-trip it back to JSON.

```bash
pip install openpyxl
```

### Export

```bash
python tools/export_xlsx.py                      # writes tools/amarakosha_export.xlsx
python tools/export_xlsx.py path/to/out.xlsx     # custom path
```

Produces a two-sheet workbook:

| Sheet | Rows | Key columns |
|---|---|---|
| **Padas** | one per pāda | `pada_id`, `section_id`, `text_dev`, `text_iast`, `review`, `review_comment` |
| **Words** | one per word | `pada_id`, `word_idx`, `w`, `artha`, `linga`, `vibhakti`, `vacana`, `stem_iast`, `form_iast`, `case_en`, `form_note` |

### Import

```bash
python tools/import_xlsx.py path/to/edited.xlsx            # apply edits
python tools/import_xlsx.py path/to/edited.xlsx --dry-run  # preview counts only
```

What the import does:

- **Text fields** — updates `text_dev`, `text_iast`, `review`, `review_comment` for every pāda present in the sheet.
- **Words** — fully replaces each pāda's word list with the rows from the Words sheet (ordered by `word_idx`).
- **Section reassignment** — change the `section_id` cell in the Padas sheet to move a pāda to a different section.
- **Row ordering** — pādas within each section are rebuilt in the order they appear in the sheet, so reordering rows reorders pādas.
- **Absent pādas** — pādas not present in the sheet are left unchanged and appended at the end of their original section.
- **Backup** — a timestamped `.bak_YYYYMMDD_HHMMSS.json` copy is written next to the JSON before any changes.

---

## License

Text is based on the [GRETIL](https://gretil.sub.uni-goettingen.de/) digital edition. Audio and text are for educational use.
