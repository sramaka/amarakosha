// lib/presentation/screens/recording_screen.dart (v3 model)
// Records one pada at a time, navigates by Section → Pada

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/audio_service.dart';
import '../../data/repositories/recording_store.dart';
import '../../data/repositories/static_data.dart';
import '../../domain/entities/entities.dart';
import '../widgets/shared_widgets.dart';
import '../../core/settings/app_settings.dart';

class RecordingScreen extends StatefulWidget {
  final Session      session;
  final VoidCallback onBack;

  const RecordingScreen({super.key, required this.session, required this.onBack});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  // ── Data ────────────────────────────────────────────────────────────────────
  List<Kanda> _kandas  = [];
  bool        _loading = true;

  // Navigation: section index + pada index within that section
  int _secIdx  = 0;
  int _padaIdx = 0;   // index within _currentSection.padas

  // ── Recording state keyed by audio key "k-v-s-p" ─────────────────────────
  final Map<String, String>    _paths     = {};   // audio key → file path/blob URL
  final Map<String, String>    _durations = {};
  final Map<String, RecStatus> _recState  = {};
  final Map<String, int>       _elapsed   = {};
  final Map<String, Timer>     _elTimers  = {};
  final Map<String, Timer>     _asTimers  = {};   // auto-stop

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer   _player   = AudioPlayer();
  String? _playingKey;

  @override
  void initState() {
    super.initState();
    // Start at the section passed in the session
    loadKandas().then((k) {
      if (!mounted) return;
      setState(() { _kandas = k; _loading = false; });
      // Find _secIdx matching session.section
      final secs = _allSections;
      final idx = secs.indexWhere((s) => s.id == widget.session.section.id);
      if (idx >= 0) setState(() { _secIdx = idx; _padaIdx = 0; });
    });
    // Load any already-persisted recordings for this session into _paths
    _loadPersistedKeys();
    AppSettings.instance.addListener(_onSettings);
  }

  Future<void> _loadPersistedKeys() async {
    final keys = await RecordingStore.instance.listKeys();
    if (!mounted) return;
    setState(() {
      for (final k in keys) {
        if (!_paths.containsKey(k)) {
          // Mark as recorded with a placeholder path; actual URL is in AudioService
          final url = AudioService.instance.userRecordings[k];
          if (url != null) _paths[k] = url;
        }  // key is GRETIL ID
      }
    });
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_onSettings);
    for (final t in _elTimers.values)  t.cancel();
    for (final t in _asTimers.values)  t.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  void _onSettings() => setState(() {});

  // ── Helpers ────────────────────────────────────────────────────────────────
  List<Section> get _allSections {
    for (final k in _kandas) {
      if (k.num != widget.session.kanda.num) continue;
      for (final v in k.vargas) {
        if (v.seq != widget.session.varga.seq) continue;
        return v.sections;
      }
    }
    return widget.session.varga.sections; // bootstrap fallback
  }

  Section? get _currentSection {
    final secs = _allSections;
    if (_secIdx >= 0 && _secIdx < secs.length) return secs[_secIdx];
    return null;
  }

  Pada? get _currentPada {
    final sec = _currentSection;
    if (sec == null) return null;
    if (_padaIdx >= 0 && _padaIdx < sec.padas.length) return sec.padas[_padaIdx];
    return null;
  }

  String _fmtSecs(int s) =>
      '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  int get _totalRecorded => _paths.length;
  int get _totalPadas    => _allSections.fold(0, (n, s) => n + s.padaCount);

