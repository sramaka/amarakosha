// lib/data/repositories/audio_service.dart
//
// Asset files: assets/audio/1.1.11.wav  (preferred, from recording tools)
//              assets/audio/1.1.11.m4a  (legacy, also supported)
// Registry key: "1.1.11"  (same as Pada.id)
//
// Priority:
//   1. User recording registered via registerRecording(gretilId, blobUrl)
//   2. Bundled asset  assets/audio/<gretilId>.wav  (tried first)
//   3. Bundled asset  assets/audio/<gretilId>.m4a  (fallback)
//   4. Silent — playPada() returns false
//
// On web, player.setUrl(Uri.base.resolve('assets/audio/...')) is used instead of
// setAsset() to avoid Flutter's dev-server asset routing (500 for some files)
// and to respect the --base-href set at build time (e.g. GitHub Pages).

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:just_audio/just_audio.dart';

class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final AudioPlayer player = AudioPlayer();

  /// User recordings keyed by GRETIL ID (e.g. "1.1.11").
  final Map<String, String> userRecordings = {};

  // GRETIL IDs that have bundled audio files (populated by preloadManifest).
  final Set<String> _manifestIds = {};

  // Cache the asset manifest so we don't reload it on every playback.
  AssetManifest? _manifest;
  Future<AssetManifest> _getManifest() async {
    _manifest ??= await AssetManifest.loadFromAssetBundle(rootBundle);
    return _manifest!;
  }

  /// Call once at startup to pre-index bundled audio files.
  /// Enables synchronous hasAudio() checks for the tree pane.
  Future<void> preloadManifest() async {
    try {
      final manifest = await _getManifest();
      for (final a in manifest.listAssets()) {
        final m = RegExp(r'assets/audio/(.+)\.(wav|m4a)$').firstMatch(a);
        if (m != null) _manifestIds.add(m.group(1)!);
      }
    } catch (_) {}
  }

  /// Register a user recording (blob URL on web, file path on native).
  void registerRecording(String gretilId, String blobUrlOrPath) {
    userRecordings[gretilId] = blobUrlOrPath;
    _manifestIds.add(gretilId); // treat user recordings as "has audio" too
  }

  /// Returns true if any audio is available for this pada (sync, after preloadManifest).
  bool hasAudio(String gretilId) =>
      userRecordings.containsKey(gretilId) || _manifestIds.contains(gretilId);

  /// Returns the extension ('wav' or 'm4a') of the first bundled file found, or null.
  Future<String?> _bundledExt(String gretilId) async {
    try {
      final manifest = await _getManifest();
      final assets = manifest.listAssets();
      for (final ext in ['wav', 'm4a']) {
        if (assets.contains('assets/audio/$gretilId.$ext')) return ext;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadBundledAsset(String gretilId, String ext) async {
    if (kIsWeb) {
      // Resolve relative to the page base so it works both locally and on
      // GitHub Pages (where base-href is /repo-name/ — an absolute path would miss it).
      final url = Uri.base.resolve('assets/audio/$gretilId.$ext').toString();
      await player.setUrl(url);
    } else {
      // setAsset requires path WITHOUT leading "assets/" — Flutter prepends it.
      await player.setAsset('audio/$gretilId.$ext');
    }
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  /// Play audio for a pada identified by its GRETIL ID (e.g. "1.1.11").
  /// Returns true if audio was found and started.
  Future<bool> playPada(String gretilId, {double speed = 1.0}) async {
    await player.stop();

    // 1. User recording
    if (userRecordings.containsKey(gretilId)) {
      try {
        await player.setUrl(userRecordings[gretilId]!);
        await player.setSpeed(speed);
        await player.play();
        return true;
      } catch (_) {}
    }

    // 2. Bundled asset (.wav preferred, .m4a fallback)
    final ext = await _bundledExt(gretilId);
    if (ext != null) {
      try {
        await _loadBundledAsset(gretilId, ext);
        await player.setSpeed(speed);
        await player.play();
        return true;
      } catch (_) {}
    }

    return false;
  }

  Future<void> pause()  async => player.pause();
  Future<void> resume() async => player.play();
  Future<void> stop()   async => player.stop();

  void dispose() => player.dispose();
}
