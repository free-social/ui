import 'package:flutter/material.dart';
import '../../utils/auth_image_headers.dart';

class IncomingCallPopup extends StatelessWidget {
  final String callerName;
  final String callerSubtitle;
  final String avatarUrl;
  final Future<void> Function() onDecline;
  final Future<void> Function() onAccept;

  const IncomingCallPopup({
    super.key,
    required this.callerName,
    required this.callerSubtitle,
    required this.avatarUrl,
    required this.onDecline,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl.trim().isNotEmpty;

    return Material(
      color: Colors.black45,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: const Color(0xFF171717),
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.white10,
                backgroundImage: hasAvatar ? authImageProvider(avatarUrl) : null,
                child: hasAvatar
                    ? null
                    : const Icon(Icons.person, color: Colors.white70, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      callerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      callerSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _ActionButton(
                backgroundColor: const Color(0xFFFF3B30),
                icon: Icons.call_end,
                onTap: onDecline,
              ),
              const SizedBox(width: 10),
              _ActionButton(
                backgroundColor: const Color(0xFF32D74B),
                icon: Icons.call,
                onTap: onAccept,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Color backgroundColor;
  final IconData icon;
  final Future<void> Function() onTap;

  const _ActionButton({
    required this.backgroundColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 54,
          height: 54,
          child: Center(
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
