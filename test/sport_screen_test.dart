import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service_platform_interface/flutter_background_service_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:spendwise/providers/sport_provider.dart';
import 'package:spendwise/screens/sport_tracking_screen.dart';

class _FakeBackgroundServicePlatform extends FlutterBackgroundServicePlatform
    with MockPlatformInterfaceMixin {
  final _controller = StreamController<Map<String, dynamic>?>.broadcast();

  @override
  Future<bool> configure({
    required IosConfiguration iosConfiguration,
    required AndroidConfiguration androidConfiguration,
  }) async {
    return true;
  }

  @override
  Future<bool> isServiceRunning() async => false;

  @override
  Future<bool> start() async => true;

  @override
  void invoke(String method, [Map<String, dynamic>? args]) {
    _controller.add({'method': method, 'args': args});
  }

  @override
  Stream<Map<String, dynamic>?> on(String method) {
    return _controller.stream
        .where((event) => event?['method'] == method)
        .map((event) => event?['args'] as Map<String, dynamic>?);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const geolocatorChannel = MethodChannel('flutter.baseflow.com/geolocator');

  setUp(() {
    FlutterBackgroundServicePlatform.instance =
        _FakeBackgroundServicePlatform();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geolocatorChannel, (call) async {
          switch (call.method) {
            case 'isLocationServiceEnabled':
              return true;
            case 'checkPermission':
              return 1; // LocationPermission.whileInUse
            case 'requestPermission':
              return 1;
            case 'getCurrentPosition':
              return {
                'latitude': 11.5564,
                'longitude': 104.9282,
                'timestamp': DateTime.now().toIso8601String(),
                'accuracy': 5.0,
                'altitude': 0.0,
                'heading': 0.0,
                'speed': 0.0,
                'speed_accuracy': 0.0,
              };
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(geolocatorChannel, null);
  });

  testWidgets('Sport tracking screen renders start state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SportProvider(),
        child: const MaterialApp(home: SportTrackingScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Sport Tracking'), findsOneWidget);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
  });
}
