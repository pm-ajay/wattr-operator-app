import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wattr_operator/main.dart';

void main() {
  testWidgets('Dashboard loads with summary header', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: WattrOperatorApp()));
    // Not pumpAndSettle: the running-pump status ring repeats a pulse
    // animation indefinitely, so "settled" never arrives.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Wattr.ai Operator'), findsWidgets);
    expect(find.text('Total Pumps'), findsOneWidget);
  });
}
