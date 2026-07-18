import 'package:get/get.dart';

import 'pace_optimization_controller.dart';

class PaceOptimizationBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(PaceOptimizationController.new);
}
