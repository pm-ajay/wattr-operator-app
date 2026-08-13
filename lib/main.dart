import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/dummy_data/providers.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/offline_banner.dart';

void main() {
  runApp(const ProviderScope(child: WattrOperatorApp()));
}

class WattrOperatorApp extends StatelessWidget {
  const WattrOperatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Wattr.ai Operator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
      builder: (context, child) => _AppShell(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Wraps every routed screen with the app-wide offline banner. When the
/// banner is showing, it — not the screen below it — owns the top safe-area
/// inset, so the routed screen's own AppBar isn't pushed down twice.
class _AppShell extends ConsumerWidget {
  const _AppShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);
    final mediaQuery = MediaQuery.of(context);

    return Column(
      children: [
        const OfflineBanner(),
        Expanded(
          child: isOffline
              ? MediaQuery(
                  data: mediaQuery.copyWith(padding: mediaQuery.padding.copyWith(top: 0)),
                  child: child,
                )
              : child,
        ),
      ],
    );
  }
}
