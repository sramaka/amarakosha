// lib/data/repositories/audio_set_store_web.dart
// Web-only — calls window.amaraSetStore / window.pickWavZip / window.countZipWavs
// from web/index.html via dart:js_interop.

import 'dart:js_interop';
import 'dart:typed_data';
import 'audio_set_store.dart';

// ── JS declarations ───────────────────────────────────────────────────────────

extension type _SetMeta(JSObject _) implements JSObject {
  external JSString get id;
  external JSString get name;
  external double   get padaCount; // JS number → Dart double directly
}

@JS('amaraSetStore.listSets')
external JSPromise<JSArray<JSObject>> _jsListSets();

@JS('amaraSetStore.importZip')
external JSPromise<JSString> _jsImportZip(
    JSString name, JSString? updateId, JSUint8Array bytes);

@JS('amaraSetStore.getRecordingBlobUrl')
external JSPromise<JSAny?> _jsGetRecordingBlobUrl(JSString setId, JSString padaId);

@JS('amaraSetStore.deleteSet')
external JSPromise<JSAny?> _jsDeleteSet(JSString setId);

@JS('pickWavZip')
external JSPromise<JSAny?> _jsPickWavZip();

@JS('countZipWavs')
external double _jsCountZipWavs(JSUint8Array bytes);

// ── Dart API ──────────────────────────────────────────────────────────────────

Future<List<AudioSetMeta>> listSetsWeb() async {
  try {
    final arr = await _jsListSets().toDart;
    final result = <AudioSetMeta>[];
    for (var i = 0; i < arr.length; i++) {
      final m = _SetMeta(arr[i]);
      result.add(AudioSetMeta(
        id:        m.id.toDart,
        name:      m.name.toDart,
        padaCount: m.padaCount.round(),
      ));
    }
    return result;
  } catch (_) {
    return [];
  }
}

Future<Uint8List?> pickFileWeb() async {
  try {
    final result = await _jsPickWavZip().toDart;
    if (result == null) return null;
    return (result as JSUint8Array).toDart;
  } catch (_) {
    return null;
  }
}

int countZipWavsWeb(Uint8List bytes) {
  try {
    return _jsCountZipWavs(bytes.toJS).round();
  } catch (_) {
    return 0;
  }
}

Future<String?> importZipWeb(
    Uint8List bytes, {required String name, String? updateId}) async {
  final setId = await _jsImportZip(name.toJS, updateId?.toJS, bytes.toJS).toDart;
  return setId.toDart;
}

Future<String?> getRecordingBlobUrlWeb(String setId, String padaId) async {
  try {
    final result =
        await _jsGetRecordingBlobUrl(setId.toJS, padaId.toJS).toDart;
    if (result == null) return null;
    return (result as JSString).toDart;
  } catch (_) {
    return null;
  }
}

Future<void> deleteSetWeb(String setId) async {
  try {
    await _jsDeleteSet(setId.toJS).toDart;
  } catch (_) {}
}
