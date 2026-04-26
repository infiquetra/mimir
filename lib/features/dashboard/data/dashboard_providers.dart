import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/di/providers.dart';
import '../../characters/data/character_providers.dart';
import '../../skills/data/skill_repository.dart';
import '../../wallet/data/wallet_repository.dart';

/// Aggregated data for next skill completion across all characters.
class NextSkillCompletion {
  final Character character;
  final SkillQueueEntry skillEntry;

  const NextSkillCompletion({
    required this.character,
    required this.skillEntry,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NextSkillCompletion &&
          runtimeType == other.runtimeType &&
          character.characterId == other.character.characterId &&
          skillEntry.id == other.skillEntry.id;

  @override
  int get hashCode => character.characterId.hashCode ^ skillEntry.id.hashCode;
}

/// Provider that returns wallet balances for all characters.
///
/// Returns a map of characterId → balance for all characters that
/// have a recorded balance. Characters without balances are excluded.
final allCharacterBalancesProvider =
    FutureProvider<Map<int, double>>((ref) async {
  final walletRepository = ref.watch(walletRepositoryProvider);
  return walletRepository.getAllCharacterBalances();
});

/// Provider that returns skill queues for all characters.
///
/// Returns a map of characterId → skill queue entries for all characters.
/// Characters with empty queues are included with empty lists.
final allCharacterSkillQueuesProvider =
    FutureProvider<Map<int, List<SkillQueueEntry>>>((ref) async {
  final skillRepository = ref.watch(skillRepositoryProvider);
  return skillRepository.getAllCharacterQueues();
});

/// Provider that calculates the total wealth across all characters.
///
/// Sums all character wallet balances. Returns 0.0 if no characters
/// or no balances are available.
final combinedWealthProvider = Provider<AsyncValue<double>>((ref) {
  final balances = ref.watch(allCharacterBalancesProvider);
  return balances.whenData((balanceMap) {
    return balanceMap.values.fold(0.0, (sum, balance) => sum + balance);
  });
});

/// Provider that returns the next skills completing across all characters.
///
/// Returns a sorted list of (Character, SkillQueueEntry) pairs for skills
/// that are actively training (have a finish date). Sorted by finish time
/// (earliest first).
///
/// Skills without finish dates are excluded. Returns empty list if no
/// characters or no active training.
final nextSkillsCompletingProvider =
    FutureProvider<List<NextSkillCompletion>>((ref) async {
  final characters = await ref.watch(allCharactersProvider.future);
  final queues = await ref.watch(allCharacterSkillQueuesProvider.future);

  final completions = <NextSkillCompletion>[];

  for (final character in characters) {
    final queue = queues[character.characterId];
    if (queue == null || queue.isEmpty) continue;

    // Add all skills with a finish date (they are actively training or in queue)
    for (final skill in queue) {
      if (skill.finishDate != null) {
        completions.add(NextSkillCompletion(
          character: character,
          skillEntry: skill,
        ));
      }
    }
  }

  // Sort by finish date (earliest first)
  completions.sort((a, b) {
    final aDate = a.skillEntry.finishDate!;
    final bDate = b.skillEntry.finishDate!;
    return aDate.compareTo(bDate);
  });

  return completions;
});

/// Data model for wallet trends chart.
class WalletTrendsData {
  /// List of data points for the chart (date, balance).
  final List<WalletTrendsPoint> chartPoints;

  /// Total income over the period (sum of positive transactions).
  final double income;

  /// Total expenses over the period (sum of negative transactions).
  final double expenses;

  /// Net change (income - expenses).
  final double net;

  const WalletTrendsData({
    required this.chartPoints,
    required this.income,
    required this.expenses,
  }) : net = income - expenses;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WalletTrendsData) return false;
    if (chartPoints.length != other.chartPoints.length) return false;

    for (var i = 0; i < chartPoints.length; i++) {
      if (chartPoints[i] != other.chartPoints[i]) return false;
    }

    return income == other.income && expenses == other.expenses;
  }

  @override
  int get hashCode =>
      chartPoints.hashCode ^ income.hashCode ^ expenses.hashCode;
}

/// Single data point for wallet trends chart.
class WalletTrendsPoint {
  final DateTime date;
  final double balance;

  const WalletTrendsPoint({
    required this.date,
    required this.balance,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletTrendsPoint &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          balance == other.balance;

  @override
  int get hashCode => date.hashCode ^ balance.hashCode;
}

/// Provider that calculates wallet trends over the last 30 days.
///
/// Returns:
/// - List of daily balance snapshots (combined across all characters)
/// - Income/expense/net totals from wallet journal entries
///
/// Returns empty data if no balance history exists.
final walletTrendsProvider = FutureProvider<WalletTrendsData>((ref) async {
  final database = ref.watch(databaseProvider);

  // Query balance history for the last 30 days
  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

  // Get all balance snapshots from the last 30 days
  final balances = await database.customSelect(
    '''
    SELECT
      strftime('%Y-%m-%d', recorded_at, 'unixepoch') as date,
      SUM(balance) as total_balance
    FROM wallet_balances
    WHERE recorded_at >= ?
    GROUP BY date
    ORDER BY date ASC
    ''',
    variables: [Variable.withDateTime(thirtyDaysAgo)],
    readsFrom: {database.walletBalances},
  ).get();

  // Convert to chart points, filtering out any null dates
  final chartPoints = balances
      .where((row) => row.read<String?>('date') != null)
      .map((row) {
    final dateStr = row.read<String?>('date')!;
    final balance = row.read<double>('total_balance');
    return WalletTrendsPoint(
      date: DateTime.parse(dateStr),
      balance: balance,
    );
  }).toList();

  // Calculate income and expenses from journal entries
  final transactions = await database.customSelect(
    '''
    SELECT
      SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as total_income,
      SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as total_expenses
    FROM wallet_journal_entries
    WHERE date >= ?
    ''',
    variables: [Variable.withDateTime(thirtyDaysAgo)],
    readsFrom: {database.walletJournalEntries},
  ).getSingleOrNull();

  final income = transactions?.read<double?>('total_income') ?? 0.0;
  final expenses = transactions?.read<double?>('total_expenses') ?? 0.0;

  return WalletTrendsData(
    chartPoints: chartPoints,
    income: income,
    expenses: expenses,
  );
});
