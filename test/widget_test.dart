import 'package:flutter_test/flutter_test.dart';
import 'package:faceshare_ai/main.dart';

void main() {
  testWidgets('FaceShare AI app loads successfully',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FaceShareAI());

    await tester.pumpAndSettle();

    expect(find.byType(FaceShareAI), findsOneWidget);
  });
}