import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/eve_colors.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/character_avatar.dart';
import '../../../data/dashboard_providers.dart';
import '../../../../characters/data/character_providers.dart';
import '../../../../skills/data/skill_providers.dart';
import '../../../../../core/sde/sde_providers.dart';
import '../../../../../core/database/app_database.dart';
import '../dashboard_card.dart';

/// Dashboard card showing skill training timeline across all characters
/// as a Gantt chart visualization.
///
/// Displays:
/// - Timeline with time markers (Today, Tomorrow, This Week, Next Week)
/// - One row per character showing first 2-3 skills in their queue
/// - Horizontal bars representing skill training duration
/// - Character portrait on the left
/// - Active skills in different color from queued skills
class TrainingTimelineCard extends ConsumerWidget {
  const TrainingTimelineCard({super.key});

  /// Maximum number of skills to show per character.
  static const int maxSkillsPerCharacter = 3;

  /// Duration threshold for "active" skill highlighting.
  static const Duration activeThreshold = Duration(hours: 1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queuesAsync = ref.watch(allCharacterSkillQueuesProvider);

    return DashboardCard(
      title: 'TRAINING TIMELINE',
      icon: Icons.calendar_today_outlined,
      glowColor: EveColors.evePrimary,
      isLoading: queuesAsync.isLoading,
      errorMessage: queuesAsync.hasError
          ? 'Failed to load training timeline'
          : null,
      onRetry: () => ref.invalidate(allCharacterSkillQueuesProvider),
      child: queuesAsync.when(
        data: (queuesMap) => _buildContent(context, ref, queuesMap),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Map<int, List<SkillQueueEntry>> queuesMap,
  ) {
    // Filter to only characters with active training
    final activeQueues = queuesMap.entries
        .where((entry) =>
            entry.value.isNotEmpty &&
            entry.value.any((skill) => skill.finishDate != null))
        .toList();

    if (activeQueues.isEmpty) {
      return _buildEmptyState(context);
    }

    // Calculate timeline bounds
    final timelineData = _calculateTimelineBounds(activeQueues);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline header with time markers
        _buildTimelineHeader(context, timelineData),
        const SizedBox(height: 16),

        // Character training rows
        ...activeQueues.map((entry) {
          final characterId = entry.key;
          final queue = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildCharacterRow(
              context,
              ref,
              characterId,
              queue,
              timelineData,
            ),
          );
        }),
      ],
    );
  }

  /// Calculates the timeline bounds based on all skill queues.
  TimelineData _calculateTimelineBounds(
    List<MapEntry<int, List<SkillQueueEntry>>> queues,
  ) {
    final now = DateTime.now();
    DateTime? latestFinish;

    for (final entry in queues) {
      final queue = entry.value.take(maxSkillsPerCharacter);
      for (final skill in queue) {
        if (skill.finishDate != null) {
          if (latestFinish == null ||
              skill.finishDate!.isAfter(latestFinish)) {
            latestFinish = skill.finishDate;
          }
        }
      }
    }

    // Default to 7 days if no skills found
    final endTime = latestFinish ?? now.add(const Duration(days: 7));
    final totalDuration = endTime.difference(now);

    return TimelineData(
      startTime: now,
      endTime: endTime,
      totalDuration: totalDuration,
    );
  }

  /// Builds the timeline header with time markers.
  Widget _buildTimelineHeader(
    BuildContext context,
    TimelineData timeline,
  ) {
    final now = timeline.startTime;
    final tomorrow = now.add(const Duration(days: 1));
    final thisWeek = now.add(const Duration(days: 3));
    final nextWeek = now.add(const Duration(days: 7));

    return Padding(
      padding: const EdgeInsets.only(left: 48), // Account for avatar space
      child: SizedBox(
        height: 24,
        child: Stack(
          children: [
            // Current time marker (vertical line)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 2,
                color: EveColors.evePrimary,
              ),
            ),

            // Time labels
            Row(
              children: [
                Expanded(
                  child: _buildTimeMarker(context, 'Now', 0),
                ),
                if (tomorrow.isBefore(timeline.endTime))
                  Expanded(
                    child: _buildTimeMarker(
                      context,
                      'Tomorrow',
                      _calculatePosition(
                        now,
                        tomorrow,
                        timeline,
                      ),
                    ),
                  ),
                if (thisWeek.isBefore(timeline.endTime))
                  Expanded(
                    child: _buildTimeMarker(
                      context,
                      'This Week',
                      _calculatePosition(
                        now,
                        thisWeek,
                        timeline,
                      ),
                    ),
                  ),
                if (nextWeek.isBefore(timeline.endTime))
                  Expanded(
                    child: _buildTimeMarker(
                      context,
                      'Next Week',
                      _calculatePosition(
                        now,
                        nextWeek,
                        timeline,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeMarker(BuildContext context, String label, double position) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white.withAlpha(128),
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
    );
  }

  /// Builds a single character's training row.
  Widget _buildCharacterRow(
    BuildContext context,
    WidgetRef ref,
    int characterId,
    List<SkillQueueEntry> queue,
    TimelineData timeline,
  ) {
    final charactersAsync = ref.watch(allCharactersProvider);

    return charactersAsync.when(
      data: (characters) {
        final character = characters.firstWhere(
          (c) => c.characterId == characterId,
          orElse: () => throw StateError('Character not found'),
        );

        // Get first maxSkillsPerCharacter skills with finish dates
        final displaySkills = queue
            .where((skill) => skill.finishDate != null)
            .take(maxSkillsPerCharacter)
            .toList();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Character portrait
            CharacterAvatar(
              portraitUrl: character.portraitUrl,
              size: CharacterAvatarSize.small,
            ),
            const SizedBox(width: 8),

            // Timeline bars
            Expanded(
              child: _buildTimelineBars(
                context,
                ref,
                displaySkills,
                timeline,
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 32,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Builds the timeline bars for a character's skills.
  Widget _buildTimelineBars(
    BuildContext context,
    WidgetRef ref,
    List<SkillQueueEntry> skills,
    TimelineData timeline,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline track with bars
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: EveColors.darkSurfaceVariant.withAlpha(77),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              // Current time indicator line
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 1,
                  color: EveColors.evePrimary.withAlpha(128),
                ),
              ),

              // Skill bars
              ...skills.map((skill) {
                return _buildSkillBar(context, skill, timeline);
              }),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Skill labels
        _buildSkillLabels(context, ref, skills),
      ],
    );
  }

  /// Builds a single skill bar in the timeline.
  Widget _buildSkillBar(
    BuildContext context,
    SkillQueueEntry skill,
    TimelineData timeline,
  ) {
    final now = timeline.startTime;
    final startDate = skill.startDate ?? now;
    final finishDate = skill.finishDate!;

    // Calculate bar position and width
    final startPosition = _calculatePosition(now, startDate, timeline);
    final endPosition = _calculatePosition(now, finishDate, timeline);
    final width = endPosition - startPosition;

    // Determine if this is the active skill (training now)
    final isActive = startDate.isBefore(now) && finishDate.isAfter(now);

    return Positioned(
      left: startPosition,
      top: 4,
      bottom: 4,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: isActive ? EveColors.evePrimary : EveColors.info,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: isActive
                ? EveColors.evePrimary.withAlpha(204)
                : EveColors.info.withAlpha(204),
            width: 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: EveColors.evePrimary.withAlpha(102),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  /// Builds the skill name labels below the timeline.
  Widget _buildSkillLabels(
    BuildContext context,
    WidgetRef ref,
    List<SkillQueueEntry> skills,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: skills.map((skill) {
        final skillNameAsync = ref.watch(skillNameProvider(skill.skillId));

        return skillNameAsync.when(
          data: (skillName) {
            final romanNumerals = ['I', 'II', 'III', 'IV', 'V'];
            final levelStr =
                skill.finishedLevel >= 1 && skill.finishedLevel <= 5
                    ? romanNumerals[skill.finishedLevel - 1]
                    : '${skill.finishedLevel}';
            final fullName = '$skillName $levelStr';

            final now = DateTime.now();
            final isActive = (skill.startDate?.isBefore(now) ?? false) &&
                skill.finishDate!.isAfter(now);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? EveColors.evePrimary.withAlpha(51)
                    : EveColors.darkSurfaceVariant.withAlpha(128),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: isActive ? EveColors.evePrimary : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Text(
                fullName,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isActive
                          ? EveColors.evePrimary
                          : Colors.white.withAlpha(179),
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
          loading: () => Container(
            width: 80,
            height: 16,
            decoration: BoxDecoration(
              color: EveColors.darkSurfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          error: (_, __) => Text(
            'Skill #${skill.skillId}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withAlpha(128),
                  fontSize: 10,
                ),
          ),
        );
      }).toList(),
    );
  }

  /// Calculates the position in pixels of a timestamp in the timeline.
  ///
  /// Returns a value representing the horizontal position where 0 is the start
  /// and the maximum is constrained by the available width.
  double _calculatePosition(
    DateTime now,
    DateTime timestamp,
    TimelineData timeline,
  ) {
    if (timestamp.isBefore(now)) return 0.0;
    if (timestamp.isAfter(timeline.endTime)) return 300.0; // Approximate max width

    final elapsed = timestamp.difference(now);
    final ratio = elapsed.inMilliseconds / timeline.totalDuration.inMilliseconds;

    // Return position in pixels (0 to ~300px for typical card width)
    return ratio * 300.0;
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 48,
              color: Colors.white.withAlpha(77),
            ),
            const SizedBox(height: 12),
            Text(
              'No Training Timeline',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withAlpha(179),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'No characters have active skill training',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withAlpha(128),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Data class holding timeline calculation results.
class TimelineData {
  final DateTime startTime;
  final DateTime endTime;
  final Duration totalDuration;

  const TimelineData({
    required this.startTime,
    required this.endTime,
    required this.totalDuration,
  });
}
