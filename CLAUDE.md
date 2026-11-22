# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this app does

**Amarakosha Practice** is a Sanskrit recitation studio for memorizing the *Amarakosha* — a classical Sanskrit thesaurus. Users browse the text (Kāṇḍa → Varga → Section → Pāda), play reference audio, and build custom **Practice Sets** — curated playlists of pādas to drill with repeat counts and guided teacher/student cycles.

Key features:
- **Browse mode** — navigate the full corpus via a tree pane; context pādas shown above/below the active pāda.
- **Guided Practice** — set playback alternates model plays (full volume) with student recitation slots (low volume), configurable cycles and gap.
- **Practice Sets** — named playlists persisted in SharedPreferences; multiple sets supported.
- **Playlist view** — during set playback, a scrollable playlist shows all set pādas plus corpus-context pādas around the active one.
- **Voice recording** — record recitations pāda by pāda via `recorder.html`, export/import as ZIP audio sets.
- **Grammar Sheet** — long-press any word chip for case, gender, and vibhakti detail.

The primary deployment target is Flutter web (GitHub Pages). The recording and audio-set features are web-only due to IndexedDB / JS-interop dependencies.

## Commands

```bash
# Run in Chrome (primary target)
flutter run -d chrome

# Build for web
flutter build web --release --base-href /amarakosha/

# Deploy to GitHub Pages (Windows)
.\deploy.ps1

# Deploy to GitHub Pages (macOS/Linux)
./deploy.sh

# Analyze
flutter analyze

# Run tests
flutter test
```

## Architecture

### Data model (`lib/domain/entities/entities.dart`)

Pure Dart entities, no framework. The hierarchy is:

```
Kanda (book)
  └─ Varga (chapter)
       └─ Section (semantic group, from GRETIL ## markers)
            └─ Pada (half-verse line, e.g. "1.1.11")
                 └─ AWord (word with meaning, gender, case)
```

**`Pada.id`** is the canonical GRETIL reference (e.g. `"1.1.11"`) used as the primary key everywhere — in audio filenames, recording keys, and practice set serialization. The `legacyId` field (`k.v.csv_shloka.pada`) is kept for backwards compatibility only.

**`Session`** is passed between screens to carry the current Kanda/Varga/Section and practice mode. It is not persisted — navigation state lives in `_AppShellState`.

### Navigation (`lib/main.dart`)

No `Navigator` or named routes. `_AppShellState` maintains a manual `List<Widget> _stack`. Pushing a screen calls `setState(() => _stack.add(w))`, popping calls `_stack.removeLast()`. The bottom tab bar (Home / Browse) uses `IndexedStack`; `PracticeScreen` is pushed on top as a stack overlay.

`PracticeScreen` constructor flags:
- `initialSetIdx` — which saved practice set to select on load
- `startWithNewSet` — open the new-set creation flow immediately
- `showSetPanel` — open the set panel on load (used when continuing a saved set from Home)

### Data loading (`lib/data/repositories/static_data.dart`)

`amarakosha_v3.json` is loaded once and cached in a module-level `_cache` variable. Bootstrap constants (`kBootstrapKanda`, `kBootstrapPada`, etc.) provide immediate first-frame data before the async JSON load completes, avoiding a loading spinner on the tree view.

### Audio pipeline (`lib/data/repositories/audio_service.dart`)

`AudioService` is a singleton wrapping a single `just_audio` `AudioPlayer`. Priority order for `playPada(gretilId)`:

1. Named audio set (ZIP imported by user) — via `AudioSetStore`
2. User's own recording — blob URL / file path in `userRecordings` map
3. Bundled asset `assets/audio/<gretilId>.wav` (preferred)
4. Bundled asset `assets/audio/<gretilId>.m4a` (fallback)
5. Silent (returns `false`)

**Web asset URL quirk**: Flutter web places assets at `{root}/assets/{pubspec-key}`. Since the pubspec key already starts with `assets/`, audio URLs get a double prefix: `assets/assets/audio/1.1.11.wav`. This is intentional — see the comment in `audio_service.dart`.

### Persistence

