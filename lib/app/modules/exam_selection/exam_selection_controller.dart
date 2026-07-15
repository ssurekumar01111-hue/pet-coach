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
}
