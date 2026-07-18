import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';

import '../../data/models/training_plan.dart';

class TrainingPlanController extends GetxController {
  TrainingPlanController({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;
  final plan = Rxn<TrainingPlan>();
  final isLoading = true.obs;
  final errorMessage = RxnString();
  final isRateLimited = false.obs;

  @override
  void onReady() {
    super.onReady();
    loadPlan();
  }

  Future<void> loadPlan() async {
    if (isLoading.value && plan.value != null) return;
    isLoading.value = true;
    errorMessage.value = null;
    isRateLimited.value = false;
    try {
      final response = await _functions.httpsCallable('generateTrainingPlan').call();
      plan.value = TrainingPlan.fromMap(Map<String, dynamic>.from(response.data as Map));
    } on FirebaseFunctionsException catch (error) {
      isRateLimited.value = error.code == 'resource-exhausted';
      errorMessage.value = isRateLimited.value
          ? 'Daily AI limit reached — resets tomorrow.'
          : 'Your training plan is unavailable right now.';
    } catch (_) {
      errorMessage.value = 'Your training plan is unavailable right now.';
    } finally {
      isLoading.value = false;
    }
  }
}