| Store | What | Platform |
|---|---|---|
| `RecordingStore` | User voice recordings as WAV blob URLs | Web (IndexedDB via JS interop) |
| `AudioSetStore` | Named ZIP audio sets | Web (IndexedDB via JS interop) |
| `AppSettings` | Display settings (font size, weight, context lines, recite volume) | All (shared_preferences) |
| `SharedPreferences` | Practice sets serialized as JSON under key `amarakosha_practice_sets_v2` | All |

The web implementations use conditional imports: `_web.dart` files contain `dart:js_interop` code; `_stub.dart` files are no-ops used when `dart.library.io` is available (native platforms).

### State management

No Riverpod in practice (listed in pubspec but unused). State is plain `StatefulWidget`. `AppSettings` is a `ChangeNotifier` singleton — screens subscribe via `addListener` / `ListenableBuilder`.

### HTML web tools (recorder / editor / help)

`web/recorder.html`, `tools/editor.html`, and `web/help.html` share the same four-theme CSS system as the Flutter app:

- Theme is stored in `localStorage` under key `amara-theme` and applied via `html[data-theme="id"]` CSS attribute — no flash on load because a tiny `<script>` in `<head>` sets the attribute before any paint.
- Four colored dot buttons in each page header switch and persist the theme.
- CSS variables used: `--bg`, `--surface`, `--surface-alt`, `--text`, `--text-sec`, `--text-muted`, `--accent`, `--border`, `--border-lt`, `--btn-bg`, `--btn-text`, `--green`, `--green-bg`, `--red`/`--rec`, `--red-bg`.
- The editor adds `--accent-lt`; the recorder uses `--rec` instead of `--red`.

### Data pipeline (`tools/update_kanda1.py`)

`update_kanda1.py` rebuilds Kanda 1 pādas in `amarakosha_v3.json` to match a reference PDF (`amarfin1.pdf`). Key steps:

1. **PDF extraction** — PyMuPDF extracts Devanagari text; font-artifact character doubling is removed by regex passes (`_PAT3`, `_PAT2`, `_PAT_MATRA`, `_PAT_VSRG`).
2. **Placeholder filtering** — JSON pādas whose `text_dev` is empty or mostly IAST are excluded from alignment but their `words` data is preserved for later recovery.
3. **LCS similarity alignment** — greedy forward scan with `similarity()` (LCS-based, threshold 0.55) matches PDF pādas to JSON pādas; unmatched PDF pādas are inserted; JSON pādas absent from the PDF edition are skipped.
4. **Word recovery** — after alignment, inserted pādas with no words are matched to filtered placeholders by word-overlap (≥ 2 words); matched words are transferred.

`dryrun_align.py` runs the same logic and writes a report to `tools/dryrun_out.txt` without touching the JSON.

### Theme (`lib/core/theme/app_theme.dart`)

Three token classes — never use raw colors or `TextStyle(...)` inline:

- **`AC`** — color getters delegating to `AppSettings.instance.colors` (e.g. `AC.bg`, `AC.accent`, `AC.sidebar`). All are `static Color get`, never `static const` — do not add `const` to any widget that references `AC.*`.
- **`AT`** — text style factory methods (`AT.garamond(size, ...)` for UI text, `AT.devanagari(size, ...)` for Sanskrit)
- **`AD`** — box decoration helpers (`AD.card(...)`, `AD.chip()`, etc.)

Four themes are defined in `AppColorSchemes`:
- **Parchment** (`id: 'parchment'`) — warm cream and terracotta, default
- **Night** (`id: 'night'`) — dark warm background with amber accents
- **Slate** (`id: 'slate'`) — cool grey-blue with steel-blue accents
- **Minimal** (`id: 'minimal'`) — clean white/zinc with indigo accents

`AppSettings.themeId` stores the active theme; `AppSettings.instance.colors` returns the matching `AppColorScheme`. The `AmarakoshaApp` widget wraps `MaterialApp` in a `ListenableBuilder` so theme changes rebuild the full tree. `_AppShellState` also subscribes to `AppSettings` for Scaffold/tab-bar color updates.

