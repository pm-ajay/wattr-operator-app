import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dummy_data/providers.dart';
import '../../core/models/pump_status.dart';
import '../dashboard/dashboard_state.dart';
import 'app_drawer.dart';

class SitesScreen extends ConsumerWidget {
  const SitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sectors = ref.watch(sectorsProvider);
    final pumps = ref.watch(pumpsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('My Sites / Sectors')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: sectors.length,
        separatorBuilder: (context, index) => const SizedBox(height: 4),
        itemBuilder: (context, index) {
          final sector = sectors[index];
          final sectorPumps = pumps.where((p) => p.sectorId == sector.id).toList();
          final faultCount = sectorPumps.where((p) => p.status.isFault).length;

          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text('${sectorPumps.length}'),
              ),
              title: Text(sector.name),
              subtitle: Text(
                faultCount > 0 ? '$faultCount pump${faultCount == 1 ? '' : 's'} need attention' : 'All pumps normal',
                style: faultCount > 0 ? TextStyle(color: theme.colorScheme.error) : null,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ref.read(dashboardFiltersProvider.notifier).setSectorFilter(sector.id);
                context.go('/');
              },
            ),
          );
        },
      ),
    );
  }
}
