import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/exam_config.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import 'tracker_controller.dart';

class TrackerView extends GetView<TrackerController> {
  const TrackerView({super.key});

  @override
  Widget build(BuildContext context) {
    final exam = Get.arguments as ExamConfig?;
    final theme = Theme.of(context);
    final tokens = theme.extension<AppThemeTokens>()!;
    return Scaffold(
      appBar: AppBar(
        title: Text(exam?.name ?? 'Live run'),
        centerTitle: false,
        actions: [
          Obx(
            () => IconButton(
              tooltip: controller.isVoiceEnabled.value
                  ? 'Mute voice coach'
                  : 'Unmute voice coach',
              onPressed: controller.toggleVoice,
              icon: Icon(controller.isVoiceEnabled.value
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Obx(
              () => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('ELAPSED TIME', style: _eyebrowStyle),
                    const SizedBox(height: 5),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _formatDuration(controller.elapsed.value),
                        style: theme.textTheme.displayLarge
                            ?.copyWith(fontSize: 68),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _metricsRow(theme, tokens),
                    const SizedBox(height: 18),
                    _movementState(tokens),
                    const SizedBox(height: 18),
                    _targetProgress(context, exam, tokens),
                    if (controller.errorMessage.value != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        controller.errorMessage.value!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _controls(context, tokens),
                  ],
                ),
              ),
            ),
            if (kDebugMode)
              Positioned(
                top: 10,
                right: 10,
                child: IgnorePointer(
                  child: Obx(() {
                    if (!controller.isTracking.value) {
                      return const SizedBox.shrink();
                    }
                    final battery = controller.debugBatteryPercent.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .72),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'DEBUG ${_formatDuration(controller.elapsed.value)}\n'
                        'Battery ${battery?.toString() ?? '--'}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _metricsRow(ThemeData theme, AppThemeTokens tokens) => Row(
        children: [
          Expanded(
            child: _metricCard(
              label: 'CURRENT PACE',
              value: _formatPace(controller.currentPaceSecPerKm.value),
              icon: Icons.speed_rounded,
              tokens: tokens,
              theme: theme,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _metricCard(
              label: 'DISTANCE',
              value: '${controller.distanceKm.value.toStringAsFixed(2)} km',
              icon: Icons.route_rounded,
              tokens: tokens,
              theme: theme,
            ),
          ),
        ],
      );

  Widget _metricCard({
    required String label,
    required String value,
    required IconData icon,
    required ThemeData theme,
    required AppThemeTokens tokens,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: tokens.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: tokens.energyOrange),
            const SizedBox(height: 15),
            Text(label, style: _eyebrowStyle.copyWith(fontSize: 10)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: theme.textTheme.titleLarge),
            ),
          ],
        ),
      );

  Widget _movementState(AppThemeTokens tokens) {
    final state = controller.movementState.value;
    final isRunning = state == 'running';
    final isStationary = state == 'stationary';
    final color = isRunning ? tokens.energyOrange : tokens.slate;
    final icon = isRunning
        ? Icons.directions_run_rounded
        : isStationary
            ? Icons.pause_circle_outline_rounded
            : Icons.directions_walk_rounded;
    final stateLabel = isRunning
        ? 'RUN'
        : isStationary
            ? 'STATIONARY'
            : 'WALK';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .34)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('MOVEMENT DETECTED',
                style: _eyebrowStyle.copyWith(color: color)),
            const SizedBox(height: 2),
            Text(stateLabel,
                style: TextStyle(
                    color: color, fontSize: 24, fontWeight: FontWeight.w900)),
          ]),
          const Spacer(),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: isRunning
                    ? [
                        BoxShadow(
                            color: color.withValues(alpha: .55),
                            blurRadius: 12,
                            spreadRadius: 2)
                      ]
                    : null),
          ),
        ],
      ),
    );
  }

  Widget _targetProgress(
      BuildContext context, ExamConfig? exam, AppThemeTokens tokens) {
    if (exam == null) {
      return _targetCard(tokens, 'TARGET', 'Select an exam to see progress', 0);
    }
    final distanceProgress =
        (controller.distanceKm.value / exam.distanceKm).clamp(0.0, 1.0);
    final allowedSeconds = (exam.timeLimitMin * 60).round();
    final secondsLeft = (allowedSeconds - controller.elapsed.value.inSeconds)
        .clamp(0, allowedSeconds);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: tokens.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('TARGET PROGRESS',
            style: _eyebrowStyle.copyWith(color: AppColors.nearBlack)),
        const SizedBox(height: 14),
        _progressLine(
          label: 'Distance',
          value:
              '${controller.distanceKm.value.toStringAsFixed(2)} / ${exam.distanceKm} km',
          progress: distanceProgress,
          color: tokens.energyOrange,
        ),
        const SizedBox(height: 15),
        _progressLine(
          label: 'Time remaining',
          value: _formatDuration(Duration(seconds: secondsLeft)),
          progress: (secondsLeft / allowedSeconds).clamp(0.0, 1.0),
          color: tokens.slate,
        ),
      ]),
    );
  }

  Widget _targetCard(
          AppThemeTokens tokens, String label, String value, double progress) =>
      Container(
        padding: const EdgeInsets.all(18),
        decoration: tokens.cardDecoration(),
        child: _progressLine(
            label: label,
            value: value,
            progress: progress,
            color: tokens.slate),
      );

  Widget _progressLine(
          {required String label,
          required String value,
          required double progress,
          required Color color}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(value,
                style: TextStyle(color: color, fontWeight: FontWeight.w800))
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: color.withValues(alpha: .14),
                valueColor: AlwaysStoppedAnimation(color)),
          ),
        ],
      );

  Widget _controls(BuildContext context, AppThemeTokens tokens) {
    if (!controller.isTracking.value) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextButton.icon(
          onPressed: () => Get.toNamed(Routes.stretchingGuidance),
          icon: const Icon(Icons.self_improvement_rounded),
          label: const Text('Warm up first?'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: controller.start,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start run'),
        ),
        if (kDebugMode) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: controller.isDemoSimulationRunning.value
                ? null
                : controller.startDemoSimulation,
            icon: const Icon(Icons.smart_display_outlined, size: 18),
            label: const Text('SIMULATE (DEMO ONLY)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: tokens.slate,
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
          ),
        ],
      ]);
    }
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed:
              controller.isPaused.value ? controller.start : controller.pause,
          icon: Icon(controller.isPaused.value
              ? Icons.play_arrow_rounded
              : Icons.pause_rounded),
          label: Text(controller.isPaused.value ? 'Resume' : 'Pause'),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: FilledButton.tonalIcon(
          onPressed: () => _confirmStop(context),
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Stop'),
          style: FilledButton.styleFrom(foregroundColor: tokens.energyOrange),
        ),
      ),
    ]);
  }

  Future<void> _confirmStop(BuildContext context) async {
    final shouldStop = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End this run?'),
        content:
            const Text('Your session will be saved and tracking will stop.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep running')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('End run')),
        ],
      ),
    );
    if (shouldStop ?? false) {
      await controller.stop();
      if (context.mounted) {
        Get.toNamed(
          Routes.sessionSummary,
          arguments: controller.completedSession.value,
        );
      }
    }
  }

  static const _eyebrowStyle = TextStyle(
    color: AppColors.slate,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.1,
  );

  String _formatDuration(Duration value) =>
      '${value.inMinutes.toString().padLeft(2, '0')}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';

  String _formatPace(double secondsPerKm) {
    if (secondsPerKm <= 0) return '--:-- /km';
    return '${(secondsPerKm ~/ 60).toString().padLeft(2, '0')}:${(secondsPerKm % 60).round().toString().padLeft(2, '0')} /km';
  }
}
