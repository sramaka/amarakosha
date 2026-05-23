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
import '../../data/repositories/audio_set_store.dart';
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

class _NamedSet {
  String name;
  final List<_SetItem> items;
  _NamedSet(this.name, [List<_SetItem>? items]) : items = items ?? [];
}

// ─────────────────────────────────────────────────────────────────────────────
class PracticeScreen extends StatefulWidget {
  final Session      session;
  final VoidCallback onBack;
  final int          initialSetIdx;   // activate this set after restore (0 = stored default)
  final bool         startWithNewSet; // add a fresh empty set after restore
  final bool         showSetPanel;    // open set panel immediately on load

  const PracticeScreen({
    super.key,
    required this.session,
    required this.onBack,
    this.initialSetIdx   = 0,
    this.startWithNewSet = false,
    this.showSetPanel    = false,
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

  bool _showWords      = false;
  bool _reciteMode     = false; // Guided Practice: model at full vol, then student recites
  int  _modelCount     = 1;    // how many times the model plays per pada (cycles)
  int  _reciteCount    = 1;    // how many times the student recites per model play
  int  _reciteGapSec   = 1;    // pause (seconds) between consecutive student recitations
  bool _stepMode       = false; // pause between padas; student presses Next to advance
  bool _waitingForStep = false; // true after a pada's repeats complete in step mode

  // ── Practice Sets ─────────────────────────────────────────────────────────
  List<_NamedSet> _practiceSets = [_NamedSet('Set 1')];
  int             _activeSetIdx = 0;
  bool            _editingSetName = false;
  final TextEditingController _setNameCtrl = TextEditingController();
  List<_SetItem> get _setItems => _practiceSets[_activeSetIdx].items;

  bool _showSetPanel = false;
  int  _padaRepeat   = 1;   // times each pada is repeated
  int  _setRepeat    = 1;   // times the full set is repeated
  bool _autoAdvance  = false; // continuous play mode

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
  final GlobalKey _activePadaPlaylistKey = GlobalKey();

  // ── Audio sets ────────────────────────────────────────────────────────────
  List<AudioSetMeta> _audioSets  = [];
  String?            _activeSetId; // null = built-in / user recordings

  static const _kSetKey    = 'amarakosha_practice_set';       // legacy
  static const _kSetsKey   = 'amarakosha_practice_sets_v2';
  static const _kActiveIdx = 'amarakosha_active_set_idx';

  List<_SetItem> _decodeItems(List<dynamic> data) {
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
    return items;
  }

  Future<void> _saveSet() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _practiceSets.map((ns) => {
      'name' : ns.name,
      'items': ns.items.map((item) => {
        'label': item.label,
        'ids'  : item.padas.map((p) => p.id).toList(),
      }).toList(),
    }).toList();
    await prefs.setString(_kSetsKey, jsonEncode(data));
    await prefs.setInt(_kActiveIdx, _activeSetIdx);
  }

  Future<void> _restoreSet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Try new format first
      final raw = prefs.getString(_kSetsKey);
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as List<dynamic>;
        final sets = <_NamedSet>[];
        for (final s in data) {
          final name  = s['name'] as String;
          final items = _decodeItems((s['items'] as List<dynamic>));
          sets.add(_NamedSet(name, items));
        }
        if (mounted && sets.isNotEmpty) {
          final idx = (prefs.getInt(_kActiveIdx) ?? 0).clamp(0, sets.length - 1);
          setState(() { _practiceSets = sets; _activeSetIdx = idx; });
        }
      } else {
        // Migrate legacy single-set key
        final legacy = prefs.getString(_kSetKey);
        if (legacy != null && legacy.isNotEmpty) {
          final items = _decodeItems(jsonDecode(legacy) as List<dynamic>);
          if (mounted && items.isNotEmpty) {
            setState(() { _practiceSets = [_NamedSet('Practice Set', items)]; _activeSetIdx = 0; });
            _saveSet(); // persist in new format
          }
        }
      }
      if (!mounted) return;
      // Apply constructor overrides after restore
      if (widget.startWithNewSet) {
        final newName = 'Set ${_practiceSets.length + 1}';
        setState(() {
          _practiceSets.add(_NamedSet(newName));
          _activeSetIdx = _practiceSets.length - 1;
          _showSetPanel = true;
        });
        _saveSet();
      } else if (widget.initialSetIdx != 0 || widget.showSetPanel) {
        final idx = widget.initialSetIdx.clamp(0, _practiceSets.length - 1);
        setState(() { _activeSetIdx = idx; _showSetPanel = true; });
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
    _selKandaNum = widget.session.kanda.num;
    _selVargaSeq = widget.session.varga.seq;
    _selSecSeq   = widget.session.section.seq;
    _expandedKandas.add(_selKandaNum);
    _expandedVargas.add('${_selKandaNum}_$_selVargaSeq');
    _refreshPada();   // show bootstrap pada immediately
    _loadData();      // load full JSON in background
    _bindAudio();
    AppSettings.instance.addListener(_onSettings);
    _loadAudioSets();
  }

  @override
  void dispose() {
    _setTimer?.cancel();
    _setCompletionSub?.cancel();
    _setNameCtrl.dispose();
    AppSettings.instance.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() => setState(() {});

  bool get _isMobile => MediaQuery.of(context).size.width <= 768;

  // ── Named set management ──────────────────────────────────────────────────
  void _addPracticeSet() {
    if (_setPlaying) _stopSetPlayback();
    final n = _practiceSets.length + 1;
    setState(() {
      _practiceSets.add(_NamedSet('Set $n'));
      _activeSetIdx = _practiceSets.length - 1;
      _editingSetName = true;
    });
    _saveSet();
  }

  void _switchPracticeSet(int idx) {
    if (idx == _activeSetIdx) return;
    if (_setPlaying) _stopSetPlayback();
    setState(() { _activeSetIdx = idx; _editingSetName = false; });
    _saveSet();
  }

  void _renamePracticeSet(int idx, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    setState(() { _practiceSets[idx].name = trimmed; _editingSetName = false; });
    _saveSet();
  }

  void _deletePracticeSet(int idx) {
    if (_practiceSets.length <= 1) return; // always keep at least one
    if (_setPlaying) _stopSetPlayback();
    setState(() {
      _practiceSets.removeAt(idx);
      _activeSetIdx = _activeSetIdx.clamp(0, _practiceSets.length - 1);
      _editingSetName = false;
    });
    _saveSet();
  }

  // ── Range picker ─────────────────────────────────────────────────────────
  void _showRangeSheet({VoidCallback? onDone}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AC.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _RangeSheet(
        kandas: _kandas,
        onAdd: (item) {
          Navigator.pop(ctx);
          setState(() => _setItems.add(item));
          _saveSet();
          onDone?.call();
        },
      ),
    );
  }

  // ── Audio sets ────────────────────────────────────────────────────────────
  Future<void> _loadAudioSets() async {
    final sets = await AudioSetStore.instance.listSets();
    if (mounted) setState(() => _audioSets = sets);
  }

  Future<void> _importAudioSet() async {
    final bytes = await AudioSetStore.instance.pickFile();
    if (bytes == null || !mounted) return;

    final count = AudioSetStore.instance.countWavs(bytes);
    if (!mounted) return;

    final result = await showDialog<_ImportSetResult>(
      context: context,
      builder: (ctx) => _ImportSetDialog(wavCount: count, existingSets: _audioSets),
    );
    if (result == null || !mounted) return;

    try {
      final setId = await AudioSetStore.instance.importZip(
        bytes, name: result.name, updateId: result.updateId);
      if (!mounted) return;
      await _loadAudioSets();
      if (setId != null) setState(() => _activeSetId = setId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Import failed: $e',
            style: AT.garamond(13, color: Colors.white)),
        backgroundColor: AC.recRed,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

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
    setState(() { _pada = found; _progress = 0; });
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
    final withAudio = sec.padas.where((p) => AudioService.instance.hasAudio(p.id)).toList();
    if (withAudio.isEmpty) {
      _showSetToast('No audio available in "${sec.titleEn}"', error: true);
      return;
    }
    setState(() => _setItems.add(_SetItem(sec.titleEn, withAudio)));
    _saveSet();
    final skipped = sec.padas.length - withAudio.length;
    final msg = skipped > 0
        ? '"${sec.titleEn}" added (${withAudio.length} pādas; $skipped skipped — no audio)'
        : 'Section "${sec.titleEn}" added to Practice Set';
    _showSetToast(msg);
  }

  void _addPadaToSet(Pada pada) {
    if (!AudioService.instance.hasAudio(pada.id)) {
      _showSetToast('No audio for pāda ${pada.id}', error: true);
      return;
    }
    final label = pada.id;
    if (_setItems.any((i) => i.label == label)) return;
    setState(() => _setItems.add(_SetItem(label, [pada])));
    _saveSet();
    _showSetToast('Pāda ${pada.id} added to Practice Set');
  }

  void _removeFromSet(int idx) {
    setState(() => _setItems.removeAt(idx));
    _saveSet();
  }

  void _showSetToast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: AT.garamond(13, color: Colors.white)),
      duration: Duration(seconds: 2),
      backgroundColor: error ? AC.recRed : AC.accent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  int get _playsPerPada => _reciteMode ? _modelCount * (1 + _reciteCount) : _padaRepeat;
  int get _totalSetPadas =>
      _setItems.fold(0, (n, i) => n + i.padas.length) * _playsPerPada * _setRepeat;

