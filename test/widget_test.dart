// Basic smoke test: the app boots into the welcome screen.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:stayfocus/main.dart';
import 'package:stayfocus/theme/theme_controller.dart';

void main() {
  testWidgets('shows the welcome screen on launch', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(MyApp(controller: ThemeController(prefs)));
    await tester.pump();

    expect(find.text('StayFocus'), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
  });
}
