import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spendwise/screens/sport_tracking_screen.dart';

void main() {
  testWidgets('Test sport tracking screen', (WidgetTester tester) async {
    FlutterError.onError = (FlutterErrorDetails details) {
      print('FLUTTER_ERROR: \${details.exceptionAsString()}');
    };
    
    await tester.pumpWidget(const MaterialApp(
      home: SportTrackingScreen(),
    ));
    await tester.pumpAndSettle();
  });
}
