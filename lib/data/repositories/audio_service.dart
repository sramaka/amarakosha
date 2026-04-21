// lib/data/repositories/audio_service.dart
//
// Loads and plays audio for practice sessions.
//
// Priority order for each pada:
//   1. User recording (from recording studio, stored as blob URL on web)
//   2. Bundled asset file  (assets/audio/1-1-1-1.m4a)
//   3. Nothing — player stays silent, UI shows "no audio"
//
// Asset naming: {kanda}-{varga}-{verse}-{pada}.m4a
// e.g. assets/audio/1-1-3-1.m4a = Kanda 1, Varga 1, Verse 3, Pada 1

import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart';

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final AudioPlayer player = AudioPlayer();

  // User recordings saved by the recording studio this session
  // key: "1-1-3-1"  value: blob URL or file path
  final Map<String, String> userRecordings = {};

  // ── Asset path helper ────────────────────────────────────────────────────────

  static String assetPath(int kanda, int varga, int verse, int pada) =>
      'assets/audio/$kanda-$varga-$verse-$pada.m4a';

  static String keyFor(int kanda, int varga, int verse, int pada) =>
      '$kanda-$varga-$verse-$pada';

  /// Check whether a bundled asset file actually exists.
  Future<bool> assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Playback ─────────────────────────────────────────────────────────────────

  /// Play audio for a specific pada.
  /// Returns true if audio was found and started, false if nothing available.
  Future<bool> playPada({
    required int kanda, required int varga,
    required int verse, required int pada,
    double speed = 1.0,
  }) async {
    await player.stop();

    final key  = keyFor(kanda, varga, verse, pada);
    final path = assetPath(kanda, varga, verse, pada);

    // 1. Check for user recording first
    if (userRecordings.containsKey(key)) {
      final url = userRecordings[key]!;
      try {
        await player.setUrl(url);
        await player.setSpeed(speed);
        await player.play();
        return true;
      } catch (_) {}
    }

    // 2. Try bundled asset
    if (await assetExists(path)) {
      try {
        await player.setAsset(path);
        await player.setSpeed(speed);
        await player.play();
        return true;
      } catch (_) {}
    }

    // 3. Nothing available
    return false;
  }

  /// Play a full shloka (both padas in sequence).
  Future<void> playShloka({
    required int kanda, required int varga,
    required int verse, int padaCount = 2,
    double speed = 1.0,
  }) async {
    for (var p = 1; p <= padaCount; p++) {
      final found = await playPada(
          kanda: kanda, varga: varga, verse: verse,
          pada: p, speed: speed);
      if (!found) continue;
      // Wait for this pada to finish before playing the next
      await player.playerStateStream.firstWhere(
          (s) => s.processingState == ProcessingState.completed
              || s.processingState == ProcessingState.idle);
    }
  }

  Future<void> pause()  async => player.pause();
  Future<void> resume() async => player.play();
  Future<void> stop()   async => player.stop();

  void dispose() => player.dispose();
}
