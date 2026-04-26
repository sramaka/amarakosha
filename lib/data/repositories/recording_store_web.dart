// lib/data/repositories/recording_store_web.dart
// Web-only — calls window.amaraStore JS helpers from web/index.html.
// Uses dart:js_interop (Dart 3.3+).

import 'dart:js_interop';

// ── Typed JS interop declarations ─────────────────────────────────────────────
// Declare each JS function with its exact signature so Dart resolves types
// correctly without needing any runtime casts.

@JS('amaraStore.saveRecording')
external JSPromise<JSAny?> jsSaveRecording(JSString key, JSString blobUrl);

@JS('amaraStore.loadAll')
external JSPromise<JSArray<JSObject>> jsLoadAll();

@JS('amaraStore.deleteRecording')
external JSPromise<JSBoolean> jsDeleteRecording(JSString key);

@JS('amaraStore.listKeys')
external JSPromise<JSArray<JSString>> jsListKeys();

@JS('amaraStore.downloadRecording')
external JSPromise<JSAny?> jsDownloadRecording(JSString key, JSString filename);

@JS('amaraStore.downloadZip')
external JSPromise<JSAny?> jsDownloadZip(JSString keysCommaSep, JSString zipFilename);

// Typed JS object for a recording entry: {key: string, blobUrl: string}
extension type _RecordingEntry(JSObject _) implements JSObject {
  external JSString get key;
  external JSString get blobUrl;
}

// ── Dart API ──────────────────────────────────────────────────────────────────

/// Save a blob: URL to IndexedDB under [key].
/// Returns the WAV blob URL to use for playback, or null on failure.
Future<String?> saveRecordingWeb(String key, String blobUrl) async {
  try {
    final result = await jsSaveRecording(key.toJS, blobUrl.toJS).toDart;
    // JS returns a WAV blob URL string; guard against old cached JS returning bool.
    if (result is JSString) return result.toDart;
    return null;
  } catch (_) {
    return null;
  }
}

/// Load all recordings from IndexedDB.
/// Returns list of {key, blobUrl} maps.
Future<List<Map<String, String>>> loadAllWeb() async {
  try {
    final jsArr = await jsLoadAll().toDart;
    final list  = <Map<String, String>>[];
    final len   = jsArr.length;
    for (var i = 0; i < len; i++) {
      final entry = _RecordingEntry(jsArr[i]);
      list.add({
        'key':     entry.key.toDart,
        'blobUrl': entry.blobUrl.toDart,
      });
    }
    return list;
  } catch (_) {
    return [];
  }
}

/// Delete a recording from IndexedDB.
Future<void> deleteRecordingWeb(String key) async {
  try {
    await jsDeleteRecording(key.toJS).toDart;
  } catch (_) {}
}

/// Trigger a browser download of a single stored recording.
Future<void> downloadRecordingWeb(String key, {String? filename}) async {
  try {
    await jsDownloadRecording(key.toJS, (filename ?? '$key.wav').toJS).toDart;
  } catch (_) {}
}

/// Trigger a browser download of multiple recordings as a ZIP.
Future<void> downloadZipWeb(List<String> keys, {String zipFilename = 'recordings.zip'}) async {
  try {
    await jsDownloadZip(keys.join(',').toJS, zipFilename.toJS).toDart;
  } catch (_) {}
}

/// List all stored keys.
Future<List<String>> listKeysWeb() async {
  try {
    final jsArr = await jsListKeys().toDart;
    final list  = <String>[];
    final len   = jsArr.length;
    for (var i = 0; i < len; i++) {
      list.add(jsArr[i].toDart);
    }
    return list;
  } catch (_) {
    return [];
  }
}