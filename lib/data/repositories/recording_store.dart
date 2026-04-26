// lib/data/repositories/recording_store.dart
//
// Persistent audio recording storage.
//
// Web:
//   Recordings are saved to IndexedDB via the JS helpers in web/index.html.
//   They survive page refresh and browser restarts.
//   On startup, call restoreAll() to reload them into AudioService.
//
// Native (Android/iOS):
//   The record package writes to a temp path; we register it directly.
//   (Full native persistence to documents dir can be added later.)
//
// Usage:
//   await RecordingStore.instance.saveRecording(key, blobUrl);
//   await RecordingStore.instance.restoreAll();  // call once at app startup
//   await RecordingStore.instance.deleteRecording(key);
//   await RecordingStore.instance.listKeys();

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'audio_service.dart';

// Conditional import: dart:js_interop only compiles on web
import 'recording_store_web.dart'
    if (dart.library.io) 'recording_store_stub.dart' as _impl;

class RecordingStore {
  RecordingStore._();
  static final RecordingStore instance = RecordingStore._();

  /// Save a new recording.
  /// [key] is the GRETIL ID e.g. "1.1.11".  [blobUrlOrPath] is a blob: URL (web) or file path (native).
  /// Returns the playback URL (WAV blob URL on web, original path on native).
  Future<String> saveRecording(String key, String blobUrlOrPath) async {
    if (kIsWeb) {
      // saveRecordingWeb converts WebM → WAV and returns the WAV blob URL.
      // Fall back to the original URL if conversion fails.
      final wavUrl = await _impl.saveRecordingWeb(key, blobUrlOrPath) ?? blobUrlOrPath;
      AudioService.instance.registerRecording(key, wavUrl);
      return wavUrl;
    }
    AudioService.instance.registerRecording(key, blobUrlOrPath);
    return blobUrlOrPath;
  }

  /// Load all recordings from persistent storage into AudioService.
  /// Call once during app init.
  Future<void> restoreAll() async {
    if (!kIsWeb) return;
    final entries = await _impl.loadAllWeb();
    for (final e in entries) {
      AudioService.instance.registerRecording(e['key']!, e['blobUrl']!);
    }
  }

  /// Delete a recording from persistent storage and memory.
  Future<void> deleteRecording(String key) async {
    AudioService.instance.userRecordings.remove(key);
    if (kIsWeb) await _impl.deleteRecordingWeb(key);
  }

  /// Download a single recording as a browser file.
  Future<void> downloadRecording(String key, {String? filename}) async {
    if (!kIsWeb) return;
    await _impl.downloadRecordingWeb(key, filename: filename);
  }

  /// Download a set of recordings as a ZIP file.
  Future<void> downloadZip(List<String> keys, {String zipFilename = 'recordings.zip'}) async {
    if (!kIsWeb) return;
    await _impl.downloadZipWeb(keys, zipFilename: zipFilename);
  }

  /// Returns list of all persisted audio keys.
  Future<List<String>> listKeys() async {
    if (!kIsWeb) return AudioService.instance.userRecordings.keys.toList();
    return _impl.listKeysWeb();
  }
}
