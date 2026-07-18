import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data/models/run_session.dart';

/// Persists finished runs before any network work. Firestore writes use the
/// session id as the document id, making a retry after an interrupted sync
/// idempotent rather than creating duplicate sessions.
class OfflineSessionSyncService extends GetxService {
  static const _boxName = 'pendingSessions';
  static const _sessionKey = 'session';
  static const _syncedKey = 'synced';

  OfflineSessionSyncService({
    FirebaseFirestore? firestore,
    Connectivity? connectivity,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _connectivity = connectivity ?? Connectivity();

  final FirebaseFirestore _firestore;
  final Connectivity _connectivity;
  final pendingCount = 0.obs;
  final isOnline = false.obs;
  Box<Map>? _box;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  Future<OfflineSessionSyncService> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<Map>(_boxName);
    _refreshPendingCount();
    await _handleConnectivity(await _connectivity.checkConnectivity());
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivity,
    );
    return this;
  }

  Future<void> enqueue(RunSession session) async {
    final box = _box;
    if (box == null) return;
    await box.put(session.id, <String, dynamic>{
      _sessionKey: session.toLocalMap(),
      _syncedKey: false,
    });
    _refreshPendingCount();
    unawaited(syncPendingSessions());
  }

  bool isPending(String sessionId) => _box?.containsKey(sessionId) ?? false;

  Future<void> syncPendingSessions() async {
    final box = _box;
    if (box == null || _isSyncing || !isOnline.value) return;
    _isSyncing = true;
    try {
      final queued = box.values
          .map(Map<String, dynamic>.from)
          .where((entry) => entry[_syncedKey] != true)
          .toList()
        ..sort((first, second) {
          final firstSession = Map<String, dynamic>.from(first[_sessionKey] as Map);
          final secondSession = Map<String, dynamic>.from(second[_sessionKey] as Map);
          return (firstSession['startTime'] as String)
              .compareTo(secondSession['startTime'] as String);
        });
      for (final entry in queued) {
        final session = RunSession.fromLocalMap(
          Map<String, dynamic>.from(entry[_sessionKey] as Map),
        );
        try {
          await _firestore.collection('sessions').doc(session.id).set(
                session.toMap(),
                SetOptions(merge: true),
              );
          // Delete only after Firestore confirms the deterministic write.
          await box.delete(session.id);
          _refreshPendingCount();
        } catch (_) {
          // Preserve the current and later sessions for the next connectivity
          // event; order is important for a predictable upload queue.
          break;
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _handleConnectivity(List<ConnectivityResult> results) async {
    isOnline.value = !results.contains(ConnectivityResult.none);
    if (isOnline.value) await syncPendingSessions();
  }

  void _refreshPendingCount() {
    final box = _box;
    if (box == null) return;
    pendingCount.value = box.values
        .map(Map<String, dynamic>.from)
        .where((entry) => entry[_syncedKey] != true)
        .length;
  }

  @override
  void onClose() {
    _connectivitySubscription?.cancel();
    super.onClose();
  }
}
