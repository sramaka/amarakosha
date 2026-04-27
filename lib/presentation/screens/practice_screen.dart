// lib/presentation/screens/practice_screen.dart (v3 model)
//
// Layout:
//   [Tree toggle btn] [Nav bar]
//   [Tree pane | Practice pane]
//
// Tree: Kanda → Varga → Section → Pada rows
//   Long-press Section or Pada → adds to Practice Set
//
// Practice Set: right-side panel with global repeat settings
// Recording: mic button in nav opens RecordingScreen

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' hide LoopMode;
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/audio_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/static_data.dart';
import '../../domain/entities/entities.dart';
import '../sheets/grammar_sheet.dart';
import '../widgets/shared_widgets.dart';
import '../../core/settings/app_settings.dart';

// ─── Practice Set item ────────────────────────────────────────────────────────
class _SetItem {
  final String label;     // section title or pada id
  final List<Pada> padas; // padas to play
  _SetItem(this.label, this.padas);
}

// ─────────────────────────────────────────────────────────────────────────────
class PracticeScreen extends StatefulWidget {
  final Session      session;
  final VoidCallback onBack;
  final VoidCallback onGoRecord;

  const PracticeScreen({
    super.key,
    required this.session,
    required this.onBack,
    required this.onGoRecord,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  // ── Data ──────────────────────────────────────────────────────────────────
  List<Kanda> _kandas = kBootstrapKandas;

  int _selKandaNum = 1;
  int _selVargaSeq = 1;
  int _selSecSeq   = 1;
  int _selPadaSeq  = 1;   // 1-based within section

  Pada? _pada;

  // ── Audio ─────────────────────────────────────────────────────────────────
  bool   _playing  = false;
  double _progress = 0.0;
  double _speed    = 1.0;
  final AudioService _audio = AudioService.instance;

  // ── Practice mode ─────────────────────────────────────────────────────────
  late PracticeMode _mode;
  bool _revealed  = false;
  bool _showWords = false;

  // ── Practice Set ──────────────────────────────────────────────────────────
  final List<_SetItem> _setItems     = [];
  bool                 _showSetPanel = false;
  int                  _padaRepeat   = 1;   // times each pada is repeated
  int                  _setRepeat    = 1;   // times the full set is repeated
  bool                 _autoAdvance  = false; // continuous play mode

  // Set playback state
  bool _setPlaying    = false;
  int  _setCurItem    = 0;
  int  _setCurPada    = 0;
  int  _setCurPadaRep = 0;
  int  _setCurSetRep  = 0;
  Timer? _setTimer;
  StreamSubscription<PlayerState>? _setCompletionSub;
  bool _advancing = false; // prevents double-fire on auto-advance
  bool _mobileTreeOpen = false;

  static const _kSetKey = 'amarakosha_practice_set';

  Future<void> _saveSet() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _setItems.map((item) => {
      'label': item.label,
      'ids'  : item.padas.map((p) => p.id).toList(),
    }).toList();
    await prefs.setString(_kSetKey, jsonEncode(data));
  }

  Future<void> _restoreSet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSetKey);
      if (raw == null || raw.isEmpty) return;
      final data = jsonDecode(raw) as List<dynamic>;
      final items = <_SetItem>[];
      for (final entry in data) {
        final label = entry['label'] as String;
        final ids   = (entry['ids'] as List<dynamic>).cast<String>();
        final padas = <Pada>[];
        for (final id in ids) {
          outer:
          for (final k in _kandas) {
            for (final v in k.vargas) {
              for (final s in v.sections) {
                for (final p in s.padas) {
                  if (p.id == id) { padas.add(p); break outer; }
                }
              }
            }
          }
        }
        if (padas.isNotEmpty) items.add(_SetItem(label, padas));
      }
      if (mounted && items.isNotEmpty) {
        setState(() {
          for (final item in items) {
            if (!_setItems.any((e) => e.label == item.label)) {
              _setItems.add(item);
            }
          }
        });
      }
    } catch (_) {}
  }

  // ── Tree UI ───────────────────────────────────────────────────────────────
  bool              _treePaneOpen   = true;
  final Set<int>    _expandedKandas = {};
  final Set<String> _expandedVargas = {};

  // ── Init ──────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _mode        = widget.session.mode;
    _selKandaNum = widget.session.kanda.num;
    _selVargaSeq = widget.session.varga.seq;
    _selSecSeq   = widget.session.section.seq;
    _expandedKandas.add(_selKandaNum);
    _expandedVargas.add('${_selKandaNum}_$_selVargaSeq');
    _refreshPada();   // show bootstrap pada immediately
    _loadData();      // load full JSON in background
    _bindAudio();
    AppSettings.instance.addListener(_onSettings);
  }

  @override
  void dispose() {
    _setTimer?.cancel();
    _setCompletionSub?.cancel();
    AppSettings.instance.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() => setState(() {});

  bool get _isMobile => MediaQuery.of(context).size.width <= 768;

  // ── Data ──────────────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    final k = await loadKandas();
    if (!mounted) return;
    setState(() { _kandas = k; });
    _refreshPada();
    await _restoreSet();
  }

  void _refreshPada() {
    if (_kandas.isEmpty) return;
    Pada? found;
    outer: for (final k in _kandas) {
      if (k.num != _selKandaNum) continue;
      for (final v in k.vargas) {
        if (v.seq != _selVargaSeq) continue;
        for (final s in v.sections) {
          if (s.seq != _selSecSeq) continue;
          final idx = _selPadaSeq - 1;
          if (idx >= 0 && idx < s.padas.length) found = s.padas[idx];
          break outer;
        }
      }
    }
    setState(() { _pada = found; _revealed = false; _progress = 0; });
  }

  Section? get _currentSection {
    for (final k in _kandas) {
      if (k.num != _selKandaNum) continue;
      for (final v in k.vargas) {
        if (v.seq != _selVargaSeq) continue;
        for (final s in v.sections) {
          if (s.seq == _selSecSeq) return s;
        }
      }
    }
    return null;
  }

  int get _sectionPadaCount => _currentSection?.padas.length ?? 1;

  void _goTo(int kanda, int varga, int sec, int pada) {
    setState(() {
      _selKandaNum    = kanda;
      _selVargaSeq    = varga;
      _selSecSeq      = sec;
      _selPadaSeq     = pada;
      _mobileTreeOpen = false;
    });
    _refreshPada();
  }

  void _prevPada() {
    if (_selPadaSeq > 1) {
      _goTo(_selKandaNum, _selVargaSeq, _selSecSeq, _selPadaSeq - 1);
    } else {
      final prev = _adjacentSection(-1);
      if (prev != null) _goTo(_selKandaNum, _selVargaSeq, prev.seq, prev.padaCount);
    }
  }

  void _nextPada() {
    if (_selPadaSeq < _sectionPadaCount) {
      _goTo(_selKandaNum, _selVargaSeq, _selSecSeq, _selPadaSeq + 1);
    } else {
      final next = _adjacentSection(1);
      if (next != null) _goTo(_selKandaNum, _selVargaSeq, next.seq, 1);
    }
  }

  Section? _adjacentSection(int delta) {
    for (final k in _kandas) {
      if (k.num != _selKandaNum) continue;
      for (final v in k.vargas) {
        if (v.seq != _selVargaSeq) continue;
        final idx = v.sections.indexWhere((s) => s.seq == _selSecSeq);
        if (idx < 0) return null;
        final ni = idx + delta;
        if (ni >= 0 && ni < v.sections.length) return v.sections[ni];
      }
    }
    return null;
  }

  // ── Practice Set ──────────────────────────────────────────────────────────
  void _addSectionToSet(Section sec) {
    if (_setItems.any((i) => i.label == sec.titleEn && i.padas == sec.padas)) return;
    setState(() => _setItems.add(_SetItem(sec.titleEn, sec.padas)));
    _saveSet();
    _showSetToast('Section "${sec.titleEn}" added to Practice Set');
  }

  void _addPadaToSet(Pada pada) {
    final label = pada.id;
    if (_setItems.any((i) => i.label == label)) return;
    setState(() => _setItems.add(_SetItem(label, [pada])));
    _saveSet();
    _showSetToast('Pada ${pada.id} added to Practice Set');
  }

  void _removeFromSet(int idx) {
    setState(() => _setItems.removeAt(idx));
    _saveSet();
  }

  void _showSetToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: AT.garamond(13, color: Colors.white)),
      duration: const Duration(seconds: 2),
      backgroundColor: AC.accent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  int get _totalSetPadas =>
      _setItems.fold(0, (n, i) => n + i.padas.length) * _padaRepeat * _setRepeat;

  // Set playback: steps through items → padas → pada-repeats → set-repeats
  void _startSetPlayback() {
    if (_setItems.isEmpty) return;
    setState(() {
      _setPlaying    = true;
      _setCurItem    = 0;
      _setCurPada    = 0;
      _setCurPadaRep = 0;
      _setCurSetRep  = 0;
    });
    _playCurrentSetPada();
  }

  void _stopSetPlayback() {
    _setTimer?.cancel();
    _setCompletionSub?.cancel();
    _setCompletionSub = null;
    _audio.stop();
    setState(() => _setPlaying = false);
  }

  void _playCurrentSetPada() async {
    if (!_setPlaying) return;
    if (_setCurItem >= _setItems.length) {
      // Finished one full pass of the set
      if (_setCurSetRep + 1 < _setRepeat) {
        setState(() { _setCurSetRep++; _setCurItem = 0; _setCurPada = 0; _setCurPadaRep = 0; });
        _playCurrentSetPada();
      } else {
        setState(() => _setPlaying = false);
      }
      return;
    }
    final item = _setItems[_setCurItem];
    if (_setCurPada >= item.padas.length) {
      setState(() { _setCurItem++; _setCurPada = 0; _setCurPadaRep = 0; });
      _playCurrentSetPada();
      return;
    }
    final pada = item.padas[_setCurPada];

    // Navigate practice pane to current pada
    final legParts = (pada.legacyId.isNotEmpty ? pada.legacyId : pada.id).split('.');
    if (legParts.length >= 2) {
      _goTo(int.tryParse(legParts[0]) ?? _selKandaNum,
            int.tryParse(legParts[1]) ?? _selVargaSeq,
            _currentSecSeqForPada(pada) ?? _selSecSeq,
            pada.seq);
    }

    final hasAudio = await _audio.playPada(pada.id, speed: _speed);
    if (!_setPlaying) return; // stopped while loading

    if (!hasAudio) {
      _setTimer = Timer(const Duration(milliseconds: 1200), _advanceSetPada);
    } else {
      // One-shot subscription — fires once per pada, prevents double-advance
      _setCompletionSub?.cancel();
      _setCompletionSub = _audio.player.playerStateStream.listen((st) {
        if (st.processingState == ProcessingState.completed) {
          _setCompletionSub?.cancel();
          _setCompletionSub = null;
          if (_setPlaying) _advanceSetPada();
        }
      });
    }
  }

  void _advanceSetPada() {
    _setTimer?.cancel();
    if (!_setPlaying) return;
    if (_setCurPadaRep + 1 < _padaRepeat) {
      setState(() => _setCurPadaRep++);
    } else {
      setState(() { _setCurPada++; _setCurPadaRep = 0; });
    }
    _playCurrentSetPada();
  }

  int? _currentSecSeqForPada(Pada pada) {
    for (final k in _kandas) {
      for (final v in k.vargas) {
        for (final s in v.sections) {
          if (s.padas.any((p) => p.id == pada.id)) return s.seq;
        }
      }
    }
    return null;
  }

  // ── Audio ─────────────────────────────────────────────────────────────────
  void _bindAudio() {
    _audio.player.playerStateStream.listen((st) {
      if (!mounted) return;
      setState(() {
        _playing = st.playing;
        if (st.processingState == ProcessingState.completed) {
          _playing = false; _progress = 1.0;
        }
      });
      if (st.processingState == ProcessingState.completed && !_setPlaying && _autoAdvance && !_advancing) {
        _advancing = true;
        Future.microtask(_nextPadaAndPlay);
      }
    });
    _audio.player.positionStream.listen((pos) {
      if (!mounted) return;
      final dur = _audio.player.duration;
      if (dur != null && dur.inMilliseconds > 0)
        setState(() => _progress = pos.inMilliseconds / dur.inMilliseconds);
    });
  }

  Future<void> _nextPadaAndPlay() async {
    _nextPada();
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted || _pada == null || !_autoAdvance) { _advancing = false; return; }
    await _audio.playPada(_pada!.id, speed: _speed);
    _advancing = false;
  }

  Future<void> _togglePlay() async {
    if (_playing) { await _audio.pause(); return; }
    final pada = _pada;
    if (pada == null) return;
    // Use GRETIL ID directly as the audio key (e.g. "1.1.11")
    await _audio.playPada(pada.id, speed: _speed);
  }

  Future<void> _stopPlay() async {
    _advancing = false;
    await _audio.stop();
    setState(() { _playing = false; _progress = 0; });
  }

  void _switchMode(PracticeMode m) {
    _stopPlay();
    setState(() { _mode = m; _revealed = false; });
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_pada == null) return const Center(child: CircularProgressIndicator(color: AC.accent));
    final isMobile = _isMobile;
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(children: [
          _buildNav(),
          Expanded(child: isMobile
            ? Column(children: [
                Expanded(child: _buildPracticePane()),
                _buildSetTray(),
              ])
            : Row(children: [
                _TreeTab(open: _treePaneOpen,
                    onTap: () => setState(() => _treePaneOpen = !_treePaneOpen)),
                if (_treePaneOpen) _buildTreePane(),
                if (_treePaneOpen) Container(width: 1, color: AC.border),
                Expanded(child: _buildPracticePane()),
                if (_showSetPanel) Container(width: 1, color: AC.border),
                if (_showSetPanel) _buildSetPanel(),
              ])),
        ]),
        if (isMobile && _mobileTreeOpen) _buildMobileTreeOverlay(),
      ],
    );
  }

  // ── Nav bar ───────────────────────────────────────────────────────────────
  Widget _buildNav() {
    final isMobile = _isMobile;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AC.border))),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: widget.onBack,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.chevron_left, color: AC.accent, size: 18),
              Text('Back', style: AT.garamond(15, color: AC.accent)),
            ]),
          ),
          // Mobile: Contents button opens tree overlay
          if (isMobile) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _mobileTreeOpen = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AC.border)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.menu_book_outlined, size: 13, color: AC.textSec),
                  const SizedBox(width: 4),
                  Text('Contents', style: AT.garamond(12, color: AC.textSec)),
                ]),
              ),
            ),
          ],
          Expanded(child: Center(
            child: Text(_pada != null ? '${_pada!.id}' : '',
                style: AT.garamond(13, color: AC.textSec, italic: true)),
          )),
          // Desktop only: Practice Set toggle (mobile uses bottom tray instead)
          if (!isMobile)
            GestureDetector(
              onTap: () => setState(() => _showSetPanel = !_showSetPanel),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _showSetPanel ? AC.accent.withOpacity(0.10) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _showSetPanel ? AC.accent : AC.border)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.playlist_play_rounded, size: 14,
                      color: _showSetPanel ? AC.accent : AC.textSec),
                  const SizedBox(width: 4),
                  Text('Set${_setItems.isEmpty ? "" : " (${_setItems.length})"}',
                      style: AT.garamond(12,
                          color: _showSetPanel ? AC.accent : AC.textSec)),
                ]),
              ),
            ),
          // Record
          GestureDetector(
            onTap: widget.onGoRecord,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AC.border)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.mic_outlined, size: 13, color: AC.recRed),
                const SizedBox(width: 4),
                Text('Record', style: AT.garamond(12, color: AC.recRed)),
              ]),
            ),
          ),
          // Display settings
          GestureDetector(
            onTap: _showDisplaySettings,
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AC.border)),
              child: const Icon(Icons.text_fields_rounded, size: 14, color: AC.textSec),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8), border: Border.all(color: AC.border)),
          clipBehavior: Clip.antiAlias,
          child: Row(children: [
            _ModeSeg('Listen', PracticeMode.listen, _mode, _switchMode, 0),
            _ModeSeg('Recite', PracticeMode.recite, _mode, _switchMode, 1),
            _ModeSeg('Guided', PracticeMode.guided, _mode, _switchMode, 2),
          ]),
        ),
      ]),
    );
  }

  // ── Tree pane ─────────────────────────────────────────────────────────────
  Widget _buildTreePane() => Container(
    width: 220,
    color: AC.sidebar,
    child: Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: AC.sidebarHdr,
          border: Border(bottom: BorderSide(color: AC.sidebarBorder))),
        child: Row(children: [
          Text('Contents'.toUpperCase(),
              style: AT.garamond(11, color: AC.sidebarText, letterSpacing: 1.2,
                  weight: FontWeight.w700)),
          const Spacer(),
          Text('Long-press → Set',
              style: AT.garamond(10, color: AC.sidebarMuted, italic: true)),
        ]),
      ),
      Expanded(child: ListView(children: _kandas.map(_buildKandaNode).toList())),
    ]),
  );

  Widget _buildKandaNode(Kanda k) {
    final exp = _expandedKandas.contains(k.num);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () => setState(() {
          if (exp) _expandedKandas.remove(k.num);
          else     _expandedKandas.add(k.num);
        }),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 9, 10, 9),
          color: Colors.transparent,
          child: Row(children: [
            Icon(exp ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                size: 16, color: AC.sidebarSel),
            const SizedBox(width: 4),
            Expanded(child: Text(k.name, style: AT.devanagari(
                AppSettings.instance.treeFontSize.toDouble(),
                color: AC.sidebarText, height: 1.4,
                family: AppSettings.instance.devFontFamily))),
          ]),
        ),
      ),
      if (exp) ...k.vargas.map((v) => _buildVargaNode(k, v)),
    ]);
  }

  Widget _buildVargaNode(Kanda k, Varga v) {
    final vkey = '${k.num}_${v.seq}';
    final exp  = _expandedVargas.contains(vkey);
    final sel  = k.num == _selKandaNum && v.seq == _selVargaSeq;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () => setState(() {
          if (exp) _expandedVargas.remove(vkey);
          else     _expandedVargas.add(vkey);
          _selKandaNum = k.num; _selVargaSeq = v.seq;
        }),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 6, 10, 6),
          color: sel ? AC.sidebarSel.withOpacity(0.14) : Colors.transparent,
          child: Row(children: [
            Icon(exp ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                size: 14, color: sel ? AC.sidebarSel : AC.sidebarMuted),
            const SizedBox(width: 4),
            Expanded(child: Text(v.name, style: AT.devanagari(
                AppSettings.instance.treeFontSize.toDouble(),
                color: sel ? AC.sidebarSel : AC.sidebarText,
                height: 1.4,
                family: AppSettings.instance.devFontFamily))),
          ]),
        ),
      ),
      if (exp) ...v.sections.map((s) => _buildSectionNode(k, v, s)),
    ]);
  }

  Widget _buildSectionNode(Kanda k, Varga v, Section sec) {
    final sel = k.num == _selKandaNum && v.seq == _selVargaSeq && sec.seq == _selSecSeq;
    final inSet = _setItems.any((i) => i.label == sec.titleEn);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap:      () => _goTo(k.num, v.seq, sec.seq, 1),
        onLongPress: () => _addSectionToSet(sec),
        child: Container(
          padding: const EdgeInsets.fromLTRB(32, 6, 10, 6),
          decoration: BoxDecoration(
            color: sel ? AC.sidebarSel.withOpacity(0.16) : Colors.transparent,
            border: sel ? const Border(left: BorderSide(color: AC.sidebarSel, width: 2)) : null),
          child: Row(children: [
            Expanded(child: Text(sec.titleEn,
                style: AT.garamond(AppSettings.instance.treeFontSize.toDouble(),
                    color: sel ? AC.sidebarSel : AC.sidebarText,
                    weight: AppSettings.instance.fontWeight))),
            if (inSet)
              Container(margin: const EdgeInsets.only(right: 4),
                child: const Icon(Icons.playlist_add_check_rounded,
                    size: 10, color: AC.sidebarSel)),
            if (sec.hasText)
              Container(width: 5, height: 5,
                  decoration: const BoxDecoration(color: AC.loopActive, shape: BoxShape.circle)),
            const SizedBox(width: 3),
            Text('${sec.padaCount}', style: AT.garamond(AppSettings.instance.treeFontSize.toDouble(),
                color: AC.sidebarMuted)),
          ]),
        ),
      ),
      if (sel) ...sec.padas.map((p) => _buildPadaNode(k, v, sec, p)),
    ]);
  }

  Widget _buildPadaNode(Kanda k, Varga v, Section sec, Pada p) {
    final sel      = p.seq == _selPadaSeq && sec.seq == _selSecSeq
        && k.num == _selKandaNum && v.seq == _selVargaSeq;
    final inSet    = _setItems.any((i) => i.label == p.id);
    final hasAudio = AudioService.instance.hasAudio(p.id);
    return GestureDetector(
      onTap:       () => _goTo(k.num, v.seq, sec.seq, p.seq),
      onLongPress: () => _addPadaToSet(p),
      child: Container(
        padding: const EdgeInsets.fromLTRB(44, 4, 10, 4),
        decoration: BoxDecoration(
          color: sel ? AC.sidebarSel.withOpacity(0.12) : Colors.transparent,
          border: sel ? const Border(left: BorderSide(color: AC.sidebarSel, width: 2)) : null),
        child: Row(children: [
          Text('P${p.padaNum}',
              style: AT.garamond((AppSettings.instance.treeFontSize - 1).toDouble(),
                  color: sel ? AC.sidebarSel : AC.sidebarMuted)),
          const SizedBox(width: 5),
          Expanded(child: Text(p.id,
              style: AT.garamond(AppSettings.instance.treeFontSize.toDouble(),
                  color: sel ? AC.sidebarSel : AC.sidebarText))),
          if (hasAudio)
            const Padding(
              padding: EdgeInsets.only(left: 3),
              child: Icon(Icons.volume_up_rounded, size: 9, color: AC.loopActive)),
          if (inSet)
            const Padding(
              padding: EdgeInsets.only(left: 3),
              child: Icon(Icons.playlist_add_check_rounded, size: 10, color: AC.sidebarSel)),
          if (p.hasText)
            Container(margin: const EdgeInsets.only(left: 3),
              child: Container(width: 4, height: 4,
                  decoration: const BoxDecoration(color: AC.loopActive, shape: BoxShape.circle))),
        ]),
      ),
    );
  }

  // ── Practice Set panel ────────────────────────────────────────────────────
  Widget _buildSetPanel() => SizedBox(
    width: 230,
    child: Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AC.border))),
        child: Row(children: [
          Text('Practice Set'.toUpperCase(),
              style: AT.garamond(12, color: AC.textMuted, letterSpacing: 1.0)),
          const Spacer(),
          if (_setItems.isNotEmpty)
            GestureDetector(
              onTap: () { setState(() => _setItems.clear()); _saveSet(); },
              child: Text('Clear', style: AT.garamond(13, color: AC.textMuted, italic: true)),
            ),
        ]),
      ),

      // Item list
      Expanded(child: _setItems.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Long-press a Section or Pada in the tree to add it here.',
                style: AT.garamond(12, color: AC.textMuted, italic: true, height: 1.5),
                textAlign: TextAlign.center,
              ),
            )
          : ReorderableListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              onReorder: (o, n) {
                setState(() {
                  final item = _setItems.removeAt(o);
                  _setItems.insert(n > o ? n - 1 : n, item);
                });
                _saveSet();
              },
              children: _setItems.asMap().entries.map((e) {
                final i = e.key;
                final item = e.value;
                return ListTile(
                  key: ValueKey(i),
                  dense: true,
                  contentPadding: const EdgeInsets.fromLTRB(10, 0, 4, 0),
                  leading: Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                        color: AC.surfaceAlt,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AC.border)),
                    child: Center(child: Text('${i+1}',
                        style: AT.garamond(13, color: AC.textMuted))),
                  ),
                  title: Text(item.label,
                      style: AT.garamond(13, color: AC.text),
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text('${item.padas.length} pada${item.padas.length != 1 ? "s" : ""}',
                      style: AT.garamond(12, color: AC.textMuted)),
                  trailing: GestureDetector(
                    onTap: () => _removeFromSet(i),
                    child: const Icon(Icons.close_rounded, size: 14, color: AC.textMuted),
                  ),
                );
              }).toList(),
            )),

      // Repeat settings
      Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AC.border))),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(children: [
          // Pada repeat
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Each Pāda', style: AT.garamond(12, color: AC.text)),
              Text('repeat × per pada', style: AT.garamond(12, color: AC.textMuted, italic: true)),
            ])),
            _SmallStepper(
              value: _padaRepeat,
              onDec: _padaRepeat > 1 ? () => setState(() => _padaRepeat--) : null,
              onInc: _padaRepeat < 20 ? () => setState(() => _padaRepeat++) : null,
            ),
          ]),
          const SizedBox(height: 8),
          // Set repeat
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Full Set', style: AT.garamond(12, color: AC.text)),
              Text('repeat entire set', style: AT.garamond(12, color: AC.textMuted, italic: true)),
            ])),
            _SmallStepper(
              value: _setRepeat,
              onDec: _setRepeat > 1 ? () => setState(() => _setRepeat--) : null,
              onInc: _setRepeat < 20 ? () => setState(() => _setRepeat++) : null,
            ),
          ]),
          if (_setItems.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('$_totalSetPadas total pādas',
                style: AT.garamond(13, color: AC.textMuted, italic: true)),
          ],
          const SizedBox(height: 10),
          // Play Set button
          GestureDetector(
            onTap: _setItems.isEmpty
                ? null
                : _setPlaying ? _stopSetPlayback : _startSetPlayback,
            child: Opacity(
              opacity: _setItems.isEmpty ? 0.4 : 1.0,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _setPlaying ? AC.recRed : AC.btnBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_setPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      color: AC.btnText, size: 16),
                  const SizedBox(width: 6),
                  Text(_setPlaying ? 'Stop Set' : 'Play Set',
                      style: AT.garamond(14, color: AC.btnText)),
                ]),
              ),
            ),
          ),
        ]),
      ),
    ]),
  );

  // ── Mobile: set tray (52px bar at bottom) ────────────────────────────────
  Widget _buildSetTray() => GestureDetector(
    onTap: _showMobileSetSheet,
    child: Container(
      height: 52,
      decoration: const BoxDecoration(
        color: AC.surface,
        border: Border(top: BorderSide(color: AC.border))),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        Icon(Icons.playlist_play_rounded, size: 18,
            color: _setItems.isEmpty ? AC.textMuted : AC.accent),
        const SizedBox(width: 10),
        Expanded(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Practice Set${_setItems.isEmpty ? "" : " (${_setItems.length})"}',
              style: AT.garamond(14,
                  color: _setItems.isEmpty ? AC.textMuted : AC.text),
            ),
            if (_setItems.isNotEmpty)
              Text('$_totalSetPadas pādas',
                  style: AT.garamond(11, color: AC.textMuted, italic: true)),
          ],
        )),
        if (_setPlaying)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AC.recRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AC.recRed)),
            child: Text('Playing', style: AT.garamond(12, color: AC.recRed)),
          ),
        const Icon(Icons.expand_less_rounded, color: AC.textMuted, size: 18),
      ]),
    ),
  );

  void _showMobileSetSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AC.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AC.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(children: [
                Text('Practice Set'.toUpperCase(),
                    style: AT.garamond(12, color: AC.textMuted, letterSpacing: 1.0)),
                const Spacer(),
                if (_setItems.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() => _setItems.clear());
                      _saveSet();
                      setSheet(() {});
                    },
                    child: Text('Clear',
                        style: AT.garamond(13, color: AC.textMuted, italic: true)),
                  ),
              ]),
            ),
            Expanded(child: _setItems.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Long-press a Section or Pada in the tree to add it here.',
                    style: AT.garamond(13, color: AC.textMuted, italic: true, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                )
              : ReorderableListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  onReorder: (o, n) {
                    setState(() {
                      final item = _setItems.removeAt(o);
                      _setItems.insert(n > o ? n - 1 : n, item);
                    });
                    _saveSet();
                    setSheet(() {});
                  },
                  children: _setItems.asMap().entries.map((e) {
                    final i = e.key; final item = e.value;
                    return ListTile(
                      key: ValueKey(i),
                      dense: true,
                      contentPadding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                      leading: Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                            color: AC.surfaceAlt,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AC.border)),
                        child: Center(child: Text('${i + 1}',
                            style: AT.garamond(13, color: AC.textMuted))),
                      ),
                      title: Text(item.label,
                          style: AT.garamond(14, color: AC.text),
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${item.padas.length} pada${item.padas.length != 1 ? "s" : ""}',
                          style: AT.garamond(12, color: AC.textMuted)),
                      trailing: GestureDetector(
                        onTap: () { _removeFromSet(i); setSheet(() {}); },
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: AC.textMuted),
                      ),
                    );
                  }).toList(),
                )),
            Container(
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AC.border))),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(children: [
                Row(children: [
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Each Pāda', style: AT.garamond(13, color: AC.text)),
                        Text('repeat × per pada',
                            style: AT.garamond(12, color: AC.textMuted, italic: true)),
                      ])),
                  _SmallStepper(
                    value: _padaRepeat,
                    onDec: _padaRepeat > 1
                        ? () { setState(() => _padaRepeat--); setSheet(() {}); } : null,
                    onInc: _padaRepeat < 20
                        ? () { setState(() => _padaRepeat++); setSheet(() {}); } : null,
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Full Set', style: AT.garamond(13, color: AC.text)),
                        Text('repeat entire set',
                            style: AT.garamond(12, color: AC.textMuted, italic: true)),
                      ])),
                  _SmallStepper(
                    value: _setRepeat,
                    onDec: _setRepeat > 1
                        ? () { setState(() => _setRepeat--); setSheet(() {}); } : null,
                    onInc: _setRepeat < 20
                        ? () { setState(() => _setRepeat++); setSheet(() {}); } : null,
                  ),
                ]),
                if (_setItems.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('$_totalSetPadas total pādas',
                      style: AT.garamond(13, color: AC.textMuted, italic: true)),
                ],
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _setItems.isEmpty ? null : () {
                    if (_setPlaying) {
                      _stopSetPlayback();
                      setSheet(() {});
                    } else {
                      Navigator.pop(ctx);
                      _startSetPlayback();
                    }
                  },
                  child: Opacity(
                    opacity: _setItems.isEmpty ? 0.4 : 1.0,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _setPlaying ? AC.recRed : AC.btnBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(
                          _setPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          color: AC.btnText, size: 20),
                        const SizedBox(width: 8),
                        Text(_setPlaying ? 'Stop Set' : 'Play Set',
                            style: AT.garamond(16, color: AC.btnText,
                                weight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Mobile: full-screen tree slide-in overlay ─────────────────────────────
  Widget _buildMobileTreeOverlay() => Positioned.fill(
    child: GestureDetector(
      onTap: () => setState(() => _mobileTreeOpen = false),
      child: Container(
        color: Colors.black54,
        child: GestureDetector(
          onTap: () {},
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              color: AC.sidebar,
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: const BoxDecoration(
                    color: AC.sidebarHdr,
                    border: Border(bottom: BorderSide(color: AC.sidebarBorder))),
                  child: Row(children: [
                    Text('Contents'.toUpperCase(),
                        style: AT.garamond(12, color: AC.sidebarText,
                            letterSpacing: 1.2, weight: FontWeight.w700)),
                    const Spacer(),
                    Text('Long-press → Set',
                        style: AT.garamond(10, color: AC.sidebarMuted,
                            italic: true)),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => setState(() => _mobileTreeOpen = false),
                      child: const Icon(Icons.close_rounded,
                          color: AC.sidebarText, size: 20),
                    ),
                  ]),
                ),
                Expanded(child: ListView(
                    children: _kandas.map(_buildKandaNode).toList())),
              ]),
            ),
          ),
        ),
      ),
    ),
  );

  // ── Practice pane ─────────────────────────────────────────────────────────
  Widget _buildPracticePane() {
    final pada = _pada;
    if (pada == null) return const Center(child: CircularProgressIndicator(color: AC.accent));

    final sec         = _currentSection;
    final s           = AppSettings.instance;
    final allPadas    = sec?.padas ?? <Pada>[];
    final idx         = _selPadaSeq - 1; // 0-based

    final beforePadas = s.contextBefore > 0 && allPadas.isNotEmpty
        ? allPadas.sublist((idx - s.contextBefore).clamp(0, idx), idx)
        : <Pada>[];
    final afterPadas  = s.contextAfter > 0 && allPadas.isNotEmpty
        ? allPadas.sublist(
            (idx + 1).clamp(0, allPadas.length),
            (idx + 1 + s.contextAfter).clamp(0, allPadas.length))
        : <Pada>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 44),
      child: Column(children: [
        _buildProgress(pada),
        ...beforePadas.map((p) => _buildContextPada(p)),
        _buildPadaCard(pada),
        ...afterPadas.map((p) => _buildContextPada(p)),
        _buildWordChips(pada),
        _buildPlayer(),
      ]),
    );
  }

  Widget _buildContextPada(Pada p) {
    final s = AppSettings.instance;
    return GestureDetector(
      onTap: () => _goTo(_selKandaNum, _selVargaSeq, _selSecSeq, p.seq),
      child: Opacity(
        opacity: 0.55,
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: AC.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AC.borderLight),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _PadaBadge(p.padaNum),
              const SizedBox(width: 8),
              Text(p.id, style: AT.garamond(s.uiFontSize.toDouble(),
                  color: AC.textMuted, italic: true)),
            ]),
            if (p.hasText) ...[
              const SizedBox(height: 8),
              Text(p.textDev,
                  style: AT.devanagari(
                      (s.devFontSize * 0.85).roundToDouble(),
                      color: AC.textMuted, family: s.devFontFamily)),
            ],
          ]),
        ),
      ),
    );
  }

  // ── Display settings sheet ────────────────────────────────────────────────
  void _showDisplaySettings() => showDisplaySettingsSheet(context);

  Widget _buildProgress(Pada pada) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(
          'Pāda $_selPadaSeq of $_sectionPadaCount'
          '${_currentSection != null ? "  ·  ${_currentSection!.titleEn}" : ""}',
          style: AT.garamond(AppSettings.instance.uiFontSize.toDouble(),
              color: AC.textSec, weight: AppSettings.instance.fontWeight),
          overflow: TextOverflow.ellipsis,
        )),
        Text(pada.id, style: AT.garamond(
            AppSettings.instance.uiFontSize.toDouble(),
            color: AC.textSec, italic: true)),
      ]),
      const SizedBox(height: 6),
      AProgressBar(value: _sectionPadaCount > 0 ? _selPadaSeq / _sectionPadaCount : 0),
    ]),
  );

  Widget _buildPadaCard(Pada pada) {
    final pad = _isMobile ? 20.0 : 16.0;
    return Container(
    margin: const EdgeInsets.fromLTRB(14, 10, 14, 10),
    padding: EdgeInsets.all(pad),
    decoration: AD.card(radius: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _PadaBadge(pada.padaNum),
        const SizedBox(width: 8),
        Expanded(child: Text(pada.id,
            style: AT.garamond(AppSettings.instance.uiFontSize.toDouble(),
                color: AC.textSec, italic: true))),
        // Add to set button
        GestureDetector(
          onTap: () => _addPadaToSet(pada),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AC.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.playlist_add_rounded, size: 12, color: AC.textMuted),
              const SizedBox(width: 3),
              Text('Set', style: AT.garamond(
                  (AppSettings.instance.uiFontSize - 1).toDouble(),
                  color: AC.textMuted)),
            ]),
          ),
        ),
        if (_mode == PracticeMode.recite && !_revealed) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _revealed = true),
            child: Text('Reveal', style: AT.garamond(
                AppSettings.instance.uiFontSize.toDouble(),
                color: AC.accent, italic: true)),
          ),
        ],
      ]),
      const SizedBox(height: 14),
      _buildPadaText(pada),
    ]),
  );
  }

  Widget _buildPadaText(Pada pada) {
    final isPlaceholder = !pada.hasText;

    if (_mode == PracticeMode.recite && !_revealed) {
      return GestureDetector(
        onTap: () => setState(() => _revealed = true),
        child: Container(
          width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AC.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AC.borderLight)),
          child: Row(children: [
            const Icon(Icons.visibility_off_outlined, size: 14, color: AC.textMuted),
            const SizedBox(width: 6),
            Text('Tap to reveal Pāda ${pada.padaNum == 1 ? "A" : "B"}',
                style: AT.garamond(AppSettings.instance.uiFontSize.toDouble(),
                    color: AC.textSec, italic: true)),
          ]),
        ),
      );
    }

    if (_mode == PracticeMode.guided) {
      return GestureDetector(
        onTap: () => setState(() => _revealed = !_revealed),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _revealed ? AC.lineHl : AC.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _revealed ? AC.lineBorder : AC.borderLight)),
          child: _revealed
              ? _devText(pada.textDev, isPlaceholder)
              : Text('Pāda ${pada.padaNum == 1 ? "A" : "B"} — tap to reveal',
                  style: AT.garamond(AppSettings.instance.uiFontSize.toDouble(),
                      color: AC.textSec, italic: true)),
        ),
      );
    }

    return Container(
      width: double.infinity, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AC.borderLight)),
      child: _devText(pada.textDev, isPlaceholder),
    );
  }

  Widget _devText(String text, bool placeholder) {
    final s = AppSettings.instance;
    return Text(
      text,
      style: placeholder
          ? AT.garamond(12, color: AC.textMuted, italic: true)
          : AT.devanagari(s.devFontSize.toDouble(),
              family: s.devFontFamily),
    );
  }

  Widget _buildWordChips(Pada pada) {
    if (pada.words.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => setState(() => _showWords = !_showWords),
          child: Row(children: [
            Text('Words'.toUpperCase(),
                style: AT.garamond(AppSettings.instance.uiFontSize.toDouble(),
                    color: AC.textSec, weight: AppSettings.instance.fontWeight,
                    letterSpacing: 1.0)),
            const SizedBox(width: 4),
            Icon(_showWords ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                size: 14, color: AC.textSec),
            const SizedBox(width: 6),
            Text('${pada.words.length}', style: AT.garamond(
                AppSettings.instance.uiFontSize.toDouble(), color: AC.textSec)),
          ]),
        ),
        if (_showWords) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: pada.words.map((w) {
            return GestureDetector(
              onLongPress: () => GrammarSheet.show(context, w),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                decoration: BoxDecoration(color: AC.chipBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AC.border)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(w.w, style: AT.devanagari(
                      (AppSettings.instance.devFontSize * 0.8).roundToDouble(),
                      color: AC.text, height: 1.4,
                      family: AppSettings.instance.devFontFamily)),
                  if (w.m.isNotEmpty)
                    Text(w.m, style: AT.garamond(
                        AppSettings.instance.uiFontSize.toDouble(),
                        color: AC.textSec)),
                  if (w.formIast.isNotEmpty)
                    Text(w.formIast, style: AT.garamond(
                        AppSettings.instance.uiFontSize.toDouble(),
                        color: AC.textSec, italic: true)),
                ]),
              ),
            );
          }).toList()),
        ],
      ]),
    );
  }

  Widget _buildPlayer() {
    final mob = _isMobile;
    return Container(
    margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
    decoration: AD.card(radius: 14),
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: Row(children: [
          Text('Audio'.toUpperCase(), style: AT.garamond(
              AppSettings.instance.uiFontSize.toDouble(),
              color: AC.textSec, weight: AppSettings.instance.fontWeight,
              letterSpacing: 1.0)),
          const Spacer(),
          GestureDetector(
            onTap: widget.onGoRecord,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
              decoration: BoxDecoration(color: AC.chipBg,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: AC.border)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.mic_outlined, size: 12, color: AC.recRed),
                const SizedBox(width: 4),
                Text('Record', style: AT.garamond(
                    (AppSettings.instance.uiFontSize - 1).toDouble(),
                    color: AC.recRed)),
              ]),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _progress, backgroundColor: AC.trackBg, minHeight: 4,
            valueColor: const AlwaysStoppedAnimation<Color>(AC.trackFill)),
        ),
      ),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: const Icon(Icons.skip_previous_rounded),
            color: AC.textSec, iconSize: mob ? 26.0 : 20.0, onPressed: _prevPada),
        GestureDetector(onTap: _stopPlay, child: Container(
          width: mob ? 36 : 32, height: mob ? 36 : 32,
          decoration: BoxDecoration(color: AC.surfaceAlt, shape: BoxShape.circle,
              border: Border.all(color: AC.border)),
          child: Icon(Icons.stop_rounded, color: AC.textSec, size: mob ? 16 : 14))),
        const SizedBox(width: 6),
        GestureDetector(onTap: _togglePlay, child: Container(
          width: mob ? 50 : 46, height: mob ? 50 : 46,
          decoration: BoxDecoration(color: AC.btnBg, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AC.trackFill.withOpacity(0.33),
                blurRadius: 10, offset: const Offset(0, 3))]),
          child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: AC.btnText, size: mob ? 24 : 22))),
        const SizedBox(width: 6),
        IconButton(icon: const Icon(Icons.skip_next_rounded),
            color: AC.textSec, iconSize: mob ? 26.0 : 20.0, onPressed: _nextPada),
      ]),
      const SizedBox(height: 2),
      Row(mainAxisAlignment: MainAxisAlignment.center,
          children: [0.5, 0.75, 1.0, 1.25, 1.5].map((s) {
        final active = _speed == s;
        return GestureDetector(
          onTap: () { setState(() => _speed = s); _audio.player.setSpeed(s); },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            padding: const EdgeInsets.fromLTRB(6, 3, 6, 3),
            decoration: BoxDecoration(
              color: active ? AC.trackFill.withOpacity(0.13) : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: active ? AC.trackFill : AC.borderLight)),
            child: Text('${s}x', style: AT.garamond(13,
                color: active ? AC.trackFill : AC.textMuted)),
          ),
        );
      }).toList()),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: () => setState(() => _autoAdvance = !_autoAdvance),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
          decoration: BoxDecoration(
            color: _autoAdvance ? AC.accent.withOpacity(0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: _autoAdvance ? AC.accent : AC.borderLight)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.fast_forward_rounded, size: 12,
                color: _autoAdvance ? AC.accent : AC.textMuted),
            const SizedBox(width: 4),
            Text('Auto-advance', style: AT.garamond(12,
                color: _autoAdvance ? AC.accent : AC.textMuted)),
          ]),
        ),
      ),
      const SizedBox(height: 12),
    ]),
  );
  }
}

