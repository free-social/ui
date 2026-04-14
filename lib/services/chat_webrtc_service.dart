import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

import '../utils/constants.dart';

class ChatWebRtcService {
  rtc.RTCPeerConnection? _peerConnection;
  rtc.MediaStream? _localStream;
  rtc.MediaStream? _remoteStream;
  bool _remoteDescriptionSet = false;
  List<Map<String, dynamic>> _iceServers = ApiConstants.rtcIceServers;
  final List<rtc.RTCIceCandidate> _pendingRemoteCandidates =
      <rtc.RTCIceCandidate>[];

  void configureIceServers(List<Map<String, dynamic>> iceServers) {
    if (iceServers.isEmpty) {
      _iceServers = ApiConstants.rtcIceServers;
      return;
    }

    _iceServers = iceServers;
  }

  Future<void> initializeRenderers(
    rtc.RTCVideoRenderer localRenderer,
    rtc.RTCVideoRenderer remoteRenderer,
  ) async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  Future<void> openLocalMedia({
    required bool videoEnabled,
    required rtc.RTCVideoRenderer localRenderer,
  }) async {
    if (_localStream != null) {
      localRenderer.srcObject = _localStream;
      return;
    }

    final mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': videoEnabled ? <String, dynamic>{'facingMode': 'user'} : false,
    };

    _localStream = await rtc.navigator.mediaDevices.getUserMedia(
      mediaConstraints,
    );
    localRenderer.srcObject = _localStream;
    await rtc.Helper.setSpeakerphoneOn(true);
  }

  Future<void> createPeerConnection({
    required rtc.RTCVideoRenderer remoteRenderer,
    required void Function(rtc.RTCIceCandidate candidate) onIceCandidate,
    required VoidCallback onRemoteStream,
  }) async {
    if (_peerConnection != null) {
      return;
    }

    _peerConnection = await rtc.createPeerConnection(<String, dynamic>{
      'iceServers': _iceServers,
      'sdpSemantics': 'unified-plan',
    });

    for (final track in _localStream?.getTracks() ?? <rtc.MediaStreamTrack>[]) {
      await _peerConnection!.addTrack(track, _localStream!);
    }

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate == null || candidate.candidate!.isEmpty) {
        return;
      }

      onIceCandidate(candidate);
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        remoteRenderer.srcObject = _remoteStream;
        onRemoteStream();
        return;
      }

      final remoteStream = _remoteStream;
      if (remoteStream == null) {
        return;
      }

      remoteStream.addTrack(event.track);
      remoteRenderer.srcObject = remoteStream;
      onRemoteStream();
    };

    _peerConnection!.onAddStream = (stream) {
      _remoteStream = stream;
      remoteRenderer.srcObject = stream;
      onRemoteStream();
    };
  }

  Future<rtc.RTCSessionDescription> createOffer() async {
    final peerConnection = _peerConnection;
    if (peerConnection == null) {
      throw StateError('Peer connection is not ready');
    }

    final offer = await peerConnection.createOffer();
    await peerConnection.setLocalDescription(offer);
    return offer;
  }

  Future<rtc.RTCSessionDescription> createAnswer() async {
    final peerConnection = _peerConnection;
    if (peerConnection == null) {
      throw StateError('Peer connection is not ready');
    }

    final answer = await peerConnection.createAnswer();
    await peerConnection.setLocalDescription(answer);
    return answer;
  }

  Future<void> setRemoteDescription({
    required String sdp,
    required String type,
  }) async {
    final peerConnection = _peerConnection;
    if (peerConnection == null) {
      throw StateError('Peer connection is not ready');
    }

    await peerConnection.setRemoteDescription(
      rtc.RTCSessionDescription(sdp, type),
    );
    _remoteDescriptionSet = true;

    for (final candidate in _pendingRemoteCandidates) {
      await peerConnection.addCandidate(candidate);
    }
    _pendingRemoteCandidates.clear();
  }

  Future<void> addRemoteCandidate(Map<String, dynamic> candidateData) async {
    final candidateValue = candidateData['candidate']?.toString() ?? '';
    if (candidateValue.isEmpty) {
      return;
    }

    final candidate = rtc.RTCIceCandidate(
      candidateValue,
      candidateData['sdpMid']?.toString(),
      candidateData['sdpMLineIndex'] is num
          ? (candidateData['sdpMLineIndex'] as num).toInt()
          : int.tryParse('${candidateData['sdpMLineIndex'] ?? ''}'),
    );

    final peerConnection = _peerConnection;
    if (peerConnection == null || !_remoteDescriptionSet) {
      _pendingRemoteCandidates.add(candidate);
      return;
    }

    await peerConnection.addCandidate(candidate);
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    for (final track
        in _localStream?.getAudioTracks() ?? <rtc.MediaStreamTrack>[]) {
      track.enabled = enabled;
    }
  }

  Future<void> setCameraEnabled(bool enabled) async {
    for (final track
        in _localStream?.getVideoTracks() ?? <rtc.MediaStreamTrack>[]) {
      track.enabled = enabled;
    }
  }

  Future<void> switchCamera() async {
    final videoTracks =
        _localStream?.getVideoTracks() ?? <rtc.MediaStreamTrack>[];
    if (videoTracks.isEmpty) {
      return;
    }

    await rtc.Helper.switchCamera(videoTracks.first);
  }

  Future<void> close({
    required rtc.RTCVideoRenderer localRenderer,
    required rtc.RTCVideoRenderer remoteRenderer,
  }) async {
    _pendingRemoteCandidates.clear();
    _remoteDescriptionSet = false;

    await _peerConnection?.close();
    _peerConnection = null;

    for (final track in _localStream?.getTracks() ?? <rtc.MediaStreamTrack>[]) {
      track.stop();
    }
    await _localStream?.dispose();
    _localStream = null;
    await _remoteStream?.dispose();
    _remoteStream = null;

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
  }

  Future<void> disposeRenderers(
    rtc.RTCVideoRenderer localRenderer,
    rtc.RTCVideoRenderer remoteRenderer,
  ) async {
    await localRenderer.dispose();
    await remoteRenderer.dispose();
  }
}
