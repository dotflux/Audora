import 'package:flutter_test/flutter_test.dart';

import 'package:audora/main.dart' show MyApp;
import 'package:audora/screens/main_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App boots and shows MainScreen', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(
      find.byType(MainScreen),
      findsOneWidget,
      reason: 'MainScreen should be visible on app start',
    );
  });
}


