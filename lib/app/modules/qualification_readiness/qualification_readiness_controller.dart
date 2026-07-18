import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/models/qualification_readiness.dart';

class QualificationReadinessController extends GetxController {
  QualificationReadinessController({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;
  final isLoading = true.obs;
  final readiness = Rxn<QualificationReadiness>();
  final isInsufficientData = false.obs;
  final errorMessage = RxnString();
  final isRateLimited = false.obs;

  @override
  void onReady() {
    super.onReady();
    loadReadiness();
  }

  Future<void> loadReadiness() async {
    if (isLoading.value && readiness.value != null) return;
    isLoading.value = true;
    errorMessage.value = null;
    isInsufficientData.value = false;
    isRateLimited.value = false;
    if (kDebugMode) {
      debugPrint('[QualificationReadiness] FirebaseAuth.currentUser?.uid='
          '${FirebaseAuth.instance.currentUser?.uid}');
      debugPrint('[QualificationReadiness] Callable request: '
          'generateQualificationReadiness (server queries sessions where uid == auth.uid)');
    }
    try {
      final response = await _functions
          .httpsCallable('generateQualificationReadiness')
          .call();
      final data = Map<String, dynamic>.from(response.data as Map);
      if (kDebugMode) {
        debugPrint('[QualificationReadiness] Callable response: '
            'insufficientData=${data['insufficientData'] == true}, '
            'keys=${data.keys.join(',')}');
      }
      if (data['insufficientData'] == true) {
        isInsufficientData.value = true;
        return;
      }
      readiness.value = QualificationReadiness.fromMap(data);
    } on FirebaseFunctionsException catch (error) {
      isRateLimited.value = error.code == 'resource-exhausted';
      errorMessage.value = isRateLimited.value
          ? 'Daily AI limit reached — resets tomorrow.'
          : 'Your readiness prediction is unavailable right now.';
    } catch (_) {
      errorMessage.value =
          'Your readiness prediction is unavailable right now.';
    } finally {
      isLoading.value = false;
    }
  }
}
