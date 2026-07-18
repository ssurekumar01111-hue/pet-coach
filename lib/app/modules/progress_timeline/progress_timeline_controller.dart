import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/models/exam_config.dart';
import '../../data/models/run_session.dart';
import '../../data/repositories/firestore_repository.dart';

class TimelineSession {
  const TimelineSession({
    required this.session,
    required this.examName,
    required this.paceSecPerKm,
    required this.qualifies,
  });

  final RunSession session;
  final String examName;
  final double? paceSecPerKm;
  final bool? qualifies;
}

class ProgressTimelineController extends GetxController {
  ProgressTimelineController({
    FirebaseAuth? auth,
    FirestoreRepository? repository,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _repository = repository ?? FirestoreRepository();

  final FirebaseAuth _auth;
  final FirestoreRepository _repository;
  final sessions = <TimelineSession>[].obs;
  final isLoading = true.obs;
  final errorMessage = RxnString();
  List<RunSession> _rawSessions = const [];
  List<ExamConfig> _exams = const [];
  StreamSubscription<List<RunSession>>? _sessionSubscription;
  StreamSubscription<List<ExamConfig>>? _examSubscription;

  static const qualificationWindow = 10;

  double get qualificationRate {
    final reviewed = sessions
        .take(qualificationWindow)
        .where((item) => item.qualifies != null);
    if (reviewed.isEmpty) return 0;
    return reviewed.where((item) => item.qualifies!).length / reviewed.length;
  }

  List<TimelineSession> get chartSessions => sessions
      .where((item) => item.paceSecPerKm != null)
      .take(8)
      .toList()
      .reversed
      .toList();

  @override
  void onInit() {
    super.onInit();
    final uid = _auth.currentUser?.uid;
    if (kDebugMode) {
      debugPrint('[ProgressTimeline] FirebaseAuth.currentUser?.uid=$uid');
    }
    if (uid == null) {
      errorMessage.value = 'Sign in to see your training progress.';
      isLoading.value = false;
      return;
    }
    _examSubscription = _repository.watchExamConfigs().listen((items) {
      _exams = items;
      _rebuildTimeline();
    });
    _sessionSubscription = _repository.watchUserSessions(uid).listen(
      (items) {
        _rawSessions = items;
        _rebuildTimeline();
        isLoading.value = false;
      },
      onError: (Object error, StackTrace stackTrace) {
        if (kDebugMode) {
          if (error is FirebaseException) {
            debugPrint('[ProgressTimeline] Firestore stream failed: '
                'code=${error.code}, message=${error.message}, '
                'plugin=${error.plugin}');
          } else {
            debugPrint('[ProgressTimeline] Firestore stream failed: $error');
          }
          debugPrintStack(
            label: '[ProgressTimeline] Firestore stream stack trace',
            stackTrace: stackTrace,
          );
        }
        errorMessage.value = 'Unable to load your run history.';
        isLoading.value = false;
      },
    );
  }

  void _rebuildTimeline() {
    final examNames = {for (final exam in _exams) exam.id: exam.name};
    sessions.assignAll(_rawSessions.map((session) {
      final pace = session.totalDistanceKm > 0
          ? session.totalTimeSec / session.totalDistanceKm
          : null;
      return TimelineSession(
        session: session,
        examName: examNames[session.examId] ??
            (session.examId.isEmpty ? 'PET training run' : session.examId),
        paceSecPerKm: pace,
        qualifies: session.aiSummary?.qualifies,
      );
    }));
  }

  @override
  void onClose() {
    _sessionSubscription?.cancel();
    _examSubscription?.cancel();
    super.onClose();
  }
}