  // ── Recording ──────────────────────────────────────────────────────────────
  Future<void> _startRec() async {
    final pada = _currentPada;
    if (pada == null) return;
    final k = pada.id;  // GRETIL ID e.g. "1.1.11"

    await _stopPlay();

    if (!await _recorder.hasPermission()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Microphone permission denied.')));
      return;
    }

    _elTimers[k]?.cancel();
    _asTimers[k]?.cancel();

    setState(() { _recState[k] = RecStatus.recording; _elapsed[k] = 0; });

    final cfg = RecordConfig(
      encoder:    kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc,
      sampleRate: kIsWeb ? 16000 : 44100,  // web caps at 16kHz; native supports 44.1kHz
      bitRate:    128000,
      numChannels: 1,
    );
    await _recorder.start(cfg, path: kIsWeb ? '' : '/tmp/amara_${k.replaceAll(".", "-")}.m4a');

    _elTimers[k] = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed[k] = (_elapsed[k] ?? 0) + 1);
    });
    _asTimers[k] = Timer(const Duration(seconds: 30), () {
      if (_recState[k] == RecStatus.recording) _stopRec();
    });
  }

  Future<void> _stopRec() async {
    final pada = _currentPada;
    if (pada == null) return;
    final k = pada.id;  // GRETIL ID e.g. "1.1.11"

    _elTimers[k]?.cancel();
    _asTimers[k]?.cancel();
    _elTimers.remove(k); _asTimers.remove(k);

    _durations[k] = _fmtSecs(_elapsed[k] ?? 0);
    final path = await _recorder.stop();

    setState(() {
      _recState[k] = RecStatus.unrecorded;
      if (path != null && path.isNotEmpty) _paths[k] = path;
      _elapsed.remove(k);
    });

    // Convert to WAV, persist, and get back the playback URL
    if (path != null && path.isNotEmpty) {
      final playUrl = await RecordingStore.instance.saveRecording(k, path);
      if (mounted) setState(() => _paths[k] = playUrl);
    }
  }

  Future<void> _playRec() async {
    final pada = _currentPada;
    if (pada == null) return;
    final k    = pada.id;
    final path = _paths[k];
    if (path == null) return;

    setState(() { _recState[k] = RecStatus.playing; _playingKey = k; });

    try {
      if (kIsWeb || path.startsWith('blob:') || path.startsWith('http')) {
        await _player.setUrl(path);
      } else {
        await _player.setFilePath(path);
      }
      await _player.play();
      _player.playerStateStream
          .firstWhere((s) => s.processingState == ProcessingState.completed)
          .then((_) {
        if (mounted && _playingKey == k) {
          setState(() { _recState[k] = RecStatus.unrecorded; _playingKey = null; });
        }
      });
    } catch (e) {
      setState(() { _recState[k] = RecStatus.unrecorded; _playingKey = null; });
    }
  }

  Future<void> _stopPlay() async {
    if (_playingKey == null) return;
    final k = _playingKey!;
    await _player.stop();
    if (mounted) setState(() { _recState[k] = RecStatus.unrecorded; _playingKey = null; });
  }

  void _deleteRec() {
    final pada = _currentPada;
    if (pada == null) return;
    final k = pada.id;  // GRETIL ID e.g. "1.1.11"
    setState(() {
      _paths.remove(k); _recState.remove(k);
      _elapsed.remove(k); _durations.remove(k);
    });
    // Remove from persistent storage too
    RecordingStore.instance.deleteRecording(k);
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _prevPada() {
    if (_padaIdx > 0) {
      setState(() => _padaIdx--);
    } else if (_secIdx > 0) {
      final prevSec = _allSections[_secIdx - 1];
      setState(() { _secIdx--; _padaIdx = prevSec.padaCount - 1; });
    }
  }

  void _nextPada() {
    final sec = _currentSection;
    if (sec != null && _padaIdx < sec.padaCount - 1) {
      setState(() => _padaIdx++);
    } else if (_secIdx < _allSections.length - 1) {
      setState(() { _secIdx++; _padaIdx = 0; });
    }
  }

  bool get _hasPrev => _secIdx > 0 || _padaIdx > 0;
  bool get _hasNext {
    final sec = _currentSection;
    return (_secIdx < _allSections.length - 1) ||
           (sec != null && _padaIdx < sec.padaCount - 1);
  }

  // ── Download ──────────────────────────────────────────────────────────
  void _showDownloadSheet() {
    if (!kIsWeb) return;
    final sec     = _currentSection;
    final secKeys = (sec?.padas ?? [])
        .map((p) => p.id).where(_paths.containsKey).toList();
    final allKeys = _allSections
        .expand((s) => s.padas)
        .map((p) => p.id).where(_paths.containsKey).toList();
    final vId = widget.session.varga.id.replaceAll('.', '-');

    showModalBottomSheet(
      context: context,
      backgroundColor: AC.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetHandle(),
          const SizedBox(height: 14),
          Text('Download Recordings', style: AT.garamond(16, weight: FontWeight.w600)),
          const SizedBox(height: 20),
          if (secKeys.isEmpty && allKeys.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No recordings yet.',
                  style: AT.garamond(13, color: AC.textMuted, italic: true)),
            ),
          if (secKeys.isNotEmpty) ...[
            _buildDownloadRow(
              label: 'This section',
              count: secKeys.length,
              onTap: () {
                Navigator.pop(context);
                RecordingStore.instance.downloadZip(
                    secKeys, zipFilename: 'amara_${vId}_sec${sec!.seq}.zip');
              },
            ),
            const SizedBox(height: 8),
          ],
          if (allKeys.isNotEmpty)
            _buildDownloadRow(
              label: 'Entire varga',
              count: allKeys.length,
              onTap: () {
                Navigator.pop(context);
                RecordingStore.instance.downloadZip(
                    allKeys, zipFilename: 'amara_$vId.zip');
              },
            ),
        ]),
      ),
    );
  }

  Widget _buildDownloadRow({
    required String label, required int count, required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AC.surfaceAlt,
          borderRadius: BorderRadius.circular(8), border: Border.all(color: AC.border)),
      child: Row(children: [
        const Icon(Icons.download_rounded, size: 16, color: AC.accent),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AT.garamond(14, color: AC.text)),
          Text('$count pāda${count == 1 ? "" : "s"}',
              style: AT.garamond(12, color: AC.textMuted, italic: true)),
        ])),
        const Icon(Icons.chevron_right, size: 16, color: AC.textMuted),
      ]),
    ),
  );

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AC.accent));
    }
    final sec  = _currentSection;
    final pada = _currentPada;
    if (sec == null || pada == null) {
      return const Center(child: Text('No content'));
    }
    final k         = pada.id;
    final state     = _recState[k] ?? RecStatus.unrecorded;
    final hasRec    = _paths.containsKey(k);
    final isRec     = state == RecStatus.recording;
    final isPlaying = state == RecStatus.playing;
    final elapsed   = _elapsed[k] ?? 0;

    return Column(children: [
      // ── Nav bar ──────────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AC.border))),
        child: Row(children: [
          GestureDetector(onTap: widget.onBack, child: Row(
            mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.chevron_left, color: AC.accent, size: 18),
              Text('Back', style: AT.garamond(
                  AppSettings.instance.uiFontSize.toDouble(), color: AC.accent)),
            ])),
          Expanded(child: Column(children: [
            Text('Recording Studio', style: AT.garamond(
                AppSettings.instance.uiFontSize.toDouble(), color: AC.text)),
            Text(widget.session.varga.name, style: AT.devanagari(
                AppSettings.instance.treeFontSize.toDouble(),
                color: AC.textSec, height: 1.4,
                family: AppSettings.instance.devFontFamily)),
          ])),
          // Trailing: settings + optional ZIP
          Row(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: () => showDisplaySettingsSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AC.border)),
                child: Text('Aa', style: AT.garamond(13, color: AC.textSec)),
              ),
            ),
            if (kIsWeb && _totalRecorded > 0) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _showDownloadSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AC.border)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.download_rounded, size: 13, color: AC.textMuted),
                    const SizedBox(width: 4),
                    Text('ZIP', style: AT.garamond(12, color: AC.textMuted)),
                  ]),
                ),
              ),
            ],
          ]),
        ]),
      ),

      // ── Body ─────────────────────────────────────────────────────────────
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(children: [
          // Storage info banner
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: AC.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AC.borderLight)),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 13, color: AC.textMuted),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  kIsWeb
                      ? 'Recordings are saved to your browser\'s local storage (IndexedDB). '
                        'They persist across page refreshes and browser restarts. '
                        'Available immediately in the Practice screen.'
                      : 'Recordings are saved as .m4a files in local storage '
                        'and available immediately in the Practice screen.',
                  style: AT.garamond(13, color: AC.textMuted, italic: true, height: 1.4),
                )),
              ]),
            ),
          ),

          // Progress badge
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                padding: const EdgeInsets.fromLTRB(11, 3, 11, 3),
                decoration: BoxDecoration(color: AC.chipBg,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AC.border)),
                child: Text('Recording · My Recordings',
                    style: AT.garamond(AppSettings.instance.uiFontSize.toDouble(),
                        color: AC.chipText)),
              ),
              Text('$_totalRecorded / $_totalPadas pādas',
                  style: AT.garamond(AppSettings.instance.uiFontSize.toDouble(),
                      color: AC.textMuted, italic: true)),
            ]),
          ),

          // Section + pada navigation
          Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              // Prev
              GestureDetector(
                onTap: _hasPrev ? _prevPada : null,
                child: Opacity(opacity: _hasPrev ? 1.0 : 0.35,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
                    decoration: BoxDecoration(color: AC.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AC.border)),
                    child: Row(children: [
                      const Icon(Icons.chevron_left, color: AC.textSec, size: 16),
                      Text('Prev', style: AT.garamond(
                          AppSettings.instance.uiFontSize.toDouble(),
                          color: AC.textSec)),
                    ]),
                  ),
                ),
              ),
              // Current indicator
              Column(children: [
                Text('Pāda'.toUpperCase(),
                    style: AT.garamond(AppSettings.instance.uiFontSize.toDouble(),
                        color: AC.textSec, letterSpacing: 1.0)),
                Text(pada.id, style: AT.garamond(
                    (AppSettings.instance.uiFontSize + 4).toDouble(),
                    color: AC.text, weight: AppSettings.instance.fontWeight)),
                Text(sec.titleEn, style: AT.garamond(
                    AppSettings.instance.uiFontSize.toDouble(),
                    color: AC.textSec, italic: true),
                    overflow: TextOverflow.ellipsis),
              ]),
              // Next
              GestureDetector(
                onTap: _hasNext ? _nextPada : null,
                child: Opacity(opacity: _hasNext ? 1.0 : 0.35,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
                    decoration: BoxDecoration(color: AC.btnBg,
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Text('Next', style: AT.garamond(
                          AppSettings.instance.uiFontSize.toDouble(),
                          color: AC.btnText)),
                      const Icon(Icons.chevron_right, color: AC.btnText, size: 16),
                    ]),
                  ),
                ),
              ),
            ]),
          ),

          // ── Pada recording card ──────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            decoration: BoxDecoration(color: AC.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AC.border)),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              // Header row
              Container(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AC.borderLight))),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Pāda ${pada.padaNum == 1 ? "A" : "B"}  ·  ${pada.shlokaId}'.toUpperCase(),
                      style: AT.garamond(AppSettings.instance.uiFontSize.toDouble(),
                          color: AC.textSec, letterSpacing: 1.0)),
                  // status dot
                  Container(width: 8, height: 8,
                      decoration: BoxDecoration(
                          color: hasRec ? AC.loopActive : AC.trackBg,
                          shape: BoxShape.circle)),
                ]),
              ),

              // Body
              Padding(padding: const EdgeInsets.all(18), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Status + controls row
                  Row(children: [
                    Text(
                      isRec
                          ? 'Recording… ${_fmtSecs(elapsed)}'
                          : hasRec
                              ? 'Recorded · ${_durations[k] ?? "0:00"}'
                              : 'Not recorded',
                      style: AT.garamond(
                          AppSettings.instance.uiFontSize.toDouble(),
                          italic: true,
                          color: isRec ? AC.recRed
                              : hasRec ? AC.loopActive
                              : AC.textMuted),
                    ),
                    const Spacer(),
                    // Play button (if recorded and not currently recording)
                    if (hasRec && !isRec) ...[
                      GestureDetector(
                        onTap: isPlaying ? _stopPlay : _playRec,
                        child: Container(width: 32, height: 32,
                          decoration: BoxDecoration(color: AC.loopActiveBg,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AC.loopActive.withOpacity(0.27))),
                          child: Center(child: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: AC.loopActive, size: 16))),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Record / Stop button
                    GestureDetector(
                      onTap: isRec ? _stopRec : _startRec,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: isRec ? AC.recRed : AC.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: isRec ? AC.recRed : AC.recRed.withOpacity(0.6),
                              width: 2),
                          boxShadow: isRec ? [BoxShadow(
                              color: AC.recRed.withOpacity(0.35),
                              blurRadius: 8, spreadRadius: 2)] : null,
                        ),
                        child: Center(child: isRec
                            ? const Icon(Icons.stop_rounded, color: Colors.white, size: 18)
                            : Icon(Icons.mic_outlined,
                                color: AC.recRed.withOpacity(0.8), size: 18)),
                      ),
                    ),
                    // Delete button
                    if (hasRec && !isRec) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _deleteRec,
                        child: Container(width: 28, height: 28,
                          decoration: BoxDecoration(shape: BoxShape.circle,
                              border: Border.all(color: AC.border)),
                          child: const Center(child: Text('×',
                              style: TextStyle(color: AC.textMuted, fontSize: 14)))),
                      ),
                    ],
                    // Download button (web only)
                    if (hasRec && !isRec && kIsWeb) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => RecordingStore.instance.downloadRecording(k),
                        child: Container(width: 28, height: 28,
                          decoration: BoxDecoration(shape: BoxShape.circle,
                              border: Border.all(color: AC.border)),
                          child: const Center(child: Icon(Icons.download_rounded,
                              color: AC.textMuted, size: 14))),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 10),
                  // Pada text
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    decoration: BoxDecoration(
                      color: isRec ? const Color(0xFFFFF0EE)
                          : isPlaying ? AC.lineHl
                          : AC.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isRec ? const Color(0xFFF0C0B8)
                              : isPlaying ? AC.lineBorder
                              : AC.borderLight),
                    ),
                    child: pada.hasText
                        ? Text(pada.textDev, style: AT.devanagari(
                            AppSettings.instance.devFontSize.toDouble(),
                            height: 1.9, family: AppSettings.instance.devFontFamily))
                        : Text('[Pada ${pada.id} — no verse text yet]',
                            style: AT.garamond(13, color: AC.textMuted, italic: true)),
                  ),
                  // Waveform animation while recording
                  if (isRec) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Container(width: 6, height: 6,
                          decoration: const BoxDecoration(
                              color: AC.recRed, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('Recording…', style: AT.garamond(
                          AppSettings.instance.uiFontSize.toDouble(),
                          color: AC.recRed, italic: true)),
                      const SizedBox(width: 8),
                      ...List.generate(24, (i) => Container(
                        margin: const EdgeInsets.only(right: 1.5),
                        width: 3,
                        height: 6.0 + math.sin(i * 0.7) * 5,
                        decoration: BoxDecoration(
                            color: AC.recRed.withOpacity(0.5 + (i % 3) * 0.15),
                            borderRadius: BorderRadius.circular(2)),
                      )),
                    ]),
                  ],
                ],
              )),
            ]),
          ),

          // ── Section overview (dots for each pada) ───────────────────────
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${sec.titleEn}  ·  ${sec.padaCount} pādas',
                  style: AT.garamond(AppSettings.instance.uiFontSize.toDouble(),
                      color: AC.textSec, italic: true)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: sec.padas.map((p) {
                final isActive = p.seq == (_padaIdx + 1);
                final recorded = _paths.containsKey(p.id);
                return GestureDetector(
                  onTap: () => setState(() => _padaIdx = p.seq - 1),
                  child: Container(
                    width: 36, height: 28,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AC.btnBg
                          : recorded ? AC.loopActiveBg : AC.surfaceAlt,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: isActive ? AC.accent
                              : recorded ? AC.loopActive.withOpacity(0.4)
                              : AC.border)),
                    child: Center(child: Text(p.id.split('.').last + (p.padaNum == 1 ? 'A' : 'B'),
                        style: TextStyle(fontSize: 12,
                            color: isActive ? AC.btnText
                                : recorded ? AC.loopActive : AC.textMuted))),
                  ),
                );
              }).toList()),
            ]),
          ),

          // ── Varga progress bar ─────────────────────────────────────────
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Varga progress',
                    style: AT.garamond(AppSettings.instance.uiFontSize.toDouble(),
                        color: AC.textSec, italic: true)),
                Text('$_totalRecorded of $_totalPadas pādas',
                    style: AT.garamond(AppSettings.instance.uiFontSize.toDouble(),
                        color: AC.textMuted)),
              ]),
              const SizedBox(height: 6),
              AProgressBar(
                  value: _totalPadas > 0 ? _totalRecorded / _totalPadas : 0,
                  fillColor: AC.loopActive),
            ]),
          ),

          // Hint
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: AD.surfaceAlt(radius: 10),
              child: Text(
                'Tap 🎙 to record a pāda. Tap ⏹ when done. '
                'Tap ▶ to play back. Auto-stops after 30 s.',
                style: AT.garamond(AppSettings.instance.uiFontSize.toDouble(),
                    color: AC.textSec, italic: true, height: 1.6)),
            ),
          ),
        ]),
      )),
    ]);
  }
}
