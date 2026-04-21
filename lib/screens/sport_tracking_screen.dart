import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../providers/sport_provider.dart';

class SportTrackingScreen extends StatefulWidget {
  const SportTrackingScreen({super.key});

  @override
  State<SportTrackingScreen> createState() => _SportTrackingScreenState();
}

class _SportTrackingScreenState extends State<SportTrackingScreen> {
  final MapController _mapController = MapController();
  final List<LatLng> _routePoints = [];

  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;
  double _totalDistanceKm = 0.0;

  LatLng _currentLocation = const LatLng(11.5564, 104.9282);

  @override
  void initState() {
    super.initState();
    _checkPermissions();
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
      _mapController.move(_currentLocation, 16.0);
    } catch (e) {
      debugPrint('Could not get initial location: $e');
    }
  }

  void _startTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    setState(() {
      _isTracking = true;
      _routePoints.clear();
      _totalDistanceKm = 0.0;
    });

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      final newPoint = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLocation = newPoint;
        if (_routePoints.isNotEmpty) {
          final distance = Geolocator.distanceBetween(
            _routePoints.last.latitude,
            _routePoints.last.longitude,
            newPoint.latitude,
            newPoint.longitude,
          );
          _totalDistanceKm += distance / 1000.0;
        }
        _routePoints.add(newPoint);
      });
      _mapController.move(newPoint, _mapController.camera.zoom);
    });
  }

  void _stopTracking() {
    _positionStream?.cancel();
    setState(() {
      _isTracking = false;
    });
    _showSaveDialog();
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
                await provider.addSport(
                  length: _totalDistanceKm,
                  category: 'track',
                  note: noteController.text,
                  date: DateTime.now(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) Navigator.pop(context);
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
    _positionStream?.cancel();
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

      // ── Map fills the entire body ──
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentLocation,
          initialZoom: 16.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.mobile_wallet',
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
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),

      // ── My-location FAB ──
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: FloatingActionButton.small(
          heroTag: 'myLocation',
          backgroundColor: Colors.white,
          child: const Icon(Icons.my_location, color: Colors.black87),
          onPressed: () => _mapController.move(_currentLocation, 16.0),
        ),
      ),

      // ── Bottom bar with distance + start/stop ──
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
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
                        color: scheme.onSurface.withOpacity(0.6),
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
                  ],
                ),
              ),

              // Start / Stop button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isTracking ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
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
                  _isTracking ? Icons.stop_rounded : Icons.play_arrow_rounded,
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
    );
  }
}
