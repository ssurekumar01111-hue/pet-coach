import 'package:get/get.dart';
import 'exam_selection_controller.dart';
import '../daily_target/daily_target_controller.dart';

class ExamSelectionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(ExamSelectionController.new);
    Get.lazyPut(DailyTargetController.new);
  }
}
