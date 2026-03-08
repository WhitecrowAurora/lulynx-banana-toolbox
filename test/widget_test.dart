import 'package:flutter_test/flutter_test.dart';
import 'package:nano_banana_app/main.dart';

void main() {
  testWidgets('app boots and shows home title', (WidgetTester tester) async {
    await tester.pumpWidget(const NanoBananaApp());
    expect(find.text("Lulynx's Toolbox"), findsOneWidget);
  });
}
