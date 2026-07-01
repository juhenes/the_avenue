import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:the_avenue/app/app.dart';
import 'package:the_avenue/app/providers.dart';
import 'package:the_avenue/core/repositories/announcement_repository.dart';
import 'package:the_avenue/core/repositories/auth_repository.dart';
import 'package:the_avenue/core/repositories/event_repository.dart';

void main() {
  testWidgets('renders The Avenue app shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(DemoAuthRepository()),
          eventRepositoryProvider.overrideWithValue(DemoEventRepository()),
          announcementRepositoryProvider.overrideWithValue(DemoAnnouncementRepository()),
        ],
        child: const TheAvenueApp(firebaseReady: false),
      ),
    );

    expect(find.text('Welcome, guest'), findsOneWidget);
  });
}
