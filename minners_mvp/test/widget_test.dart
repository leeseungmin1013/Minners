import 'package:flutter_test/flutter_test.dart';

import 'package:minners_mvp/main.dart';

void main() {
  testWidgets('MiningApp can be created', (WidgetTester tester) async {
    await tester.pumpWidget(const MiningApp());
    // Just verify the app builds without crashing
    expect(find.byType(MiningApp), findsOneWidget);
  });
}
