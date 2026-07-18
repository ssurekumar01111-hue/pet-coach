import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_theme.dart';
import 'profile_controller.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppThemeTokens>()!;
    return Scaffold(
      appBar: AppBar(title: const Text('YOUR PROFILE')),
      body: SafeArea(
        top: false,
        child: Obx(() {
          if (controller.isLoading.value) {
            return Center(
              child: CircularProgressIndicator(color: tokens.energyOrange),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Build your training plan.',
                      style: theme.textTheme.headlineLarge),
                  const SizedBox(height: 8),
                  Text(
                      'Keep these details current for a more relevant PET target.',
                      style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: tokens.energyOrange.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(children: [
                      Icon(Icons.cloud_done_rounded,
                          color: tokens.energyOrange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Synced — your data is stored securely in the cloud.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 26),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: tokens.cardDecoration(),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('VERIFIED PHONE NUMBER'),
                          const SizedBox(height: 8),
                          Row(children: [
                            Icon(Icons.phone_rounded,
                                color: tokens.energyOrange),
                            const SizedBox(width: 10),
                            Text(
                              controller.maskedPhoneNumber,
                              style: theme.textTheme.titleLarge,
                            ),
                          ]),
                          const SizedBox(height: 22),
                          const _FieldLabel('LEADERBOARD DISPLAY NAME'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: controller.displayNameController,
                            maxLength: 24,
                            decoration: const InputDecoration(
                              hintText: 'e.g. SpeedRunner',
                              helperText:
                                  'This name is visible on leaderboards.',
                            ),
                          ),
                          const SizedBox(height: 14),
                          const _FieldLabel('AGE'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: controller.ageController,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(hintText: 'Your age'),
                          ),
                          const SizedBox(height: 22),
                          const _FieldLabel('GENDER'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: controller.gender.value,
                            hint: const Text('Select gender'),
                            isExpanded: true,
                            items: ProfileController.genders
                                .map((value) => DropdownMenuItem(
                                    value: value, child: Text(value)))
                                .toList(),
                            onChanged: (value) =>
                                controller.gender.value = value,
                          ),
                          const SizedBox(height: 22),
                          const _FieldLabel('EXAM TARGET'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: controller.exams.any((exam) =>
                                    exam.id == controller.examTarget.value)
                                ? controller.examTarget.value
                                : null,
                            hint: const Text('Select exam target'),
                            isExpanded: true,
                            items: controller.exams
                                .map((exam) => DropdownMenuItem(
                                      value: exam.id,
                                      child: Text(exam.name),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                controller.examTarget.value = value,
                          ),
                        ]),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    decoration: tokens.cardDecoration(),
                    child: Obx(() => SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 6),
                          title: Text('Hydration reminders',
                              style: theme.textTheme.titleLarge),
                          subtitle: const Text(
                              'Every two hours from 7am to 9pm on this device.'),
                          value: controller.hydration.isEnabled.value,
                          activeTrackColor:
                              tokens.energyOrange.withValues(alpha: .45),
                          activeThumbColor: tokens.energyOrange,
                          onChanged: controller.setHydrationReminders,
                        )),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 22),
                    _fieldTestLogs(theme, tokens),
                  ],
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed:
                        controller.isSaving.value ? null : controller.save,
                    icon: controller.isSaving.value
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(controller.isSaving.value
                        ? 'Saving...'
                        : 'Save profile'),
                  ),
                  const SizedBox(height: 34),
                  OutlinedButton.icon(
                    onPressed: () => _confirmSignOut(context),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.slate,
                      side: BorderSide(
                          color: tokens.slate.withValues(alpha: .35)),
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ]),
          );
        }),
      ),
    );
  }

  Widget _fieldTestLogs(ThemeData theme, AppThemeTokens tokens) => Container(
        padding: const EdgeInsets.all(18),
        decoration: tokens.cardDecoration(),
        child: Obx(() {
          final logs = controller.fieldTestLogs;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bug_report_rounded, color: tokens.energyOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('FIELD-TEST LOGS',
                        style: theme.textTheme.titleLarge),
                  ),
                  IconButton(
                    tooltip: 'Refresh logs',
                    onPressed: controller.isLoadingFieldTestLogs.value
                        ? null
                        : controller.loadFieldTestLogs,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Debug builds only. Share diagnostics directly from this device.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              if (controller.isLoadingFieldTestLogs.value)
                const Center(
                    child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ))
              else if (logs.isEmpty)
                const Text('No completed field-test logs yet.')
              else
                ...logs.map(
                  (file) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(file.uri.pathSegments.last),
                    trailing: IconButton(
                      tooltip: 'Share log',
                      onPressed: () => controller.shareFieldTestLog(file),
                      icon: const Icon(Icons.ios_share_rounded),
                    ),
                  ),
                ),
            ],
          );
        }),
      );

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'You will need to sign in again to access your training data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay signed in'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await controller.signOut();
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          color: AppColors.slate,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      );
}
