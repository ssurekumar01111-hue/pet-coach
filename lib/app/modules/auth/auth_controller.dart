import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';

class AuthController extends GetxController {
  AuthController({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  static const _resendCooldown = Duration(seconds: 30);

  final FirebaseAuth _auth;
  final phoneNumberController = TextEditingController();
  final otpController = TextEditingController();
  final isSendingCode = false.obs;
  final isVerifyingCode = false.obs;
  final resendSecondsRemaining = 0.obs;
  final errorMessage = RxnString();

  String? _verificationId;
  int? _resendToken;
  Timer? _resendTimer;
  String? _phoneNumber;

  bool get isLoading => isSendingCode.value || isVerifyingCode.value;
  bool get canResend =>
      !isSendingCode.value && resendSecondsRemaining.value == 0;
  String get maskedPhoneNumber => _maskPhone(_phoneNumber ?? '');

  /// Starts Firebase Phone Auth. Firebase treats configured test numbers just
  /// like live numbers here; the fixed OTP is validated server-side.
  Future<void> verifyPhoneNumber({bool forceResend = false}) async {
    if (isSendingCode.value) return;
    final phone = _normalisedIndianPhoneNumber();
    if (phone == null) {
      errorMessage.value = 'Enter a valid 10-digit Indian mobile number.';
      return;
    }

    errorMessage.value = null;
    isSendingCode.value = true;
    _phoneNumber = phone;
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: forceResend ? _resendToken : null,
        verificationCompleted: (credential) async {
          await _completeSignIn(credential);
        },
        verificationFailed: (exception) {
          isSendingCode.value = false;
          errorMessage.value = _friendlyError(exception);
        },
        codeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          isSendingCode.value = false;
          _startResendCooldown();
          if (Get.currentRoute != Routes.otpVerification) {
            Get.toNamed(Routes.otpVerification);
          }
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId ??= verificationId;
          isSendingCode.value = false;
        },
      );
    } on FirebaseAuthException catch (exception) {
      isSendingCode.value = false;
      errorMessage.value = _friendlyError(exception);
    } catch (_) {
      isSendingCode.value = false;
      errorMessage.value =
          'Unable to send an OTP. Check your connection and retry.';
    }
  }

  Future<void> verifyOtp() async {
    if (isVerifyingCode.value) return;
    final verificationId = _verificationId;
    final code = otpController.text.trim();
    if (verificationId == null) {
      errorMessage.value = 'Request a new OTP before verifying.';
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      errorMessage.value = 'Enter the 6-digit code sent to your phone.';
      return;
    }

    errorMessage.value = null;
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );
      await _completeSignIn(credential);
    } on FirebaseAuthException catch (exception) {
      isVerifyingCode.value = false;
      errorMessage.value = _friendlyError(exception);
    } catch (_) {
      isVerifyingCode.value = false;
      errorMessage.value = 'Unable to verify this code. Please try again.';
    }
  }

  Future<void> resendCode() async {
    if (!canResend) return;
    otpController.clear();
    await verifyPhoneNumber(forceResend: true);
  }

  Future<void> _completeSignIn(PhoneAuthCredential credential) async {
    if (isVerifyingCode.value) return;
    isSendingCode.value = false;
    isVerifyingCode.value = true;
    try {
      await _auth.signInWithCredential(credential);
      Get.offAllNamed(Routes.examSelection);
    } on FirebaseAuthException catch (exception) {
      errorMessage.value = _friendlyError(exception);
    } catch (_) {
      errorMessage.value = 'Sign-in could not be completed. Please retry.';
    } finally {
      isVerifyingCode.value = false;
    }
  }

  String? _normalisedIndianPhoneNumber() {
    final digits = phoneNumberController.text.replaceAll(RegExp(r'\D'), '');
    final localNumber = digits.startsWith('91') && digits.length == 12
        ? digits.substring(2)
        : digits;
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(localNumber)) return null;
    return '+91$localNumber';
  }

  String _maskPhone(String phone) {
    if (phone.length < 5) return 'Your verified phone number';
    final prefix = phone.startsWith('+91') ? '+91' : phone.substring(0, 3);
    return '$prefix XXXXX${phone.substring(phone.length - 5)}';
  }

  String _friendlyError(FirebaseAuthException exception) {
    switch (exception.code) {
      case 'invalid-phone-number':
        return 'Enter a valid phone number.';
      case 'invalid-verification-code':
        return 'That OTP is invalid. Please check the code and retry.';
      case 'session-expired':
        return 'This OTP has expired. Request a new code.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait before requesting another OTP.';
      default:
        return exception.message ?? 'Phone verification failed. Please retry.';
    }
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    resendSecondsRemaining.value = _resendCooldown.inSeconds;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = resendSecondsRemaining.value - 1;
      resendSecondsRemaining.value =
          remaining.clamp(0, _resendCooldown.inSeconds).toInt();
      if (remaining <= 0) timer.cancel();
    });
  }

  @override
  void onClose() {
    _resendTimer?.cancel();
    phoneNumberController.dispose();
    otpController.dispose();
    super.onClose();
  }
}
