import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../theme/app_theme.dart';
import 'auth_controller.dart';

class AuthView extends GetView<AuthController> {
  const AuthView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppThemeTokens>()!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Obx(() => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.bolt_rounded,
                          color: tokens.energyOrange, size: 48),
                      const SizedBox(height: 22),
                      Text('PET COACH', style: theme.textTheme.displaySmall),
                      const SizedBox(height: 8),
                      Text(
                        'Train with purpose. Sign in with your phone to keep every run synced.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 30),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: tokens.cardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('YOUR MOBILE NUMBER', style: _labelStyle),
                            const SizedBox(height: 10),
                            TextField(
                              controller: controller.phoneNumberController,
                              enabled: !controller.isLoading,
                              autofocus: true,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              maxLength: 10,
                              decoration: const InputDecoration(
                                prefixText: '+91  ',
                                hintText: '10-digit mobile number',
                                counterText: '',
                              ),
                              onSubmitted: (_) =>
                                  controller.verifyPhoneNumber(),
                            ),
                            if (controller.errorMessage.value != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                controller.errorMessage.value!,
                                style:
                                    TextStyle(color: theme.colorScheme.error),
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: controller.isLoading
                                  ? null
                                  : controller.verifyPhoneNumber,
                              icon: controller.isSendingCode.value
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.sms_rounded),
                              label: Text(controller.isSendingCode.value
                                  ? 'Sending code...'
                                  : 'Send OTP'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'We use Firebase Phone Authentication to verify this number.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  )),
            ),
          ),
        ),
      ),
    );
  }

  static const _labelStyle = TextStyle(
    color: AppColors.slate,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.1,
  );
}
