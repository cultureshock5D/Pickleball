import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/main.dart';
import 'package:pickleball_app/screens/auth/login_screen.dart';

void main() {
  testWidgets('App renders login screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify that Login Screen is presented
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome to SmashCourt'), findsOneWidget);
    expect(find.text('Sign In to Account'), findsWidgets);
  });
}
