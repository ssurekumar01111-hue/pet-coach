import 'package:get/get.dart';

import 'progress_timeline_controller.dart';

class ProgressTimelineBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(ProgressTimelineController.new);
}
