import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/p2p_models.dart';

class WebRTCService {
  // Remove singleton pattern to allow multiple instances per tab
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  final List<RTCIceCandidate> _remoteCandidates = [];
  String? _targetPeerId;

  // Callbacks
  Function(String, String)? onDataChannelMessage; // (message, fromPeerId)
  Function(RTCPeerConnectionState)? onConnectionStateChanged;
  Function(SignalingMessage)? onSignalingMessage;
  Function(String)? onError;
  Function(Uint8List, String, String)?
      onFileReceived; // (data, fileName, fromPeerId)

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
          'stun:stun.stunprotocol.org:3478',
        ]
      }
    ],
    'iceCandidatePoolSize': 10,
  };

  Future<void> initialize(String targetPeerId, bool isInitiator) async {
    try {
      _targetPeerId = targetPeerId;

      _peerConnection = await createPeerConnection(_configuration);

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        _sendSignalingMessage('ice-candidate', {
          'candidate': candidate.candidate,
          'sdpMLineIndex': candidate.sdpMLineIndex,
          'sdpMid': candidate.sdpMid,
          'targetPeerId': _targetPeerId,
        });
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        print('WebRTC connection state: $state');
        onConnectionStateChanged?.call(state);
      };

      _peerConnection!.onDataChannel = (RTCDataChannel channel) {
        print('Received data channel: ${channel.label}');
        _setupDataChannel(channel);
      };

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        print('ICE connection state: $state');
      };

      _peerConnection!.onIceGatheringState = (RTCIceGatheringState state) {
        print('ICE gathering state: $state');
      };
    } catch (e) {
      onError?.call('Failed to initialize WebRTC: $e');
    }
  }

  Future<void> createOffer() async {
    try {
      if (_peerConnection == null) {
        onError?.call('Peer connection not initialized');
        return;
      }

      // Create data channel for messages
      _dataChannel = await _peerConnection!.createDataChannel(
        'globgram-messages',
        RTCDataChannelInit()
          ..ordered = true
          ..maxRetransmits = 3,
      );
      _setupDataChannel(_dataChannel!);

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      _sendSignalingMessage('offer', {
        'sdp': offer.sdp,
        'type': offer.type,
        'targetPeerId': _targetPeerId,
      });
    } catch (e) {
      onError?.call('Failed to create offer: $e');
    }
  }

  Future<void> createAnswer(
      Map<String, dynamic> offerData, String fromPeerId) async {
    try {
      if (_peerConnection == null) {
        await initialize(fromPeerId, false);
      }

      final offer = RTCSessionDescription(
        offerData['sdp'] as String,
        offerData['type'] as String,
      );

      await _peerConnection!.setRemoteDescription(offer);

      // Add any queued remote candidates
      for (final candidate in _remoteCandidates) {
        await _peerConnection!.addCandidate(candidate);
      }
      _remoteCandidates.clear();

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      _sendSignalingMessage('answer', {
        'sdp': answer.sdp,
        'type': answer.type,
        'targetPeerId': fromPeerId,
      });
    } catch (e) {
      onError?.call('Failed to create answer: $e');
    }
  }

  Future<void> handleAnswer(Map<String, dynamic> answerData) async {
    try {
      final answer = RTCSessionDescription(
        answerData['sdp'] as String,
        answerData['type'] as String,
      );

      await _peerConnection!.setRemoteDescription(answer);

      // Add any queued remote candidates
      for (final candidate in _remoteCandidates) {
        await _peerConnection!.addCandidate(candidate);
      }
      _remoteCandidates.clear();
    } catch (e) {
      onError?.call('Failed to handle answer: $e');
    }
  }

  Future<void> handleIceCandidate(Map<String, dynamic> candidateData) async {
    try {
      final candidate = RTCIceCandidate(
        candidateData['candidate'] as String,
        candidateData['sdpMid'] as String?,
        candidateData['sdpMLineIndex'] as int?,
      );

      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      onError?.call('Failed to handle ICE candidate: $e');
    }
  }

  void sendMessage(String message) {
    if (_dataChannel != null &&
        _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      final messageData = {
        'type': 'text',
        'content': message,
        'timestamp': DateTime.now().toIso8601String(),
        'from': _targetPeerId ?? 'unknown',
      };
      _dataChannel!.send(RTCDataChannelMessage(jsonEncode(messageData)));
    } else {
      onError?.call('Data channel is not open');
    }
  }

  void sendFile(Uint8List fileData, String fileName, String mimeType) {
    if (_dataChannel != null &&
        _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      final messageData = {
        'type': 'file',
        'fileName': fileName,
        'mimeType': mimeType,
        'data': base64Encode(fileData),
        'timestamp': DateTime.now().toIso8601String(),
        'from': _targetPeerId ?? 'unknown',
      };
      _dataChannel!.send(RTCDataChannelMessage(jsonEncode(messageData)));
    } else {
      onError?.call('Data channel is not open');
    }
  }

  void _setupDataChannel(RTCDataChannel channel) {
    channel.onMessage = (RTCDataChannelMessage message) {
      try {
        final data = jsonDecode(message.text) as Map<String, dynamic>;
        final messageType = data['type'] as String;
        final fromPeer = data['from'] as String? ?? 'unknown';

        if (messageType == 'text') {
          final content = data['content'] as String;
          onDataChannelMessage?.call(content, fromPeer);
        } else if (messageType == 'file') {
          final fileName = data['fileName'] as String;
          final fileDataB64 = data['data'] as String;
          final fileData = base64Decode(fileDataB64);
          onFileReceived?.call(fileData, fileName, fromPeer);
        }
      } catch (e) {
        onError?.call('Failed to process data channel message: $e');
      }
    };

    channel.onDataChannelState = (RTCDataChannelState state) {
      print('Data channel state: $state');
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        print('Data channel is now open for communication');
      }
    };

    // Store the channel reference if we didn't create it
    if (_dataChannel == null) {
      _dataChannel = channel;
    }
  }

  void _sendSignalingMessage(String type, Map<String, dynamic> data) {
    final message = SignalingMessage(
      type: type,
      data: data,
      timestamp: DateTime.now(),
    );
    onSignalingMessage?.call(message);
  }

  Future<void> disconnect() async {
    try {
      await _dataChannel?.close();
      await _peerConnection?.close();
      _dataChannel = null;
      _peerConnection = null;
      _remoteCandidates.clear();
    } catch (e) {
      onError?.call('Failed to disconnect: $e');
    }
  }

  void dispose() {
    disconnect();
    onDataChannelMessage = null;
    onConnectionStateChanged = null;
    onSignalingMessage = null;
    onError = null;
  }
}
