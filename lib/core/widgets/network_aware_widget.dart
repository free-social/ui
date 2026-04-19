import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class NetworkAwareWidget extends StatefulWidget {
  final Widget child;

  const NetworkAwareWidget({super.key, required this.child});

  @override
  State<NetworkAwareWidget> createState() => _NetworkAwareWidgetState();
}

class _NetworkAwareWidgetState extends State<NetworkAwareWidget> {
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isOffline = false;
  bool _wasOffline = false;
  Timer? _hideBannerTimer;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _checkInitialConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _updateConnectionStatus(result);
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    setState(() {
      final isNowOffline = result.contains(ConnectivityResult.none) || result.isEmpty;
      
      if (!isNowOffline && _isOffline) {
        // Came back online
        _isOffline = false;
        _wasOffline = true;
        // Hide the "Back online" banner after 3 seconds
        _hideBannerTimer?.cancel();
        _hideBannerTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _wasOffline = false;
            });
          }
        });
      } else if (isNowOffline && !_isOffline) {
        // Went offline
        _isOffline = true;
        _wasOffline = false;
        _hideBannerTimer?.cancel();
      } else {
        _isOffline = isNowOffline;
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _hideBannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isOffline || _wasOffline)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _isOffline ? const Color(0xFFE53935) : const Color(0xFF43A047),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          _isOffline ? 'No Internet Connection' : 'Back Online',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
