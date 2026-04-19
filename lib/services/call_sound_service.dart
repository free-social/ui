import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class CallSoundService {
  CallSoundService._();

  static final CallSoundService instance = CallSoundService._();

  final AudioPlayer _ringtonePlayer = AudioPlayer();
  final AudioPlayer _effectPlayer = AudioPlayer();
  bool _isRingtoneActive = false;

  Future<void> startRingtone() async {
    if (_isRingtoneActive) {
      return;
    }

    debugPrint('[CallSound] startRingtone called');
    debugPrintStack(label: '[CallSound] startRingtone stack');

    try {
      await _ringtonePlayer.setLoopMode(LoopMode.one);
      await _ringtonePlayer.setAsset('assets/sounds/video_call_sound.mp3');
      await _ringtonePlayer.seek(Duration.zero);
      await _ringtonePlayer.play();
      _isRingtoneActive = true;
    } catch (error) {
      debugPrint('Call ringtone playback failed: $error');
    }
  }

  Future<void> stopRingtone() async {
    debugPrint('[CallSound] stopRingtone called, active=$_isRingtoneActive');
    // Always attempt to stop the player even if the flag is already false,
    // to guard against cases where stop() previously threw and left the
    // flag reset but the player still playing.
    try {
      await _ringtonePlayer.stop();
    } catch (error) {
      debugPrint('Call ringtone stop failed: $error');
    } finally {
      _isRingtoneActive = false;
    }
  }

  Future<void> playEndCall() async {
    try {
      await _effectPlayer.stop();
      await _effectPlayer.setAsset('assets/sounds/end_call.mp3');
      await _effectPlayer.seek(Duration.zero);
      await _effectPlayer.play();
    } catch (error) {
      debugPrint('End call sound playback failed: $error');
    }
  }

  Future<void> dispose() async {
    await _ringtonePlayer.dispose();
    await _effectPlayer.dispose();
  }
}
