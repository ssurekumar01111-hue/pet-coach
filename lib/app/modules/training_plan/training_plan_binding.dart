import 'package:get/get.dart';

import 'training_plan_controller.dart';

class TrainingPlanBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(TrainingPlanController.new);
}
