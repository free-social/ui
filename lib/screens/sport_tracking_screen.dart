import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../providers/sport_provider.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SportTrackingScreen extends StatefulWidget {
  const SportTrackingScreen({super.key});

  @override
  State<SportTrackingScreen> createState() => _SportTrackingScreenState();
}

class _SportTrackingScreenState extends State<SportTrackingScreen> {
  final MapController _mapController = MapController();
  final List<LatLng> _routePoints = [];

  bool _isTracking = false;
  bool _mapReady = false;
  double _totalDistanceKm = 0.0;

  LatLng _currentLocation = const LatLng(11.5564, 104.9282);
  DateTime? _startTime;
  int _durationMinutes = 0;
  StreamSubscription? _serviceSubscription;
  Timer? _durationTicker;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _initBackgroundListener();
  }

  void _initBackgroundListener() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (isRunning) {
      service.invoke('resumeTracking');

      // Resume startTime from shared prefs
      SharedPreferences.getInstance().then((prefs) {
        final savedStartTime = prefs.getString('bg_start_time');
        if (savedStartTime != null) {
          if (!mounted) return;
          setState(() {
            _startTime = DateTime.parse(savedStartTime);
          });
        }
      });

      if (mounted) {
        setState(() {
          _isTracking = true;
        });
        _startDurationTicker();
      }
    }

    _serviceSubscription = service.on('update').listen((event) {
      if (event != null && mounted) {
        setState(() {
          _totalDistanceKm = (event['distance'] as num).toDouble();
          final List<dynamic> points = event['points'];
          _routePoints.clear();
          _routePoints.addAll(points.map((p) => LatLng(p['lat'], p['lng'])));
          if (_routePoints.isNotEmpty) {
            _currentLocation = _routePoints.last;
          }
        });
        _tryMoveMap(_currentLocation, _mapController.camera.zoom);
      }
    });
  }

  Future<void> _checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    try {
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _tryMoveMap(_currentLocation, 16.0);
    } catch (e) {
      debugPrint('Could not get initial location: $e');
    }
  }

  void _tryMoveMap(LatLng center, double zoom) {
    if (!_mapReady) return;
    try {
      _mapController.move(center, zoom);
    } catch (_) {}
  }

  void _startTracking() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
    service.invoke('startTracking');

    setState(() {
      _isTracking = true;
      _routePoints.clear();
      _totalDistanceKm = 0.0;
      _durationMinutes = 0;
      _startTime = DateTime.now();
    });
    _startDurationTicker();
  }

  void _stopTracking() {
    final service = FlutterBackgroundService();
    service.invoke('stopService');

    if (_startTime != null) {
      final elapsedSeconds = _elapsedSeconds;
      _durationMinutes = elapsedSeconds ~/ 60;
      if (_durationMinutes == 0) {
        if (elapsedSeconds > 10) _durationMinutes = 1;
      }
    } else {
      // Best guess from shared prefs if start time was lost
      _durationMinutes = 1; // Default
    }

    _durationTicker?.cancel();
    setState(() {
      _isTracking = false;
      _startTime = null;
    });
    _showSaveDialog();
  }

  int get _elapsedSeconds {
    if (_startTime == null) return 0;
    final seconds = DateTime.now().difference(_startTime!).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  String get _durationLabel {
    final totalSeconds = _isTracking ? _elapsedSeconds : _durationMinutes * 60;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  void _startDurationTicker() {
    _durationTicker?.cancel();
    _durationTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isTracking) return;
      setState(() {});
    });
  }

  Future<void> _showSaveDialog() async {
    final noteController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Save Workout?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Distance: ${_totalDistanceKm.toStringAsFixed(2)} km'),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'How was your run?',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final provider = context.read<SportProvider>();
                try {
                  await provider.addSport(
                    length: _totalDistanceKm,
                    category: 'jogging',
                    duration: _durationMinutes,
                    note: noteController.text.trim().isEmpty
                        ? null
                        : noteController.text.trim(),
                    date: DateTime.now(),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) Navigator.pop(context);
                } catch (_) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not save activity. Please try again.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _serviceSubscription?.cancel();
    _durationTicker?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sport Tracking'),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // ── Map fills the entire area ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 16.0,
              onMapReady: () {
                _mapReady = true;
                _tryMoveMap(_currentLocation, 16.0);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.spendwise.expenses',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: scheme.primary, width: 2),
                      ),
                      child: Icon(
                        Icons.directions_run_rounded,
                        color: scheme.primary,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── My-location button ──
          Positioned(
            top: 12,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'myLocation',
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.black87),
              onPressed: () => _tryMoveMap(_currentLocation, 16.0),
            ),
          ),

          // ── Bottom bar with distance + start/stop ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Distance info
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Distance',
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_totalDistanceKm.toStringAsFixed(2)} km',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Duration',
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _durationLabel,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Start / Stop button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTracking
                            ? Colors.red
                            : Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      onPressed: _isTracking ? _stopTracking : _startTracking,
                      icon: Icon(
                        _isTracking
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        size: 24,
                      ),
                      label: Text(
                        _isTracking ? 'STOP' : 'START',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
