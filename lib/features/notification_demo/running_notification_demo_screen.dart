import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dummy_data/providers.dart';
import '../../core/models/pump.dart';
import '../../core/models/pump_mode.dart';
import '../../core/theme/status_colors.dart';
import '../../core/utils/format_duration.dart';
import '../dashboard/dashboard_state.dart';

enum _Scenario { single, multiple, overflow }

/// A UI mockup of Phase 2 PRD §2.1's persistent running notification —
/// not a real Android/iOS system notification. Lets the operator preview
/// all three scenarios (single pump, multi-pump sliding cards, the >10
/// overview-only fallback) using real pump data from this build.
class RunningNotificationDemoScreen extends ConsumerStatefulWidget {
  const RunningNotificationDemoScreen({super.key});

  @override
  ConsumerState<RunningNotificationDemoScreen> createState() => _RunningNotificationDemoScreenState();
}

class _RunningNotificationDemoScreenState extends ConsumerState<RunningNotificationDemoScreen> {
  _Scenario _scenario = _Scenario.single;
  bool _singleScheduled = false;
  int _multiCount = 3;
  final Set<String> _clearedIds = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pumps = ref.watch(scopedPumpsProvider);
    final scheduledPumps = pumps.where((p) => p.activeScheduledRun != null).toList();
    final manualPumps = pumps.where((p) => p.activeScheduledRun == null).toList();
    final singlePump = _singleScheduled && scheduledPumps.isNotEmpty
        ? scheduledPumps.first
        : (manualPumps.isNotEmpty ? manualPumps.first : pumps.first);

    return Scaffold(
      appBar: AppBar(title: const Text('Running Notification Preview')),
      body: pumps.isEmpty
          ? const Center(child: Text('No pumps available to preview with.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 18, color: theme.colorScheme.outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This is a UI mockup of the persistent notification described in the '
                          'Phase 2 PRD — it doesn\'t post a real system notification.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SegmentedButton<_Scenario>(
                  segments: const [
                    ButtonSegment(value: _Scenario.single, label: Text('Single pump')),
                    ButtonSegment(value: _Scenario.multiple, label: Text('Multiple (≤10)')),
                    ButtonSegment(value: _Scenario.overflow, label: Text('Beyond 10')),
                  ],
                  selected: {_scenario},
                  onSelectionChanged: (s) => setState(() {
                    _scenario = s.first;
                    _clearedIds.clear();
                  }),
                ),
                const SizedBox(height: 20),
                if (_scenario == _Scenario.single) ...[
                  SegmentedButton<bool>(
                    segments: [
                      const ButtonSegment(value: false, label: Text('Manual / Auto')),
                      const ButtonSegment(value: true, label: Text('Scheduled (with progress)')),
                    ],
                    selected: {_singleScheduled},
                    onSelectionChanged: (s) => setState(() {
                      _singleScheduled = s.first;
                      _clearedIds.clear();
                    }),
                  ),
                  if (_singleScheduled && scheduledPumps.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'None of your pumps are currently on an active scheduled run to preview this with. '
                      'Try switching preview role from the drawer — another Operator or the JE view may have one running.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
                switch (_scenario) {
                  _Scenario.single when _singleScheduled && scheduledPumps.isEmpty => const SizedBox.shrink(),
                  _Scenario.single => _SingleScenario(
                      pump: singlePump,
                      cleared: _clearedIds.contains(singlePump.id),
                      onSimulateFault: () => setState(() => _clearedIds.add(singlePump.id)),
                      onReset: () => setState(() => _clearedIds.remove(singlePump.id)),
                    ),
                  _Scenario.multiple => _MultiScenario(
                      pumps: pumps,
                      count: _multiCount,
                      onCountChanged: (v) => setState(() => _multiCount = v),
                      clearedIds: _clearedIds,
                      onSimulateFault: (id) => setState(() => _clearedIds.add(id)),
                      onReset: () => setState(() => _clearedIds.clear()),
                    ),
                  _Scenario.overflow => const _OverflowScenario(),
                },
              ],
            ),
    );
  }
}

