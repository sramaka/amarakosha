// lib/data/repositories/audio_set_store_stub.dart
// Non-web stub — all operations are no-ops.

import 'dart:typed_data';
import 'audio_set_store.dart';

Future<List<AudioSetMeta>> listSetsWeb() async => [];
Future<Uint8List?> pickFileWeb() async => null;
int countZipWavsWeb(Uint8List bytes) => 0;
Future<String?> importZipWeb(
    Uint8List bytes, {required String name, String? updateId}) async => null;
Future<String?> getRecordingBlobUrlWeb(String setId, String padaId) async => null;
Future<void> deleteSetWeb(String setId) async {}
