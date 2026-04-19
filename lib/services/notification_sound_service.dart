import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class NotificationSoundService {
  NotificationSoundService._();

  static final NotificationSoundService instance =
      NotificationSoundService._();

  final AudioPlayer _player = AudioPlayer();

  Future<void> playNotification() async {
    try {
      await _player.stop();
      await _player.setAsset(
        'assets/sounds/notification_and_message_sound.mp3',
      );
      await _player.seek(Duration.zero);
      await _player.play();
    } catch (error) {
      debugPrint('Notification sound playback failed: $error');
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
