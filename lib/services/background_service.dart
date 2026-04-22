import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'sport_tracking_channel',
    'Sport Tracking',
    description: 'Channel for sport tracking background service',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'sport_tracking_channel',
      initialNotificationTitle: 'Sport Tracking',
      initialNotificationContent: 'Initializing...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  double totalDistance = 0.0;
  List<LatLng> routePoints = [];
  DateTime startTime = DateTime.now();

  StreamSubscription<Position>? positionStream;

  void updateNotification() {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Sport Tracking",
        content: "Distance: ${totalDistance.toStringAsFixed(2)} km",
      );
    }
  }

  Future<void> saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('bg_total_distance', totalDistance);
    await prefs.setString('bg_start_time', startTime.toIso8601String());
    final pointsJson = routePoints.map((p) => [p.latitude, p.longitude]).toList();
    await prefs.setString('bg_route_points', jsonEncode(pointsJson));
  }

  service.on('stopService').listen((event) {
    positionStream?.cancel();
    service.stopSelf();
  });

  service.on('startTracking').listen((event) async {
    startTime = DateTime.now();
    totalDistance = 0.0;
    routePoints.clear();
    await saveState();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    positionStream?.cancel();
    positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      final newPoint = LatLng(position.latitude, position.longitude);
      
      if (routePoints.isNotEmpty) {
        final distance = Geolocator.distanceBetween(
          routePoints.last.latitude,
          routePoints.last.longitude,
          newPoint.latitude,
          newPoint.longitude,
        );
        totalDistance += distance / 1000.0;
      }
      
      routePoints.add(newPoint);
      saveState();
      updateNotification();

      service.invoke('update', {
        'distance': totalDistance,
        'points': routePoints.map((e) => {'lat': e.latitude, 'lng': e.longitude}).toList(),
      });
    });
  });

  service.on('resumeTracking').listen((event) async {
    final prefs = await SharedPreferences.getInstance();
    totalDistance = prefs.getDouble('bg_total_distance') ?? 0.0;
    final startTimeStr = prefs.getString('bg_start_time');
    if (startTimeStr != null) startTime = DateTime.parse(startTimeStr);
    
    final pointsStr = prefs.getString('bg_route_points');
    if (pointsStr != null) {
      final List<dynamic> decoded = jsonDecode(pointsStr);
      routePoints = decoded.map((e) => LatLng(e[0], e[1])).toList();
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    positionStream?.cancel();
    positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      final newPoint = LatLng(position.latitude, position.longitude);
      
      if (routePoints.isNotEmpty) {
        final distance = Geolocator.distanceBetween(
          routePoints.last.latitude,
          routePoints.last.longitude,
          newPoint.latitude,
          newPoint.longitude,
        );
        totalDistance += distance / 1000.0;
      }
      
      routePoints.add(newPoint);
      saveState();
      updateNotification();

      service.invoke('update', {
        'distance': totalDistance,
        'points': routePoints.map((e) => {'lat': e.latitude, 'lng': e.longitude}).toList(),
      });
    });
  });
}
