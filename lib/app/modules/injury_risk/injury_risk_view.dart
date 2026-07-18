import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/injury_risk_assessment.dart';
import '../../theme/app_theme.dart';
import 'injury_risk_controller.dart';

class InjuryRiskView extends GetView<InjuryRiskController> {
  const InjuryRiskView({super.key});
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context); final tokens = theme.extension<AppThemeTokens>()!;
    return Scaffold(appBar: AppBar(title: const Text('TRAINING-LOAD CHECK')), body: SafeArea(top: false, child: Obx(() {
      if (controller.isLoading.value) return Center(child: CircularProgressIndicator(color: tokens.energyOrange));
      if (controller.isInsufficientData.value) return const _Message(icon: Icons.history_toggle_off_rounded, message: 'Complete a few more runs to unlock your training-load estimate.');
      if (controller.errorMessage.value != null) return _Error(message: controller.errorMessage.value!);
      final assessment = controller.assessment.value;
      if (assessment == null) return const _Message(icon: Icons.history_toggle_off_rounded, message: 'Complete a few more runs to unlock your training-load estimate.');
      return _Content(assessment: assessment, theme: theme, tokens: tokens);
    })));
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.assessment, required this.theme, required this.tokens});
  final InjuryRiskAssessment assessment; final ThemeData theme; final AppThemeTokens tokens;
  @override Widget build(BuildContext context) {
    final color = switch (assessment.riskLevel) { 'elevated' => Colors.red.shade700, 'moderate' => tokens.energyOrange, _ => Colors.green.shade700 };
    return ListView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 24), children: [
      Text('Training-load signal.', style: theme.textTheme.headlineLarge), const SizedBox(height: 8),
      Text('A cautious look at recent pace, recovery, and rest patterns.', style: theme.textTheme.bodyLarge), const SizedBox(height: 24),
      Container(padding: const EdgeInsets.all(21), decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: tokens.cardRadius, border: Border.all(color: color.withValues(alpha: .35))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.health_and_safety_outlined, color: color, size: 30), const SizedBox(height: 12),
        Text(assessment.riskLevel.toUpperCase(), style: theme.textTheme.headlineLarge?.copyWith(color: color)),
        const Text('TRAINING-LOAD RISK LEVEL', style: TextStyle(color: AppColors.slate, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
      ])), const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(20), decoration: tokens.cardDecoration(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PATTERN FACTORS', style: theme.textTheme.titleLarge), const SizedBox(height: 12),
        for (final factor in assessment.riskFactors) Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.circle, size: 8, color: tokens.energyOrange), const SizedBox(width: 9), Expanded(child: Text(factor, style: theme.textTheme.bodyMedium))])),
      ])), const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(20), decoration: tokens.cardDecoration(), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('RECOMMENDATION', style: theme.textTheme.titleLarge), const SizedBox(height: 10), Text(assessment.recommendation, style: theme.textTheme.bodyLarge)])), const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.nearBlack, borderRadius: tokens.cardRadius), child: Text("This is a training-pattern estimate, not a medical diagnosis. If you're experiencing pain or discomfort, consult a doctor or physiotherapist.", style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white))),
    ]);
  }
}

class _Message extends StatelessWidget { const _Message({required this.icon, required this.message}); final IconData icon; final String message; @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: AppColors.energyOrange, size: 46), const SizedBox(height: 16), Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge)]))); }
class _Error extends GetView<InjuryRiskController> {
  const _Error({required this.message});
  final String message;
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.cloud_off_rounded, color: AppColors.slate, size: 46), const SizedBox(height: 16),
    Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 18),
    if (controller.isRateLimited.value) const Text('Retry is available tomorrow.') else FilledButton.icon(onPressed: controller.loadAssessment, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
  ])));
}
