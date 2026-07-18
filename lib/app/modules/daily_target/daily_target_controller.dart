import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';

import '../../data/models/daily_target.dart';

class DailyTargetController extends GetxController {
  DailyTargetController({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;
  final isLoading = true.obs;
  final target = Rxn<DailyTarget>();
  final errorMessage = RxnString();
  final isRateLimited = false.obs;

  @override
  void onReady() {
    super.onReady();
    loadTarget();
  }

  Future<void> loadTarget() async {
    if (isLoading.value && target.value != null) return;
    isLoading.value = true;
    errorMessage.value = null;
    isRateLimited.value = false;
    try {
      final response = await _functions.httpsCallable('generateDailyTarget').call();
      target.value = DailyTarget.fromMap(Map<String, dynamic>.from(response.data as Map));
    } on FirebaseFunctionsException catch (error) {
      isRateLimited.value = error.code == 'resource-exhausted';
      errorMessage.value = isRateLimited.value
          ? 'Daily AI limit reached — resets tomorrow.'
          : 'Today\'s target is unavailable right now.';
    } catch (_) {
      errorMessage.value = 'Today\'s target is unavailable right now.';
    } finally {
      isLoading.value = false;
    }
  }
}