  int get _setTotalPadasFlat =>
      _setItems.fold(0, (n, item) => n + item.padas.length);

  int get _setCurFlatIdx {
    if (_setItems.isEmpty) return 0;
    int idx = 0;
    final ci = _setCurItem.clamp(0, _setItems.length - 1);
    for (int i = 0; i < ci; i++) idx += _setItems[i].padas.length;
    if (_setItems[ci].padas.isEmpty) return idx;
    return idx + _setCurPada.clamp(0, _setItems[ci].padas.length - 1);
  }

  void _scrollToCurrentPlaylistPada() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _activePadaPlaylistKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 250),
            alignment: 0.3,
            curve: Curves.easeInOut);
      }
    });
  }

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
    setState(() { _setPlaying = false; _waitingForStep = false; });
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
    _scrollToCurrentPlaylistPada();

    // cycle position within [model, student×_reciteCount]: 0 = model, 1.._reciteCount = student
    final cyclePos = _reciteMode ? _setCurPadaRep % (1 + _reciteCount) : 0;
    final isRepeatPlay = _reciteMode && cyclePos > 0;
    final vol = isRepeatPlay ? AppSettings.instance.reciteVolumePct / 100.0 : 1.0;
    final hasAudio = await _audio.playPada(pada.id,
        speed: _speed, volume: vol, setId: _activeSetId);
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
          if (!_setPlaying) return;
          // Gap between consecutive student recitations within a cycle (not after model, not after last student)
          final needsGap = _reciteMode && _reciteGapSec > 0
              && cyclePos > 0 && cyclePos < _reciteCount;
          if (needsGap) {
            _setTimer = Timer(Duration(seconds: _reciteGapSec), _advanceSetPada);
          } else {
            _advanceSetPada();
          }
        }
      });
    }
  }

  void _advanceSetPada() {
    _setTimer?.cancel();
    if (!_setPlaying) return;
    // "all plays done" depends on mode:
    //   Guided: _modelCount cycles of [model play + _reciteCount student plays]
    //   Normal: repeat _padaRepeat times
    final allDone = _reciteMode
        ? _setCurPadaRep + 1 >= _modelCount * (1 + _reciteCount)
        : _setCurPadaRep + 1 >= _padaRepeat;
    if (!allDone) {
      setState(() => _setCurPadaRep++);
      _playCurrentSetPada();
    } else {
      setState(() { _setCurPada++; _setCurPadaRep = 0; });
      if (_stepMode) {
        setState(() => _waitingForStep = true);
      } else {
        _playCurrentSetPada();
      }
    }
  }

  void _stepNext() {
    if (!_setPlaying) return;
    setState(() => _waitingForStep = false);
    _playCurrentSetPada();
  }

  void _replayCurrentPada() {
    if (!_setPlaying) return;
    _setTimer?.cancel();
    _setCompletionSub?.cancel();
    _setCompletionSub = null;
    setState(() { _setCurPadaRep = 0; _waitingForStep = false; });
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
    await _audio.playPada(_pada!.id, speed: _speed, setId: _activeSetId);
    _advancing = false;
  }

  Future<void> _togglePlay() async {
    if (_playing) { await _audio.pause(); return; }
    final pada = _pada;
    if (pada == null) return;
    await _audio.playPada(pada.id, speed: _speed, setId: _activeSetId);
  }

  Future<void> _stopPlay() async {
    _advancing = false;
    await _audio.stop();
    setState(() { _playing = false; _progress = 0; });
  }


  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_pada == null) return Center(child: CircularProgressIndicator(color: AC.accent));
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
      padding: EdgeInsets.fromLTRB(6, 6, 12, 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AC.border))),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: widget.onBack,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.home_outlined, color: AC.accent, size: 16),
              SizedBox(width: 3),
              Text('Home', style: AT.garamond(15, color: AC.accent)),
            ]),
          ),
          // Mobile: Contents button opens tree overlay
          if (isMobile) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _mobileTreeOpen = true),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AC.border)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.menu_book_outlined, size: 13, color: AC.textSec),
                  SizedBox(width: 4),
                  Text('Contents', style: AT.garamond(12, color: AC.textSec)),
                ]),
              ),
            ),
          ],
          Expanded(child: Center(
            child: Builder(builder: (ctx) {
              String vname = '';
              for (final k in _kandas) {
                if (k.num != _selKandaNum) continue;
                for (final v in k.vargas) {
                  if (v.seq == _selVargaSeq) { vname = v.name; break; }
                }
              }
              if (isMobile) {
                return Text(vname, style: TextStyle(
                    fontFamily: 'TiroDevanagarSanskrit',
                    fontSize: 15, color: AC.textSec, height: 1.2));
              }
              return Column(mainAxisSize: MainAxisSize.min, children: [
                Text('अमरकोशः', style: TextStyle(
                    fontFamily: 'TiroDevanagarSanskrit',
                    fontSize: 11, color: AC.textMuted, height: 1.2)),
                const SizedBox(height: 1),
                Text(vname, style: TextStyle(
                    fontFamily: 'TiroDevanagarSanskrit',
                    fontSize: 14, color: AC.textSec, height: 1.2)),
              ]);
            }),
          )),
          // Practice Set toggle — side panel on desktop, bottom sheet on mobile
          GestureDetector(
            onTap: isMobile
                ? _showMobileSetSheet
                : () => setState(() => _showSetPanel = !_showSetPanel),
            child: Container(
              margin: EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (!isMobile && _showSetPanel) ? AC.accent.withOpacity(0.10) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: (!isMobile && _showSetPanel) ? AC.accent : AC.border)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.playlist_play_rounded, size: 14,
                    color: (!isMobile && _showSetPanel) ? AC.accent : AC.textSec),
                SizedBox(width: 4),
                Text('Set${_setItems.isEmpty ? "" : " (${_setItems.length})"}',
                    style: AT.garamond(12,
                        color: (!isMobile && _showSetPanel) ? AC.accent : AC.textSec)),
              ]),
            ),
          ),
          // Display settings
          GestureDetector(
            onTap: _showDisplaySettings,
            child: Container(
              margin: EdgeInsets.only(left: 8),
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AC.border)),
              child: Icon(Icons.text_fields_rounded, size: 14, color: AC.textSec),
            ),
          ),
        ]),
      ]),
    );
  }

  // ── Tree pane ─────────────────────────────────────────────────────────────
  Widget _buildTreePane() => Container(
    width: 220,
    color: AC.sidebar,
    child: Column(children: [
      Container(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: AC.sidebarHdr,
          border: Border(bottom: BorderSide(color: AC.sidebarBorder))),
        child: Row(children: [
          Text('Contents'.toUpperCase(),
              style: AT.garamond(11, color: AC.sidebarText, letterSpacing: 1.2,
                  weight: FontWeight.w700)),
          Spacer(),
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
          padding: EdgeInsets.fromLTRB(8, 9, 10, 9),
          color: Colors.transparent,
          child: Row(children: [
            Icon(exp ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                size: 16, color: AC.sidebarSel),
            SizedBox(width: 4),
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
          padding: EdgeInsets.fromLTRB(20, 6, 10, 6),
          color: sel ? AC.sidebarSel.withOpacity(0.14) : Colors.transparent,
          child: Row(children: [
            Icon(exp ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                size: 14, color: sel ? AC.sidebarSel : AC.sidebarMuted),
            SizedBox(width: 4),
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
          padding: EdgeInsets.fromLTRB(32, 6, 10, 6),
          decoration: BoxDecoration(
            color: sel ? AC.sidebarSel.withOpacity(0.16) : Colors.transparent,
            border: sel ? Border(left: BorderSide(color: AC.sidebarSel, width: 2)) : null),
          child: Row(children: [
            Expanded(child: Text(sec.titleEn,
                style: AT.garamond(AppSettings.instance.treeFontSize.toDouble(),
                    color: sel ? AC.sidebarSel : AC.sidebarText,
                    weight: AppSettings.instance.fontWeight))),
            if (inSet)
              Container(margin: EdgeInsets.only(right: 4),
                child: Icon(Icons.playlist_add_check_rounded,
                    size: 10, color: AC.sidebarSel)),
            if (sec.hasText)
              Container(width: 5, height: 5,
                  decoration: BoxDecoration(color: AC.loopActive, shape: BoxShape.circle)),
            SizedBox(width: 3),
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
        padding: EdgeInsets.fromLTRB(44, 4, 10, 4),
        decoration: BoxDecoration(
          color: sel ? AC.sidebarSel.withOpacity(0.12) : Colors.transparent,
          border: sel ? Border(left: BorderSide(color: AC.sidebarSel, width: 2)) : null),
        child: Row(children: [
          Text('P${p.padaNum}',
              style: AT.garamond((AppSettings.instance.treeFontSize - 1).toDouble(),
                  color: sel ? AC.sidebarSel : AC.sidebarMuted)),
          SizedBox(width: 5),
          Expanded(child: Text(p.id,
              style: AT.garamond(AppSettings.instance.treeFontSize.toDouble(),
                  color: sel ? AC.sidebarSel : AC.sidebarText))),
          if (hasAudio)
            Padding(
              padding: EdgeInsets.only(left: 3),
              child: Icon(Icons.volume_up_rounded, size: 9, color: AC.loopActive)),
          if (inSet)
            Padding(
              padding: EdgeInsets.only(left: 3),
              child: Icon(Icons.playlist_add_check_rounded, size: 10, color: AC.sidebarSel)),
          if (p.hasText)
            Container(margin: EdgeInsets.only(left: 3),
              child: Container(width: 4, height: 4,
                  decoration: BoxDecoration(color: AC.loopActive, shape: BoxShape.circle))),
        ]),
      ),
    );
  }

  // ── Set selector strip ────────────────────────────────────────────────────
  Widget _buildSetSelectorStrip({VoidCallback? setSheet}) => Container(
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AC.border))),
    child: Row(children: [
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(children: [
            for (int i = 0; i < _practiceSets.length; i++)
              _buildSetChip(i, setSheet: setSheet),
          ]),
        ),
      ),
      GestureDetector(
        onTap: () { _addPracticeSet(); setSheet?.call(); },
        child: Container(
          width: 34, height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              border: Border(left: BorderSide(color: AC.border))),
          child: Icon(Icons.add_rounded, size: 16, color: AC.textMuted),
        ),
      ),
    ]),
  );

  Widget _buildSetChip(int idx, {VoidCallback? setSheet}) {
    final active = idx == _activeSetIdx;
    if (active && _editingSetName) {
      return SizedBox(
        width: 88,
        child: TextField(
          controller: _setNameCtrl,
          autofocus: true,
          onSubmitted: (v) { _renamePracticeSet(idx, v); setSheet?.call(); },
          onTapOutside: (_) { _renamePracticeSet(idx, _setNameCtrl.text); setSheet?.call(); },
          style: AT.garamond(12, color: AC.text),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AC.accent)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AC.accent)),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () { _switchPracticeSet(idx); setSheet?.call(); },
      onLongPress: () {
        _setNameCtrl.text = _practiceSets[idx].name;
        setState(() { _activeSetIdx = idx; _editingSetName = true; });
        setSheet?.call();
      },
      child: Container(
        margin: EdgeInsets.only(right: 4),
        padding: EdgeInsets.fromLTRB(8, 3, _practiceSets.length > 1 ? 4 : 8, 3),
        decoration: BoxDecoration(
          color: active ? AC.accent : AC.chipBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AC.accent : AC.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_practiceSets[idx].name,
              style: AT.garamond(12, color: active ? Colors.white : AC.text)),
          if (_practiceSets.length > 1) ...[
            SizedBox(width: 3),
            GestureDetector(
              onTap: () { _deletePracticeSet(idx); setSheet?.call(); },
              child: Icon(Icons.close_rounded, size: 11,
                  color: active ? Colors.white : AC.textMuted),
            ),
          ],
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
        padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AC.border))),
        child: Row(children: [
          Text('Practice Sets'.toUpperCase(),
              style: AT.garamond(12, color: AC.textMuted, letterSpacing: 1.0)),
          Spacer(),
          if (_setItems.isNotEmpty)
            GestureDetector(
              onTap: () { setState(() => _setItems.clear()); _saveSet(); },
              child: Text('Clear', style: AT.garamond(13, color: AC.textMuted, italic: true)),
            ),
        ]),
      ),
      _buildSetSelectorStrip(),

      // Item list
      Expanded(child: _setItems.isEmpty
          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Long-press a Section or Pada in the tree to add it here.',
                  style: AT.garamond(12, color: AC.textMuted, italic: true, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
              GestureDetector(
                onTap: _showRangeSheet,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AC.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AC.border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.format_list_numbered_rounded, size: 14, color: AC.accent),
                    SizedBox(width: 6),
                    Text('Add by position',
                        style: AT.garamond(12, color: AC.accent, weight: FontWeight.w600)),
                  ]),
                ),
              ),
            ])
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
                  contentPadding: EdgeInsets.fromLTRB(10, 0, 4, 0),
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
                    child: Icon(Icons.close_rounded, size: 14, color: AC.textMuted),
                  ),
                );
              }).toList(),
            )),

      // Add range link
      GestureDetector(
        onTap: _showRangeSheet,
        child: Container(
          padding: EdgeInsets.fromLTRB(12, 6, 12, 6),
          decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AC.border))),
          child: Row(children: [
            Icon(Icons.add_rounded, size: 13, color: AC.textSec),
            SizedBox(width: 4),
            Text('Add range', style: AT.garamond(12, color: AC.textSec)),
          ]),
        ),
      ),

      // Repeat settings
      Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: AC.border))),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(children: [
          // Pada repeat / recite count
          if (!_reciteMode) ...[
            Row(children: [
              Expanded(child: Text('Each Pāda', style: AT.garamond(13, color: AC.text))),
              _SmallStepper(
                value: _padaRepeat,
                onDec: _padaRepeat > 1 ? () => setState(() => _padaRepeat--) : null,
                onInc: _padaRepeat < 20 ? () => setState(() => _padaRepeat++) : null,
              ),
            ]),
            SizedBox(height: 8),
          ] else ...[
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Teacher plays', style: AT.garamond(13, color: AC.text)),
                Text('model + student cycles', style: AT.garamond(11, color: AC.textSec)),
              ])),
              _SmallStepper(
                value: _modelCount,
                onDec: _modelCount > 1 ? () => setState(() => _modelCount--) : null,
                onInc: _modelCount < 5 ? () => setState(() => _modelCount++) : null,
              ),
            ]),
            SizedBox(height: 8),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Student recites', style: AT.garamond(13, color: AC.text)),
                Text('times per teacher play', style: AT.garamond(11, color: AC.textSec)),
              ])),
              _SmallStepper(
                value: _reciteCount,
                onDec: _reciteCount > 1 ? () => setState(() => _reciteCount--) : null,
                onInc: _reciteCount < 5 ? () => setState(() => _reciteCount++) : null,
              ),
            ]),
            SizedBox(height: 8),
          ],
          // Set repeat
          Row(children: [
            Expanded(child: Text('Full Set', style: AT.garamond(13, color: AC.text))),
            _SmallStepper(
              value: _setRepeat,
              onDec: _setRepeat > 1 ? () => setState(() => _setRepeat--) : null,
              onInc: _setRepeat < 20 ? () => setState(() => _setRepeat++) : null,
            ),
          ]),
          if (_setItems.isNotEmpty) ...[
            SizedBox(height: 4),
            Text('$_totalSetPadas total pādas',
                style: AT.garamond(12, color: AC.textSec)),
          ],
          const SizedBox(height: 8),
          // Guided Practice toggle
          GestureDetector(
            onTap: () => setState(() => _reciteMode = !_reciteMode),
            child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Guided Practice', style: AT.garamond(13, color: AC.text)),
                  Text('model plays, then student recites', style: AT.garamond(11, color: AC.textSec)),
                ])),
                Container(
                  width: 36, height: 20,
                  decoration: BoxDecoration(
                    color: _reciteMode ? AC.accent : AC.border,
                    borderRadius: BorderRadius.circular(10)),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 150),
                    alignment: _reciteMode ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 16, height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ]),
          ),
          if (_reciteMode) ...[
            SizedBox(height: 6),
            Row(children: [
              Expanded(child: Text('Student volume',
                  style: AT.garamond(13, color: AC.text))),
              _SmallStepper(
                value: AppSettings.instance.reciteVolumePct,
                label: '${AppSettings.instance.reciteVolumePct}%',
                onDec: AppSettings.instance.reciteVolumePct > 0
                    ? () => AppSettings.instance.setReciteVolumePct(
                        AppSettings.instance.reciteVolumePct - 2)
                    : null,
                onInc: AppSettings.instance.reciteVolumePct < 20
                    ? () => AppSettings.instance.setReciteVolumePct(
                        AppSettings.instance.reciteVolumePct + 2)
                    : null,
              ),
            ]),
            if (_reciteCount > 1) ...[
              SizedBox(height: 6),
              Row(children: [
                Expanded(child: Text('Gap between recitations',
                    style: AT.garamond(13, color: AC.text))),
                _SmallStepper(
                  value: _reciteGapSec,
                  label: '${_reciteGapSec}s',
                  onDec: _reciteGapSec > 0 ? () => setState(() => _reciteGapSec--) : null,
                  onInc: _reciteGapSec < 5 ? () => setState(() => _reciteGapSec++) : null,
                ),
              ]),
            ],
          ],
          if (_reciteMode) ...[
            SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _stepMode = !_stepMode),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Step through pādas', style: AT.garamond(13, color: AC.text)),
                  Text('press Next to advance', style: AT.garamond(11, color: AC.textSec)),
                ])),
                Container(
                  width: 36, height: 20,
                  decoration: BoxDecoration(
                    color: _stepMode ? AC.accent : AC.border,
                    borderRadius: BorderRadius.circular(10)),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 150),
                    alignment: _stepMode ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 16, height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ]),
            ),
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
                padding: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _setPlaying ? AC.recRed : AC.btnBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_setPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      color: AC.btnText, size: 16),
                  SizedBox(width: 6),
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
      decoration: BoxDecoration(
        color: AC.surface,
        border: Border(top: BorderSide(color: AC.border))),
      padding: EdgeInsets.symmetric(horizontal: 16),
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
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AC.recRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AC.recRed)),
            child: Text('Playing', style: AT.garamond(12, color: AC.recRed)),
          ),
        Icon(Icons.expand_less_rounded, color: AC.textMuted, size: 18),
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
                margin: EdgeInsets.only(top: 8, bottom: 4),
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AC.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Row(children: [
                Text('Practice Sets'.toUpperCase(),
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
            _buildSetSelectorStrip(setSheet: () => setSheet(() {})),
            Expanded(child: _setItems.isEmpty
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Text(
                      'Long-press a Section or Pada in the tree to add it here.',
                      style: AT.garamond(13, color: AC.textMuted, italic: true, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showRangeSheet(onDone: () => setSheet(() {})),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AC.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AC.border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.format_list_numbered_rounded, size: 14, color: AC.accent),
                        SizedBox(width: 6),
                        Text('Add by position',
                            style: AT.garamond(13, color: AC.accent, weight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ])
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
                      contentPadding: EdgeInsets.fromLTRB(16, 0, 8, 0),
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
                        child: Icon(Icons.close_rounded,
                            size: 16, color: AC.textMuted),
                      ),
                    );
                  }).toList(),
                )),
            // Add range link
            GestureDetector(
              onTap: () => _showRangeSheet(onDone: () => setSheet(() {})),
              child: Container(
                padding: EdgeInsets.fromLTRB(16, 7, 16, 7),
                decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: AC.border))),
                child: Row(children: [
                  Icon(Icons.add_rounded, size: 13, color: AC.textSec),
                  SizedBox(width: 5),
                  Text('Add range', style: AT.garamond(13, color: AC.textSec)),
                ]),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AC.border))),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(children: [
                if (!_reciteMode) ...[
                  Row(children: [
                    Expanded(child: Text('Each Pāda', style: AT.garamond(13, color: AC.text))),
                    _SmallStepper(
                      value: _padaRepeat,
                      onDec: _padaRepeat > 1
                          ? () { setState(() => _padaRepeat--); setSheet(() {}); } : null,
                      onInc: _padaRepeat < 20
                          ? () { setState(() => _padaRepeat++); setSheet(() {}); } : null,
                    ),
                  ]),
                  const SizedBox(height: 10),
                ] else ...[
                  Row(children: [
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Teacher plays', style: AT.garamond(13, color: AC.text)),
                          Text('model + student cycles',
                              style: AT.garamond(11, color: AC.textSec)),
                        ])),
                    _SmallStepper(
                      value: _modelCount,
                      onDec: _modelCount > 1 ? () { setState(() => _modelCount--); setSheet(() {}); } : null,
                      onInc: _modelCount < 5 ? () { setState(() => _modelCount++); setSheet(() {}); } : null,
                    ),
                  ]),
                  SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Student recites', style: AT.garamond(13, color: AC.text)),
                          Text('times per teacher play',
                              style: AT.garamond(11, color: AC.textSec)),
                        ])),
                    _SmallStepper(
                      value: _reciteCount,
                      onDec: _reciteCount > 1 ? () { setState(() => _reciteCount--); setSheet(() {}); } : null,
                      onInc: _reciteCount < 5 ? () { setState(() => _reciteCount++); setSheet(() {}); } : null,
                    ),
                  ]),
                  const SizedBox(height: 10),
                ],
                Row(children: [
                  Expanded(child: Text('Full Set', style: AT.garamond(13, color: AC.text))),
                  _SmallStepper(
                    value: _setRepeat,
                    onDec: _setRepeat > 1
                        ? () { setState(() => _setRepeat--); setSheet(() {}); } : null,
                    onInc: _setRepeat < 20
                        ? () { setState(() => _setRepeat++); setSheet(() {}); } : null,
                  ),
                ]),
                if (_setItems.isNotEmpty) ...[
                  SizedBox(height: 6),
                  Text('$_totalSetPadas total pādas',
                      style: AT.garamond(12, color: AC.textSec)),
                ],
                const SizedBox(height: 10),
                // Guided Practice toggle
                GestureDetector(
                  onTap: () {
                    setState(() => _reciteMode = !_reciteMode);
                    setSheet(() {});
                  },
                  child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Guided Practice', style: AT.garamond(13, color: AC.text)),
                        Text('model plays, then student recites', style: AT.garamond(11, color: AC.textSec)),
                      ])),
                      Container(
                        width: 36, height: 20,
                        decoration: BoxDecoration(
                          color: _reciteMode ? AC.accent : AC.border,
                          borderRadius: BorderRadius.circular(10)),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 150),
                          alignment: _reciteMode ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            width: 16, height: 16,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle),
                          ),
                        ),
                      ),
                    ]),
                ),
                if (_reciteMode) ...[
                  SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: Text('Student volume',
                        style: AT.garamond(13, color: AC.text))),
                    _SmallStepper(
                      value: AppSettings.instance.reciteVolumePct,
                      label: '${AppSettings.instance.reciteVolumePct}%',
                      onDec: AppSettings.instance.reciteVolumePct > 0
                          ? () { AppSettings.instance.setReciteVolumePct(
                                AppSettings.instance.reciteVolumePct - 2);
                                setSheet(() {}); }
                          : null,
                      onInc: AppSettings.instance.reciteVolumePct < 20
                          ? () { AppSettings.instance.setReciteVolumePct(
                                AppSettings.instance.reciteVolumePct + 2);
                                setSheet(() {}); }
                          : null,
                    ),
                  ]),
                  if (_reciteCount > 1) ...[
                    SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: Text('Gap between recitations',
                          style: AT.garamond(13, color: AC.text))),
                      _SmallStepper(
                        value: _reciteGapSec,
                        label: '${_reciteGapSec}s',
                        onDec: _reciteGapSec > 0
                            ? () { setState(() => _reciteGapSec--); setSheet(() {}); } : null,
                        onInc: _reciteGapSec < 5
                            ? () { setState(() => _reciteGapSec++); setSheet(() {}); } : null,
                      ),
                    ]),
                  ],
                ],
                if (_reciteMode) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() => _stepMode = !_stepMode);
                      setSheet(() {});
                    },
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Step through pādas', style: AT.garamond(13, color: AC.text)),
                        Text('press Next to advance', style: AT.garamond(11, color: AC.textSec)),
                      ])),
                      Container(
                        width: 36, height: 20,
                        decoration: BoxDecoration(
                          color: _stepMode ? AC.accent : AC.border,
                          borderRadius: BorderRadius.circular(10)),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 150),
                          alignment: _stepMode ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            width: 16, height: 16,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle),
                          ),
                        ),
                      ),
                    ]),
                  ),
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
                      padding: EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _setPlaying ? AC.recRed : AC.btnBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Icon(
                          _setPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          color: AC.btnText, size: 20),
                        SizedBox(width: 8),
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
                  padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: AC.sidebarHdr,
                    border: Border(bottom: BorderSide(color: AC.sidebarBorder))),
                  child: Row(children: [
                    Text('Contents'.toUpperCase(),
                        style: AT.garamond(12, color: AC.sidebarText,
                            letterSpacing: 1.2, weight: FontWeight.w700)),
                    Spacer(),
                    Text('Long-press → Set',
                        style: AT.garamond(10, color: AC.sidebarMuted,
                            italic: true)),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => setState(() => _mobileTreeOpen = false),
                      child: Icon(Icons.close_rounded,
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
    if (pada == null) return Center(child: CircularProgressIndicator(color: AC.accent));

    if (_setPlaying || _waitingForStep) return _buildSetPlaylistView(pada);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 44),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildProgress(pada),
        _buildPadaBox(pada),
        _buildPrevNext(),
        _buildWordChips(pada),
        _buildPlayer(),
      ]),
    );
  }

  // ── Prev / Next navigation (normal browse mode) ───────────────────────────
  Widget _buildPrevNext() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      child: Row(children: [
        GestureDetector(
          onTap: _prevPada,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AC.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.arrow_back_rounded, size: 14, color: AC.textSec),
              SizedBox(width: 4),
              Text('Prev', style: AT.garamond(13, color: AC.textSec)),
            ]),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: _nextPada,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AC.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Next', style: AT.garamond(13, color: AC.textSec)),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 14, color: AC.textSec),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Playlist view (set playing / waiting for step) ────────────────────────
  Widget _buildSetPlaylistView(Pada activePada) {
    final s       = AppSettings.instance;
    final flatIdx = _setCurFlatIdx;
    final total   = _setTotalPadasFlat;

    // Build item-heading + pada-row list
    int fi = 0;
    final listChildren = <Widget>[];
    final ctxBefore = s.setPlaylistContextBefore;
    final ctxAfter  = s.setPlaylistContextAfter;
    for (final item in _setItems) {
      if (item.label.isNotEmpty) {
        listChildren.add(Padding(
          padding: EdgeInsets.fromLTRB(0, 10, 0, 4),
          child: Text(item.label.toUpperCase(),
              style: AT.garamond(10, color: AC.textMuted,
                  letterSpacing: 0.6, weight: FontWeight.w600)),
        ));
      }
      for (final p in item.padas) {
        final isActive = fi == flatIdx;
        if (isActive && (ctxBefore > 0 || ctxAfter > 0)) {
          // Insert context padas from the corpus around the active pada
          final entries = _buildBoxEntries(p,
              ctxBeforeOverride: ctxBefore,
              ctxAfterOverride: ctxAfter);
          for (final entry in entries) {
            if (entry.isHeading) continue; // skip section/varga headings in playlist
            if (entry.isActive) {
              listChildren.add(_buildPlaylistPadaRow(p,
                  isActive: true, key: _activePadaPlaylistKey));
            } else {
              listChildren.add(_buildContextPadaInPlaylist(entry.pada!));
            }
          }
        } else {
          listChildren.add(_buildPlaylistPadaRow(p,
              isActive: isActive,
              key: isActive ? _activePadaPlaylistKey : null));
        }
        fi++;
      }
    }

    return Column(children: [
      // Header: set name · current/total  +  Replay / Next (step mode)
      Padding(
        padding: EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: Row(children: [
          Expanded(child: Text(
            '${_practiceSets[_activeSetIdx].name}  ·  ${flatIdx + 1} / $total',
            style: AT.garamond(s.uiFontSize.toDouble(), color: AC.textSec),
            overflow: TextOverflow.ellipsis,
          )),
          GestureDetector(
            onTap: _replayCurrentPada,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AC.border)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.replay_rounded, size: 12, color: AC.textMuted),
                SizedBox(width: 3),
                Text('Replay', style: AT.garamond(
                    (s.uiFontSize - 1).toDouble(), color: AC.textMuted)),
              ]),
            ),
          ),
          if (_waitingForStep) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _stepNext,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AC.accent, borderRadius: BorderRadius.circular(4)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Next', style: AT.garamond(
                      (s.uiFontSize - 1).toDouble(), color: Colors.white)),
                  const SizedBox(width: 3),
                  const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                ]),
              ),
            ),
          ],
        ]),
      ),
      // Scrollable pada list
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: listChildren,
        ),
      )),
      // Audio player
      _buildPlayer(),
    ]);
  }

  Widget _buildPlaylistPadaRow(Pada p, {required bool isActive, Key? key}) {
    final s = AppSettings.instance;
    Widget content;
    if (!p.hasText) {
      content = Text('[no text available]',
          style: AT.garamond(12, color: AC.textMuted, italic: true));
    } else {
      content = Text.rich(TextSpan(children: [
        TextSpan(
          text: '${p.id} ${p.padaNum == 1 ? "A" : "B"}  ',
          style: AT.garamond(
              (s.devFontSize * 0.52).clamp(10.0, 16.0),
              color: AC.textMuted, italic: true),
        ),
        TextSpan(
          text: p.textDev,
          style: AT.devanagari(
              s.devFontSize.toDouble(),
              color: isActive ? AC.text : AC.textSec,
              family: s.devFontFamily),
        ),
      ]));
    }
    if (isActive) {
      return Container(
        key: key,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: AD.activeLine(),
        child: content,
      );
    }
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(width: double.infinity, child: content),
    );
  }

  // Context pada shown in playlist — dimmer than non-active set padas
  Widget _buildContextPadaInPlaylist(Pada p) {
    final s = AppSettings.instance;
    Widget content;
    if (!p.hasText) {
      content = Text('[no text]',
          style: AT.garamond(11, color: AC.textMuted, italic: true));
    } else {
      content = Text.rich(TextSpan(children: [
        TextSpan(
          text: '${p.id} ${p.padaNum == 1 ? "A" : "B"}  ',
          style: AT.garamond(
              (s.devFontSize * 0.52).clamp(10.0, 16.0),
              color: AC.textMuted, italic: true),
        ),
        TextSpan(
          text: p.textDev,
          style: AT.devanagari(
              s.devFontSize.toDouble(),
              color: AC.textMuted,
              family: s.devFontFamily),
        ),
      ]));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SizedBox(width: double.infinity, child: content),
    );
  }

  // ── Display settings sheet ────────────────────────────────────────────────
  void _showDisplaySettings() => showDisplaySettingsSheet(context);

  Widget _buildProgress(Pada pada) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'Pāda $_selPadaSeq of $_sectionPadaCount'
        '${_currentSection != null ? "  ·  ${_currentSection!.titleEn}" : ""}',
        style: AT.garamond(AppSettings.instance.uiFontSize.toDouble(),
            color: AC.textSec, weight: AppSettings.instance.fontWeight),
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 6),
      AProgressBar(value: _sectionPadaCount > 0 ? _selPadaSeq / _sectionPadaCount : 0),
    ]),
  );

  Widget _buildPadaBox(Pada activePada) {
    final s          = AppSettings.instance;
    final pad        = _isMobile ? 16.0 : 14.0;
    final hasButtons = _setPlaying || _waitingForStep;
    final entries    = _buildBoxEntries(activePada);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      padding: EdgeInsets.all(pad),
      decoration: AD.card(radius: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Replay / Next — only visible during set playback
        if (hasButtons) ...[
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            GestureDetector(
              onTap: _replayCurrentPada,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AC.border)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.replay_rounded, size: 12, color: AC.textMuted),
                  SizedBox(width: 3),
                  Text('Replay', style: AT.garamond(
                      (s.uiFontSize - 1).toDouble(), color: AC.textMuted)),
                ]),
              ),
            ),
            if (_waitingForStep) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _stepNext,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AC.accent, borderRadius: BorderRadius.circular(4)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Next', style: AT.garamond(
                        (s.uiFontSize - 1).toDouble(), color: Colors.white)),
                    const SizedBox(width: 3),
                    const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                  ]),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 10),
        ],
        // Context + active padas with section/varga headings at boundaries
        for (final entry in entries)
          if (entry.isHeading)
            _buildBoxHeading(entry)
          else
            _buildPadaRowInBox(entry),
      ]),
    );
  }

  Widget _buildBoxHeading(_BoxEntry entry) {
    final s = AppSettings.instance;
    if (entry.isVargaHeading) {
      return Padding(
        padding: EdgeInsets.fromLTRB(2, 10, 2, 4),
        child: Text(entry.headingText,
            style: TextStyle(
                fontFamily: 'TiroDevanagarSanskrit',
                fontSize: (s.devFontSize * 0.75).clamp(12.0, 18.0),
                color: AC.textSec, height: 1.4)),
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(2, 8, 2, 3),
      child: Text(entry.headingText.toUpperCase(),
          style: AT.garamond(10, color: AC.textMuted,
              letterSpacing: 0.6, weight: FontWeight.w600)),
    );
  }

  List<_BoxEntry> _buildBoxEntries(Pada activePada, {int? ctxBeforeOverride, int? ctxAfterOverride}) {
    // Flat list: all padas across all kandas/vargas/sections in order
    final flat = <_FlatPadaRef>[];
    for (final k in _kandas) {
      for (final v in k.vargas) {
        for (final sec in v.sections) {
          for (final p in sec.padas) {
            flat.add(_FlatPadaRef(k, v, sec, p));
          }
        }
      }
    }
    final activeIdx = flat.indexWhere((e) => e.pada.id == activePada.id);
    if (activeIdx < 0) {
      return [_BoxEntry.pada(activePada,
          isActive: true,
          kandaNum: _selKandaNum,
          vargaSeq: _selVargaSeq,
          secSeq: _selSecSeq)];
    }

    final ctxBefore = ctxBeforeOverride ?? AppSettings.instance.contextBefore;
    final ctxAfter  = ctxAfterOverride  ?? AppSettings.instance.contextAfter;
    final start = (activeIdx - ctxBefore).clamp(0, flat.length - 1);
    final end   = (activeIdx + ctxAfter).clamp(0, flat.length - 1);

    final entries = <_BoxEntry>[];
    // Init to active pada's keys so a heading appears when context crosses its boundary
    final ae = flat[activeIdx];
    var lastVKey = '${ae.kanda.num}_${ae.varga.seq}';
    var lastSKey = '${ae.kanda.num}_${ae.varga.seq}_${ae.section.seq}';

    for (int i = start; i <= end; i++) {
      final e    = flat[i];
      final vKey = '${e.kanda.num}_${e.varga.seq}';
      final sKey = '${e.kanda.num}_${e.varga.seq}_${e.section.seq}';

      if (vKey != lastVKey) {
        entries.add(_BoxEntry.heading(e.varga.name, isVargaHeading: true));
      }
      if (sKey != lastSKey && e.section.titleEn.isNotEmpty) {
        entries.add(_BoxEntry.heading(e.section.titleEn, isVargaHeading: false));
      }

      entries.add(_BoxEntry.pada(e.pada,
          isActive: i == activeIdx,
          kandaNum: e.kanda.num,
          vargaSeq: e.varga.seq,
          secSeq: e.section.seq));

      lastVKey = vKey;
      lastSKey = sKey;
    }
    return entries;
  }

  Widget _buildPadaRowInBox(_BoxEntry entry) {
    final p        = entry.pada!;
    final isActive = entry.isActive;
    final s        = AppSettings.instance;
    Widget content;
    if (!p.hasText) {
      content = Text('[no text available]',
          style: AT.garamond(12, color: AC.textMuted, italic: true));
    } else {
      content = Text.rich(TextSpan(children: [
        TextSpan(
          text: '${p.id} ${p.padaNum == 1 ? "A" : "B"}  ',
          style: AT.garamond(
              (s.devFontSize * 0.52).clamp(10.0, 16.0),
              color: AC.textMuted, italic: true),
        ),
        TextSpan(
          text: p.textDev,
          style: AT.devanagari(
              s.devFontSize.toDouble(),
              color: isActive ? AC.text : AC.textSec,
              family: s.devFontFamily),
        ),
      ]));
    }
    if (isActive) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: AD.activeLine(),
        child: content,
      );
    }
    return GestureDetector(
      onTap: () => _goTo(entry.kandaNum, entry.vargaSeq, entry.secSeq, p.seq),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
          child: content,
        ),
      ),
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
                style: AT.garamond(11, color: AC.textMuted, letterSpacing: 0.7)),
            SizedBox(width: 3),
            Text('${pada.words.length}',
                style: AT.garamond(11, color: AC.textMuted)),
            SizedBox(width: 2),
            Icon(_showWords ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                size: 13, color: AC.textMuted),
          ]),
        ),
        if (_showWords) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: pada.words.map((w) {
            return GestureDetector(
              onLongPress: () => GrammarSheet.show(context, w),
              child: Container(
                padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
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
      // Audio source chips — no heading; chips are self-labelled
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _AudioSetChip(
              label: 'Built-in',
              active: _activeSetId == null,
              onTap: () => setState(() => _activeSetId = null),
            ),
            ..._audioSets.map((s) => _AudioSetChip(
              label: s.name,
              active: _activeSetId == s.id,
              onTap: () => setState(() => _activeSetId = s.id),
              onDelete: () async {
                await AudioSetStore.instance.deleteSet(s.id);
                if (!mounted) return;
                if (_activeSetId == s.id) setState(() => _activeSetId = null);
                await _loadAudioSets();
              },
            )),
            GestureDetector(
              onTap: _importAudioSet,
              child: Container(
                margin: const EdgeInsets.only(left: 4),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AC.border)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, size: 12, color: AC.textMuted),
                  SizedBox(width: 3),
                  Text('Import', style: AT.garamond(12, color: AC.textMuted)),
                ]),
              ),
            ),
          ]),
        ),
      ),
      // Progress bar
      Padding(
        padding: EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _progress, backgroundColor: AC.trackBg, minHeight: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AC.trackFill)),
        ),
      ),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: Icon(Icons.skip_previous_rounded),
            color: AC.textSec, iconSize: mob ? 26.0 : 20.0, onPressed: _prevPada),
        GestureDetector(onTap: _stopPlay, child: Container(
          width: mob ? 36 : 32, height: mob ? 36 : 32,
          decoration: BoxDecoration(color: AC.surfaceAlt, shape: BoxShape.circle,
              border: Border.all(color: AC.border)),
          child: Icon(Icons.stop_rounded, color: AC.textSec, size: mob ? 16 : 14))),
        SizedBox(width: 6),
        GestureDetector(onTap: _togglePlay, child: Container(
          width: mob ? 50 : 46, height: mob ? 50 : 46,
          decoration: BoxDecoration(color: AC.btnBg, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AC.trackFill.withOpacity(0.33),
                blurRadius: 10, offset: Offset(0, 3))]),
          child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: AC.btnText, size: mob ? 24 : 22))),
        const SizedBox(width: 6),
        IconButton(icon: Icon(Icons.skip_next_rounded),
            color: AC.textSec, iconSize: mob ? 26.0 : 20.0, onPressed: _nextPada),
      ]),
      const SizedBox(height: 4),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Row(children: [
          // Speed chips
          ...[0.5, 0.75, 1.0, 1.25, 1.5].map((s) {
            final active = _speed == s;
            return GestureDetector(
              onTap: () { setState(() => _speed = s); _audio.player.setSpeed(s); },
              child: Container(
                margin: EdgeInsets.only(right: 4),
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: active ? AC.trackFill.withOpacity(0.13) : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: active ? AC.trackFill : AC.borderLight)),
                child: Text('${s}x',
                    style: AT.garamond(13, color: active ? AC.trackFill : AC.textMuted)),
              ),
            );
          }),
          const Spacer(),
          // Auto-advance toggle
          GestureDetector(
            onTap: () => setState(() => _autoAdvance = !_autoAdvance),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _autoAdvance ? AC.accent.withOpacity(0.10) : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: _autoAdvance ? AC.accent : AC.borderLight)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.fast_forward_rounded, size: 12,
                    color: _autoAdvance ? AC.accent : AC.textMuted),
                SizedBox(width: 3),
                Text('Auto', style: AT.garamond(12,
                    color: _autoAdvance ? AC.accent : AC.textMuted)),
              ]),
            ),
          ),
        ]),
      ),
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
        SizedBox(height: 6),
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
  final String? label;
  final VoidCallback? onDec, onInc;
  const _SmallStepper({required this.value, this.label, this.onDec, this.onInc});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    GestureDetector(
      onTap: onDec,
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(color: AC.surfaceAlt,
            borderRadius: BorderRadius.circular(6), border: Border.all(color: AC.border)),
        child: Center(child: Opacity(opacity: onDec != null ? 1 : 0.3,
            child: Icon(Icons.remove_rounded, size: 12, color: AC.textSec))),
      ),
    ),
    Container(
      width: 32, alignment: Alignment.center,
      child: Text(label ?? '$value', style: AT.garamond(14, color: AC.text)),
    ),
    GestureDetector(
      onTap: onInc,
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(color: AC.surfaceAlt,
            borderRadius: BorderRadius.circular(6), border: Border.all(color: AC.border)),
        child: Center(child: Opacity(opacity: onInc != null ? 1 : 0.3,
            child: Icon(Icons.add_rounded, size: 12, color: AC.textSec))),
      ),
    ),
  ]);
}


