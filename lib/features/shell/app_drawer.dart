import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/dummy_data/providers.dart';
import '../../core/models/user_role.dart';

const _jeName = 'Rajesh Kumar';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    final operators = ref.watch(operatorsProvider);
    final currentOperatorMatches = operators.where(
      (o) => o.id == session.operatorId,
    );
    final currentOperatorName = currentOperatorMatches.isEmpty
        ? ''
        : currentOperatorMatches.first.name;

    void go(String path) {
      Navigator.of(context).pop();
      context.go(path);
    }

    void push(String path) {
      Navigator.of(context).pop();
      context.push(path);
    }

    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.water_drop,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wattr.ai Operator',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          session.role == UserRole.je
                              ? '$_jeName · Junior Engineer'
                              : '$currentOperatorName · Operator',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: OutlinedButton.icon(
                onPressed: () => _showRoleSwitcherSheet(context, ref),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Switch preview role'),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
                children: [
                  _SectionLabel('Navigate'),
                  _NavItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    onTap: () => go('/'),
                  ),
                  const SizedBox(height: 20),
                  _SectionLabel('Alerts'),
                  _NavItem(
                    icon: Icons.notifications_outlined,
                    label: 'Notification History',
                    onTap: () => go('/notifications'),
                  ),
                  _NavItem(
                    icon: Icons.tune_outlined,
                    label: 'Notification Preferences',
                    onTap: () => push('/notification-preferences'),
                  ),
                  const SizedBox(height: 20),
                  _SectionLabel('Preferences'),
                  _NavItem(
                    icon: Icons.language_outlined,
                    label: 'Language',
                    onTap: () => push('/language'),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Column(
                children: [
                  _NavItem(
                    icon: Icons.help_outline,
                    label: 'Support',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  _NavItem(
                    icon: Icons.logout,
                    label: 'Logout',
                    iconColor: theme.colorScheme.error,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                'Wattr.ai Operator · v1.0.0 (UI preview)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoleSwitcherSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Consumer(
        builder: (sheetContext, sheetRef, _) {
          final session = sheetRef.watch(sessionProvider);
          final operators = sheetRef.watch(operatorsProvider);
          final theme = Theme.of(sheetContext);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preview as',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Stands in for a real login — this app always auto-scopes to one role.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'OPERATOR (sees only their own pumps)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    for (final operator in operators)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        title: Text(operator.name),
                        value: operator.id,
                        groupValue: session.role == UserRole.operator
                            ? session.operatorId
                            : null,
                        onChanged: (id) {
                          if (id == null) return;
                          ref.read(sessionProvider.notifier).viewAsOperator(id);
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                    const Divider(height: 24),
                    Text(
                      'JUNIOR ENGINEER (sees every Operator\'s pumps)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    RadioListTile<UserRole>(
                      contentPadding: EdgeInsets.zero,
                      title: Text('$_jeName (all pumps)'),
                      value: UserRole.je,
                      groupValue: session.role,
                      onChanged: (_) {
                        ref.read(sessionProvider.notifier).viewAsJE();
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.outline,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = iconColor ?? theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
