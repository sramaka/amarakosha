// lib/presentation/screens/practice_screen.dart
//
// Two-pane practice screen:
//   Left pane  — collapsible tree: Kanda → Varga → Verse selector
//   Right pane — Listen / Recite / Guided modes, audio player, word chips
//
// Verse data loaded async from assets/data/amarakosha.json

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' hide LoopMode;
import '../../data/repositories/audio_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/static_data.dart';
import '../../domain/entities/entities.dart';
import '../sheets/grammar_sheet.dart';
import '../widgets/shared_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────

class PracticeScreen extends StatefulWidget {
  final Session session;
  final VoidCallback onBack;
  final VoidCallback onGoRecord;

  const PracticeScreen({
    super.key, required this.session,
    required this.onBack, required this.onGoRecord,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {

  // ── Data ────────────────────────────────────────────────────────────────────
  List<Kanda> _allKandas = [];
  bool _dataLoading = true;

  // Currently selected position
  late int _selKanda;   // kanda num
  late int _selVarga;   // varga seq
  late int _selShloka;  // shloka seq (1-based within varga)

  // The verse currently shown in the practice pane
  Verse? _verse;

  // ── Audio ───────────────────────────────────────────────────────────────────
  bool _playing = false;
  double _progress = 0;
  double _speed = 1.0;
  AudioSet _activeAudioSet = AudioSet.defaultSet;
  final AudioService _audio = AudioService.instance;

  // ── Practice ────────────────────────────────────────────────────────────────
  late PracticeMode _mode;
  final Set<int> _revealed = {};
  int _guidedLine = 0;
  bool _showWords = false;
  bool _loopOn = false;
  late LoopConfig _loop;
  int _curRep = 1;

  // ── UI state ─────────────────────────────────────────────────────────────────
  bool _treePaneOpen = true;
  final Set<int> _expandedKandas = {};

  @override
  void initState() {
    super.initState();
    _mode = widget.session.mode;
    _selKanda  = widget.session.kanda.num;
    _selVarga  = widget.session.varga.num;
    _selShloka = widget.session.verseFrom;
    _loop = LoopConfig(
      setFrom: widget.session.verseFrom,
      setTo:   widget.session.verseTo,
      setRepN: widget.session.repeatN,
      repN:    widget.session.repeatN,
    );
    _expandedKandas.add(_selKanda);
    _loadData();
    _bindAudioStream();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    final kandas = await loadKandas();
    if (!mounted) return;
    setState(() {
      _allKandas = kandas;
      _dataLoading = false;
    });
    _updateVerse();
  }

  void _updateVerse() {
    if (_allKandas.isEmpty) return;
    Verse? found;
    for (final k in _allKandas) {
      if (k.num != _selKanda) continue;
      for (final v in k.vargas) {
        if (v.num != _selVarga) continue;
        if (_selShloka <= v.shlokaList.length) {
          found = v.shlokaList[_selShloka - 1];
        }
        break;
      }
      break;
    }
    setState(() {
      _verse = found ?? kSampleVerse;
      _revealed.clear();
      _guidedLine = 0;
      _progress = 0;
      _curRep = 1;
    });
  }

  Varga? get _currentVarga {
    for (final k in _allKandas) {
      if (k.num != _selKanda) continue;
      for (final v in k.vargas) {
        if (v.num == _selVarga) return v;
      }
    }
    return null;
  }

  int get _vargaVerseCount => _currentVarga?.shlokaList.length ?? 1;

  void _goToShloka(int kanda, int varga, int shloka) {
    setState(() {
      _selKanda  = kanda;
      _selVarga  = varga;
      _selShloka = shloka;
    });
    _updateVerse();
  }

  void _prevVerse() {
    if (_selShloka > 1) {
      _goToShloka(_selKanda, _selVarga, _selShloka - 1);
    }
  }

  void _nextVerse() {
    if (_selShloka < _vargaVerseCount) {
      _goToShloka(_selKanda, _selVarga, _selShloka + 1);
    }
  }

  // ── Audio ─────────────────────────────────────────────────────────────────

  void _bindAudioStream() {
    _audio.player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _playing = state.playing;
        if (state.processingState == ProcessingState.completed) {
          _playing = false;
          _progress = 1.0;
        }
      });
    });
    _audio.player.positionStream.listen((pos) {
      if (!mounted) return;
      final dur = _audio.player.duration;
      if (dur != null && dur.inMilliseconds > 0) {
        setState(() => _progress = pos.inMilliseconds / dur.inMilliseconds);
      }
    });
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _audio.pause();
    } else {
      if (_verse == null) return;
      final found = await _audio.playPada(
        kanda: _selKanda, varga: _selVarga,
        verse: _selShloka, pada: 1, speed: _speed,
      );
      if (!found && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'No audio file found for this verse. '
            'Add .m4a files to assets/audio/ or record your own.'),
          duration: Duration(seconds: 3),
        ));
      }
    }
  }

  Future<void> _stopPlayback() async {
    await _audio.stop();
    setState(() { _playing = false; _progress = 0; _curRep = 1; });
  }

  void _switchMode(PracticeMode m) {
    _stopPlayback();
    setState(() {
      _mode = m;
      _revealed.clear();
      _guidedLine = 0;
    });
  }

  bool _highlightLine(int i) =>
      _loopOn && _loop.mode == LoopMode.padaRange &&
      (i + 1) >= _loop.lineA && (i + 1) <= _loop.lineB;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_dataLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AC.accent),
      );
    }
    return Column(children: [
      _buildNav(),
      Expanded(
        child: Row(children: [
          // Left tree pane
          if (_treePaneOpen) _buildTreePane(),
          // Divider
          if (_treePaneOpen)
            Container(width: 1, color: AC.border),
          // Right practice pane
          Expanded(child: _buildPracticePane()),
        ]),
      ),
    ]);
  }

  // ── Nav bar ───────────────────────────────────────────────────────────────

  Widget _buildNav() => Container(
    padding: const EdgeInsets.fromLTRB(12, 6, 16, 8),
    decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AC.border))),
    child: Column(children: [
      Row(children: [
        GestureDetector(
          onTap: widget.onBack,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const _ChevLeft(),
            const SizedBox(width: 4),
            Text('Back', style: AT.garamond(15, color: AC.accent)),
          ]),
        ),
        // Toggle tree
        GestureDetector(
          onTap: () => setState(() => _treePaneOpen = !_treePaneOpen),
          child: Container(
            margin: const EdgeInsets.only(left: 10),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _treePaneOpen ? AC.accent.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: _treePaneOpen ? AC.accent : AC.border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.account_tree_outlined,
                  size: 13, color: _treePaneOpen ? AC.accent : AC.textMuted),
              const SizedBox(width: 4),
              Text('Tree', style: AT.garamond(12,
                  color: _treePaneOpen ? AC.accent : AC.textMuted)),
            ]),
          ),
        ),
        Expanded(
          child: Center(
            child: Text(_verse?.id ?? '',
                style: AT.garamond(12, color: AC.textMuted, italic: true)),
          ),
        ),
        GestureDetector(
          child: Text('···', style: AT.garamond(20, color: AC.textMuted)),
        ),
      ]),
      const SizedBox(height: 8),
      // Mode segmented control
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AC.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(children: [
          _ModeSegment('Listen', PracticeMode.listen, _mode, _switchMode, 0),
          _ModeSegment('Recite', PracticeMode.recite, _mode, _switchMode, 1),
          _ModeSegment('Guided', PracticeMode.guided, _mode, _switchMode, 2),
        ]),
      ),
    ]),
  );

  // ── Tree pane ─────────────────────────────────────────────────────────────

  Widget _buildTreePane() => SizedBox(
    width: 220,
    child: Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AC.border))),
        child: Row(children: [
          Text('Verses'.toUpperCase(),
              style: AT.garamond(10, color: AC.textMuted, letterSpacing: 1.0)),
        ]),
      ),
      // Scrollable tree
      Expanded(
        child: ListView(
          children: _allKandas.map((kanda) {
            final expanded = _expandedKandas.contains(kanda.num);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Kanda row
              GestureDetector(
                onTap: () => setState(() {
                  if (expanded) _expandedKandas.remove(kanda.num);
                  else _expandedKandas.add(kanda.num);
                }),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  color: Colors.transparent,
                  child: Row(children: [
                    Icon(expanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_right_rounded,
                        size: 16, color: AC.accent),
                    const SizedBox(width: 4),
                    Expanded(child: Text(
                      kanda.name,
                      style: const TextStyle(
                        fontFamily: 'TiroDevanagarSanskrit',
                        fontSize: 13, color: AC.text,
                      ),
                    )),
                  ]),
                ),
              ),
              if (expanded)
                ...kanda.vargas.map((varga) => _buildVargaNode(kanda, varga)),
            ]);
          }).toList(),
        ),
      ),
    ]),
  );

  Widget _buildVargaNode(Kanda kanda, Varga varga) {
    final isSelVarga = kanda.num == _selKanda && varga.num == _selVarga;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Varga row
      GestureDetector(
        onTap: () {
          setState(() {
            _selKanda = kanda.num;
            _selVarga = varga.num;
            _selShloka = 1;
          });
          _updateVerse();
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 6, 10, 6),
          color: isSelVarga
              ? AC.accent.withOpacity(0.08)
              : Colors.transparent,
          child: Row(children: [
            Expanded(child: Text(
              varga.name,
              style: TextStyle(
                fontFamily: 'TiroDevanagarSanskrit',
                fontSize: 12,
                color: isSelVarga ? AC.accent : AC.textSec,
              ),
            )),
            Text(
              '${varga.shlokaList.length}',
              style: AT.garamond(10, color: AC.textMuted),
            ),
          ]),
        ),
      ),
      // Show verse list only for selected varga
      if (isSelVarga)
        ...varga.shlokaList.map((s) => _buildVerseNode(kanda, varga, s)),
    ]);
  }

  Widget _buildVerseNode(Kanda kanda, Varga varga, Verse shloka) {
    final isSel = kanda.num == _selKanda &&
        varga.num == _selVarga &&
        shloka.num == _selShloka;
    return GestureDetector(
      onTap: () => _goToShloka(kanda.num, varga.num, shloka.num),
      child: Container(
        padding: const EdgeInsets.fromLTRB(36, 5, 10, 5),
        decoration: BoxDecoration(
          color: isSel ? AC.accent.withOpacity(0.15) : Colors.transparent,
          border: isSel
              ? const Border(left: BorderSide(color: AC.accent, width: 2))
              : null,
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              shloka.id,
              style: AT.garamond(11, color: isSel ? AC.accent : AC.textMuted),
            ),
          ),
          if (shloka.lines[0].isNotEmpty && !shloka.lines[0].startsWith('['))
            Container(
              width: 5, height: 5,
              decoration: const BoxDecoration(
                  color: AC.loopActive, shape: BoxShape.circle),
            ),
        ]),
      ),
    );
  }

  // ── Practice pane ─────────────────────────────────────────────────────────

  Widget _buildPracticePane() {
    final verse = _verse;
    if (verse == null) {
      return const Center(child: CircularProgressIndicator(color: AC.accent));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 44),
      child: Column(children: [
        _buildProgress(verse),
        _buildVerseCard(verse),
        _buildWordChips(verse),
        _buildAudioPlayer(),
      ]),
    );
  }

  // ── Progress row ──────────────────────────────────────────────────────────

  Widget _buildProgress(Verse verse) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(
          'श्लोक $_selShloka of $_vargaVerseCount',
          style: AT.garamond(13, color: AC.textSec, italic: true),
        ),
        Text(
          verse.id,
          style: AT.garamond(11, color: AC.textMuted, italic: true),
        ),
      ]),
      const SizedBox(height: 6),
      AProgressBar(
          value: _vargaVerseCount > 0
              ? _selShloka / _vargaVerseCount
              : 0),
    ]),
  );

  // ── Verse card ────────────────────────────────────────────────────────────

  Widget _buildVerseCard(Verse verse) => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
    padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
    decoration: AD.card(radius: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Verse id chip
      Row(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
          decoration: BoxDecoration(
            color: AC.surfaceAlt,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AC.borderLight),
          ),
          child: Text(verse.id,
              style: AT.garamond(10, color: AC.textMuted, letterSpacing: 0.05)),
        ),
        const Spacer(),
        // Reveal-all button in Recite mode
        if (_mode == PracticeMode.recite && _revealed.length < verse.lines.length)
          GestureDetector(
            onTap: () => setState(() {
              for (var i = 0; i < verse.lines.length; i++) _revealed.add(i);
            }),
            child: Text('Show all',
                style: AT.garamond(12, color: AC.accent, italic: true)),
          ),
      ]),
      const SizedBox(height: 14),

      // Meaning summary (Listen / Guided)
      if (verse.meaning.isNotEmpty && _mode != PracticeMode.recite) ...[
        Text(verse.meaning,
            style: AT.garamond(13, color: AC.textSec, italic: true, height: 1.5)),
        const SizedBox(height: 10),
      ],

      // Pāda lines
      ...verse.lines.asMap().entries.map((e) {
        final i = e.key;
        final line = e.value;
        final isPlaceholder = line.startsWith('[');

        // Recite mode — hidden unless revealed
        if (_mode == PracticeMode.recite) {
          final shown = _revealed.contains(i);
          return GestureDetector(
            onTap: () => setState(() => _revealed.add(i)),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: shown ? AC.lineHl : AC.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: shown ? AC.lineBorder : AC.borderLight),
              ),
              child: shown
                  ? _padaText(line, isPlaceholder)
                  : Row(children: [
                      const Icon(Icons.visibility_off_outlined,
                          size: 14, color: AC.textMuted),
                      const SizedBox(width: 6),
                      Text('Tap to reveal Pāda ${i + 1}',
                          style: AT.garamond(13, color: AC.textMuted,
                              italic: true)),
                    ]),
            ),
          );
        }

        // Guided mode
        if (_mode == PracticeMode.guided) {
          final active = i == _guidedLine;
          final done = i < _guidedLine;
          return GestureDetector(
            onTap: active
                ? () => setState(() {
                    if (_guidedLine < verse.lines.length - 1) _guidedLine++;
                  })
                : null,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: active
                    ? AC.lineHl
                    : done
                        ? AC.loopActiveBg
                        : AC.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: active
                        ? AC.lineBorder
                        : done
                            ? AC.loopActive.withOpacity(0.3)
                            : AC.borderLight),
              ),
              child: done || active
                  ? _padaText(line, isPlaceholder)
                  : Text('Pāda ${i + 1}',
                      style: AT.garamond(14, color: AC.textMuted,
                          italic: true)),
            ),
          );
        }

        // Listen mode — show all, highlight if in loop
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _highlightLine(i) ? AC.lineHl : AC.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: _highlightLine(i) ? AC.lineBorder : AC.borderLight),
          ),
          child: _padaText(line, isPlaceholder),
        );
      }),
    ]),
  );

  Widget _padaText(String line, bool isPlaceholder) => Text(
    line,
    style: isPlaceholder
        ? AT.garamond(12, color: AC.textMuted, italic: true)
        : const TextStyle(
            fontFamily: 'TiroDevanagarSanskrit',
            fontSize: 19, height: 1.7, color: AC.text),
  );

  // ── Word chips ────────────────────────────────────────────────────────────

  Widget _buildWordChips(Verse verse) {
    if (verse.words.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => setState(() => _showWords = !_showWords),
          child: Row(children: [
            Text('Words'.toUpperCase(),
                style: AT.garamond(10, color: AC.textMuted, letterSpacing: 1.0)),
            const SizedBox(width: 4),
            Icon(_showWords
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
                size: 14, color: AC.textMuted),
          ]),
        ),
        if (_showWords) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: verse.words.map((word) {
            return GestureDetector(
              onLongPress: () => GrammarSheet.show(context, word),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                decoration: BoxDecoration(
                  color: AC.chipBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AC.border),
                ),
                child: Column(children: [
                  Text(word.w,
                      style: const TextStyle(
                        fontFamily: 'TiroDevanagarSanskrit',
                        fontSize: 15, color: AC.text,
                      )),
                  if (word.m.isNotEmpty)
                    Text(word.m,
                        style: AT.garamond(10, color: AC.textMuted)),
                ]),
              ),
            );
          }).toList()),
        ],
      ]),
    );
  }

  // ── Audio player ──────────────────────────────────────────────────────────

  Widget _buildAudioPlayer() => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    decoration: AD.card(radius: 14),
    child: Column(children: [
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          Text('Audio', style: AT.garamond(13, color: AC.textSec)),
          const Spacer(),
          // Audio set picker pill
          GestureDetector(
            onTap: widget.onGoRecord,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 3, 10, 3),
              decoration: BoxDecoration(
                color: AC.chipBg,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AC.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.mic_outlined, size: 12, color: AC.textMuted),
                const SizedBox(width: 4),
                Text('Record', style: AT.garamond(12, color: AC.chipText)),
              ]),
            ),
          ),
        ]),
      ),

      // Progress bar
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Column(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: AC.trackBg,
              valueColor: const AlwaysStoppedAnimation<Color>(AC.trackFill),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0:00', style: AT.garamond(10, color: AC.textMuted)),
              Text('--:--', style: AT.garamond(10, color: AC.textMuted)),
            ],
          ),
        ]),
      ),

      // Transport controls
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Prev verse
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded),
          color: _selShloka > 1 ? AC.textSec : AC.textMuted,
          iconSize: 20,
          onPressed: _selShloka > 1 ? _prevVerse : null,
        ),
        const SizedBox(width: 10),
        // Stop
        GestureDetector(
          onTap: _stopPlayback,
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: AC.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: AC.border),
            ),
            child: const Icon(Icons.stop_rounded, color: AC.textSec, size: 15),
          ),
        ),
        const SizedBox(width: 10),
        // Play/Pause
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AC.btnBg,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                  color: AC.trackFill.withOpacity(0.33),
                  blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Icon(
              _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: AC.btnText, size: 22,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Next verse
        IconButton(
          icon: const Icon(Icons.skip_next_rounded),
          color: _selShloka < _vargaVerseCount ? AC.textSec : AC.textMuted,
          iconSize: 20,
          onPressed: _selShloka < _vargaVerseCount ? _nextVerse : null,
        ),
      ]),

      // Speed buttons
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ...[0.5, 0.75, 1.0, 1.25, 1.5].map((s) {
          final active = _speed == s;
          return GestureDetector(
            onTap: () {
              setState(() => _speed = s);
              _audio.player.setSpeed(s);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              padding: const EdgeInsets.fromLTRB(7, 3, 7, 3),
              decoration: BoxDecoration(
                color: active
                    ? AC.trackFill.withOpacity(0.13)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                    color: active ? AC.trackFill : AC.borderLight),
              ),
              child: Text('${s}x',
                  style: AT.garamond(11,
                      color: active ? AC.trackFill : AC.textMuted)),
            ),
          );
        }),
      ]),
      const SizedBox(height: 14),
    ]),
  );
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _ChevLeft extends StatelessWidget {
  const _ChevLeft();
  @override
  Widget build(BuildContext context) =>
      const Icon(Icons.chevron_left, color: AC.accent, size: 18);
}

class _ModeSegment extends StatelessWidget {
  final String label;
  final PracticeMode value;
  final PracticeMode current;
  final ValueChanged<PracticeMode> onTap;
  final int index;

  const _ModeSegment(this.label, this.value, this.current, this.onTap, this.index);

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active ? AC.btnBg : Colors.transparent,
            border: index > 0
                ? const Border(left: BorderSide(color: AC.border))
                : null,
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: AT.garamond(13,
                  color: active ? AC.btnText : AC.textMuted)),
        ),
      ),
    );
  }
}
