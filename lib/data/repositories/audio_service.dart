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
// On web, player.setUrl(Uri.base.resolve('assets/assets/audio/...')) is used
// instead of setAsset() to avoid dev-server routing issues.
// Flutter web places built assets at {root}/assets/{pubspec-key}; since the
// pubspec key already starts with "assets/", the URL has a double "assets/" prefix.

import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
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
      // Flutter web places assets at: {app-root}/assets/{pubspec-key}
      // The pubspec key already starts with "assets/", giving a double prefix.
      // e.g. key "assets/audio/1.1.11.wav" → URL "assets/assets/audio/1.1.11.wav"
      final url = Uri.base.resolve('assets/assets/audio/$gretilId.$ext').toString();
      _log('setUrl($url)');
      await player.setUrl(url);
    } else {
      // setAsset requires path WITHOUT leading "assets/" — Flutter prepends it.
      await player.setAsset('audio/$gretilId.$ext');
    }
  }

  void _log(String msg) {
    // Always print on web so errors are visible in the browser console.
    if (kIsWeb || kDebugMode) print('[AudioService] $msg');
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  /// Play audio for a pada identified by its GRETIL ID (e.g. "1.1.11").
  /// Returns true if audio was found and started.
  Future<bool> playPada(String gretilId, {double speed = 1.0}) async {
    _log('playPada($gretilId)');

    // 1. User recording
    if (userRecordings.containsKey(gretilId)) {
      try {
        _log('loading user recording');
        await player.setUrl(userRecordings[gretilId]!);
        await player.setSpeed(speed);
        await player.play();
        _log('user recording playing');
        return true;
      } catch (e) {
        _log('user recording error: $e');
      }
    }

    // 2. Bundled asset (.wav preferred, .m4a fallback)
    final ext = await _bundledExt(gretilId);
    _log('bundled ext: $ext');
    if (ext != null) {
      try {
        await _loadBundledAsset(gretilId, ext);
        _log('source loaded, calling play()');
        await player.setSpeed(speed);
        await player.play();
        _log('play() returned OK');
        return true;
      } catch (e) {
        _log('bundled asset error: $e');
      }
    }

    _log('no audio — returning false');
    return false;
  }

  Future<void> pause()  async => player.pause();
  Future<void> resume() async => player.play();
  Future<void> stop()   async => player.stop();

  void dispose() => player.dispose();
}
