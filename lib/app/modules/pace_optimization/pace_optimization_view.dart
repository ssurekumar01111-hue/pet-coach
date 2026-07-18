import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_theme.dart';
import 'pace_analyzer.dart';
import 'pace_optimization_controller.dart';

class PaceOptimizationView extends GetView<PaceOptimizationController> {
  const PaceOptimizationView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppThemeTokens>()!;
    return Scaffold(
      appBar: AppBar(title: const Text('PACE ANALYSIS')),
      body: SafeArea(
        top: false,
        child: Obx(() {
          if (controller.isLoading.value) {
            return Center(child: CircularProgressIndicator(color: tokens.energyOrange));
          }
          if (controller.errorMessage.value != null) {
            return _MessageState(message: controller.errorMessage.value!);
          }
          final analysis = controller.analysis.value;
          if (analysis == null || analysis.splits.isEmpty) {
            return const _MessageState(message: 'Complete at least one full kilometer with GPS tracking to see split analysis.');
          }
          return _AnalysisContent(analysis: analysis, theme: theme, tokens: tokens);
        }),
      ),
    );
  }
}

class _AnalysisContent extends StatelessWidget {
  const _AnalysisContent({required this.analysis, required this.theme, required this.tokens});
  final PaceAnalysis analysis;
  final ThemeData theme;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(21),
            decoration: BoxDecoration(color: AppColors.nearBlack, borderRadius: tokens.cardRadius),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PACING CONSISTENCY', style: _eyebrowStyle.copyWith(color: Colors.white.withValues(alpha: .65))),
              const SizedBox(height: 9),
              Text(analysis.consistencyNote,
                  style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, height: 1.25)),
            ]),
          ),
          const SizedBox(height: 18),
          _SplitChart(analysis: analysis, theme: theme, tokens: tokens),
          const SizedBox(height: 23),
          const Text('KILOMETER SPLITS', style: _eyebrowStyle),
          const SizedBox(height: 11),
          ...analysis.splits.map((split) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SplitCard(split: split, theme: theme, tokens: tokens),
              )),
        ],
      );

  static const _eyebrowStyle = TextStyle(
    color: AppColors.slate,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.1,
  );
}

class _SplitChart extends StatelessWidget {
  const _SplitChart({required this.analysis, required this.theme, required this.tokens});
  final PaceAnalysis analysis;
  final ThemeData theme;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final paces = analysis.splits.map((split) => split.paceSecPerKm).toList();
    final maxPace = [...paces, analysis.targetPaceSecPerKm].reduce((a, b) => a > b ? a : b) * 1.12;
    return Container(
      height: 260,
      padding: const EdgeInsets.fromLTRB(18, 18, 12, 10),
      decoration: tokens.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PACE PER KILOMETER', style: theme.textTheme.titleLarge),
        const SizedBox(height: 3),
        Text('Orange line = required exam pace', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 13),
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: maxPace,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              extraLinesData: ExtraLinesData(horizontalLines: [
                HorizontalLine(
                  y: analysis.targetPaceSecPerKm,
                  color: tokens.energyOrange,
                  strokeWidth: 2,
                  dashArray: [6, 4],
                ),
              ]),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, _) => Text(_formatPace(value),
                      style: const TextStyle(color: AppColors.slate, fontSize: 10)),
                )),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, _) {
                    final index = value.toInt();
                    if (index < 0 || index >= analysis.splits.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Text('KM ${analysis.splits[index].kilometer}',
                          style: const TextStyle(color: AppColors.slate, fontSize: 10)),
                    );
                  },
                )),
              ),
              barGroups: [
                for (var index = 0; index < analysis.splits.length; index++)
                  BarChartGroupData(x: index, barRods: [
                    BarChartRodData(
                      toY: analysis.splits[index].paceSecPerKm,
                      width: 22,
                      borderRadius: BorderRadius.circular(8),
                      color: _statusColor(analysis.splits[index].recommendation, tokens),
                    ),
                  ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  static Color _statusColor(String status, AppThemeTokens tokens) =>
      status == 'needs improvement' ? tokens.slate : tokens.energyOrange;
  static String _formatPace(double seconds) =>
      '${(seconds ~/ 60).toString()}:${(seconds % 60).round().toString().padLeft(2, '0')}';
}

class _SplitCard extends StatelessWidget {
  const _SplitCard({required this.split, required this.theme, required this.tokens});
  final PaceSplit split;
  final ThemeData theme;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final color = split.recommendation == 'needs improvement' ? tokens.slate : tokens.energyOrange;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: tokens.cardDecoration(),
      child: Row(children: [
        Container(
          width: 45,
          height: 45,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
          child: Text('${split.kilometer}', style: theme.textTheme.titleLarge?.copyWith(color: color)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('KILOMETER ${split.kilometer}', style: const TextStyle(color: AppColors.slate, fontSize: 10, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(_formatPace(split.paceSecPerKm), style: theme.textTheme.titleLarge),
        ])),
        Text(split.recommendation.toUpperCase(),
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  static String _formatPace(double seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).round().toString().padLeft(2, '0')} /km';
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.route_rounded, size: 46, color: AppColors.energyOrange),
            const SizedBox(height: 17),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          ]),
        ),
      );
}
