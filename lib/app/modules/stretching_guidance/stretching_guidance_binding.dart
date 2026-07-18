import 'package:get/get.dart';

import 'stretching_guidance_controller.dart';

class StretchingGuidanceBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(StretchingGuidanceController.new);
}
