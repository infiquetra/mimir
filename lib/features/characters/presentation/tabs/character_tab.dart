import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/eve_colors.dart';
import 'character_sub_tabs/attributes_sub_tab.dart';
import 'character_sub_tabs/jump_clones_sub_tab.dart';
import 'character_sub_tabs/skills_sub_tab.dart';

/// Character tab with nested sub-tabs for detailed information.
///
/// Sub-tabs:
/// - Attributes: Detailed attribute display with bonuses
/// - Jump Clones: List of all jump clones with locations and implants
/// - Skills: Skills overview and training information
class CharacterTab extends ConsumerStatefulWidget {
  const CharacterTab({super.key});

  @override
  ConsumerState<CharacterTab> createState() => _CharacterTabState();
}

class _CharacterTabState extends ConsumerState<CharacterTab>
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
              Tab(text: 'Attributes'),
              Tab(text: 'Jump Clones'),
              Tab(text: 'Skills'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              AttributesSubTab(),
              JumpClonesSubTab(),
              SkillsSubTab(),
            ],
          ),
        ),
      ],
    );
  }
}