// ─── Persistent tree toggle tab ────────────────────────────────────────────────
// A vertical tab on the left edge that is ALWAYS visible so the tree can be
// reopened even after closing it.
class _TreeTab extends StatelessWidget {
  final bool open;
  final VoidCallback onTap;
  const _TreeTab({required this.open, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,   // ensures thin strip registers taps on web
    child: Container(
      width: 28,
      color: open ? AC.sidebar : AC.surfaceAlt,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: open
                ? AC.sidebarSel.withOpacity(0.20)
                : AC.accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            open ? Icons.chevron_left : Icons.chevron_right,
            size: 14,
            color: open ? AC.sidebarSel : AC.accent,
          ),
        ),
        const SizedBox(height: 6),
        RotatedBox(
          quarterTurns: 1,
          child: Text('Tree',
              style: AT.garamond(10,
                  color: open ? AC.sidebarSel : AC.accent,
                  letterSpacing: 0.5)),
        ),
      ]),
    ),
  );
}

// ─── Small stepper ─────────────────────────────────────────────────────────────
class _SmallStepper extends StatelessWidget {
  final int value;
  final VoidCallback? onDec, onInc;
  const _SmallStepper({required this.value, this.onDec, this.onInc});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    GestureDetector(
      onTap: onDec,
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(color: AC.surfaceAlt,
            borderRadius: BorderRadius.circular(6), border: Border.all(color: AC.border)),
        child: Center(child: Opacity(opacity: onDec != null ? 1 : 0.3,
            child: const Icon(Icons.remove_rounded, size: 12, color: AC.textSec))),
      ),
    ),
    Container(
      width: 32, alignment: Alignment.center,
      child: Text('$value', style: AT.garamond(14, color: AC.text)),
    ),
    GestureDetector(
      onTap: onInc,
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(color: AC.surfaceAlt,
            borderRadius: BorderRadius.circular(6), border: Border.all(color: AC.border)),
        child: Center(child: Opacity(opacity: onInc != null ? 1 : 0.3,
            child: const Icon(Icons.add_rounded, size: 12, color: AC.textSec))),
      ),
    ),
  ]);
}

// ─── Helpers ───────────────────────────────────────────────────────────────────
class _PadaBadge extends StatelessWidget {
  final int padaNum;
  const _PadaBadge(this.padaNum);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: AC.surfaceAlt,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AC.borderLight)),
    child: Text('Pāda ${padaNum == 1 ? "A" : "B"}',
        style: AT.garamond(14, color: AC.textSec, weight: FontWeight.w600)),
  );
}

class _ModeSeg extends StatelessWidget {
  final String label;
  final PracticeMode value, current;
  final ValueChanged<PracticeMode> onTap;
  final int index;
  const _ModeSeg(this.label, this.value, this.current, this.onTap, this.index);
  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return Expanded(child: GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: active ? AC.btnBg : Colors.transparent,
          border: index > 0 ? const Border(left: BorderSide(color: AC.border)) : null),
        child: Text(label, textAlign: TextAlign.center,
            style: AT.garamond(13,
                color: active ? AC.btnText : AC.text,
                weight: FontWeight.w600)),
      ),
    ));
  }
}
