import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_spacing.dart';
import '../providers/chat_provider.dart';

class ChatCallScreen extends StatelessWidget {
  const ChatCallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final call = chatProvider.activeCall;
        if (call == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        final peer = chatProvider.activeCallPeer;
        final displayName = peer?.username.isNotEmpty == true
            ? peer!.username
            : peer?.email ?? 'Unknown';
        final showRemoteVideo = call.isVideo && chatProvider.hasRemoteVideo;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              return;
            }

            await chatProvider.endCurrentCall();
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RTCVideoView(
                      chatProvider.remoteRenderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                  if (!showRemoteVideo)
                    Positioned.fill(
                      child: _CallBackdrop(
                        title: displayName,
                        subtitle: chatProvider.activeCallStatusLabel,
                      ),
                    ),
                  if (call.isVideo)
                    Positioned(
                      top: AppSpacing.lg,
                      right: AppSpacing.lg,
                      child: Container(
                        width: 120,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white24),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: RTCVideoView(
                          chatProvider.localRenderer,
                          mirror: true,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      ),
                    ),
                  if (showRemoteVideo)
                    Positioned(
                      top: AppSpacing.xl,
                      left: AppSpacing.lg,
                      right: AppSpacing.lg,
                      child: Column(
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            chatProvider.activeCallStatusLabel,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Positioned(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    bottom: AppSpacing.xl,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CallControlButton(
                          icon: chatProvider.isMicEnabled
                              ? Icons.mic
                              : Icons.mic_off,
                          onPressed: chatProvider.toggleMicrophone,
                        ),
                        if (call.isVideo) ...[
                          const SizedBox(width: AppSpacing.md),
                          _CallControlButton(
                            icon: chatProvider.isCameraEnabled
                                ? Icons.videocam
                                : Icons.videocam_off,
                            onPressed: chatProvider.toggleCamera,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          _CallControlButton(
                            icon: Icons.flip_camera_ios_outlined,
                            onPressed: chatProvider.switchCamera,
                          ),
                        ],
                        const SizedBox(width: AppSpacing.md),
                        _CallControlButton(
                          icon: Icons.call_end,
                          backgroundColor: const Color(0xFFE53935),
                          onPressed: () => chatProvider.endCurrentCall(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CallBackdrop extends StatelessWidget {
  final String title;
  final String subtitle;

  const _CallBackdrop({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF172033), Color(0xFF0E1320), Color(0xFF243B5A)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: Colors.white12,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallControlButton extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Future<void> Function() onPressed;

  const _CallControlButton({
    required this.icon,
    required this.onPressed,
    this.backgroundColor = const Color(0xFF2A3447),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Center(
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
