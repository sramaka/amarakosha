// lib/presentation/screens/recording_screen.dart
//
// Real audio recording using the `record` package.
// Real playback using `just_audio`.
// Works on Web (blob URLs), Android and iOS (file paths).

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/static_data.dart';
import '../../domain/entities/entities.dart';
import '../widgets/shared_widgets.dart';

class RecordingScreen extends StatefulWidget {
  final Session session;
  final VoidCallback onBack;

  const RecordingScreen({
    super.key, required this.session, required this.onBack,
  });

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  int _verseIdx = 0;

  // Actual audio path/URL after recording stops
  final Map<String, String> _recordedPaths = {};
  final Map<String, String> _durations    = {};

  // UI state per pada key
  final Map<String, RecStatus> _recState = {};

  // Elapsed seconds while recording
  final Map<String, int>   _elapsed       = {};
  final Map<String, Timer> _elapsedTimers = {};
  final Map<String, Timer> _autoStopTimers = {};

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer   _player   = AudioPlayer();
  String? _currentlyPlayingKey;

  final Verse _verse = kSampleVerse;

  @override
  void dispose() {
    for (final t in _elapsedTimers.values)  t.cancel();
    for (final t in _autoStopTimers.values) t.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _key(int verseIdx, int padaIdx) => RecordingEntry.makeKey(
        widget.session.kanda.num, widget.session.varga.num,
        verseIdx + 1, padaIdx + 1);

  int get _totalVerses   => widget.session.varga.verses;
  int get _verseNum      => _verseIdx + 1;
  int get _totalRecorded => _recordedPaths.length;
  int get _vargaTotal    => _totalVerses * _verse.padaCount;

  String _fmtSecs(int s) =>
      '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  // ── Recording ──────────────────────────────────────────────────────────────

  Future<void> _startRec(int padaIdx) async {
    final k = _key(_verseIdx, padaIdx);

    await _stopPlay();

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Microphone permission denied. Allow microphone access and try again.')));
      return;
    }

    _elapsedTimers[k]?.cancel();
    _autoStopTimers[k]?.cancel();

    setState(() { _recState[k] = RecStatus.recording; _elapsed[k] = 0; });

    final config = RecordConfig(
      encoder:    kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc,
      sampleRate: 44100, bitRate: 128000, numChannels: 1,
    );
    await _recorder.start(config, path: kIsWeb ? '' : '/tmp/amara_$k.m4a');

    _elapsedTimers[k] = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed[k] = (_elapsed[k] ?? 0) + 1);
    });

    _autoStopTimers[k] = Timer(const Duration(seconds: 30), () {
      if (_recState[k] == RecStatus.recording) _stopRec(padaIdx);
    });
  }

  Future<void> _stopRec(int padaIdx) async {
    final k = _key(_verseIdx, padaIdx);

    _elapsedTimers[k]?.cancel();
    _autoStopTimers[k]?.cancel();
    _elapsedTimers.remove(k);
    _autoStopTimers.remove(k);

    final secs = _elapsed[k] ?? 0;
    _durations[k] = _fmtSecs(secs);

    final path = await _recorder.stop();

    setState(() {
      _recState[k] = RecStatus.unrecorded;
      if (path != null && path.isNotEmpty) _recordedPaths[k] = path;
      _elapsed.remove(k);
    });
  }

  // ── Playback ───────────────────────────────────────────────────────────────

  Future<void> _playRec(int padaIdx) async {
    final k    = _key(_verseIdx, padaIdx);
    final path = _recordedPaths[k];
    if (path == null) return;

    setState(() { _recState[k] = RecStatus.playing; _currentlyPlayingKey = k; });

    try {
      if (kIsWeb || path.startsWith('blob:') || path.startsWith('http')) {
        await _player.setUrl(path);
      } else {
        await _player.setFilePath(path);
      }
      await _player.play();

      _player.playerStateStream.firstWhere(
        (s) => s.processingState == ProcessingState.completed,
      ).then((_) {
        if (mounted && _currentlyPlayingKey == k) {
          setState(() { _recState[k] = RecStatus.unrecorded; _currentlyPlayingKey = null; });
        }
      });
    } catch (e) {
      setState(() { _recState[k] = RecStatus.unrecorded; _currentlyPlayingKey = null; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Playback error: $e')));
    }
  }

  Future<void> _stopPlay() async {
    if (_currentlyPlayingKey == null) return;
    final k = _currentlyPlayingKey!;
    await _player.stop();
    if (mounted) setState(() { _recState[k] = RecStatus.unrecorded; _currentlyPlayingKey = null; });
  }

  void _deleteRec(int padaIdx) {
    final k = _key(_verseIdx, padaIdx);
    setState(() { _recordedPaths.remove(k); _recState.remove(k);
                  _elapsed.remove(k);       _durations.remove(k); });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => Column(children: [
    // NAV
    Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AC.border))),
      child: Row(children: [
        GestureDetector(
          onTap: widget.onBack,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.chevron_left, color: AC.accent, size: 18),
            Text('Back', style: AT.garamond(15, color: AC.accent)),
          ]),
        ),
        Expanded(child: Column(children: [
          Text('Recording Studio', style: AT.garamond(15, color: AC.text)),
          Text(widget.session.varga.name,
              style: const TextStyle(fontFamily: 'TiroDevanagarSanskrit',
                  fontSize: 13, color: AC.textMuted)),
        ])),
        const SizedBox(width: 50),
      ]),
    ),

    // BODY
    Expanded(child: SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(children: [
        // Badge + count
        Padding(padding: const EdgeInsets.fromLTRB(16,10,16,0),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(11,3,11,3),
              decoration: BoxDecoration(color: AC.chipBg,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: AC.border)),
              child: Text('Recording to: My Recordings',
                  style: AT.garamond(12, color: AC.chipText)),
            ),
            Text('$_totalRecorded / $_vargaTotal pādas',
                style: AT.garamond(12, color: AC.textMuted, italic: true)),
          ]),
        ),

        // Verse nav
        Padding(padding: const EdgeInsets.fromLTRB(16,12,16,0),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(
              onTap: _verseIdx > 0 ? () => setState(() => _verseIdx--) : null,
              child: Opacity(opacity: _verseIdx > 0 ? 1.0 : 0.4,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14,7,14,7),
                  decoration: BoxDecoration(color: AC.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AC.border)),
                  child: Row(children: [
                    const Icon(Icons.chevron_left, color: AC.textSec, size: 16),
                    Text('Prev', style: AT.garamond(14, color: AC.textSec)),
                  ]),
                ),
              ),
            ),
            Column(children: [
              Text('Verse'.toUpperCase(),
                  style: AT.garamond(10, color: AC.textMuted, letterSpacing: 1.0)),
              RichText(text: TextSpan(style: AT.garamond(20, color: AC.text), children: [
                TextSpan(text: '$_verseNum '),
                TextSpan(text: 'of $_totalVerses',
                    style: AT.garamond(14, color: AC.textMuted)),
              ])),
            ]),
            GestureDetector(
              onTap: _verseIdx < _totalVerses-1 ? () => setState(() => _verseIdx++) : null,
              child: Opacity(opacity: _verseIdx < _totalVerses-1 ? 1.0 : 0.4,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14,7,14,7),
                  decoration: BoxDecoration(color: AC.btnBg,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Text('Next', style: AT.garamond(14, color: AC.btnText)),
                    const Icon(Icons.chevron_right, color: AC.btnText, size: 16),
                  ]),
                ),
              ),
            ),
          ]),
        ),

        // Verse card
        Container(
          margin: const EdgeInsets.fromLTRB(16,12,16,0),
          decoration: BoxDecoration(color: AC.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AC.border)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18,10,18,10),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AC.borderLight))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('श्लोक · $_verseNum'.toUpperCase(),
                    style: AT.garamond(10, color: AC.textMuted, letterSpacing: 1.0)),
                Row(children: List.generate(_verse.padaCount, (i) => Container(
                  margin: const EdgeInsets.only(left: 5),
                  width: 8, height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: _recordedPaths.containsKey(_key(_verseIdx, i))
                          ? AC.loopActive : AC.trackBg),
                ))),
              ]),
            ),
            ...List.generate(_verse.padaCount, (i) {
              final k = _key(_verseIdx, i);
              return _PadaRow(
                padaIdx: i,
                padaText: _verse.lines[i],
                hasRecording: _recordedPaths.containsKey(k),
                state: _recState[k] ?? RecStatus.unrecorded,
                elapsedSecs: _elapsed[k] ?? 0,
                savedDuration: _durations[k] ?? '0:00',
                isLast: i == _verse.padaCount - 1,
                onRecord: () => _startRec(i),
                onStop:   () => _stopRec(i),
                onPlay:   () => _playRec(i),
                onPause:  () => _stopPlay(),
                onDelete: () => _deleteRec(i),
              );
            }),
          ]),
        ),

        // Progress bar
        Padding(padding: const EdgeInsets.fromLTRB(16,14,16,0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Varga progress',
                  style: AT.garamond(13, color: AC.textSec, italic: true)),
              Text('$_totalRecorded of $_vargaTotal pādas',
                  style: AT.garamond(12, color: AC.textMuted)),
            ]),
            const SizedBox(height: 6),
            AProgressBar(
                value: _vargaTotal > 0 ? _totalRecorded / _vargaTotal : 0,
                fillColor: AC.loopActive),
          ]),
        ),

        // Hint
        Padding(padding: const EdgeInsets.fromLTRB(16,12,16,0),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: AD.surfaceAlt(radius: 10),
            child: Text(
              'Tap 🎙 to start recording a pāda. Tap ⏹ when done. '
              'Tap ▶ to play it back. Auto-stops after 30 seconds.',
              style: AT.garamond(13, color: AC.textSec, italic: true, height: 1.6)),
          ),
        ),
      ]),
    )),
  ]);
}