Sanskrit text always uses `TiroDevanagarSanskrit` (bundled TTF) or `NotoSerifDevanagari` (via `google_fonts`). UI text always uses EB Garamond (via `google_fonts`).

### Key asset files

- `assets/data/amarakosha_v3.json` — canonical text (GRETIL-based, structured as kandas → vargas → sections → padas → words)
- `assets/audio/<gretilId>.wav` — bundled audio recordings keyed by GRETIL ID
- `web/recorder.html` — standalone recording studio (separate HTML page, links from Home screen)
- `web/landing.html` — landing/about page, linked from the Home screen header
- `web/help.html` — help page, linked from the Home screen
- `tools/editor.html` — offline JSON editor for the corpus data
- `tools/strip_fields.py` — strips fields from the JSON for distribution
- `tools/update_kanda1.py` — rebuilds Kanda 1 pādas in the JSON from `amarfin1.pdf` (see below)
- `tools/dryrun_align.py` — dry-run of the Kanda 1 alignment without writing the JSON

### Feedback & bug reporting

Bug reports and improvement suggestions are collected via the GitHub Issues tracker at `https://github.com/sramaka/amarakosha/issues`. There are two entry points in the app:

- **Home screen** (`lib/presentation/screens/home_screen.dart`) — "Report a bug or error" link at the bottom of the page (small italic text, opens GitHub Issues in a new tab).
- **Help page** (`web/help.html`) — "Feedback & Bug Reports" section near the bottom with a direct link.

Both open the GitHub Issues URL. When editing the home screen or help page, preserve these links.

### Responsive layout

`_isMobile` is `MediaQuery.of(context).size.width <= 768`. On mobile, the tree pane becomes a slide-in overlay (`_buildMobileTreeOverlay`) and the Practice Set panel becomes a modal bottom sheet accessed via a tray at the bottom of the practice screen.

---

## Practice Screen details (`lib/presentation/screens/practice_screen.dart`)

### Pada box (`_buildPadaBox`)

Shows all context pādas in a **single unified box** — context-before, active, context-after. Context extends **across section and varga boundaries** using a flat list of all pādas in the corpus (`_buildBoxEntries`). Varga and section headings are inserted at boundaries. The active pāda is highlighted with `AD.activeLine()`; inactive pādas are tappable (navigate to that pāda) and rendered at reduced opacity. All text is left-aligned with `width: double.infinity` on the active container.

### Prev / Next navigation

When not in set-playback mode, `_buildPrevNext()` shows Prev / Next buttons below the pada box for linear navigation through the corpus.

### Practice Set playlist view (`_buildSetPlaylistView`)

When a practice set is playing (`_setPlaying`) or paused at a step (`_waitingForStep`), the practice pane switches to a **playlist view**: a scrollable list of all pādas in the set, with the current pāda highlighted and others dimmed. Auto-scrolls to the current pāda via `GlobalKey _activePadaPlaylistKey` + `Scrollable.ensureVisible` in a `addPostFrameCallback`.

### Guided Practice playback model

Controlled by two settings:

- **`_modelCount`** ("Teacher plays") — how many full cycles to run per pāda. Each cycle = one model play followed by `_reciteCount` student recitations.
- **`_reciteCount`** ("Student recites") — how many times the student recites within each cycle.

For `modelCount=2, reciteCount=2`, the sequence per pāda is:
```
rep 0: model (full vol)   ← cycle 0
rep 1: student (low vol)
rep 2: student (low vol)
rep 3: model (full vol)   ← cycle 1
rep 4: student (low vol)
rep 5: student (low vol)
```

Implemented via `cyclePos = _setCurPadaRep % (1 + _reciteCount)`. `cyclePos == 0` → model play; `cyclePos > 0` → student play. Total reps = `_modelCount * (1 + _reciteCount)`.

The "Student volume" setting (`AppSettings.reciteVolumePct`) controls playback volume during student reps. A configurable gap (`_reciteGapSec`) can be inserted between consecutive student recitations within a cycle.

### Set panel

Shown as a side panel on desktop, a modal bottom sheet on mobile. The Set button is always visible in the nav bar (both mobile and desktop). Opening `PracticeScreen` with `showSetPanel: true` opens the panel immediately.
