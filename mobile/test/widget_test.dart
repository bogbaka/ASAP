import 'package:flutter_test/flutter_test.dart';
import 'package:asap/main.dart';

void main() {
  testWidgets('ASAP welcome screen displays correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ASAPApp());

    expect(find.text('ASAP'), findsOneWidget);
    expect(find.text('Stay connected, anytime.'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });
}