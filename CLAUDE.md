# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this app does

**Amarakosha Practice** is a Sanskrit recitation studio for memorizing the *Amarakosha* — a classical Sanskrit thesaurus. The app presents the text at three levels of difficulty and plays recorded audio for each half-verse line (pāda):

- **Listen** — text and audio shown; student follows along
- **Recite** — text hidden until tapped; student recites from memory
- **Guided** — text toggles on tap; hybrid drill mode

Users can also record their own voice for each pāda, build custom **Practice Sets** (curated lists of sections or pādas to drill with repeat counts), and import named audio sets (ZIP files exported from `recorder.html`) as alternative audio sources. Long-pressing a word chip opens a **Grammar Sheet** showing case, gender, and vibhakti detail.

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

# Run a single test file
flutter test test/widget_test.dart
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

No `Navigator` or named routes. `_AppShellState` maintains a manual `List<Widget> _stack`. Pushing a screen calls `setState(() => _stack.add(w))`, popping calls `_stack.removeLast()`. The bottom tab bar (Home / Browse / Record) uses `IndexedStack`; `PracticeScreen` is pushed on top as a stack overlay.

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
| `AppSettings` | Display settings (font size, weight, context lines) | All (shared_preferences) |
| `SharedPreferences` | Practice set (serialized pāda ID lists) | All |

The web implementations use conditional imports: `_web.dart` files contain `dart:js_interop` code; `_stub.dart` files are no-ops used when `dart.library.io` is available (native platforms).

### State management

No Riverpod in practice (listed in pubspec but unused). State is plain `StatefulWidget`. `AppSettings` is a `ChangeNotifier` singleton — screens subscribe via `addListener` / `ListenableBuilder`.

### Theme (`lib/core/theme/app_theme.dart`)

Three token classes — never use raw colors or `TextStyle(...)` inline:

- **`AC`** — color constants (warm parchment palette: `AC.bg`, `AC.accent`, `AC.sidebar`, etc.)
- **`AT`** — text style factory methods (`AT.garamond(size, ...)` for UI text, `AT.devanagari(size, ...)` for Sanskrit)
- **`AD`** — box decoration helpers (`AD.card(...)`, `AD.chip()`, etc.)

Sanskrit text always uses `TiroDevanagarSanskrit` (bundled TTF) or `NotoSerifDevanagari` (via `google_fonts`). UI text always uses EB Garamond (via `google_fonts`).

### Key asset files

- `assets/data/amarakosha_v3.json` — canonical text (GRETIL-based, structured as kandas → vargas → sections → padas → words)
- `assets/audio/<gretilId>.wav` — bundled audio recordings keyed by GRETIL ID
- `web/recorder.html` — standalone recording studio (separate HTML page, links from Home screen "Studio" button)
- `web/editor.html` / `tools/strip_fields.py` — offline data editing utilities

### Responsive layout

`_isMobile` is `MediaQuery.of(context).size.width <= 768`. On mobile, the tree pane becomes a slide-in overlay (`_buildMobileTreeOverlay`) and the Practice Set panel becomes a modal bottom sheet accessed via a tray at the bottom of the practice screen.
