import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../../data/models/exam_config.dart';
import '../../data/models/leaderboard_entry.dart';
import '../../data/repositories/firestore_repository.dart';

class LeaderboardController extends GetxController {
  LeaderboardController({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirestoreRepository? repository,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _repository = repository ?? FirestoreRepository();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirestoreRepository _repository;
  final exams = <ExamConfig>[].obs;
  final entries = <LeaderboardEntry>[].obs;
  final selectedExamId = RxnString();
  final isLoading = true.obs;
  final errorMessage = RxnString();
  StreamSubscription<List<ExamConfig>>? _examSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _entrySubscription;

  String? get currentUid => _auth.currentUser?.uid;

  @override
  void onInit() {
    super.onInit();
    _examSubscription = _repository.watchExamConfigs().listen(
      (items) {
        exams.assignAll(items);
        final selected = selectedExamId.value;
        if (items.isNotEmpty && !items.any((exam) => exam.id == selected)) {
          selectExam(items.first.id);
        }
      },
      onError: (_) {
        errorMessage.value = 'Unable to load exam categories.';
        isLoading.value = false;
      },
    );
  }

  void selectExam(String? examId) {
    if (examId == null || examId == selectedExamId.value) return;
    selectedExamId.value = examId;
    entries.clear();
    errorMessage.value = null;
    isLoading.value = true;
    _entrySubscription?.cancel();
    _entrySubscription = _firestore
        .collection('leaderboards')
        .doc(examId)
        .collection('entries')
        .orderBy('bestTime')
        .snapshots()
        .listen(
      (snapshot) {
        entries.assignAll(snapshot.docs.map(LeaderboardEntry.fromFirestore));
        isLoading.value = false;
      },
      onError: (_) {
        errorMessage.value = 'Unable to load this leaderboard.';
        isLoading.value = false;
      },
    );
  }

  @override
  void onClose() {
    _examSubscription?.cancel();
    _entrySubscription?.cancel();
    super.onClose();
  }
}
