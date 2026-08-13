import 'package:go_router/go_router.dart';

import '../../features/dashboard/dashboard_screen.dart';
import '../../features/language/language_screen.dart';
import '../../features/notification_demo/running_notification_demo_screen.dart';
import '../../features/notifications/notification_history_screen.dart';
import '../../features/notifications/notification_preferences_screen.dart';
import '../../features/permissions/permissions_screen.dart';
import '../../features/pump_detail/pump_detail_screen.dart';
import '../../features/running_times/running_times_screen.dart';
import '../../features/scheduling/schedules_list_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/support/support_screen.dart';
import '../../features/theme/theme_screen.dart';
import '../../features/wattr_bot/wattr_bot_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
    GoRoute(path: '/notifications', builder: (context, state) => const NotificationHistoryScreen()),
    GoRoute(
      path: '/notification-preferences',
      builder: (context, state) => const NotificationPreferencesScreen(),
    ),
    GoRoute(path: '/language', builder: (context, state) => const LanguageScreen()),
    GoRoute(path: '/theme', builder: (context, state) => const ThemeScreen()),
    GoRoute(path: '/support', builder: (context, state) => const SupportScreen()),
    GoRoute(path: '/permissions', builder: (context, state) => const PermissionsScreen()),
    GoRoute(
      path: '/running-notification-preview',
      builder: (context, state) => const RunningNotificationDemoScreen(),
    ),
    GoRoute(
      path: '/wattr-bot',
      builder: (context, state) => WattrBotScreen(pumpLabel: state.extra as String?),
    ),
    GoRoute(
      path: '/pump/:id',
      builder: (context, state) => PumpDetailScreen(pumpId: state.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'settings',
          builder: (context, state) => SettingsScreen(pumpId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: 'running-times',
          builder: (context, state) => RunningTimesScreen(pumpId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: 'schedules',
          builder: (context, state) => SchedulesListScreen(pumpId: state.pathParameters['id']!),
        ),
      ],
    ),
  ],
);
