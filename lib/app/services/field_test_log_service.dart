import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Debug-only, per-session field-test log persistence.
///
/// All callers are additionally guarded by [kDebugMode]. Keeping that guard
/// here makes accidental use from a release-only code path a no-op as well.
class FieldTestLogService {
  static const _prefix = 'field_test_log_';
  File? _activeFile;
  Future<void> _writeQueue = Future<void>.value();

  Future<void> startSession(DateTime sessionStart) async {
    if (!kDebugMode) return;
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = sessionStart
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
    _activeFile = File('${directory.path}${Platform.pathSeparator}'
        '$_prefix$timestamp.txt');
    await _activeFile!.writeAsString(
      'PET Coach field-test log\n'
      'Session started: ${sessionStart.toIso8601String()}\n\n',
      flush: true,
    );
  }

  /// Serializes immediate, flushed appends so concurrent GPS callbacks retain
  /// their order and a previous write failure cannot block later diagnostics.
  Future<void> append(String message) {
    if (!kDebugMode || _activeFile == null) return Future<void>.value();
    final line = '[${DateTime.now().toIso8601String()}] $message\n';
    final file = _activeFile!;
    _writeQueue = _writeQueue.then(
      (_) => file.writeAsString(line, mode: FileMode.append, flush: true),
      onError: (_) => file.writeAsString(line, mode: FileMode.append, flush: true),
    );
    return _writeQueue;
  }

  Future<List<File>> recentLogs() async {
    if (!kDebugMode) return const [];
    final directory = await getApplicationDocumentsDirectory();
    final logs = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.uri.pathSegments.last.startsWith(_prefix))
        .toList();
    logs.sort((first, second) =>
        second.lastModifiedSync().compareTo(first.lastModifiedSync()));
    return logs;
  }

  Future<void> share(File file) async {
    if (!kDebugMode) return;
    await SharePlus.instance.share(
      ShareParams(
        text: 'PET Coach field-test diagnostics',
        files: [XFile(file.path)],
      ),
    );
  }
}