// ─── Audio set chip ────────────────────────────────────────────────────────────
class _AudioSetChip extends StatelessWidget {
  final String        label;
  final bool          active;
  final VoidCallback  onTap;
  final VoidCallback? onDelete;
  const _AudioSetChip({
    required this.label, required this.active,
    required this.onTap, this.onDelete,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: EdgeInsets.only(right: 6),
      padding: EdgeInsets.fromLTRB(10, 4, active && onDelete != null ? 4 : 10, 4),
      decoration: BoxDecoration(
        color: active ? AC.accent.withOpacity(0.10) : AC.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? AC.accent : AC.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: AT.garamond(12,
            color: active ? AC.accent : AC.textSec)),
        if (active && onDelete != null) ...[
          SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.close_rounded, size: 12, color: AC.textMuted),
          ),
        ],
      ]),
    ),
  );
}

// ─── Import set dialog ─────────────────────────────────────────────────────────
class _ImportSetResult {
  final String  name;
  final String? updateId;
  const _ImportSetResult(this.name, this.updateId);
}

class _ImportSetDialog extends StatefulWidget {
  final int                wavCount;
  final List<AudioSetMeta> existingSets;
  const _ImportSetDialog({required this.wavCount, required this.existingSets});
  @override
  State<_ImportSetDialog> createState() => _ImportSetDialogState();
}

