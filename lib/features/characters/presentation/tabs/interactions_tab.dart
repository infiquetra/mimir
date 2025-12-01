import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/eve_colors.dart';
import 'interactions_sub_tabs/standings_sub_tab.dart';

/// Interactions tab with nested sub-tabs for social features.
///
/// Sub-tabs:
/// - Standings: Character standings with NPCs, corps, alliances
/// - Contacts: Contact list (placeholder for future implementation)
/// - Mail: EVE mail inbox (placeholder for future implementation)
class InteractionsTab extends ConsumerStatefulWidget {
  const InteractionsTab({super.key});

  @override
  ConsumerState<InteractionsTab> createState() => _InteractionsTabState();
}

class _InteractionsTabState extends ConsumerState<InteractionsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: EveColors.darkSurface,
          child: TabBar(
            controller: _tabController,
            indicatorColor: EveColors.evePrimary,
            labelColor: EveColors.evePrimary,
            unselectedLabelColor: Colors.white.withAlpha(179),
            tabs: const [
              Tab(text: 'Standings'),
              Tab(text: 'Contacts'),
              Tab(text: 'Mail'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              const StandingsSubTab(),
              _buildPlaceholderSubTab(
                context,
                'Contacts',
                Icons.contacts_outlined,
                'Contact list management coming soon',
              ),
              _buildPlaceholderSubTab(
                context,
                'Mail',
                Icons.mail_outline,
                'EVE mail inbox coming soon',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderSubTab(
    BuildContext context,
    String title,
    IconData icon,
    String description,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: EveColors.evePrimary.withAlpha(128),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: EveColors.evePrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
