import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';

const double _maxAcceptedAccuracyMeters = 20.0;
const double _maxAcceptedAccuracyFirstPointMeters = 30.0;
const double _minSegmentDistanceMeters = 2.5;
const double _maxSegmentDistanceMeters = 80.0;
const double _maxJoggingSpeedMps = 8.0;
const double _stationarySpeedMps = 0.9;
const int _smoothingWindowSize = 3;

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
        AndroidFlutterLocalNotificationsPlugin
      >()
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
  List<LatLng> recentRawPoints = [];
  DateTime startTime = DateTime.now();
  DateTime? lastPointTime;

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
    final pointsJson = routePoints
        .map((p) => [p.latitude, p.longitude])
        .toList();
    await prefs.setString('bg_route_points', jsonEncode(pointsJson));
  }

  LocationSettings buildLocationSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 1),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3,
    );
  }

  LatLng smoothPoint(LatLng rawPoint) {
    recentRawPoints.add(rawPoint);
    if (recentRawPoints.length > _smoothingWindowSize) {
      recentRawPoints = recentRawPoints.sublist(
        recentRawPoints.length - _smoothingWindowSize,
      );
    }

    if (recentRawPoints.length < _smoothingWindowSize) {
      return rawPoint;
    }

    final latitudes = recentRawPoints.map((p) => p.latitude).toList()..sort();
    final longitudes = recentRawPoints.map((p) => p.longitude).toList()..sort();

    return LatLng(latitudes[1], longitudes[1]);
  }

  bool shouldAcceptPosition(Position position) {
    final accuracy = position.accuracy;
    final maxAccuracyAllowed = routePoints.isEmpty
        ? _maxAcceptedAccuracyFirstPointMeters
        : _maxAcceptedAccuracyMeters;
    if (accuracy.isFinite && accuracy > maxAccuracyAllowed) {
      return false;
    }

    if (routePoints.isEmpty) return true;

    final previous = routePoints.last;
    final segmentDistance = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      position.latitude,
      position.longitude,
    );

    if (segmentDistance < _minSegmentDistanceMeters) return false;
    if (segmentDistance > _maxSegmentDistanceMeters) return false;

    final measuredSpeed = position.speed;
    if (measuredSpeed.isFinite &&
        measuredSpeed >= 0 &&
        measuredSpeed < _stationarySpeedMps &&
        segmentDistance < 8) {
      return false;
    }

    final currentTime = position.timestamp;
    final previousTime = lastPointTime;
    if (previousTime != null) {
      final elapsedSeconds = currentTime.difference(previousTime).inSeconds;
      if (elapsedSeconds > 0) {
        final speedMps = segmentDistance / elapsedSeconds;
        if (speedMps > _maxJoggingSpeedMps) return false;
      }
    }

    return true;
  }

  Future<void> processPosition(Position position) async {
    if (!shouldAcceptPosition(position)) return;

    final rawPoint = LatLng(position.latitude, position.longitude);
    final newPoint = smoothPoint(rawPoint);
    if (routePoints.isNotEmpty) {
      final segmentDistance = Geolocator.distanceBetween(
        routePoints.last.latitude,
        routePoints.last.longitude,
        newPoint.latitude,
        newPoint.longitude,
      );
      totalDistance += segmentDistance / 1000.0;
    }

    routePoints.add(newPoint);
    lastPointTime = position.timestamp;
    await saveState();
    updateNotification();

    service.invoke('update', {
      'distance': totalDistance,
      'points': routePoints
          .map((e) => {'lat': e.latitude, 'lng': e.longitude})
          .toList(),
    });
  }

  service.on('stopService').listen((event) {
    positionStream?.cancel();
    service.stopSelf();
  });

  service.on('startTracking').listen((event) async {
    startTime = DateTime.now();
    totalDistance = 0.0;
    routePoints.clear();
    recentRawPoints.clear();
    lastPointTime = null;
    await saveState();

    final locationSettings = buildLocationSettings();

    positionStream?.cancel();
    positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            processPosition(position);
          },
        );
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
    recentRawPoints = List<LatLng>.from(routePoints.take(_smoothingWindowSize));
    lastPointTime = DateTime.now();

    service.invoke('update', {
      'distance': totalDistance,
      'points': routePoints
          .map((e) => {'lat': e.latitude, 'lng': e.longitude})
          .toList(),
    });

    final locationSettings = buildLocationSettings();

    positionStream?.cancel();
    positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            processPosition(position);
          },
        );
  });
}
