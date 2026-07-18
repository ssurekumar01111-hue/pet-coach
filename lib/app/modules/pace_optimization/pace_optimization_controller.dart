import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../../data/models/exam_config.dart';
import '../../data/repositories/firestore_repository.dart';
import 'pace_analyzer.dart';

class PaceOptimizationController extends GetxController {
  PaceOptimizationController({
    FirestoreRepository? repository,
    FirebaseAuth? auth,
  })  : _repository = repository ?? FirestoreRepository(),
        _auth = auth ?? FirebaseAuth.instance;

  final FirestoreRepository _repository;
  final FirebaseAuth _auth;
  final isLoading = true.obs;
  final analysis = Rxn<PaceAnalysis>();
  final errorMessage = RxnString();

  @override
  void onReady() {
    super.onReady();
    loadAnalysis();
  }

  Future<void> loadAnalysis() async {
    final sessionId = Get.arguments;
    if (sessionId is! String || sessionId.isEmpty) {
      errorMessage.value = 'A completed session is required for pace analysis.';
      isLoading.value = false;
      return;
    }
    try {
      final session = await _repository.getSession(sessionId);
      final uid = _auth.currentUser?.uid;
      if (session == null || uid == null || session.uid != uid) {
        throw StateError('Session not available.');
      }
      final exams = await _repository.getExamConfigs();
      final matchingExams = exams.where((item) => item.id == session.examId).toList();
      final ExamConfig? exam = matchingExams.isEmpty ? null : matchingExams.first;
      if (exam == null || exam.distanceKm <= 0) throw StateError('Exam target not available.');
      final recent = await _repository.getRecentUserSessions(uid);
      final historicalPaces = recent
          .where((item) => item.id != session.id && item.totalDistanceKm > 0 && item.totalTimeSec > 0)
          .map((item) => item.totalTimeSec / item.totalDistanceKm)
          .toList();
      final historical = historicalPaces.isEmpty
          ? null
          : historicalPaces.reduce((a, b) => a + b) / historicalPaces.length;
      analysis.value = PaceAnalyzer.analyze(
        session: session,
        targetPaceSecPerKm: exam.timeLimitMin * 60 / exam.distanceKm,
        historicalPaceSecPerKm: historical,
      );
    } catch (_) {
      errorMessage.value = 'Unable to build pace analysis for this session.';
    } finally {
      isLoading.value = false;
    }
  }
}
