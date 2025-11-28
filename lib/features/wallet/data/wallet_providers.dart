import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/formatters.dart';
import '../../characters/data/character_providers.dart';
import 'wallet_repository.dart';

/// Provider that streams the wallet journal for the active character.
final walletJournalProvider = StreamProvider<List<WalletJournalEntry>>((ref) {
  final activeCharacter = ref.watch(activeCharacterProvider).valueOrNull;
  if (activeCharacter == null) {
    return Stream.value([]);
  }

  final repository = ref.watch(walletRepositoryProvider);
  return repository.watchWalletJournal(activeCharacter.characterId);
});

/// Provider for refreshing wallet data (balance + journal) from ESI.
final refreshWalletProvider =
    FutureProvider.family<double, int>((ref, characterId) async {
  final repository = ref.read(walletRepositoryProvider);

  // Refresh both balance and journal.
  final balance = await repository.refreshWalletBalance(characterId);
  await repository.refreshWalletJournal(characterId);

  return balance;
});

/// Provider for the current wallet balance.
///
/// Returns the balance from the most recent journal entry, or fetches from ESI.
final walletBalanceProvider = FutureProvider<double?>((ref) async {
  final activeCharacter = ref.watch(activeCharacterProvider).valueOrNull;
  if (activeCharacter == null) {
    return null;
  }

  final repository = ref.read(walletRepositoryProvider);
  return repository.getLatestWalletBalance(activeCharacter.characterId);
});

/// Provider that formats a wallet balance as ISK.
///
/// Example: 1234567.89 → "1,234,567.89 ISK"
final formattedBalanceProvider =
    Provider.family<String, double>((ref, balance) {
  return formatIsk(balance);
});
