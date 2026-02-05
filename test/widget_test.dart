import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spendwise/main.dart';
import 'package:spendwise/providers/auth_provider.dart';
import 'package:spendwise/providers/expense_provider.dart';
import 'package:spendwise/providers/theme_provider.dart';

void main() {
  testWidgets('App loads login screen', (WidgetTester tester) async {
    // ✅ Wrap MyApp with all necessary Providers
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ExpenseProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MyApp(),
      ),
    );

    // Trigger a frame to let the Consumer/Stream settle
    await tester.pumpAndSettle();

    // ✅ Match the text exactly as it appears in your LoginScreen
    // Based on your previous code, it says "Welcome Back" and "Sign In"
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    
    // Check for icons or specific labels
    expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });
}