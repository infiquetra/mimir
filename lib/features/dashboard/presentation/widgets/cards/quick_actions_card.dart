import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/theme/eve_colors.dart';
import '../../../../characters/data/character_providers.dart';
import '../../../../characters/data/character_repository.dart';
import '../../../../skills/data/skill_repository.dart';
import '../../../../wallet/data/wallet_repository.dart';
import '../../../data/dashboard_providers.dart';
import '../dashboard_card.dart';

/// Dashboard card providing quick actions and alert notifications.
///
/// Features:
/// - Refresh All: Triggers data refresh for all characters
/// - Copy Fleet Status: Copies formatted fleet status to clipboard
/// - Alerts: Displays warnings for empty skill queues and other notifications
class QuickActionsCard extends ConsumerStatefulWidget {
  const QuickActionsCard({super.key});

  @override
  ConsumerState<QuickActionsCard> createState() => _QuickActionsCardState();
}

class _QuickActionsCardState extends ConsumerState<QuickActionsCard> {
  bool _isRefreshing = false;

  /// Refreshes data for all characters.
  Future<void> _refreshAll() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      // Get all characters
      final characters = await ref.read(allCharactersProvider.future);

      // Invalidate aggregate providers first
      ref.invalidate(allCharacterBalancesProvider);
      ref.invalidate(allCharacterSkillQueuesProvider);

      // Refresh data for each character
      final characterRepo = ref.read(characterRepositoryProvider);
      final walletRepo = ref.read(walletRepositoryProvider);
      final skillRepo = ref.read(skillRepositoryProvider);

      for (final character in characters) {
        try {
          // Refresh character info
          await characterRepo.refreshCharacter(character.characterId);

          // Refresh wallet balance and journal
          await walletRepo.refreshWalletBalance(character.characterId);
          await walletRepo.refreshWalletJournal(character.characterId);

          // Refresh skill queue
          await skillRepo.refreshSkillQueue(character.characterId);
        } catch (e) {
          // Continue refreshing other characters even if one fails
          debugPrint(
              'Failed to refresh character ${character.characterId}: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All characters refreshed successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: $e'),
            backgroundColor: EveColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  /// Copies fleet status to clipboard.
  Future<void> _copyFleetStatus() async {
    try {
      final characters = await ref.read(allCharactersProvider.future);
      final queues = await ref.read(allCharacterSkillQueuesProvider.future);
      final balances = await ref.read(allCharacterBalancesProvider.future);

      // Format fleet status
      final buffer = StringBuffer();
      buffer.writeln('=== Fleet Status ===\n');

      for (final character in characters) {
        buffer.writeln(character.name);

        // Add balance
        final balance = balances[character.characterId];
        if (balance != null) {
          buffer.writeln('  Balance: ${_formatIsk(balance)} ISK');
        }

        // Add skill queue status
        final queue = queues[character.characterId] ?? [];
        if (queue.isEmpty) {
          buffer.writeln('  Skill Queue: EMPTY');
        } else {
          final activeSkills = queue.where((s) => s.finishDate != null).length;
          buffer.writeln('  Skill Queue: $activeSkills active');

          // Add next completing skill
          final nextSkill = queue.where((s) => s.finishDate != null).toList()
            ..sort((a, b) => a.finishDate!.compareTo(b.finishDate!));

          if (nextSkill.isNotEmpty) {
            final timeRemaining =
                _formatTimeRemaining(nextSkill.first.finishDate!);
            buffer.writeln('  Next Skill: $timeRemaining');
          }
        }

        buffer.writeln();
      }

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: buffer.toString()));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fleet status copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy fleet status: $e'),
            backgroundColor: EveColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Formats ISK amount with appropriate suffix.
  String _formatIsk(double isk) {
    if (isk >= 1e9) {
      return '${(isk / 1e9).toStringAsFixed(2)}B';
    } else if (isk >= 1e6) {
      return '${(isk / 1e6).toStringAsFixed(2)}M';
    } else if (isk >= 1e3) {
      return '${(isk / 1e3).toStringAsFixed(2)}K';
    } else {
      return isk.toStringAsFixed(2);
    }
  }

  /// Formats time remaining until a date.
  String _formatTimeRemaining(DateTime finishDate) {
    final now = DateTime.now();
    final remaining = finishDate.difference(now);

    if (remaining.inDays > 0) {
      return '${remaining.inDays}d ${remaining.inHours % 24}h';
    } else if (remaining.inHours > 0) {
      return '${remaining.inHours}h ${remaining.inMinutes % 60}m';
    } else if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes}m';
    } else {
      return 'Complete';
    }
  }

  /// Gets all alerts for the dashboard.
  List<_Alert> _getAlerts(
    List<Character> characters,
    Map<int, List<SkillQueueEntry>> queues,
  ) {
    final alerts = <_Alert>[];

    // Check for empty skill queues
    for (final character in characters) {
      final queue = queues[character.characterId] ?? [];
      if (queue.isEmpty) {
        alerts.add(_Alert(
          icon: Icons.warning_amber_rounded,
          color: EveColors.warning,
          message: '${character.name} has empty skill queue!',
          type: _AlertType.warning,
        ));
      }
    }

    return alerts;
  }

  @override
  Widget build(BuildContext context) {
    final charactersAsync = ref.watch(allCharactersProvider);
    final queuesAsync = ref.watch(allCharacterSkillQueuesProvider);

    return DashboardCard(
      title: 'QUICK ACTIONS',
      icon: Icons.bolt,
      glowColor: EveColors.evePrimary,
      isLoading: charactersAsync.isLoading || queuesAsync.isLoading,
      child: charactersAsync.when(
        data: (characters) => queuesAsync.when(
          data: (queues) => _buildContent(characters, queues),
          loading: () => const SizedBox.shrink(),
          error: (error, stack) => _buildError(error),
        ),
        loading: () => const SizedBox.shrink(),
        error: (error, stack) => _buildError(error),
      ),
    );
  }

  Widget _buildContent(
    List<Character> characters,
    Map<int, List<SkillQueueEntry>> queues,
  ) {
    final alerts = _getAlerts(characters, queues);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Action buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: _isRefreshing ? null : _refreshAll,
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh All'),
              style: ElevatedButton.styleFrom(
                backgroundColor: EveColors.evePrimary,
                foregroundColor: Colors.white,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _isRefreshing ? null : _copyFleetStatus,
              icon: const Icon(Icons.content_copy, size: 18),
              label: const Text('Copy Fleet Status'),
              style: OutlinedButton.styleFrom(
                foregroundColor: EveColors.evePrimary,
                side: const BorderSide(color: EveColors.evePrimary),
              ),
            ),
          ],
        ),

        // Alerts section
        if (alerts.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'ALERTS',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: EveColors.warning.withAlpha(51),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: EveColors.warning),
                ),
                child: Text(
                  alerts.length.toString(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: EveColors.warning,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...alerts.map((alert) => _buildAlert(alert)),
        ],
      ],
    );
  }

  Widget _buildAlert(_Alert alert) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            alert.icon,
            color: alert.color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              alert.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: alert.color,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    return Text(
      'Failed to load alerts: $error',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: EveColors.error,
          ),
    );
  }
}

/// Alert type for categorizing notifications.
enum _AlertType {
  warning,
  // info, // Reserved for future info-level alerts
}

/// Internal alert model.
class _Alert {
  final IconData icon;
  final Color color;
  final String message;
  final _AlertType type;

  const _Alert({
    required this.icon,
    required this.color,
    required this.message,
    required this.type,
  });
}
