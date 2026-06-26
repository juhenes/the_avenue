import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:the_avenue/app/app.dart';

void main() {
  testWidgets('renders The Avenue app shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: TheAvenueApp(firebaseReady: false),
      ),
    );

    expect(find.text('The Avenue'), findsWidgets);
    expect(find.text('Welcome, guest'), findsOneWidget);
  });
}