class _ImportSetDialogState extends State<_ImportSetDialog> {
  late final TextEditingController _nameCtrl;
  bool    _updating = false;
  String? _updateId;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: 'Imported Set');
    if (widget.existingSets.isNotEmpty) _updateId = widget.existingSets.first.id;
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final canImport = widget.wavCount > 0 &&
        (_updating ? _updateId != null : _nameCtrl.text.trim().isNotEmpty);
    return AlertDialog(
      backgroundColor: AC.surface,
      title: Text('Import Audio Set', style: AT.garamond(18, color: AC.text)),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            widget.wavCount > 0
                ? 'Found ${widget.wavCount} WAV recording${widget.wavCount != 1 ? "s" : ""} in ZIP.'
                : 'No WAV files found in this ZIP.',
            style: AT.garamond(14, color: widget.wavCount > 0 ? AC.text : AC.recRed),
          ),
          if (widget.wavCount > 0) ...[
            SizedBox(height: 16),
            if (widget.existingSets.isNotEmpty)
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Create new set', style: AT.garamond(14, color: AC.text)),
                  value: false, groupValue: _updating,
                  activeColor: AC.accent,
                  onChanged: (v) => setState(() => _updating = false),
                ),
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Update existing set', style: AT.garamond(14, color: AC.text)),
                  value: true, groupValue: _updating,
                  activeColor: AC.accent,
                  onChanged: (v) => setState(() => _updating = true),
                ),
              ]),
            SizedBox(height: 8),
            if (!_updating) ...[
              Text('Set name', style: AT.garamond(13, color: AC.textSec)),
              SizedBox(height: 4),
              TextField(
                controller: _nameCtrl,
                onChanged: (_) => setState(() {}),
                style: AT.garamond(14, color: AC.text),
                decoration: InputDecoration(
                  filled: true, fillColor: AC.surfaceAlt,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AC.border)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AC.border)),
                ),
              ),
            ] else ...[
              Text('Select set to update', style: AT.garamond(13, color: AC.textSec)),
              SizedBox(height: 4),
              DropdownButton<String>(
                value: _updateId,
                isExpanded: true,
                style: AT.garamond(14, color: AC.text),
                dropdownColor: AC.surface,
                underline: Container(height: 1, color: AC.border),
                onChanged: (v) => setState(() => _updateId = v),
                items: widget.existingSets.map((s) => DropdownMenuItem(
                  value: s.id,
                  child: Text(s.name, style: AT.garamond(14, color: AC.text)),
                )).toList(),
              ),
            ],
          ],
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: AT.garamond(14, color: AC.textMuted)),
        ),
        TextButton(
          onPressed: canImport
              ? () => Navigator.pop(context, _ImportSetResult(
                  _updating
                      ? (widget.existingSets
                            .firstWhere((s) => s.id == _updateId!).name)
                      : _nameCtrl.text.trim(),
                  _updating ? _updateId : null))
              : null,
          child: Text(_updating ? 'Update' : 'Import',
              style: AT.garamond(14,
                  color: canImport ? AC.accent : AC.textMuted)),
        ),
      ],
    );
  }
}

