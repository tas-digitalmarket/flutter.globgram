import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/p2p_models.dart';
import '../utils/app_logger.dart';

/// Firebase Firestore-based signaling service for WebRTC peer-to-peer communication
/// Replaces BroadcastChannel with real-time Firebase listeners
class FirebaseSignalingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppLogger _logger = AppLogger();
  
  String? _localPeerId;
  String? _roomId;
  bool _isInitialized = false;
  
  // Firestore listeners
  StreamSubscription<DocumentSnapshot>? _roomListener;
  StreamSubscription<QuerySnapshot>? _localCandidatesListener;
  StreamSubscription<QuerySnapshot>? _remoteCandidatesListener;
  
  // Callbacks
  Function(SignalingMessage)? onMessage;
  Function(PeerInfo)? onPeerJoined;
  Function(String)? onPeerLeft;
  Function(String)? onError;
  Function(bool)? onConnectionStatusChanged;

  /// Initialize the signaling service with a room ID
  Future<void> initialize(String roomId) async {
    try {
      _roomId = roomId;
      _localPeerId = _generatePeerId();
      
      _logger.info('🔥 Initializing Firebase signaling for room: $roomId');
      _logger.info('🆔 Local Peer ID: $_localPeerId');
      
      // Ensure room document exists
      await _createOrJoinRoom();
      
      // Set up listeners for real-time updates
      _setupRoomListener();
      _setupCandidatesListeners();
      
      _isInitialized = true;
      onConnectionStatusChanged?.call(true);
      
      _logger.success('✅ Firebase signaling service initialized');
    } catch (e) {
      _logger.error('❌ Failed to initialize Firebase signaling: $e');
      onError?.call('Failed to initialize signaling: $e');
    }
  }

  /// Create or join a room in Firestore
  Future<void> _createOrJoinRoom() async {
    final roomRef = _firestore.collection('rooms').doc(_roomId!);
    
    try {
      await roomRef.set({
        'created_at': FieldValue.serverTimestamp(),
        'participants': FieldValue.arrayUnion([_localPeerId!]),
        'last_activity': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      _logger.info('📝 Created/joined room: $_roomId');
    } catch (e) {
      _logger.error('❌ Failed to create/join room: $e');
      throw e;
    }
  }

  /// Set up listener for room document changes (offers/answers)
  void _setupRoomListener() {
    final roomRef = _firestore.collection('rooms').doc(_roomId!);
    
    _roomListener = roomRef.snapshots().listen((snapshot) {
      if (!snapshot.exists) return;
      
      final data = snapshot.data() as Map<String, dynamic>;
      _logger.debug('🔥 Room data updated: ${data.keys}');
      
      // Check for SDP offer
      if (data.containsKey('offer') && data['offer'] != null) {
        final offer = data['offer'] as Map<String, dynamic>;
        final fromPeer = offer['from'] as String?;
        
        if (fromPeer != null && fromPeer != _localPeerId) {
          _logger.info('📨 Received offer from: $fromPeer');
          _handleSignalingMessage(SignalingMessage(
            type: 'offer',
            from: fromPeer,
            to: _localPeerId!,
            data: offer['sdp'],
            timestamp: DateTime.now(),
          ));
        }
      }
      
      // Check for SDP answer
      if (data.containsKey('answer') && data['answer'] != null) {
        final answer = data['answer'] as Map<String, dynamic>;
        final fromPeer = answer['from'] as String?;
        
        if (fromPeer != null && fromPeer != _localPeerId) {
          _logger.info('📨 Received answer from: $fromPeer');
          _handleSignalingMessage(SignalingMessage(
            type: 'answer',
            from: fromPeer,
            to: _localPeerId!,
            data: answer['sdp'],
            timestamp: DateTime.now(),
          ));
        }
      }
      
      // Check for participants changes
      if (data.containsKey('participants')) {
        final participants = List<String>.from(data['participants'] ?? []);
        _handleParticipantsChange(participants);
      }
    });
  }

  /// Set up listeners for ICE candidates
  void _setupCandidatesListeners() {
    final roomRef = _firestore.collection('rooms').doc(_roomId!);
    
    // Listen for remote candidates (not from us)
    _remoteCandidatesListener = roomRef
        .collection('candidates')
        .where('from', isNotEqualTo: _localPeerId)
        .snapshots()
        .listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final candidateData = change.doc.data() as Map<String, dynamic>;
          final fromPeer = candidateData['from'] as String;
          
          _logger.debug('🧊 Received ICE candidate from: $fromPeer');
          _handleSignalingMessage(SignalingMessage(
            type: 'ice_candidate',
            from: fromPeer,
            to: _localPeerId!,
            data: candidateData['candidate'],
            timestamp: DateTime.now(),
          ));
        }
      }
    });
  }

  /// Handle participants list changes
  void _handleParticipantsChange(List<String> participants) {
    for (final participantId in participants) {
      if (participantId != _localPeerId) {
        _logger.info('👥 New participant detected: $participantId');
        onPeerJoined?.call(PeerInfo(
          id: participantId,
          name: 'User ${participantId.substring(0, 8)}',
          connectedAt: DateTime.now(),
          isConnected: false,
        ));
      }
    }
  }

  /// Handle incoming signaling messages
  void _handleSignalingMessage(SignalingMessage message) {
    _logger.debug('📬 Handling signaling: ${message.type} from ${message.from}');
    onMessage?.call(message);
  }

  /// Send an SDP offer to the room
  Future<void> sendOffer(RTCSessionDescription offer, String targetPeerId) async {
    try {
      final roomRef = _firestore.collection('rooms').doc(_roomId!);
      
      await roomRef.update({
        'offer': {
          'from': _localPeerId!,
          'to': targetPeerId,
          'sdp': {
            'type': offer.type,
            'sdp': offer.sdp,
          },
          'timestamp': FieldValue.serverTimestamp(),
        },
      });
      
      _logger.info('📤 Sent offer to: $targetPeerId');
    } catch (e) {
      _logger.error('❌ Failed to send offer: $e');
      onError?.call('Failed to send offer: $e');
    }
  }

  /// Send an SDP answer to the room
  Future<void> sendAnswer(RTCSessionDescription answer, String targetPeerId) async {
    try {
      final roomRef = _firestore.collection('rooms').doc(_roomId!);
      
      await roomRef.update({
        'answer': {
          'from': _localPeerId!,
          'to': targetPeerId,
          'sdp': {
            'type': answer.type,
            'sdp': answer.sdp,
          },
          'timestamp': FieldValue.serverTimestamp(),
        },
      });
      
      _logger.info('📤 Sent answer to: $targetPeerId');
    } catch (e) {
      _logger.error('❌ Failed to send answer: $e');
      onError?.call('Failed to send answer: $e');
    }
  }

  /// Send an ICE candidate
  Future<void> sendIceCandidate(RTCIceCandidate candidate, String targetPeerId) async {
    try {
      final roomRef = _firestore.collection('rooms').doc(_roomId!);
      
      await roomRef.collection('candidates').add({
        'from': _localPeerId!,
        'to': targetPeerId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      _logger.debug('🧊 Sent ICE candidate to: $targetPeerId');
    } catch (e) {
      _logger.error('❌ Failed to send ICE candidate: $e');
    }
  }

  /// Send signaling message (generic method for compatibility)
  Future<void> sendSignalingMessage(SignalingMessage message) async {
    switch (message.type) {
      case 'offer':
        final offer = RTCSessionDescription(
          message.data['sdp'] as String,
          message.data['type'] as String,
        );
        await sendOffer(offer, message.to!);
        break;
        
      case 'answer':
        final answer = RTCSessionDescription(
          message.data['sdp'] as String,
          message.data['type'] as String,
        );
        await sendAnswer(answer, message.to!);
        break;
        
      case 'ice_candidate':
        final candidate = RTCIceCandidate(
          message.data['candidate'] as String,
          message.data['sdpMid'] as String?,
          message.data['sdpMLineIndex'] as int?,
        );
        await sendIceCandidate(candidate, message.to!);
        break;
        
      default:
        _logger.warning('⚠️ Unknown signaling message type: ${message.type}');
    }
  }

  /// Generate a unique peer ID
  String _generatePeerId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'peer_${random}_$timestamp';
  }

  /// Clean up the room when leaving
  Future<void> _cleanupRoom() async {
    if (_roomId == null || _localPeerId == null) return;
    
    try {
      final roomRef = _firestore.collection('rooms').doc(_roomId!);
      
      // Remove ourselves from participants
      await roomRef.update({
        'participants': FieldValue.arrayRemove([_localPeerId!]),
        'last_activity': FieldValue.serverTimestamp(),
      });
      
      // Clean up our candidates
      final candidatesQuery = await roomRef
          .collection('candidates')
          .where('from', isEqualTo: _localPeerId!)
          .get();
      
      for (final doc in candidatesQuery.docs) {
        await doc.reference.delete();
      }
      
      // If no participants left, clean up the entire room
      final roomSnapshot = await roomRef.get();
      if (roomSnapshot.exists) {
        final participants = List<String>.from(
          roomSnapshot.data()?['participants'] ?? []
        );
        
        if (participants.isEmpty) {
          await roomRef.delete();
          _logger.info('🗑️ Cleaned up empty room: $_roomId');
        }
      }
      
      _logger.info('🧹 Cleaned up room data for peer: $_localPeerId');
    } catch (e) {
      _logger.error('❌ Failed to cleanup room: $e');
    }
  }

  // Getters
  String? get localPeerId => _localPeerId;
  String? get roomId => _roomId;
  bool get isInitialized => _isInitialized;
  bool get isConnectedToServer => _isInitialized;

  /// Disconnect and cleanup
  Future<void> disconnect() async {
    _logger.info('🔌 Disconnecting Firebase signaling service...');
    
    // Cleanup Firebase data
    await _cleanupRoom();
    
    // Cancel listeners
    await _roomListener?.cancel();
    await _localCandidatesListener?.cancel();
    await _remoteCandidatesListener?.cancel();
    
    // Reset state
    _roomListener = null;
    _localCandidatesListener = null;
    _remoteCandidatesListener = null;
    _localPeerId = null;
    _roomId = null;
    _isInitialized = false;
    
    onConnectionStatusChanged?.call(false);
    _logger.success('✅ Firebase signaling service disconnected');
  }

  /// Dispose all resources
  void dispose() {
    disconnect();
    onMessage = null;
    onPeerJoined = null;
    onPeerLeft = null;
    onError = null;
    onConnectionStatusChanged = null;
  }
}
