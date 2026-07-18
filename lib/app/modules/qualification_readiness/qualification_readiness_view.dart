import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/qualification_readiness.dart';
import '../../theme/app_theme.dart';
import 'qualification_readiness_controller.dart';

class QualificationReadinessView extends GetView<QualificationReadinessController> {
  const QualificationReadinessView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppThemeTokens>()!;
    return Scaffold(
      appBar: AppBar(title: const Text('QUALIFICATION READINESS')),
      body: SafeArea(
        top: false,
        child: Obx(() {
          if (controller.isLoading.value) {
            return Center(child: CircularProgressIndicator(color: tokens.energyOrange));
          }
          if (controller.isInsufficientData.value) return const _InsufficientData();
          if (controller.errorMessage.value != null) {
            return _ErrorState(message: controller.errorMessage.value!);
          }
          final readiness = controller.readiness.value;
          if (readiness == null) return const _InsufficientData();
          return _ReadinessContent(readiness: readiness, theme: theme, tokens: tokens);
        }),
      ),
    );
  }
}

class _ReadinessContent extends StatelessWidget {
  const _ReadinessContent({
    required this.readiness,
    required this.theme,
    required this.tokens,
  });
  final QualificationReadiness readiness;
  final ThemeData theme;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final trend = _trendPresentation(readiness.trend, tokens);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Are you on track?', style: theme.textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text('A trend-based estimate from your recent training runs.',
            style: theme.textTheme.bodyLarge),
        const SizedBox(height: 27),
        Center(
          child: SizedBox(
            width: 196,
            height: 196,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 196,
                height: 196,
                child: CircularProgressIndicator(
                  value: readiness.readinessPercent / 100,
                  strokeWidth: 15,
                  backgroundColor: tokens.energyOrange.withValues(alpha: .12),
                  color: tokens.energyOrange,
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${readiness.readinessPercent}%',
                    style: theme.textTheme.displayLarge?.copyWith(fontSize: 53)),
                const Text('READINESS', style: _eyebrowStyle),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: tokens.cardDecoration(),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: trend.color.withValues(alpha: .12), shape: BoxShape.circle),
              child: Icon(trend.icon, color: trend.color),
            ),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('TREND', style: _eyebrowStyle),
              const SizedBox(height: 3),
              Text(trend.label, style: theme.textTheme.titleLarge?.copyWith(color: trend.color)),
            ])),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(21),
          decoration: BoxDecoration(color: AppColors.nearBlack, borderRadius: tokens.cardRadius),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PREDICTED QUALIFICATION',
                style: _eyebrowStyle.copyWith(color: Colors.white.withValues(alpha: .65))),
            const SizedBox(height: 9),
            Text(readiness.predictedQualificationDate,
                style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(21),
          decoration: tokens.cardDecoration(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.insights_rounded, color: tokens.energyOrange),
              const SizedBox(width: 9),
              Text('READINESS INSIGHT', style: theme.textTheme.titleLarge),
            ]),
            const SizedBox(height: 15),
            Text(readiness.summary, style: theme.textTheme.bodyLarge),
          ]),
        ),
      ]),
    );
  }

  _TrendPresentation _trendPresentation(String trend, AppThemeTokens tokens) => switch (trend) {
        'improving' => _TrendPresentation('IMPROVING', Icons.trending_up_rounded, tokens.energyOrange),
        'declining' => _TrendPresentation('DECLINING', Icons.trending_down_rounded, tokens.slate),
        _ => _TrendPresentation('STEADY', Icons.trending_flat_rounded, tokens.slate),
      };

  static const _eyebrowStyle = TextStyle(
    color: AppColors.slate,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.1,
  );
}

class _TrendPresentation {
  const _TrendPresentation(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class _InsufficientData extends StatelessWidget {
  const _InsufficientData();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.directions_run_rounded, color: AppColors.energyOrange, size: 48),
            const SizedBox(height: 18),
            Text('Complete a few more runs to unlock your readiness prediction.',
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          ]),
        ),
      );
}

class _ErrorState extends GetView<QualificationReadinessController> {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.slate, size: 44),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            if (controller.isRateLimited.value)
              const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.schedule_rounded, color: AppColors.slate),
                SizedBox(width: 8),
                Text('Retry is available tomorrow.'),
              ])
            else
              FilledButton.icon(
                onPressed: controller.isLoading.value ? null : controller.loadReadiness,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
          ]),
        ),
      );
}