// ─── Flat pada reference (used for cross-boundary context) ────────────────────
class _FlatPadaRef {
  final Kanda   kanda;
  final Varga   varga;
  final Section section;
  final Pada    pada;
  const _FlatPadaRef(this.kanda, this.varga, this.section, this.pada);
}

// ─── Unified pada-box entry (heading or pada row) ─────────────────────────────
class _BoxEntry {
  final bool   isHeading;
  final String headingText;
  final bool   isVargaHeading;
  final Pada?  pada;
  final bool   isActive;
  final int    kandaNum;
  final int    vargaSeq;
  final int    secSeq;

  const _BoxEntry._({
    required this.isHeading,
    required this.headingText,
    required this.isVargaHeading,
    required this.pada,
    required this.isActive,
    required this.kandaNum,
    required this.vargaSeq,
    required this.secSeq,
  });

  factory _BoxEntry.heading(String text, {required bool isVargaHeading}) =>
      _BoxEntry._(
        isHeading: true, headingText: text,
        isVargaHeading: isVargaHeading,
        pada: null, isActive: false,
        kandaNum: 0, vargaSeq: 0, secSeq: 0,
      );

  factory _BoxEntry.pada(Pada p, {
    required bool isActive,
    required int  kandaNum,
    required int  vargaSeq,
    required int  secSeq,
  }) => _BoxEntry._(
        isHeading: false, headingText: '',
        isVargaHeading: false,
        pada: p, isActive: isActive,
        kandaNum: kandaNum, vargaSeq: vargaSeq, secSeq: secSeq,
      );
}

