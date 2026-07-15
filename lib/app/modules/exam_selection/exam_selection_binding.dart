import 'package:get/get.dart';
import 'exam_selection_controller.dart';

class ExamSelectionBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(ExamSelectionController.new);
}
