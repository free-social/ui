import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _SportTrackingScreenState extends State<SportTrackingScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final List<LatLng> _routePoints = [];

  bool _isTracking = false;
  bool _isPaused = false;
  bool _mapReady = false;
  double _totalDistanceKm = 0.0;

  LatLng _currentLocation = const LatLng(11.5564, 104.9282);
  DateTime? _startTime;
  int _durationMinutes = 0;
  int _pausedElapsedSeconds = 0;
  DateTime? _pauseStartTime;
  StreamSubscription? _serviceSubscription;
  StreamSubscription? _pauseSubscription;
  StreamSubscription? _unpauseSubscription;
  Timer? _durationTicker;

  // Live pulse animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    // Pulse animation for LIVE dot
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkPermissions();
    _initBackgroundListener();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _initBackgroundListener() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (isRunning) {
      service.invoke('resumeTracking');
      SharedPreferences.getInstance().then((prefs) {
        final savedStartTime = prefs.getString('bg_start_time');
        if (savedStartTime != null && mounted) {
          setState(() {
            _startTime = DateTime.parse(savedStartTime);
            _isPaused = prefs.getBool('bg_is_paused') ?? false;
          });
        }
      });
      if (mounted) {
        setState(() => _isTracking = true);
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
          if (_routePoints.isNotEmpty) _currentLocation = _routePoints.last;
          if (event['isPaused'] == true && !_isPaused) _isPaused = true;
        });
        _tryMoveMap(_currentLocation, _mapController.camera.zoom);
      }
    });

    _pauseSubscription = service.on('paused').listen((_) {
      if (mounted) setState(() => _isPaused = true);
    });
    _unpauseSubscription = service.on('unpaused').listen((_) {
      if (mounted) setState(() => _isPaused = false);
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

  // ── Tracking controls ──────────────────────────────────────────────────────

  void _startTracking() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) await service.startService();
    service.invoke('startTracking');
    setState(() {
      _isTracking = true;
      _isPaused = false;
      _routePoints.clear();
      _totalDistanceKm = 0.0;
      _durationMinutes = 0;
      _pausedElapsedSeconds = 0;
      _pauseStartTime = null;
      _startTime = DateTime.now();
    });
    _startDurationTicker();
  }

  void _pauseTracking() {
    FlutterBackgroundService().invoke('pauseTracking');
    setState(() {
      _isPaused = true;
      _pauseStartTime = DateTime.now();
      if (_startTime != null) {
        _pausedElapsedSeconds =
            DateTime.now().difference(_startTime!).inSeconds -
                _pausedElapsedSeconds;
      }
    });
  }

  void _unpauseTracking() {
    FlutterBackgroundService().invoke('unpauseTracking');
    setState(() {
      _isPaused = false;
      _pauseStartTime = null;
    });
  }

  void _stopTracking() {
    FlutterBackgroundService().invoke('stopService');
    final activeSeconds = _activeElapsedSeconds;
    _durationMinutes = activeSeconds ~/ 60;
    if (_durationMinutes == 0 && activeSeconds > 10) _durationMinutes = 1;
    _durationTicker?.cancel();
    setState(() {
      _isTracking = false;
      _isPaused = false;
      _startTime = null;
      _pausedElapsedSeconds = 0;
      _pauseStartTime = null;
    });
    _showSaveDialog();
  }

  // ── Duration helpers ───────────────────────────────────────────────────────

  int get _activeElapsedSeconds {
    if (_startTime == null) return 0;
    final wallClock = DateTime.now().difference(_startTime!).inSeconds;
    final pausedSoFar = _isPaused && _pauseStartTime != null
        ? DateTime.now().difference(_pauseStartTime!).inSeconds
        : 0;
    final active = wallClock - pausedSoFar;
    return active < 0 ? 0 : active;
  }

  int get _elapsedSeconds =>
      _isPaused ? _pausedElapsedSeconds : _activeElapsedSeconds;

  String get _durationLabel {
    final totalSeconds = _isTracking ? _elapsedSeconds : _durationMinutes * 60;
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Pace in min/km as "m:ss"
  String get _paceLabel {
    if (_totalDistanceKm < 0.01 || _elapsedSeconds == 0) return '--:--';
    final secondsPerKm = _elapsedSeconds / _totalDistanceKm;
    final m = secondsPerKm ~/ 60;
    final s = (secondsPerKm % 60).toInt();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get _speedLabel {
    if (_elapsedSeconds == 0) return '0.0';
    final kmh = _totalDistanceKm / (_elapsedSeconds / 3600.0);
    return kmh.toStringAsFixed(1);
  }

  void _startDurationTicker() {
    _durationTicker?.cancel();
    _durationTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isTracking || _isPaused) return;
      setState(() {});
    });
  }

  // ── Save dialog ────────────────────────────────────────────────────────────

  Future<void> _showSaveDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final savedWeightKg = prefs.getDouble('sport_weight_kg') ?? 70.0;
    if (!mounted) return;
    final noteController = TextEditingController();
    final weightController = TextEditingController(
      text: savedWeightKg.toStringAsFixed(1),
    );
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Save Workout?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statRow(
              Icons.route_rounded,
              'Distance',
              '${_totalDistanceKm.toStringAsFixed(2)} km',
            ),
            const SizedBox(height: 8),
            _statRow(
              Icons.timer_rounded,
              'Duration',
              _durationLabel,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: false,
                labelText: 'Weight (kg)',
                labelStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00C853)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: false,
                labelText: 'How was your run?',
                labelStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00C853)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              minimumSize: const Size(80, 44),
            ),
            child:
                const Text('Discard', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(120, 44),
              backgroundColor: const Color(0xFF00C853),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final provider = context.read<SportProvider>();
              try {
                final weightKg =
                    double.tryParse(weightController.text.trim());
                if (weightKg == null || weightKg <= 0) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a valid weight.')),
                  );
                  return;
                }
                final calories = await provider.calculateCalories(
                  category: 'jogging',
                  weightKg: weightKg,
                  durationMinutes: _durationMinutes,
                );
                await prefs.setDouble('sport_weight_kg', weightKg);
                await provider.addSport(
                  length: _totalDistanceKm,
                  category: 'jogging',
                  calories: calories,
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
                      content: Text('Could not save. Please try again.')),
                );
              }
            },
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _statRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00C853), size: 18),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _serviceSubscription?.cancel();
    _pauseSubscription?.cancel();
    _unpauseSubscription?.cancel();
    _durationTicker?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0, // hidden — we use our own floating controls
      ),
      body: Stack(
        children: [
          // ── Full-screen Map ─────────────────────────────────────────────
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
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.spendwise.expenses',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5.0,
                      color: const Color(0xFF2979FF),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
                    width: 56,
                    height: 56,
                    child: _CurrentPositionMarker(isTracking: _isTracking && !_isPaused),
                  ),
                ],
              ),
            ],
          ),

          // ── Top floating controls ───────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _FloatingIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),

                  // LIVE indicator
                  if (_isTracking && !_isPaused)
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => _LiveBadge(opacity: _pulseAnim.value),
                    ),

                  if (_isTracking && !_isPaused) const SizedBox(width: 12),

                  _FloatingIconButton(
                    icon: Icons.my_location_rounded,
                    onTap: () => _tryMoveMap(_currentLocation, 16.0),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom glassmorphism panel ──────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D0D).withValues(alpha: 0.82),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Drag handle
                          Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),

                          // PAUSED chip
                          if (_isPaused) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6D00)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFFF6D00),
                                  width: 1,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.pause_circle_filled_rounded,
                                      color: Color(0xFFFF6D00), size: 14),
                                  SizedBox(width: 6),
                                  Text(
                                    'PAUSED',
                                    style: TextStyle(
                                      color: Color(0xFFFF6D00),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Metrics row
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _MetricBlock(
                                    label: 'DISTANCE',
                                    value: _totalDistanceKm
                                        .toStringAsFixed(2),
                                    unit: 'km',
                                  ),
                                ),
                                VerticalDivider(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  thickness: 1,
                                  indent: 4,
                                  endIndent: 4,
                                ),
                                Expanded(
                                  child: _MetricBlock(
                                    label: 'DURATION',
                                    value: _durationLabel,
                                    unit: '',
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Pace / Speed row (only while tracking)
                          if (_isTracking) ...[
                            const SizedBox(height: 12),
                            Divider(
                                color: Colors.white.withValues(alpha: 0.08),
                                height: 1),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _MiniStat(
                                  label: 'PACE',
                                  value: _paceLabel,
                                  unit: '/km',
                                ),
                                Container(
                                  width: 1,
                                  height: 30,
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                                _MiniStat(
                                  label: 'SPEED',
                                  value: _speedLabel,
                                  unit: 'km/h',
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Buttons
                          if (!_isTracking)
                            _GradientButton(
                              label: 'START RUN',
                              icon: Icons.play_arrow_rounded,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00C853), Color(0xFF69F0AE)],
                              ),
                              onTap: _startTracking,
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: _isPaused
                                      ? _GradientButton(
                                          label: 'RESUME',
                                          icon: Icons.play_arrow_rounded,
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF00C853),
                                              Color(0xFF69F0AE),
                                            ],
                                          ),
                                          onTap: _unpauseTracking,
                                        )
                                      : _GradientButton(
                                          label: 'PAUSE',
                                          icon: Icons.pause_rounded,
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFFF6D00),
                                              Color(0xFFFFAB40),
                                            ],
                                          ),
                                          onTap: _pauseTracking,
                                        ),
                                ),
                                const SizedBox(width: 12),
                                _RoundIconButton(
                                  icon: Icons.stop_rounded,
                                  color: const Color(0xFFD50000),
                                  onTap: _stopTracking,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _FloatingIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _FloatingIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final double opacity;
  const _LiveBadge({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withValues(alpha: 0.6)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, color: Colors.red, size: 8),
            SizedBox(width: 5),
            Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _MetricBlock(
      {required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  letterSpacing: -1,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    unit,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _MiniStat(
      {required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 3),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;
  const _GradientButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _RoundIconButton(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

class _CurrentPositionMarker extends StatefulWidget {
  final bool isTracking;
  const _CurrentPositionMarker({required this.isTracking});

  @override
  State<_CurrentPositionMarker> createState() => _CurrentPositionMarkerState();
}

class _CurrentPositionMarkerState extends State<_CurrentPositionMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (widget.isTracking)
          AnimatedBuilder(
            animation: _scaleAnim,
            builder: (_, __) => Transform.scale(
              scale: _scaleAnim.value,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2979FF).withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: const Color(0xFF2979FF),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2979FF).withValues(alpha: 0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_run_rounded,
            color: Color(0xFF2979FF),
            size: 14,
          ),
        ),
      ],
    );
  }
}
