import 'package:get/get.dart';
import 'tracker_controller.dart';

class TrackerBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(TrackerController.new);
}
