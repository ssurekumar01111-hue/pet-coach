import 'package:get/get.dart';
import 'session_summary_controller.dart';

class SessionSummaryBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(SessionSummaryController.new);
}
