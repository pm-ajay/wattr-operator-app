import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dummy_data/providers.dart';
import '../../core/models/user_role.dart';
import '../shell/app_drawer.dart';
import 'dashboard_state.dart';
import 'widgets/filter_sheet.dart';
import 'widgets/pump_list_tile.dart';
import 'widgets/summary_header.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _searchController = TextEditingController();
  // Sectors start expanded (fast at-a-glance status is the primary need);
  // collapsing is an explicit per-sector opt-out, tracked here.
  final _collapsedSectors = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(dashboardSummaryProvider);
    final groups = ref.watch(groupedPumpsProvider);
    final filters = ref.watch(dashboardFiltersProvider);
    final isJE = ref.watch(sessionProvider.select((s) => s.role)) == UserRole.je;
    final theme = Theme.of(context);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Wattr.ai Operator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 700));
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => ref.read(dashboardFiltersProvider.notifier).setQuery(v),
                        decoration: InputDecoration(
                          hintText: 'Search by tower or sector',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: filters.query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(dashboardFiltersProvider.notifier).setQuery('');
                                  },
                                )
                              : null,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.tune),
                      tooltip: 'Filter & sort',
                      onPressed: () => showDashboardFilterSheet(context),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: SummaryHeader(summary: summary)),
            if (filters.sectorId != null ||
                filters.statusFilter != DashboardStatusFilter.all ||
                filters.modeFilter != DashboardModeFilter.all ||
                (isJE && filters.operatorId != null))
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (filters.statusFilter != DashboardStatusFilter.all)
                        Chip(
                          avatar: const Icon(Icons.filter_alt, size: 16),
                          label: Text('Status: ${_statusFilterLabel(filters.statusFilter)}'),
                          onDeleted: () =>
                              ref.read(dashboardFiltersProvider.notifier).setStatusFilter(DashboardStatusFilter.all),
                        ),
                      if (filters.modeFilter != DashboardModeFilter.all)
                        Chip(
                          avatar: const Icon(Icons.settings_suggest, size: 16),
                          label: Text('Mode: ${_modeFilterLabel(filters.modeFilter)}'),
                          onDeleted: () =>
                              ref.read(dashboardFiltersProvider.notifier).setModeFilter(DashboardModeFilter.all),
                        ),
                      if (filters.sectorId != null)
                        Chip(
                          avatar: const Icon(Icons.location_on, size: 16),
                          label: Text('Sector: ${_sectorName(ref, filters.sectorId!)}'),
                          onDeleted: () => ref.read(dashboardFiltersProvider.notifier).clearSectorFilter(),
                        ),
                      if (isJE && filters.operatorId != null)
                        Chip(
                          avatar: const Icon(Icons.person_outline, size: 16),
                          label: Text('Operator: ${_operatorName(ref, filters.operatorId!)}'),
                          onDeleted: () => ref.read(dashboardFiltersProvider.notifier).clearOperatorFilter(),
                        ),
                    ],
                  ),
                ),
              ),
            if (groups.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 40, color: theme.colorScheme.outline),
                        const SizedBox(height: 12),
                        Text('No pumps match your search or filters.', textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final group = groups[index];
                      final isExpanded = !_collapsedSectors.contains(group.sector.id);
                      return _SectorSection(
                        title: group.sector.name,
                        count: group.pumps.length,
                        isExpanded: isExpanded,
                        onToggle: () => setState(() {
                          if (isExpanded) {
                            _collapsedSectors.add(group.sector.id);
                          } else {
                            _collapsedSectors.remove(group.sector.id);
                          }
                        }),
                        children: [
                          for (final pump in group.pumps)
                            PumpListTile(pump: pump, onTap: () => context.push('/pump/${pump.id}')),
                        ],
                      );
                    },
                    childCount: groups.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _statusFilterLabel(DashboardStatusFilter filter) => switch (filter) {
        DashboardStatusFilter.all => 'All',
        DashboardStatusFilter.on => 'On',
        DashboardStatusFilter.off => 'Off',
        DashboardStatusFilter.fault => 'Fault',
      };

  String _modeFilterLabel(DashboardModeFilter filter) => switch (filter) {
        DashboardModeFilter.all => 'All',
        DashboardModeFilter.manual => 'Manual',
        DashboardModeFilter.schedule => 'Schedule',
        DashboardModeFilter.auto => 'Auto',
      };

  String _sectorName(WidgetRef ref, String sectorId) {
    final sectors = ref.read(sectorsProvider);
    final matches = sectors.where((s) => s.id == sectorId);
    return matches.isEmpty ? '' : matches.first.name;
  }

  String _operatorName(WidgetRef ref, String operatorId) {
    final operators = ref.read(operatorsProvider);
    final matches = operators.where((o) => o.id == operatorId);
    return matches.isEmpty ? '' : matches.first.name;
  }
}

class _SectorSection extends StatelessWidget {
  const _SectorSection({
    required this.title,
    required this.count,
    required this.isExpanded,
    required this.onToggle,
    required this.children,
  });

  final String title;
  final int count;
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(isExpanded ? Icons.expand_more : Icons.chevron_right, color: theme.colorScheme.outline),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$count', style: theme.textTheme.labelSmall),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...children,
      ],
    );
  }
}
