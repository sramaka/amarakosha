// lib/data/repositories/recording_store_stub.dart
// Non-web stub — these functions are never called on native since
// recording_store.dart guards all calls with kIsWeb checks.

Future<String?> saveRecordingWeb(String key, String blobUrl) async => null;

Future<List<Map<String, String>>> loadAllWeb() async => [];

Future<void> deleteRecordingWeb(String key) async {}

Future<List<String>> listKeysWeb() async => [];

Future<void> downloadRecordingWeb(String key, {String? filename}) async {}

Future<void> downloadZipWeb(List<String> keys, {String zipFilename = 'recordings.zip'}) async {}
