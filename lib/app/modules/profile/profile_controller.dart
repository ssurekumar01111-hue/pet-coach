import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/models/exam_config.dart';
import '../../data/repositories/firestore_repository.dart';
import '../../routes/app_routes.dart';
import '../../services/hydration_service.dart';
import '../../services/field_test_log_service.dart';

class ProfileController extends GetxController {
  ProfileController({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirestoreRepository? repository,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _repository = repository ?? FirestoreRepository();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirestoreRepository _repository;
  final displayNameController = TextEditingController();
  final ageController = TextEditingController();
  final gender = RxnString();
  final examTarget = RxnString();
  final exams = <ExamConfig>[].obs;
  final isLoading = true.obs;
  final isSaving = false.obs;
  final fieldTestLogs = <File>[].obs;
  final isLoadingFieldTestLogs = false.obs;
  final FieldTestLogService _fieldTestLog = FieldTestLogService();
  HydrationService get hydration => Get.find<HydrationService>();
  String? _uid;
  StreamSubscription<List<ExamConfig>>? _examSubscription;

  static const genders = <String>['Male', 'Female', 'Other'];

  String get maskedPhoneNumber {
    final phone = _auth.currentUser?.phoneNumber;
    if (phone == null || phone.length < 5) return 'Phone number unavailable';
    final prefix = phone.startsWith('+91') ? '+91' : phone.substring(0, 3);
    return '$prefix XXXXX${phone.substring(phone.length - 5)}';
  }

  @override
  void onInit() {
    super.onInit();
    _uid = _auth.currentUser?.uid;
    _examSubscription = _repository.watchExamConfigs().listen(exams.assignAll);
    _loadProfile();
    if (kDebugMode) unawaited(loadFieldTestLogs());
  }

  Future<void> _loadProfile() async {
    final uid = _uid;
    if (uid == null) {
      isLoading.value = false;
      return;
    }
    try {
      final document = await _firestore.collection('users').doc(uid).get();
      final data = document.data();
      final profile = Map<String, dynamic>.from(data?['profile'] as Map? ?? {});
      final displayName = data?['displayName'];
      if (displayName is String) displayNameController.text = displayName;
      final age = profile['age'];
      if (age is num) ageController.text = age.toInt().toString();
      final savedGender = profile['gender'];
      if (savedGender is String && genders.contains(savedGender)) {
        gender.value = savedGender;
      }
      final savedTarget = data?['examTarget'];
      if (savedTarget is String) examTarget.value = savedTarget;
    } catch (_) {
      Get.snackbar('Profile unavailable', 'Unable to load your saved profile.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> save() async {
    final uid = _uid;
    if (uid == null || isSaving.value) return;
    final age = int.tryParse(ageController.text.trim());
    if (age == null || age <= 0 || age > 120) {
      Get.snackbar('Check your age', 'Enter an age between 1 and 120.');
      return;
    }
    if (gender.value == null || examTarget.value == null) {
      Get.snackbar(
          'Complete your profile', 'Choose your gender and exam target.');
      return;
    }

    isSaving.value = true;
    try {
      await _firestore.collection('users').doc(uid).set({
        'displayName': displayNameController.text.trim(),
        'profile': {'age': age, 'gender': gender.value},
        'examTarget': examTarget.value,
      }, SetOptions(merge: true));
      Get.snackbar('Profile saved', 'Your training target is up to date.');
    } catch (_) {
      Get.snackbar('Save failed', 'Unable to save your profile. Please retry.');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    Get.offAllNamed(Routes.auth);
  }

  Future<void> setHydrationReminders(bool enabled) async {
    final applied = await hydration.setEnabled(enabled);
    if (enabled && !applied) {
      Get.snackbar('Notifications disabled',
          'Allow notifications to receive hydration reminders.');
    }
  }

  Future<void> loadFieldTestLogs() async {
    if (!kDebugMode || isLoadingFieldTestLogs.value) return;
    isLoadingFieldTestLogs.value = true;
    try {
      fieldTestLogs.assignAll(await _fieldTestLog.recentLogs());
    } catch (_) {
      Get.snackbar('Logs unavailable', 'Unable to read field-test logs.');
    } finally {
      isLoadingFieldTestLogs.value = false;
    }
  }

  Future<void> shareFieldTestLog(File file) async {
    if (!kDebugMode) return;
    try {
      await _fieldTestLog.share(file);
    } catch (_) {
      Get.snackbar('Share unavailable', 'Unable to share this field-test log.');
    }
  }

  @override
  void onClose() {
    _examSubscription?.cancel();
    displayNameController.dispose();
    ageController.dispose();
    super.onClose();
  }
}
