import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';

class AuthController extends GetxController {
  AuthController({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;
  final isLoading = false.obs;
  User? get user => _auth.currentUser;

  Future<void> signInAnonymously() async {
    isLoading.value = true;
    try {
      await _auth.signInAnonymously();
      Get.offAllNamed(Routes.examSelection);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    isLoading.value = true;
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      Get.offAllNamed(Routes.examSelection);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> registerWithEmail(String email, String password) async {
    isLoading.value = true;
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      Get.offAllNamed(Routes.examSelection);
    } finally {
      isLoading.value = false;
    }
  }
}