// ─── Pāda Row ─────────────────────────────────────────────────────────────────
class _PadaRow extends StatelessWidget {
  final int padaIdx;
  final String padaText;
  final bool hasRecording;
  final RecStatus state;
  final int elapsedSecs;
  final String savedDuration;
  final bool isLast;
  final VoidCallback onRecord, onStop, onPlay, onPause, onDelete;

  const _PadaRow({
    required this.padaIdx, required this.padaText,
    required this.hasRecording, required this.state,
    required this.elapsedSecs, required this.savedDuration,
    required this.isLast,
    required this.onRecord, required this.onStop,
    required this.onPlay, required this.onPause, required this.onDelete,
  });

  bool get _isRec     => state == RecStatus.recording;
  bool get _isPlaying => state == RecStatus.playing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(border: isLast ? null
        : const Border(bottom: BorderSide(color: AC.borderLight))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        // Badge
        Container(width: 22, height: 22,
          decoration: BoxDecoration(
            color: hasRecording ? AC.loopActiveBg : AC.surfaceAlt,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: hasRecording
                ? AC.loopActive.withOpacity(0.4) : AC.border)),
          child: Center(child: Text('P${padaIdx+1}',
              style: TextStyle(fontSize: 10,
                  color: hasRecording ? AC.loopActive : AC.textMuted))),
        ),
        const SizedBox(width: 8),
        // Status label
        Text(
          _isRec
              ? 'Recording… '
                '${elapsedSecs ~/ 60}:'
                '${(elapsedSecs % 60).toString().padLeft(2, '0')}'
              : hasRecording ? 'Recorded · $savedDuration' : 'Not recorded',
          style: AT.garamond(13,
              color: _isRec ? AC.recRed
                  : hasRecording ? AC.loopActive : AC.textMuted,
              italic: true),
        ),
        const Spacer(),
        // Play/Pause
        if (hasRecording && !_isRec) ...[
          GestureDetector(
            onTap: _isPlaying ? onPause : onPlay,
            child: Container(width: 32, height: 32,
              decoration: BoxDecoration(color: AC.loopActiveBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: AC.loopActive.withOpacity(0.27))),
              child: Center(child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: AC.loopActive, size: 16)),
            ),
          ),
          const SizedBox(width: 8),
        ],
        // Record / Stop
        GestureDetector(
          onTap: _isRec ? onStop : onRecord,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _isRec ? AC.recRed : AC.surface,
              shape: BoxShape.circle,
              border: Border.all(color: _isRec
                  ? AC.recRed : AC.recRed.withOpacity(0.6), width: 2),
              boxShadow: _isRec ? [BoxShadow(
                  color: AC.recRed.withOpacity(0.35),
                  blurRadius: 8, spreadRadius: 2)] : null,
            ),
            child: Center(child: _isRec
                ? const Icon(Icons.stop_rounded, color: Colors.white, size: 18)
                : Icon(Icons.mic_outlined,
                    color: AC.recRed.withOpacity(0.8), size: 18)),
          ),
        ),
        // Delete
        if (hasRecording && !_isRec) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: Container(width: 28, height: 28,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  border: Border.all(color: AC.border)),
              child: const Center(child: Text('×',
                  style: TextStyle(color: AC.textMuted, fontSize: 14))),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 8),
      // Pāda text
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(
          color: _isRec ? const Color(0xFFFFF0EE)
              : _isPlaying ? AC.lineHl : AC.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _isRec ? const Color(0xFFF0C0B8)
              : _isPlaying ? AC.lineBorder : AC.borderLight),
        ),
        child: Text(padaText, style: const TextStyle(
            fontFamily: 'TiroDevanagarSanskrit',
            fontSize: 20, height: 1.7, color: AC.text)),
      ),
      // Waveform while recording
      if (_isRec) ...[
        const SizedBox(height: 8),
        Row(children: [
          Container(width: 6, height: 6,
              decoration: BoxDecoration(color: AC.recRed, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('Recording…', style: AT.garamond(12, color: AC.recRed, italic: true)),
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
    ]),
  );
}
