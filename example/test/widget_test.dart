import 'package:flutter_test/flutter_test.dart';

import 'package:sendsar_uikit_example/main.dart';

void main() {
  testWidgets('renders the identity picker on launch', (tester) async {
    await tester.pumpWidget(const SendsarUIKitExampleApp());
    expect(find.byType(SendsarUIKitExampleApp), findsOneWidget);
  });
}
