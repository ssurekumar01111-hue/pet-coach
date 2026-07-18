import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/exam_config.dart';
import '../../routes/app_routes.dart';
import '../../services/offline_session_sync_service.dart';
import '../../theme/app_theme.dart';
import '../daily_target/daily_target_card.dart';
import 'exam_selection_controller.dart';

class ExamSelectionView extends GetView<ExamSelectionController> {
  const ExamSelectionView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppThemeTokens>()!;
    final offlineSync = Get.find<OfflineSessionSyncService>();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt_rounded,
                      color: AppColors.energyOrange, size: 30),
                  const SizedBox(width: 8),
                  const Text('PET COACH',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, letterSpacing: .8)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Profile',
                    onPressed: () => Get.toNamed(Routes.profile),
                    icon: const CircleAvatar(
                      backgroundColor: AppColors.nearBlack,
                      child: Icon(Icons.person_outline, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Obx(() {
                final count = offlineSync.pendingCount.value;
                if (count == 0) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: tokens.slate.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    const Icon(Icons.cloud_upload_outlined, color: AppColors.slate),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$count session${count == 1 ? '' : 's'} pending sync',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ]),
                );
              }),
              const DailyTargetCard(),
              const SizedBox(height: 18),
              const Text('EXPLORE', style: _eyebrowStyle),
              const SizedBox(height: 10),
              _featureGrid(tokens),
              const SizedBox(height: 26),
              Text('What are we\ntraining for?',
                  style: theme.textTheme.headlineLarge),
              const SizedBox(height: 12),
              Text('Choose an exam and let’s set your pace.',
                  style: theme.textTheme.bodyLarge),
              const SizedBox(height: 18),
              TextField(
                controller: controller.searchController,
                onChanged: (value) => controller.searchQuery.value = value,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search exams',
                ),
              ),
              const SizedBox(height: 16),
              Obx(() {
                if (controller.isLoading.value) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final groups = controller.groupedFilteredExams;
                if (groups.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('No exams match your search.')),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in groups.entries) ...[
                      Text(entry.key, style: _eyebrowStyle),
                      const SizedBox(height: 10),
                      for (final exam in entry.value) ...[
                        _examCard(context, exam, tokens),
                        const SizedBox(height: 14),
                      ],
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              }),
              const SizedBox(height: 10),
              const Text(
                'YOUR NEXT RUN STARTS HERE',
                style: TextStyle(
                    color: AppColors.slate,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _examCard(
          BuildContext context, ExamConfig exam, AppThemeTokens tokens) =>
      Material(
        color: Colors.transparent,
        child: Ink(
          decoration: tokens.cardDecoration(),
          child: InkWell(
            borderRadius: tokens.cardRadius,
            onTap: () => controller.selectExam(exam),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: tokens.energyOrange,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.directions_run_rounded,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exam.name,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 5),
                        Text(
                            '${exam.distanceKm} km  ·  ${exam.timeLimitMin} min limit'),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_circle_right_rounded,
                      color: AppColors.nearBlack, size: 30),
                  ]),
                  if (exam.approximate) ...[
                    const SizedBox(height: 13),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: tokens.slate.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(children: [
                        Icon(Icons.info_outline_rounded, size: 15, color: AppColors.slate),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Standards may vary by post — verify with official notification',
                            style: TextStyle(color: AppColors.slate, fontSize: 11),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

  Widget _featureGrid(AppThemeTokens tokens) => LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FeatureLink(
                width: cardWidth,
                icon: Icons.insights_rounded,
                label: 'Progress',
                onTap: () => Get.toNamed(Routes.progressTimeline),
                tokens: tokens,
              ),
              _FeatureLink(
                width: cardWidth,
                icon: Icons.calendar_month_rounded,
                label: 'Training plan',
                onTap: () => Get.toNamed(Routes.trainingPlan),
                tokens: tokens,
              ),
              _FeatureLink(
                width: cardWidth,
                icon: Icons.verified_rounded,
                label: 'Readiness',
                onTap: () => Get.toNamed(Routes.qualificationReadiness),
                tokens: tokens,
              ),
              _FeatureLink(
                width: cardWidth,
                icon: Icons.emoji_events_rounded,
                label: 'Leaderboard',
                onTap: () => Get.toNamed(Routes.leaderboard),
                tokens: tokens,
              ),
              _FeatureLink(
                width: cardWidth,
                icon: Icons.self_improvement_rounded,
                label: 'Stretching',
                onTap: () => Get.toNamed(Routes.stretchingGuidance),
                tokens: tokens,
              ),
              _FeatureLink(
                width: cardWidth,
                icon: Icons.health_and_safety_outlined,
                label: 'Load check',
                onTap: () => Get.toNamed(Routes.injuryRisk),
                tokens: tokens,
              ),
            ],
          );
        },
      );

  static const _eyebrowStyle = TextStyle(
    color: AppColors.slate,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.1,
  );
}

class _FeatureLink extends StatelessWidget {
  const _FeatureLink({
    required this.width,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.tokens,
  });
  final double width;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: 58,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: tokens.cardDecoration(),
            child: InkWell(
              borderRadius: tokens.cardRadius,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  Icon(icon, color: tokens.energyOrange),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}
