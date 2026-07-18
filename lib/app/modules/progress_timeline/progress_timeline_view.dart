import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import 'progress_timeline_controller.dart';

class ProgressTimelineView extends GetView<ProgressTimelineController> {
  const ProgressTimelineView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppThemeTokens>()!;
    return Scaffold(
      appBar: AppBar(title: const Text('YOUR PROGRESS')),
      body: SafeArea(
        top: false,
        child: Obx(() {
          if (controller.isLoading.value) {
            return Center(child: CircularProgressIndicator(color: tokens.energyOrange));
          }
          if (controller.errorMessage.value != null) {
            return _MessageState(message: controller.errorMessage.value!, icon: Icons.cloud_off_rounded);
          }
          if (controller.sessions.isEmpty) return const _EmptyState();
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            children: [
              Text('Progress, run by run.', style: theme.textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text('Your recent pace and PET readiness in one place.', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 22),
              _PaceChart(theme: theme, tokens: tokens),
              const SizedBox(height: 16),
              _QualificationRate(theme: theme, tokens: tokens),
              const SizedBox(height: 26),
              const Text('SESSION TIMELINE', style: _eyebrowStyle),
              const SizedBox(height: 12),
              ...controller.sessions.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _SessionCard(item: item, theme: theme, tokens: tokens),
                  )),
            ],
          );
        }),
      ),
    );
  }

  static const _eyebrowStyle = TextStyle(
    color: AppColors.slate,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.1,
  );
}

class _PaceChart extends GetView<ProgressTimelineController> {
  const _PaceChart({required this.theme, required this.tokens});
  final ThemeData theme;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final items = controller.chartSessions;
    if (items.isEmpty) return const SizedBox.shrink();
    final paces = items.map((item) => item.paceSecPerKm!).toList();
    final low = paces.reduce((a, b) => a < b ? a : b);
    final high = paces.reduce((a, b) => a > b ? a : b);
    final padding = high == low ? 30.0 : (high - low) * .2;
    return Container(
      height: 224,
      padding: const EdgeInsets.fromLTRB(18, 18, 12, 12),
      decoration: tokens.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PACE TREND', style: theme.textTheme.titleLarge),
        const SizedBox(height: 2),
        Text('Recent sessions · faster is lower', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        Expanded(
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: items.length == 1 ? 1 : (items.length - 1).toDouble(),
              minY: (low - padding).clamp(0, double.infinity),
              maxY: high + padding,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 43,
                    interval: high == low ? 15 : null,
                    getTitlesWidget: (value, _) => Text(
                      _formatPace(value),
                      style: const TextStyle(color: AppColors.slate, fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (value, _) {
                      final index = value.round();
                      if (index < 0 || index >= items.length || (items.length > 4 && index.isOdd)) {
                        return const SizedBox.shrink();
                      }
                      final date = items[index].session.startTime;
                      return Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text('${date.day}/${date.month}',
                            style: const TextStyle(color: AppColors.slate, fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var index = 0; index < paces.length; index++)
                      FlSpot(index.toDouble(), paces[index]),
                  ],
                  isCurved: true,
                  color: tokens.energyOrange,
                  barWidth: 3,
                  belowBarData: BarAreaData(show: true, color: tokens.energyOrange.withValues(alpha: .09)),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 4,
                      color: tokens.energyOrange,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  static String _formatPace(double seconds) =>
      '${(seconds ~/ 60).toString()}:${(seconds % 60).round().toString().padLeft(2, '0')}';
}

class _QualificationRate extends GetView<ProgressTimelineController> {
  const _QualificationRate({required this.theme, required this.tokens});
  final ThemeData theme;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final percentage = (controller.qualificationRate * 100).round();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.nearBlack, borderRadius: tokens.cardRadius),
      child: Row(children: [
        Text('$percentage%', style: theme.textTheme.headlineLarge?.copyWith(color: Colors.white)),
        const SizedBox(width: 16),
        Expanded(
          child: Text('qualification rate across your latest reviewed runs',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: .72))),
        ),
      ]),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.item, required this.theme, required this.tokens});
  final TimelineSession item;
  final ThemeData theme;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final qualifies = item.qualifies;
    final badgeColor = qualifies == true ? tokens.energyOrange : tokens.slate;
    final date = item.session.startTime;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: tokens.cardDecoration(),
        child: InkWell(
          borderRadius: tokens.cardRadius,
          onTap: () => Get.toNamed(Routes.paceOptimization, arguments: item.session.id),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(item.examName, style: theme.textTheme.titleLarge)),
          if (qualifies != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: badgeColor.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
              child: Text(qualifies ? 'QUALIFIED' : 'NOT YET',
                  style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w900)),
            )
          else
            const Text('PENDING', style: TextStyle(color: AppColors.slate, fontSize: 10, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 5),
        Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
            style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        Row(children: [
          _Metric('DISTANCE', '${item.session.totalDistanceKm.toStringAsFixed(2)} km'),
          _Metric('TIME', _formatDuration(item.session.totalTimeSec)),
          _Metric('PACE', item.paceSecPerKm == null ? '--:--' : _formatPace(item.paceSecPerKm!)),
        ]),
            ]),
          ),
        ),
      ),
    );
  }

  static String _formatDuration(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  static String _formatPace(double seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).round().toString().padLeft(2, '0')} /km';
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: AppColors.slate, fontSize: 10, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const _MessageState(
        icon: Icons.directions_run_rounded,
        message: 'Complete your first run to see progress here.',
      );
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.message, required this.icon});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: AppColors.energyOrange, size: 44),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          ]),
        ),
      );
}
