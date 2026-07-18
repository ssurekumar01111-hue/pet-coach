import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';
import '../../data/models/injury_risk_assessment.dart';

class InjuryRiskController extends GetxController {
  InjuryRiskController({FirebaseFunctions? functions}) : _functions = functions ?? FirebaseFunctions.instance;
  final FirebaseFunctions _functions;
  final isLoading = true.obs;
  final assessment = Rxn<InjuryRiskAssessment>();
  final isInsufficientData = false.obs;
  final isRateLimited = false.obs;
  final errorMessage = RxnString();
  @override void onReady() { super.onReady(); loadAssessment(); }
  Future<void> loadAssessment() async {
    if (isLoading.value && assessment.value != null) return;
    isLoading.value = true; errorMessage.value = null; isInsufficientData.value = false; isRateLimited.value = false;
    try {
      final response = await _functions.httpsCallable('generateInjuryRiskAssessment').call();
      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['insufficientData'] == true) { isInsufficientData.value = true; return; }
      assessment.value = InjuryRiskAssessment.fromMap(data);
    } on FirebaseFunctionsException catch (error) {
      isRateLimited.value = error.code == 'resource-exhausted';
      errorMessage.value = isRateLimited.value ? 'Daily AI limit reached — resets tomorrow.' : 'Your training-load estimate is unavailable right now.';
    } catch (_) { errorMessage.value = 'Your training-load estimate is unavailable right now.'; }
    finally { isLoading.value = false; }
  }
}
