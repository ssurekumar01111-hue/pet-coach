import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../data/models/ai_summary.dart';
import '../../data/models/recovery_summary.dart';
import '../../data/models/run_session.dart';
import 'session_summary_controller.dart';

class SessionSummaryView extends GetView<SessionSummaryController> {
  const SessionSummaryView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppThemeTokens>()!;
    return Scaffold(
      appBar: AppBar(title: const Text('RUN SUMMARY')),
      body: SafeArea(
        top: false,
        child: Obx(() {
          if (controller.isWaitingForConnection.value) {
            return _WaitingForConnectionState(
              session: controller.session.value,
              theme: theme,
              tokens: tokens,
            );
          }
          if (controller.isLoading.value) return _LoadingState(theme, tokens);
          final feedback = controller.summary.value;
          if (feedback != null) {
            return _SuccessState(
              controller: controller,
              summary: feedback,
              qualifiedDeterministic:
                  controller.qualifiedDeterministic.value,
              recoverySummary: controller.recoverySummary.value,
              actualTime: _formatDuration(
                Duration(seconds: controller.session.value?.totalTimeSec ?? 0),
              ),
              theme: theme,
              tokens: tokens,
            );
          }
          return _ErrorState(theme: theme, tokens: tokens);
        }),
      ),
    );
  }

  static String _formatDuration(Duration duration) =>
      '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _WaitingForConnectionState extends StatelessWidget {
  const _WaitingForConnectionState({
    required this.session,
    required this.theme,
    required this.tokens,
  });
  final RunSession? session;
  final ThemeData theme;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final distance = session?.totalDistanceKm ?? 0;
    final time = session?.totalTimeSec ?? 0;
    final pace = distance > 0 ? time / distance : 0.0;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: tokens.cardDecoration(),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_upload_outlined, size: 44, color: tokens.energyOrange),
            const SizedBox(height: 16),
            Text('SESSION SAVED LOCALLY', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Waiting for connection to analyze your run...',
                textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: _OfflineMetric('DISTANCE', '${distance.toStringAsFixed(2)} km')),
              Expanded(child: _OfflineMetric('TIME', SessionSummaryView._formatDuration(Duration(seconds: time)))),
              Expanded(child: _OfflineMetric('PACE', pace <= 0 ? '--:--' : '${pace ~/ 60}:${(pace % 60).round().toString().padLeft(2, '0')} /km')),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _OfflineMetric extends StatelessWidget {
  const _OfflineMetric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: AppColors.slate, fontSize: 10, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ]);
}

class _LoadingState extends StatelessWidget {
  const _LoadingState(this.theme, this.tokens);
  final ThemeData theme;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 42,
            height: 42,
            child: CircularProgressIndicator(color: tokens.energyOrange),
          ),
          const SizedBox(height: 20),
          Text('Analyzing your run...', style: theme.textTheme.titleLarge),
          const SizedBox(height: 7),
          Text('Your AI coach is reviewing the session.',
              style: theme.textTheme.bodyMedium),
        ]),
      );
}

class _ErrorState extends GetView<SessionSummaryController> {
  const _ErrorState({required this.theme, required this.tokens});
  final ThemeData theme;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: tokens.cardDecoration(),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.psychology_alt_outlined,
                  size: 42, color: tokens.slate),
              const SizedBox(height: 16),
              Text(
                controller.isRateLimited.value
                    ? 'DAILY AI LIMIT REACHED'
                    : 'COACH UNAVAILABLE',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                controller.errorMessage.value ??
                    'Your coach could not analyze this run just now.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 22),
              if (controller.isRateLimited.value)
                const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.schedule_rounded, color: AppColors.slate),
                  SizedBox(width: 8),
                  Text('Retry is available tomorrow.'),
                ])
              else
                FilledButton.icon(
                  onPressed: controller.canRetry.value ? controller.retry : null,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(controller.canRetry.value
                      ? 'Retry analysis'
                      : 'Please wait...'),
                ),
            ]),
          ),
        ),
      );
}

