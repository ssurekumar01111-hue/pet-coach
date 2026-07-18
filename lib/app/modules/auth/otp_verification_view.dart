import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../theme/app_theme.dart';
import 'auth_controller.dart';

class OtpVerificationView extends GetView<AuthController> {
  const OtpVerificationView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppThemeTokens>()!;
    return Scaffold(
      appBar: AppBar(title: const Text('VERIFY PHONE')),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Obx(() => Container(
                    padding: const EdgeInsets.all(22),
                    decoration: tokens.cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(Icons.verified_user_rounded,
                            color: tokens.energyOrange, size: 42),
                        const SizedBox(height: 16),
                        Text('Enter your OTP',
                            style: theme.textTheme.headlineLarge),
                        const SizedBox(height: 8),
                        Text(
                          'We sent a 6-digit code to ${controller.maskedPhoneNumber}.',
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: controller.otpController,
                          enabled: !controller.isLoading,
                          autofocus: true,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          maxLength: 6,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            letterSpacing: 10,
                            fontWeight: FontWeight.w900,
                          ),
                          decoration: const InputDecoration(
                            hintText: '000000',
                            counterText: '',
                          ),
                          onSubmitted: (_) => controller.verifyOtp(),
                        ),
                        if (controller.errorMessage.value != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            controller.errorMessage.value!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: controller.isLoading
                              ? null
                              : controller.verifyOtp,
                          icon: controller.isVerifyingCode.value
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(controller.isVerifyingCode.value
                              ? 'Verifying...'
                              : 'Verify and continue'),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: controller.canResend
                              ? controller.resendCode
                              : null,
                          child: Text(controller.canResend
                              ? 'Resend code'
                              : 'Resend in ${controller.resendSecondsRemaining.value}s'),
                        ),
                      ],
                    ),
                  )),
            ),
          ),
        ),
      ),
    );
  }
}
