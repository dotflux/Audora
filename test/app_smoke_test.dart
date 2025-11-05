import 'package:flutter_test/flutter_test.dart';

import 'package:audora/main.dart' as app;
import 'package:audora/screens/main_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App boots and shows MainScreen', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 10));

    expect(
      find.byType(MainScreen),
      findsOneWidget,
      reason: 'MainScreen should be visible on app start',
    );
  });
}


