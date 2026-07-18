import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/training_plan.dart';
import '../../theme/app_theme.dart';
import 'training_plan_controller.dart';

class TrainingPlanView extends GetView<TrainingPlanController> {
  const TrainingPlanView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppThemeTokens>()!;
    return Scaffold(
      appBar: AppBar(title: const Text('YOUR TRAINING PLAN')),
      body: SafeArea(
        top: false,
        child: Obx(() {
          if (controller.isLoading.value) {
            return Center(child: CircularProgressIndicator(color: tokens.energyOrange));
          }
          if (controller.errorMessage.value != null) {
            return _PlanError(message: controller.errorMessage.value!);
          }
          final plan = controller.plan.value;
          if (plan == null) return const _PlanError(message: 'Your training plan is unavailable right now.');
          return _PlanContent(plan: plan, theme: theme, tokens: tokens);
        }),
      ),
    );
  }
}

class _PlanContent extends GetView<TrainingPlanController> {
  const _PlanContent({required this.plan, required this.theme, required this.tokens});
  final TrainingPlan plan;
  final ThemeData theme;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          Text('Your next seven days.', style: theme.textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text('A focused plan built from your target and recent runs.', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: controller.loadPlan,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Regenerate Plan'),
          ),
          const SizedBox(height: 24),
          ...plan.days.map((day) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _DayCard(day: day, theme: theme, tokens: tokens),
              )),
        ],
      );
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.theme, required this.tokens});
  final TrainingPlanDay day;
  final ThemeData theme;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(19),
        decoration: tokens.cardDecoration(),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tokens.energyOrange, borderRadius: BorderRadius.circular(16)),
            child: Text('D${day.day}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(day.focus, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(day.target,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: tokens.energyOrange,
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 7),
            Text(day.notes, style: theme.textTheme.bodyMedium),
          ])),
        ]),
      );
}

class _PlanError extends GetView<TrainingPlanController> {
  const _PlanError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_month_outlined, color: AppColors.slate, size: 48),
            const SizedBox(height: 17),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 19),
            if (controller.isRateLimited.value)
              const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.schedule_rounded, color: AppColors.slate),
                SizedBox(width: 8),
                Text('Retry is available tomorrow.'),
              ])
            else
              FilledButton.icon(
                onPressed: controller.isLoading.value ? null : controller.loadPlan,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
          ]),
        ),
      );
}
