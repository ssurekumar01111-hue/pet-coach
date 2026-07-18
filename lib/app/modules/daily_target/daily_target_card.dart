import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/daily_target.dart';
import '../../theme/app_theme.dart';
import 'daily_target_controller.dart';

class DailyTargetCard extends GetView<DailyTargetController> {
  const DailyTargetCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppThemeTokens>()!;
    return Obx(() {
      if (controller.isLoading.value) {
        return Container(
          height: 124,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.nearBlack, borderRadius: tokens.cardRadius),
          child: Row(children: [
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: tokens.energyOrange)),
            const SizedBox(width: 15),
            const Expanded(child: Text('Preparing today\'s target...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
          ]),
        );
      }
      final target = controller.target.value;
      if (target == null) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: tokens.cardDecoration(),
          child: Row(children: [
            const Icon(Icons.today_outlined, color: AppColors.slate),
            const SizedBox(width: 12),
            Expanded(child: Text(controller.errorMessage.value ?? 'Today\'s target is unavailable.', style: theme.textTheme.bodyMedium)),
            if (controller.isRateLimited.value)
              const Icon(Icons.schedule_rounded, color: AppColors.slate)
            else
              IconButton(
                tooltip: 'Retry',
                onPressed: controller.isLoading.value ? null : controller.loadTarget,
                icon: const Icon(Icons.refresh_rounded),
              ),
          ]),
        );
      }
      return _TargetContent(target: target, theme: theme, tokens: tokens);
    });
  }
}

class _TargetContent extends StatelessWidget {
  const _TargetContent({required this.target, required this.theme, required this.tokens});
  final DailyTarget target;
  final ThemeData theme;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final presentation = switch (target.targetType) {
      'rest' => (label: 'RECOVERY DAY', icon: Icons.self_improvement_rounded, color: tokens.slate),
      'cross-train' => (label: 'CROSS-TRAIN', icon: Icons.directions_bike_rounded, color: tokens.slate),
      _ => (label: 'TODAY\'S RUN', icon: Icons.directions_run_rounded, color: tokens.energyOrange),
    };
    final date = DateTime.now();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.nearBlack, borderRadius: tokens.cardRadius),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: presentation.color, borderRadius: BorderRadius.circular(12)),
            child: Icon(presentation.icon, color: Colors.white),
          ),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TODAY · ${date.day}/${date.month}', style: _eyebrowStyle),
            const SizedBox(height: 2),
            Text(presentation.label, style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
          ])),
        ]),
        const SizedBox(height: 15),
        if (target.distanceKm != null)
          Text('${target.distanceKm!.toStringAsFixed(1)} km · ${target.paceGuidance}',
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800))
        else
          Text(target.paceGuidance, style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        Text(target.reasoning, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: .72))),
      ]),
    );
  }

  static const _eyebrowStyle = TextStyle(
    color: Color(0xB3FFFFFF),
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.1,
  );
}
