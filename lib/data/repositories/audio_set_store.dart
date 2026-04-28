// lib/data/repositories/audio_set_store.dart
//
// Named audio sets — ZIP files exported from recorder.html and imported
// into the app for playback.  Each set is stored in IndexedDB on web.
//
// Usage:
//   final sets = await AudioSetStore.instance.listSets();
//   final bytes = await AudioSetStore.instance.pickFile();   // file picker
//   final id = await AudioSetStore.instance.importZip(bytes, name: 'Teacher A');
//   final url = await AudioSetStore.instance.getRecordingBlobUrl(id, '1.1.11');
//   await AudioSetStore.instance.deleteSet(id);

import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'audio_set_store_web.dart'
    if (dart.library.io) 'audio_set_store_stub.dart' as _impl;

class AudioSetMeta {
  final String id;
  final String name;
  final int    padaCount;
  const AudioSetMeta({required this.id, required this.name, required this.padaCount});
}

class AudioSetStore {
  AudioSetStore._();
  static final instance = AudioSetStore._();

  /// List all stored audio sets (metadata only).
  Future<List<AudioSetMeta>> listSets() async {
    if (!kIsWeb) return [];
    return _impl.listSetsWeb();
  }

  /// Open the OS file picker and return ZIP bytes, or null if cancelled.
  Future<Uint8List?> pickFile() async {
    if (!kIsWeb) return null;
    return _impl.pickFileWeb();
  }

  /// Count WAV files inside a ZIP (synchronous scan, no storage).
  int countWavs(Uint8List bytes) {
    if (!kIsWeb) return 0;
    return _impl.countZipWavsWeb(bytes);
  }

  /// Parse [bytes] (a ZIP) and store all WAV files as a named audio set.
  /// Pass [updateId] to overwrite an existing set's recordings.
  /// Returns the new/updated set ID, or null on failure.
  Future<String?> importZip(
      Uint8List bytes, {required String name, String? updateId}) async {
    if (!kIsWeb) return null;
    return _impl.importZipWeb(bytes, name: name, updateId: updateId);
  }

  /// Returns a WAV blob: URL for a pada in the given set, or null.
  Future<String?> getRecordingBlobUrl(String setId, String padaId) async {
    if (!kIsWeb) return null;
    return _impl.getRecordingBlobUrlWeb(setId, padaId);
  }

  /// Delete a set and all its recordings from IndexedDB.
  Future<void> deleteSet(String setId) async {
    if (!kIsWeb) return;
    await _impl.deleteSetWeb(setId);
  }
}
