import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class P2pRepositoryImpl {
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;

  // STUN/TURN servers configuration - Stage D compliant
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {
        'urls': 'turn:relay.metered.ca:80',
        'username': 'webrtc',
        'credential': 'webrtc'
      },
    ]
  };

  Future<void> initialize() async {
    try {
      // Initialize WebRTC
      await WebRTC.initialize();
    } catch (e) {
      throw Exception('Failed to initialize WebRTC: $e');
    }
  }

  Future<String> createRoom(String roomName) async {
    try {
      // Create peer connection
      _peerConnection = await createPeerConnection(_configuration);

      // Create data channel for messaging
      _dataChannel = await _peerConnection!.createDataChannel(
        'messages',
        RTCDataChannelInit()..ordered = true,
      );

      // Set up data channel listeners
      _dataChannel!.onMessage = (RTCDataChannelMessage message) {
        // Handle incoming message
        print('Received message: ${message.text}');
      };

      // Create offer
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // Return SDP offer as base64 encoded string for QR code
      final sdpData = {
        'type': 'offer',
        'sdp': offer.sdp,
        'room': roomName,
      };

      return base64Encode(utf8.encode(jsonEncode(sdpData)));
    } catch (e) {
      throw Exception('Failed to create room: $e');
    }
  }

  Future<String> joinRoom(String encodedSdpOffer) async {
    try {
      // Decode SDP offer
      final decodedData = utf8.decode(base64Decode(encodedSdpOffer));
      final sdpData = jsonDecode(decodedData);

      // Create peer connection
      _peerConnection = await createPeerConnection(_configuration);

      // Set up data channel listener for incoming channels
      _peerConnection!.onDataChannel = (RTCDataChannel channel) {
        _dataChannel = channel;
        _dataChannel!.onMessage = (RTCDataChannelMessage message) {
          // Handle incoming message
          print('Received message: ${message.text}');
        };
      };

      // Set remote description (offer)
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdpData['sdp'], sdpData['type']),
      );

      // Create and set answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // In a real implementation, you would exchange this answer
      // with the peer through some signaling mechanism
      // For now, we'll simulate successful connection

      return 'peer_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      throw Exception('Failed to join room: $e');
    }
  }

  Future<void> sendMessage(String message) async {
    try {
      if (_dataChannel != null &&
          _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
        _dataChannel!.send(RTCDataChannelMessage(message));
      } else {
        throw Exception('Data channel is not open');
      }
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      await _dataChannel?.close();
      await _peerConnection?.close();
      _dataChannel = null;
      _peerConnection = null;
    } catch (e) {
      throw Exception('Failed to disconnect: $e');
    }
  }

  void dispose() {
    disconnect();
  }
}
