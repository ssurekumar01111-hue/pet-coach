import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/leaderboard_entry.dart';
import '../../theme/app_theme.dart';
import 'leaderboard_controller.dart';

class LeaderboardView extends GetView<LeaderboardController> {
  const LeaderboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<AppThemeTokens>()!;
    return Scaffold(
      appBar: AppBar(title: const Text('LEADERBOARDS')),
      body: SafeArea(
        top: false,
        child: Obx(() {
          if (controller.exams.isEmpty && controller.isLoading.value) {
            return Center(child: CircularProgressIndicator(color: tokens.energyOrange));
          }
          if (controller.errorMessage.value != null) {
            return _MessageState(
              icon: Icons.cloud_off_rounded,
              message: controller.errorMessage.value!,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            children: [
              Text('Train. Qualify. Rise.', style: theme.textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text('Best qualifying times, by exam target.', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 22),
              DropdownButtonFormField<String>(
                initialValue: controller.selectedExamId.value,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Exam leaderboard'),
                items: controller.exams
                    .map((exam) => DropdownMenuItem(value: exam.id, child: Text(exam.name)))
                    .toList(),
                onChanged: controller.selectExam,
              ),
              const SizedBox(height: 22),
              if (controller.isLoading.value)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator(color: tokens.energyOrange)),
                )
              else if (controller.entries.isEmpty)
                const _MessageState(
                  icon: Icons.emoji_events_outlined,
                  message: 'No qualifying times yet. Be the first to set the pace.',
                )
              else ...[
                const Text('TOP QUALIFIERS', style: _eyebrowStyle),
                const SizedBox(height: 12),
                for (var index = 0; index < controller.entries.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RankCard(
                      entry: controller.entries[index],
                      rank: index + 1,
                      isCurrentUser: controller.entries[index].uid == controller.currentUid,
                      theme: theme,
                      tokens: tokens,
                    ),
                  ),
              ],
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

class _RankCard extends StatelessWidget {
  const _RankCard({
    required this.entry,
    required this.rank,
    required this.isCurrentUser,
    required this.theme,
    required this.tokens,
  });

  final LeaderboardEntry entry;
  final int rank;
  final bool isCurrentUser;
  final ThemeData theme;
  final AppThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final medal = switch (rank) {
      1 => (icon: Icons.emoji_events_rounded, color: tokens.energyOrange),
      2 => (icon: Icons.military_tech_rounded, color: AppColors.slate),
      3 => (icon: Icons.workspace_premium_rounded, color: const Color(0xFF9A6B3F)),
      _ => (icon: Icons.tag_rounded, color: AppColors.slate),
    };
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: isCurrentUser ? tokens.energyOrange.withValues(alpha: .10) : AppColors.offWhite,
        borderRadius: tokens.cardRadius,
        border: isCurrentUser ? Border.all(color: tokens.energyOrange) : null,
      ),
      child: Row(children: [
        SizedBox(
          width: 38,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(medal.icon, color: medal.color),
            const SizedBox(height: 2),
            Text('#$rank', style: const TextStyle(fontWeight: FontWeight.w900)),
          ]),
        ),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            isCurrentUser ? '${entry.displayName} (You)' : entry.displayName,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text('${entry.bestDistanceKm.toStringAsFixed(1)} km qualifying run',
              style: theme.textTheme.bodyMedium),
        ])),
        Text(_formatDuration(entry.bestTimeSec), style: theme.textTheme.titleLarge),
      ]),
    );
  }

  static String _formatDuration(int seconds) =>
      '${(seconds ~/ 60).toString()}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 52),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: AppColors.energyOrange, size: 46),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
          ]),
        ),
      );
}