class _NotificationShell extends StatelessWidget {
  const _NotificationShell({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SingleScenario extends ConsumerWidget {
  const _SingleScenario({
    required this.pump,
    required this.cleared,
    required this.onSimulateFault,
    required this.onReset,
  });

  final Pump pump;
  final bool cleared;
  final VoidCallback onSimulateFault;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cleared) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: StatusColors.warnBg, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Icon(Icons.notifications_off_outlined, color: StatusColors.warn),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'A fault occurred — the persistent notification closed. The existing fault popup '
                    'alert handles notifying you.',
                    style: const TextStyle(color: StatusColors.warn, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onReset, child: const Text('Reset preview')),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NotificationShell(
          onTap: () => context.push('/pump/${pump.id}'),
          child: _PumpCardContent(pump: pump),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onSimulateFault,
          icon: const Icon(Icons.bolt_outlined, size: 18),
          label: const Text('Simulate a fault mid-run'),
        ),
      ],
    );
  }
}

/// The pump-status content shown inside a notification card — shared by the
/// single-pump preview and each swipeable card in the multi-pump preview so
/// both read as the same notification, just at a different scale.
class _PumpCardContent extends ConsumerWidget {
  const _PumpCardContent({required this.pump});

  final Pump pump;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mode = ref.watch(pumpModeProvider(pump.id));
    final progress = pump.activeScheduledRun;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: StatusColors.goodBg,
          child: const Icon(Icons.water_drop, color: StatusColors.good),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pump.displayLabel,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text('Running · ${mode.label} · ${formatDurationShort(DateTime.now().difference(pump.stateSince))}'),
              if (progress != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.fraction,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${progress.deliveredMinutes}/${progress.targetMinutes} min delivered — "${progress.scheduleName}"',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MultiScenario extends ConsumerWidget {
  const _MultiScenario({
    required this.pumps,
    required this.count,
    required this.onCountChanged,
    required this.clearedIds,
    required this.onSimulateFault,
    required this.onReset,
  });

  final List<Pump> pumps;
  final int count;
  final ValueChanged<int> onCountChanged;
  final Set<String> clearedIds;
  final ValueChanged<String> onSimulateFault;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final maxCount = pumps.length < 10 ? pumps.length : 10;
    final shown = List.generate(count, (i) => pumps[i % pumps.length]).where((p) => !clearedIds.contains(p.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Pumps to preview: $count', style: theme.textTheme.labelLarge),
            Expanded(
              child: Slider(
                value: count.toDouble(),
                min: 1,
                max: maxCount.toDouble().clamp(1, 10),
                divisions: (maxCount - 1).clamp(1, 9),
                label: '$count',
                onChanged: (v) => onCountChanged(v.round()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _NotificationShell(
          onTap: () {
            ref.read(dashboardFiltersProvider.notifier).setStatusFilter(DashboardStatusFilter.on);
            context.go('/');
          },
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.water_drop, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${shown.length} pump${shown.length == 1 ? '' : 's'} running',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text('Overview page — tap to open the Dashboard filtered to running pumps', style: theme.textTheme.bodySmall),
        ),
        const SizedBox(height: 16),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('All cards cleared.', style: theme.textTheme.bodyMedium)),
          )
        else
          SizedBox(
            height: 210,
            child: PageView(
              controller: PageController(viewportFraction: 0.88),
              children: [
                for (final pump in shown)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _MultiCard(pump: pump, onSimulateFault: () => onSimulateFault(pump.id)),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Center(child: Text('Swipe through individual pump cards', style: theme.textTheme.bodySmall)),
        if (clearedIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          Center(child: TextButton(onPressed: onReset, child: const Text('Reset cleared cards'))),
        ],
      ],
    );
  }
}

class _MultiCard extends StatelessWidget {
  const _MultiCard({required this.pump, required this.onSimulateFault});

  final Pump pump;
  final VoidCallback onSimulateFault;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _NotificationShell(
          onTap: () => context.push('/pump/${pump.id}'),
          child: _PumpCardContent(pump: pump),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onSimulateFault,
          icon: const Icon(Icons.bolt_outlined, size: 16),
          label: const Text('Simulate a fault'),
          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ],
    );
  }
}

class _OverflowScenario extends ConsumerWidget {
  const _OverflowScenario();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NotificationShell(
          onTap: () {
            ref.read(dashboardFiltersProvider.notifier).setStatusFilter(DashboardStatusFilter.on);
            context.go('/');
          },
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.water_drop, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('14 pumps running', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Beyond 10 pumps running at once, only this Overview page shows — no individual sliding '
          'cards. Tapping it opens the Dashboard pre-filtered to running pumps.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
