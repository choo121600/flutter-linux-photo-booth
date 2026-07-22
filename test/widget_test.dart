import 'package:flutter_test/flutter_test.dart';
import 'package:ubu4cut/main.dart';

void main() {
  testWidgets('App launches and shows home page', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    // Every route is wrapped in TapGuard, which schedules a short "absorb"
    // timer (BOOTH_TAP_GUARD_MS, default 300ms) in initState. Advance past it
    // so the test doesn't tear down with a pending timer.
    await tester.pump(const Duration(milliseconds: 400));

    // Verify home page content is displayed
    expect(find.text('Choose your mode'), findsOneWidget);
    expect(find.text('1 Cut'), findsOneWidget);
    expect(find.text('4 Cuts'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });
}
