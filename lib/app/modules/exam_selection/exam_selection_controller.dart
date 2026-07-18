import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/exam_config.dart';
import '../../data/repositories/firestore_repository.dart';
import '../../routes/app_routes.dart';

class ExamSelectionController extends GetxController {
  ExamSelectionController({FirestoreRepository? repository})
      : _repository = repository ?? FirestoreRepository();
  final FirestoreRepository _repository;
  final exams = <ExamConfig>[].obs;
  final isLoading = true.obs;
  final searchController = TextEditingController();
  final searchQuery = ''.obs;
  @override
  void onInit() {
    super.onInit();
    _repository.watchExamConfigs().listen((items) {
      exams.assignAll(items);
      isLoading.value = false;
    }, onError: (_) => isLoading.value = false);
  }

  void selectExam(ExamConfig exam) =>
      Get.toNamed(Routes.tracker, arguments: exam);

  Map<String, List<ExamConfig>> get groupedFilteredExams {
    final query = searchQuery.value.trim().toLowerCase();
    final matching = exams.where((exam) =>
        query.isEmpty ||
        exam.name.toLowerCase().contains(query) ||
        exam.id.toLowerCase().contains(query));
    final groups = <String, List<ExamConfig>>{};
    for (final exam in matching) {
      groups.putIfAbsent(_categoryFor(exam), () => []).add(exam);
    }
    return groups;
  }

  String _categoryFor(ExamConfig exam) {
    if (exam.id == 'army_agniveer') return 'Defence';
    if (exam.id == 'up_home_guard' || exam.id == 'up_police' || exam.id == 'delhi_police') {
      return 'State Police';
    }
    return 'Central Armed Police Forces';
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}