// ─── Range picker sheet ────────────────────────────────────────────────────────

class _PadaListEntry {
  final bool   isHeader;
  final String headerTitle;
  final Pada?  pada;
  final int    flatIdx;
  _PadaListEntry.header(this.headerTitle) : isHeader = true, pada = null, flatIdx = -1;
  _PadaListEntry.pada(Pada p, int i) : isHeader = false, headerTitle = '', pada = p, flatIdx = i;
}

class _RangeSheet extends StatefulWidget {
  final List<Kanda>              kandas;
  final void Function(_SetItem) onAdd;
  const _RangeSheet({required this.kandas, required this.onAdd});
  @override State<_RangeSheet> createState() => _RangeSheetState();
}

class _RangeSheetState extends State<_RangeSheet> {
  int _kandaIdx = 0;
  int _vargaIdx = 0;
  int _padaIdx  = 0;
  int _count    = 5;

  final _vargaScroll = ScrollController();
  final _padaScroll  = ScrollController();

  Kanda      get _kanda    => widget.kandas[_kandaIdx];
  Varga      get _varga    => _kanda.vargas[_vargaIdx.clamp(0, _kanda.vargas.length - 1)];
  List<Pada> get _allPadas => _varga.allPadas;
  int        get _maxCount => (_allPadas.length - _padaIdx).clamp(1, 200);

