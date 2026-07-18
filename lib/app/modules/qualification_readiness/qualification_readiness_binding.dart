import 'package:get/get.dart';

import 'qualification_readiness_controller.dart';

class QualificationReadinessBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(QualificationReadinessController.new);
}
