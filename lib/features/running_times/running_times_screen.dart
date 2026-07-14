import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dummy_data/providers.dart';
import '../../core/models/running_session.dart';
import '../../core/utils/format_duration.dart';
import '../../shared/widgets/section_card.dart';
import 'running_times_state.dart';
import 'widgets/daily_runtime_chart.dart';

class RunningTimesScreen extends ConsumerStatefulWidget {
  const RunningTimesScreen({super.key, required this.pumpId});

  final String pumpId;

  @override
  ConsumerState<RunningTimesScreen> createState() => _RunningTimesScreenState();
}

class _RunningTimesScreenState extends ConsumerState<RunningTimesScreen> {
  RunningTimesRange _range = RunningTimesRange.last7;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pumps = ref.watch(pumpsProvider);
    final matches = pumps.where((p) => p.id == widget.pumpId);
    final pumpLabel = matches.isEmpty ? '' : matches.first.displayLabel;

    final allSessions = ref.watch(runningSessionsProvider)[widget.pumpId] ?? [];
    final now = DateTime.now();
    final start = _range.startFrom(now);
    final sessions = allSessions.where((s) => s.start.isAfter(start)).toList()
      ..sort((a, b) => b.start.compareTo(a.start));

    final totalMinutes = sessions.fold<int>(0, (sum, s) => sum + s.duration.inMinutes);
    final avgMinutes = sessions.isEmpty ? 0 : totalMinutes ~/ sessions.length;
    final abnormalCount = sessions.where((s) => s.isAbnormallyShort).length;

    return Scaffold(
      appBar: AppBar(title: Text('Running Times — $pumpLabel')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final r in RunningTimesRange.values)
                ChoiceChip(
                  label: Text(r.label),
                  selected: _range == r,
                  onSelected: (_) => setState(() => _range = r),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCard(label: 'Total Runtime', value: _formatDuration(totalMinutes))),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(label: 'Sessions', value: '${sessions.length}')),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(label: 'Avg Session', value: _formatDuration(avgMinutes))),
            ],
          ),
          const SizedBox(height: 12),
          if (abnormalCount > 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$abnormalCount abnormally short session${abnormalCount == 1 ? '' : 's'} detected — possible fault cycling.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          SectionCard(
            title: 'Daily Runtime',
            children: [DailyRuntimeChart(sessions: allSessions, days: _range == RunningTimesRange.today ? 1 : (_range == RunningTimesRange.last7 ? 7 : 14))],
          ),
          const SizedBox(height: 12),
          Text('Session Log', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No sessions in this period.', style: theme.textTheme.bodyMedium)),
            )
          else
            for (final s in sessions)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: Icon(
                    s.isAbnormallyShort ? Icons.warning_amber_rounded : Icons.play_circle_outline,
                    color: s.isAbnormallyShort ? theme.colorScheme.error : theme.colorScheme.primary,
                  ),
                  title: Text('${_formatDate(s.start)} · ${_formatTime(s.start)} – ${_formatTime(s.end)}'),
                  subtitle: Text(
                    s.isAbnormallyShort ? '${_formatDuration(s.duration.inMinutes)} · possibly abnormal' : _formatDuration(s.duration.inMinutes),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(s.trigger.label, style: theme.textTheme.labelSmall),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) => formatDurationShort(Duration(minutes: minutes));

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          Text(label, style: theme.textTheme.labelSmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
