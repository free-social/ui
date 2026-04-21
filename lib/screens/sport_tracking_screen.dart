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
  
  // Map center starts at some default or gets updated on first location
  LatLng _currentLocation = const LatLng(11.5564, 104.9282); // Default to Phnom Penh

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return;
    }

    // Get initial location
    try {
      final position = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 5),
      );
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_currentLocation, 16.0);
    } catch (e) {
      debugPrint('Failed to get initial location, using default: $e');
    }
  }

  void _startTracking() async {
    final locationSettings = const LocationSettings(
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
          _totalDistanceKm += distance / 1000.0; // convert meters to km
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
      builder: (context) {
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
              onPressed: () => Navigator.pop(context),
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
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context);
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
    _positionStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sport Tracking'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mobile_wallet', // Update to your package ID
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
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Distance',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        Text(
                          '${_totalDistanceKm.toStringAsFixed(2)} km',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTracking ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: _isTracking ? _stopTracking : _startTracking,
                      icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                      label: Text(_isTracking ? 'STOP' : 'START'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.black),
              onPressed: () {
                _mapController.move(_currentLocation, 16.0);
              },
            ),
          ),
        ],
      ),
    );
  }
}
