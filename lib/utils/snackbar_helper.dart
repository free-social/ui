import 'package:flutter/material.dart';

/// Show a custom notification from the top of the screen
void showTopSnackBar(
  BuildContext context,
  String message, {
  Color? backgroundColor,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return; // Exit if overlay not ready
  final topPadding = MediaQuery.of(context).padding.top;

  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => TopNotification(
      message: message,
      backgroundColor: backgroundColor ?? Colors.grey.shade800,
      topPadding: topPadding,
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

/// Success message at top (green)
void showSuccessSnackBar(BuildContext context, String message) {
  showTopSnackBar(context, message, backgroundColor: Colors.green);
}

/// Error message at top (red)
void showErrorSnackBar(BuildContext context, String message) {
  showTopSnackBar(context, message, backgroundColor: Colors.red);
}

/// Info message at top (blue)
void showInfoSnackBar(BuildContext context, String message) {
  showTopSnackBar(context, message, backgroundColor: Colors.blue);
}

/// Custom notification widget that slides from top
class TopNotification extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final double topPadding;
  final VoidCallback onDismiss;

  const TopNotification({
    super.key,
    required this.message,
    required this.backgroundColor,
    required this.topPadding,
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
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

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
      top: widget.topPadding + 10,
      left: 10,
      right: 10,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _controller.reverse().then((_) => widget.onDismiss());
                  },
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
