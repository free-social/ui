import 'package:flutter/material.dart';

/// Show a custom notification from the top of the screen
void showTopSnackBar(
  BuildContext context,
  String message, {
  Color? backgroundColor,
  IconData icon = Icons.info_outline_rounded,
  Duration duration = const Duration(seconds: 3),
  double topOffset = 10,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return; // Exit if overlay not ready
  final topPadding = MediaQuery.of(context).padding.top;

  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => TopNotification(
      icon: icon,
      backgroundColor: backgroundColor ?? Colors.grey.shade800,
      topPadding: topPadding,
      topOffset: topOffset,
      onDismiss: () => overlayEntry.remove(),
    ),
  );

  overlay.insert(overlayEntry);

  // Auto-dismiss after duration
  Future.delayed(duration, () {
    if (overlayEntry.mounted) {
      overlayEntry.remove();
    }
  });
}

/// Success message at top (green tick)
void showSuccessSnackBar(
  BuildContext context,
  String message, {
  double topOffset = 10,
}) {
  showTopSnackBar(
    context,
    message,
    icon: Icons.check_rounded,
    backgroundColor: Colors.green,
    topOffset: topOffset,
  );
}

/// Error message at top (red cross)
void showErrorSnackBar(
  BuildContext context,
  String message, {
  double topOffset = 10,
}) {
  showTopSnackBar(
    context,
    message,
    icon: Icons.close_rounded,
    backgroundColor: Colors.red,
    topOffset: topOffset,
  );
}

/// Info message at top (blue info)
void showInfoSnackBar(
  BuildContext context,
  String message, {
  double topOffset = 10,
}) {
  showTopSnackBar(
    context,
    message,
    icon: Icons.info_outline_rounded,
    backgroundColor: Colors.blue,
    topOffset: topOffset,
  );
}

/// Custom notification widget that slides from top
class TopNotification extends StatefulWidget {
  final IconData icon;
  final Color backgroundColor;
  final double topPadding;
  final double topOffset;
  final VoidCallback onDismiss;

  const TopNotification({
    super.key,
    required this.icon,
    required this.backgroundColor,
    required this.topPadding,
    required this.topOffset,
    required this.onDismiss,
  });

  @override
  State<TopNotification> createState() => _TopNotificationState();
}

class _TopNotificationState extends State<TopNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -3.0), // Fall completely from outside the top screen bounds
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCirc));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.topPadding + widget.topOffset,
      left: 0,
      right: 0,
      child: Center(
        child: SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: _controller,
              curve: const ElasticOutCurve(0.9),
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.backgroundColor.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    widget.icon,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
