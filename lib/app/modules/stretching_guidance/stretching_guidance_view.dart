import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_theme.dart';
import 'stretching_guidance_controller.dart';

class StretchingGuidanceView extends GetView<StretchingGuidanceController> {
  const StretchingGuidanceView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppThemeTokens>()!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('STRETCHING GUIDE'),
          bottom: const TabBar(tabs: [Tab(text: 'PRE-RUN'), Tab(text: 'POST-RUN')]),
        ),
        body: TabBarView(children: [
          _StretchList(timing: StretchTiming.preRun, theme: theme, tokens: tokens),
          _StretchList(timing: StretchTiming.postRun, theme: theme, tokens: tokens),
        ]),
      ),
    );
  }
}

class _StretchList extends GetView<StretchingGuidanceController> {
  const _StretchList({required this.timing, required this.theme, required this.tokens});
  final StretchTiming timing;
  final ThemeData theme;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final preRun = timing == StretchTiming.preRun;
    final stretches = controller.forTiming(timing);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      children: [
        Text(preRun ? 'Prime your run.' : 'Recover with care.', style: theme.textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(
          preRun
              ? 'Dynamic movement to warm up. Stay smooth and never force a range.'
              : 'Gentle holds after you finish. Breathe steadily and ease off if painful.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 22),
        for (final stretch in stretches) ...[
          _StretchCard(stretch: stretch, theme: theme, tokens: tokens),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _StretchCard extends GetView<StretchingGuidanceController> {
  const _StretchCard({required this.stretch, required this.theme, required this.tokens});
  final Stretch stretch;
  final ThemeData theme;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: tokens.cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(stretch.name, style: theme.textTheme.titleLarge)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: tokens.energyOrange.withValues(alpha: .12), borderRadius: BorderRadius.circular(18)),
              child: Text('${stretch.durationSeconds}s', style: TextStyle(color: tokens.energyOrange, fontWeight: FontWeight.w900)),
            ),
          ]),
          const SizedBox(height: 5),
          Text(stretch.targetMuscle.toUpperCase(), style: const TextStyle(color: AppColors.slate, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 10),
          Text(stretch.instructions, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 15),
          Obx(() {
            final active = controller.activeStretchName.value == stretch.name;
            return OutlinedButton.icon(
              onPressed: active ? controller.stopTimer : () => controller.startTimer(stretch),
              icon: Icon(active ? Icons.stop_circle_outlined : Icons.timer_outlined),
              label: Text(active ? '${controller.remainingSeconds.value}s remaining · Stop' : 'Start timer'),
            );
          }),
        ]),
      );
}