  void _clamp() {
    _vargaIdx = _vargaIdx.clamp(0, (_kanda.vargas.length - 1).clamp(0, 999));
    _padaIdx  = _padaIdx.clamp(0, (_allPadas.length - 1).clamp(0, 999));
    _count    = _count.clamp(1, _maxCount);
  }

  List<_PadaListEntry> get _entries {
    final list = <_PadaListEntry>[];
    int fi = 0;
    for (final sec in _varga.sections) {
      if (sec.padas.isEmpty) continue;
      if (sec.titleEn.isNotEmpty) list.add(_PadaListEntry.header(sec.titleEn));
      for (final p in sec.padas) { list.add(_PadaListEntry.pada(p, fi)); fi++; }
    }
    return list;
  }

  @override
  void dispose() { _vargaScroll.dispose(); _padaScroll.dispose(); super.dispose(); }

  void _selectKanda(int idx) {
    setState(() { _kandaIdx = idx; _vargaIdx = 0; _padaIdx = 0; _clamp(); });
    _vargaScroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    _padaScroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  void _selectVarga(int idx) {
    setState(() { _vargaIdx = idx; _padaIdx = 0; _clamp(); });
    _padaScroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    _clamp();
    final padas    = _allPadas;
    final endIdx   = (_padaIdx + _count - 1).clamp(0, (padas.length - 1).clamp(0, 999));
    final actual   = padas.isEmpty ? 0 : endIdx - _padaIdx + 1;
    final startId  = padas.isNotEmpty ? padas[_padaIdx].id : '—';
    final endId    = padas.isNotEmpty ? padas[endIdx].id   : '—';
    final entries  = _entries;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(children: [
        // Drag handle
        Center(child: Container(
          margin: EdgeInsets.only(top: 8, bottom: 10),
          width: 36, height: 4,
          decoration: BoxDecoration(color: AC.border, borderRadius: BorderRadius.circular(2)),
        )),

        // Title
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Add Range to Set'.toUpperCase(),
                style: AT.garamond(12, color: AC.textMuted, letterSpacing: 1.0)),
          ),
        ),

        // Kanda pills
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Text('Kāṇḍa ', style: AT.garamond(12, color: AC.textMuted)),
            ...widget.kandas.asMap().entries.map((e) {
              final active = e.key == _kandaIdx;
              return GestureDetector(
                onTap: () => _selectKanda(e.key),
                child: Container(
                  margin: EdgeInsets.only(right: 6),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: active ? AC.accent : AC.chipBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: active ? AC.accent : AC.border),
                  ),
                  child: Text(e.value.nameEn.split(' ').first,
                      style: AT.garamond(12,
                          color: active ? Colors.white : AC.text,
                          weight: active ? FontWeight.w600 : FontWeight.w400)),
                ),
              );
            }),
          ]),
        ),

        // Varga chips (horizontal scroll)
        SizedBox(
          height: 30,
          child: ListView.builder(
            controller: _vargaScroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16, right: 8),
            itemCount: _kanda.vargas.length,
            itemBuilder: (_, i) {
              final v = _kanda.vargas[i];
              final active = i == _vargaIdx;
              // truncate Devanagari name to ~5 Unicode code points
              final name = v.name;
              final runes = name.runes.toList();
              final label = runes.length > 5
                  ? '${String.fromCharCodes(runes.take(5))}…'
                  : name;
              return GestureDetector(
                onTap: () => _selectVarga(i),
                child: Container(
                  margin: EdgeInsets.only(right: 6),
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: active ? AC.accent : AC.chipBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: active ? AC.accent : AC.border),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          fontFamily: 'TiroDevanagarSanskrit',
                          fontSize: 12,
                          color: active ? Colors.white : AC.text)),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 8),
        Divider(height: 1, color: AC.border),

        // Pada list
        Expanded(
          child: padas.isEmpty
              ? Center(child: Text('No pādas in this varga.',
                  style: AT.garamond(13, color: AC.textMuted, italic: true)))
              : ListView.builder(
                  controller: _padaScroll,
                  itemCount: entries.length,
                  itemBuilder: (_, i) {
                    final entry = entries[i];
                    if (entry.isHeader) {
                      return Padding(
                        padding: EdgeInsets.fromLTRB(16, 10, 16, 3),
                        child: Text(entry.headerTitle.toUpperCase(),
                            style: AT.garamond(10, color: AC.textMuted, letterSpacing: 0.6)),
                      );
                    }
                    final fi       = entry.flatIdx;
                    final isStart  = fi == _padaIdx;
                    final isInRange = fi >= _padaIdx && fi < _padaIdx + _count;
                    return GestureDetector(
                      onTap: () => setState(() { _padaIdx = fi; _clamp(); }),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        color: isInRange
                            ? AC.lineHl.withAlpha(isStart ? 255 : 180)
                            : Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        child: Row(children: [
                          AnimatedContainer(
                            duration: Duration(milliseconds: 150),
                            width: 9, height: 9,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isStart ? AC.accent : Colors.transparent,
                              border: Border.all(
                                  color: isStart ? AC.accent : AC.border, width: 1.5),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(entry.pada!.id,
                              style: AT.garamond(11, color: AC.textMuted)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(entry.pada!.textDev,
                                style: TextStyle(
                                    fontFamily: 'TiroDevanagarSanskrit',
                                    fontSize: 13, color: AC.text),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
        Divider(height: 1, color: AC.border),

        // Footer: count stepper + summary + button
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16,
              12 + MediaQuery.of(context).padding.bottom),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Number of pādas', style: AT.garamond(13, color: AC.text)),
              const Spacer(),
              _SmallStepper(
                value: actual,
                onDec: _count > 1 ? () => setState(() { _count--; }) : null,
                onInc: _count < _maxCount ? () => setState(() { _count++; }) : null,
              ),
            ]),
            const SizedBox(height: 6),
            Text(
              actual == 0
                  ? 'No pādas available'
                  : startId == endId
                      ? 'Pāda $startId'
                      : 'Pādas $startId – $endId  ($actual pādas)',
              style: AT.garamond(12, color: AC.textSec, italic: true),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: actual > 0 ? () {
                final slice    = padas.sublist(_padaIdx, _padaIdx + actual);
                final selected = slice.where((p) => AudioService.instance.hasAudio(p.id)).toList();
                if (selected.isEmpty) return;
                final label    = selected.length == 1
                    ? selected.first.id
                    : '${selected.first.id}–${selected.last.id}';
                widget.onAdd(_SetItem(label, selected));
              } : null,
              child: Builder(builder: (ctx) {
                final slice     = actual > 0 ? padas.sublist(_padaIdx, _padaIdx + actual) : <Pada>[];
                final withAudio = slice.where((p) => AudioService.instance.hasAudio(p.id)).length;
                final canAdd    = withAudio > 0;
                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: canAdd ? AC.btnBg : AC.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: Text(
                    canAdd
                        ? (withAudio < actual
                            ? 'Add $withAudio pādas (${actual - withAudio} no audio)'
                            : 'Add to Set')
                        : 'No audio in range',
                    style: AT.garamond(14,
                        color: canAdd ? AC.btnText : AC.textMuted,
                        weight: FontWeight.w600))),
                );
              }),
            ),
          ]),
        ),
      ]),
    );
  }
}

