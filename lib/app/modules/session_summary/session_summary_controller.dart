import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';

import '../../data/models/ai_summary.dart';
import '../../data/models/run_session.dart';
import '../../data/models/recovery_summary.dart';
import '../../services/offline_session_sync_service.dart';

class SessionSummaryController extends GetxController {
  SessionSummaryController({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FlutterTts? tts,
    OfflineSessionSyncService? offlineSync,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _tts = tts ?? FlutterTts(),
        _offlineSync = offlineSync ??
            (Get.isRegistered<OfflineSessionSyncService>()
                ? Get.find<OfflineSessionSyncService>()
                : null);

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FlutterTts _tts;
  final OfflineSessionSyncService? _offlineSync;

  final isLoading = false.obs;
  final summary = Rxn<AiSummary>();
  final recoverySummary = Rxn<RecoverySummary>();
  final qualifiedDeterministic = RxnBool();
  final session = Rxn<RunSession>();
  final errorMessage = RxnString();
  final canRetry = true.obs;
  final isRateLimited = false.obs;
  final isFeedbackSpeaking = false.obs;
  final isWaitingForConnection = false.obs;
  Worker? _syncWorker;

  @override
  void onReady() {
    super.onReady();
    _syncWorker = everAll(
      [_offlineSync?.pendingCount ?? 0.obs, _offlineSync?.isOnline ?? false.obs],
      (_) {
        final current = session.value;
        if (isWaitingForConnection.value && current != null &&
            (_offlineSync?.isPending(current.id) ?? false) == false &&
            (_offlineSync?.isOnline.value ?? true)) {
          loadFeedback();
        }
      },
    );
    loadFeedback();
  }

  Future<void> loadFeedback({bool bypassRetryThrottle = false}) async {
    if (isLoading.value || (!bypassRetryThrottle && !canRetry.value)) return;

    isLoading.value = true;
    errorMessage.value = null;
    isRateLimited.value = false;
    try {
      final currentSession = await _resolveSession();
      if (currentSession == null) {
        throw StateError('We could not find the run you just completed.');
      }
      session.value = currentSession;
      qualifiedDeterministic.value = currentSession.qualifiedDeterministic;
      final waitingForUpload = _offlineSync?.isPending(currentSession.id) ?? false;
      final offline = _offlineSync?.isOnline.value == false;
      if (waitingForUpload || offline) {
        isWaitingForConnection.value = true;
        return;
      }
      isWaitingForConnection.value = false;

      final callable = _functions.httpsCallable('generateCoachFeedback');
      final response = await callable.call(<String, dynamic>{
        'sessionId': currentSession.id,
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      summary.value = AiSummary.fromMap(data);
      qualifiedDeterministic.value = data['qualifiedDeterministic'] as bool?;
      recoverySummary.value = RecoverySummary.fromMap(
        Map<String, dynamic>.from(data['recoverySummary'] as Map),
      );
    } on FirebaseFunctionsException catch (error) {
      isRateLimited.value = error.code == 'resource-exhausted';
      errorMessage.value = isRateLimited.value
          ? 'Daily AI limit reached — resets tomorrow.'
          : 'Your coach could not analyze this run just now. Please try again.';
    } catch (_) {
      errorMessage.value =
          'Your coach could not analyze this run just now. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<RunSession?> _resolveSession() async {
    final argument = Get.arguments;
    if (argument is RunSession) return argument;
    if (argument is String && argument.isNotEmpty) {
      final document = await _firestore.collection('sessions').doc(argument).get();
      return document.exists ? RunSession.fromFirestore(document) : null;
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final snapshot = await _firestore
        .collection('sessions')
        .where('uid', isEqualTo: uid)
        .orderBy('startTime', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return RunSession.fromFirestore(snapshot.docs.single);
  }

  void retry() {
    if (isWaitingForConnection.value || isRateLimited.value || !canRetry.value || isLoading.value) return;
    canRetry.value = false;
    loadFeedback(bypassRetryThrottle: true);
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!isClosed) canRetry.value = true;
    });
  }

  Future<void> toggleFeedbackReadAloud() async {
    if (isFeedbackSpeaking.value) {
      await _stopFeedbackSpeech();
      return;
    }
    final feedback = summary.value?.feedback;
    if (feedback == null || feedback.isEmpty) return;
    isFeedbackSpeaking.value = true;
    try {
      await _tts.setLanguage('en-IN');
      await _tts.setSpeechRate(.48);
      await _tts.awaitSpeakCompletion(true);
      await _tts.speak(feedback);
    } catch (_) {
      Get.snackbar('Voice unavailable', 'Unable to read feedback aloud right now.');
    } finally {
      isFeedbackSpeaking.value = false;
    }
  }

  Future<void> _stopFeedbackSpeech() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Reading feedback aloud is optional.
    } finally {
      isFeedbackSpeaking.value = false;
    }
  }

  @override
  void onClose() {
    _syncWorker?.dispose();
    unawaited(_stopFeedbackSpeech());
    super.onClose();
  }
}
