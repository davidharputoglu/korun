import 'package:flutter_test/flutter_test.dart';
import 'package:korun/main.dart';

void main() {
  testWidgets('KorunApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KorunApp());
    expect(find.text('Körün v0.3.0'), findsOneWidget);
  });
}
