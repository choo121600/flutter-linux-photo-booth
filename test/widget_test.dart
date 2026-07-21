import 'package:flutter_test/flutter_test.dart';
import 'package:ubu4cut/main.dart';

void main() {
  testWidgets('App launches and shows home page', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify home page content is displayed
    expect(find.text('사진 모드를 선택하세요:'), findsOneWidget);
    expect(find.text('1장'), findsOneWidget);
    expect(find.text('4장'), findsOneWidget);
    expect(find.text('사진 촬영 시작'), findsOneWidget);
  });
}