class _SuccessState extends StatelessWidget {
  const _SuccessState({
    required this.controller,
    required this.summary,
    required this.qualifiedDeterministic,
    required this.recoverySummary,
    required this.actualTime,
    required this.theme,
    required this.tokens,
  });
  final SessionSummaryController controller;
  final AiSummary summary;
  final bool? qualifiedDeterministic;
  final RecoverySummary? recoverySummary;
  final String actualTime;
  final ThemeData theme;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    // The banner is PET ground truth from server-side arithmetic, never the
    // model's conversational assessment.
    final qualifies = qualifiedDeterministic ?? false;
    final resultColor = qualifies ? tokens.energyOrange : tokens.slate;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: resultColor.withValues(alpha: .12),
            borderRadius: tokens.cardRadius,
            border: Border.all(color: resultColor.withValues(alpha: .3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(qualifies ? Icons.emoji_events_rounded : Icons.flag_rounded,
                size: 31, color: resultColor),
            const SizedBox(height: 15),
            Text(qualifies ? 'QUALIFIED' : 'NOT YET QUALIFIED',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: resultColor,
                  fontSize: qualifies ? 34 : 28,
                )),
            const SizedBox(height: 7),
            Text(qualifies
                ? 'You are on target for your PET standard.'
                : 'You have a clear next step to reach your standard.'),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _TimeCard('PREDICTED TIME', summary.predictedTime,
              Icons.auto_graph_rounded, tokens, theme)),
          const SizedBox(width: 14),
          Expanded(child: _TimeCard('YOUR SESSION', actualTime,
              Icons.timer_outlined, tokens, theme)),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: tokens.cardDecoration(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: tokens.energyOrange.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.psychology_alt_rounded,
                    color: tokens.energyOrange),
              ),
              const SizedBox(width: 11),
              Text('AI COACH', style: theme.textTheme.titleLarge),
            ]),
            const SizedBox(height: 17),
            Text(summary.feedback, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            Obx(
              () => OutlinedButton.icon(
                onPressed: controller.toggleFeedbackReadAloud,
                icon: Icon(controller.isFeedbackSpeaking.value
                    ? Icons.stop_circle_outlined
                    : Icons.volume_up_rounded),
                label: Text(controller.isFeedbackSpeaking.value
                    ? 'Stop reading'
                    : 'Read feedback aloud'),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        if (recoverySummary != null) ...[
          _RecoveryCard(summary: recoverySummary!, theme: theme, tokens: tokens),
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.nearBlack,
            borderRadius: tokens.cardRadius,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NEXT TARGET',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: .65),
                  letterSpacing: 1.1,
                )),
            const SizedBox(height: 9),
            Text(summary.nextTarget,
                style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
          ]),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: controller.session.value == null
              ? null
              : () => Get.toNamed(
                    Routes.paceOptimization,
                    arguments: controller.session.value!.id,
                  ),
          icon: const Icon(Icons.bar_chart_rounded),
          label: const Text('View Pace Analysis'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Get.toNamed(Routes.stretchingGuidance),
          icon: const Icon(Icons.self_improvement_rounded),
          label: const Text('Cool down'),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Get.offAllNamed(Routes.examSelection),
          child: const Text('Back to exams'),
        ),
      ]),
    );
  }
}

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({
    required this.summary,
    required this.theme,
    required this.tokens,
  });
  final RecoverySummary summary;
  final ThemeData theme;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: tokens.cardDecoration(),
        child: Row(children: [
          SizedBox(
            width: 74,
            height: 74,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                value: summary.score / 100,
                strokeWidth: 7,
                backgroundColor: tokens.slate.withValues(alpha: .14),
                color: tokens.energyOrange,
              ),
              Text('${summary.score}', style: theme.textTheme.titleLarge),
            ]),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('RECOVERY MONITOR', style: theme.textTheme.titleLarge),
              const SizedBox(height: 5),
              Text(summary.recommendation,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: tokens.energyOrange,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 5),
              Row(children: [
                Icon(Icons.info_outline_rounded, size: 14, color: tokens.slate),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('Based on your pace and running intensity',
                      style: theme.textTheme.bodyMedium),
                ),
              ]),
            ]),
          ),
        ]),
      );
}

class _TimeCard extends StatelessWidget {
  const _TimeCard(this.label, this.value, this.icon, this.tokens, this.theme);
  final String label;
  final String value;
  final IconData icon;
  final AppThemeTokens tokens;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: tokens.cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: tokens.energyOrange),
          const SizedBox(height: 15),
          Text(label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: 10,
                color: tokens.slate,
                letterSpacing: .8,
              )),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: theme.textTheme.titleLarge),
          ),
        ]),
      );
}
