import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../utils/app_logger.dart';

/// Firestore-based signaling service for WebRTC peer-to-peer communication
/// Collection schema:
/// - rooms/{roomId} → offer, answer, createdBy, createdAt
/// - rooms/{roomId}/candidates/local/{autoId}
/// - rooms/{roomId}/candidates/remote/{autoId}
class FirestoreSignalingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppLogger _logger = AppLogger();
  
  String? _roomId;
  String? _localPeerId;
  bool _isOfferingPeer = false;
  
  // Firestore listeners
  StreamSubscription<DocumentSnapshot>? _roomListener;
  StreamSubscription<QuerySnapshot>? _localCandidatesListener;
  StreamSubscription<QuerySnapshot>? _remoteCandidatesListener;
  
  // Callbacks
  Function(RTCSessionDescription)? onRemoteOffer;
  Function(RTCSessionDescription)? onRemoteAnswer;
  Function(RTCIceCandidate)? onRemoteIceCandidate;
  Function(String)? onPeerJoined;
  Function(String)? onPeerLeft;
  Function(String)? onError;

  /// Create a new room and become the offering peer
  Future<String> createRoom() async {
    try {
      _roomId = _generateRoomId();
      _localPeerId = _generatePeerId();
      _isOfferingPeer = true;
      
      _logger.info('🏠 Creating room: $_roomId');
      
      // Create room document
      await _firestore.collection('rooms').doc(_roomId).set({
        'createdBy': _localPeerId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'waiting',
      });
      
      // Setup listeners
      _setupRoomListener();
      _setupCandidatesListeners();
      
      _logger.success('✅ Room created: $_roomId');
      return _roomId!;
    } catch (e) {
      _logger.error('❌ Failed to create room: $e');
      onError?.call('Failed to create room: $e');
      rethrow;
    }
  }

  /// Join an existing room and become the answering peer
  Future<void> joinRoom(String roomId) async {
    try {
      _roomId = roomId;
      _localPeerId = _generatePeerId();
      _isOfferingPeer = false;
      
      _logger.info('🚪 Joining room: $roomId');
      
      // Check if room exists
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();
      if (!roomDoc.exists) {
        throw Exception('Room does not exist');
      }
      
      // Update room status
      await _firestore.collection('rooms').doc(roomId).update({
        'answererPeerId': _localPeerId,
        'status': 'connected',
        'joinedAt': FieldValue.serverTimestamp(),
      });
      
      // Setup listeners
      _setupRoomListener();
      _setupCandidatesListeners();
      
      _logger.success('✅ Joined room: $roomId');
      onPeerJoined?.call(_localPeerId!);
    } catch (e) {
      _logger.error('❌ Failed to join room: $e');
      onError?.call('Failed to join room: $e');
      rethrow;
    }
  }

  /// Send offer to remote peer
  Future<void> sendOffer(RTCSessionDescription offer) async {
    try {
      if (_roomId == null) throw Exception('Room not initialized');
      
      _logger.info('📤 Sending offer');
      
      await _firestore.collection('rooms').doc(_roomId).update({
        'offer': {
          'sdp': offer.sdp,
          'type': offer.type,
        },
        'offerSentAt': FieldValue.serverTimestamp(),
      });
      
      _logger.success('✅ Offer sent');
    } catch (e) {
      _logger.error('❌ Failed to send offer: $e');
      onError?.call('Failed to send offer: $e');
      rethrow;
    }
  }

  /// Send answer to remote peer
  Future<void> sendAnswer(RTCSessionDescription answer) async {
    try {
      if (_roomId == null) throw Exception('Room not initialized');
      
      _logger.info('📤 Sending answer');
      
      await _firestore.collection('rooms').doc(_roomId).update({
        'answer': {
          'sdp': answer.sdp,
          'type': answer.type,
        },
        'answerSentAt': FieldValue.serverTimestamp(),
      });
      
      _logger.success('✅ Answer sent');
    } catch (e) {
      _logger.error('❌ Failed to send answer: $e');
      onError?.call('Failed to send answer: $e');
      rethrow;
    }
  }

  /// Send ICE candidate to remote peer
  Future<void> sendIceCandidate(RTCIceCandidate candidate) async {
    try {
      if (_roomId == null) throw Exception('Room not initialized');
      
      final candidateData = {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'timestamp': FieldValue.serverTimestamp(),
        'fromPeer': _localPeerId,
      };
      
      // Store in local candidates collection
      await _firestore
          .collection('rooms')
          .doc(_roomId)
          .collection('candidates')
          .doc('local')
          .collection(_localPeerId!)
          .add(candidateData);
      
      _logger.info('🧊 ICE candidate sent');
    } catch (e) {
      _logger.error('❌ Failed to send ICE candidate: $e');
      onError?.call('Failed to send ICE candidate: $e');
      rethrow;
    }
  }

  /// Listen for remote ICE candidates
  void listenForRemoteCandidates() {
    if (_roomId == null) return;
    
    final remotePeerId = _isOfferingPeer ? 'answerer' : 'offerer';
    
    _remoteCandidatesListener = _firestore
        .collection('rooms')
        .doc(_roomId)
        .collection('candidates')
        .doc('remote')
        .collection(remotePeerId)
        .orderBy('timestamp')
        .snapshots()
        .listen(
      (snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data() as Map<String, dynamic>;
            
            final candidate = RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            );
            
            _logger.info('🧊 Received remote ICE candidate');
            onRemoteIceCandidate?.call(candidate);
          }
        }
      },
      onError: (error) {
        _logger.error('❌ Error listening for remote candidates: $error');
        onError?.call('Error listening for remote candidates: $error');
      },
    );
  }

  /// Setup room document listener for offers/answers
  void _setupRoomListener() {
    if (_roomId == null) return;
    
    _roomListener = _firestore
        .collection('rooms')
        .doc(_roomId)
        .snapshots()
        .listen(
      (snapshot) {
        if (!snapshot.exists) return;
        
        final data = snapshot.data() as Map<String, dynamic>;
        
        // Handle offer
        if (data.containsKey('offer') && !_isOfferingPeer) {
          final offerData = data['offer'] as Map<String, dynamic>;
          final offer = RTCSessionDescription(
            offerData['sdp'],
            offerData['type'],
          );
          
          _logger.info('📥 Received remote offer');
          onRemoteOffer?.call(offer);
        }
        
        // Handle answer
        if (data.containsKey('answer') && _isOfferingPeer) {
          final answerData = data['answer'] as Map<String, dynamic>;
          final answer = RTCSessionDescription(
            answerData['sdp'],
            answerData['type'],
          );
          
          _logger.info('📥 Received remote answer');
          onRemoteAnswer?.call(answer);
        }
      },
      onError: (error) {
        _logger.error('❌ Error listening to room: $error');
        onError?.call('Error listening to room: $error');
      },
    );
  }

  /// Setup candidates listeners
  void _setupCandidatesListeners() {
    // Listen for candidates from remote peer
    listenForRemoteCandidates();
  }

  /// Clean up room and close all connections
  Future<void> cleanup() async {
    try {
      _logger.info('🧹 Cleaning up Firestore signaling');
      
      // Cancel listeners
      await _roomListener?.cancel();
      await _localCandidatesListener?.cancel();
      await _remoteCandidatesListener?.cancel();
      
      // Delete room document and sub-collections
      if (_roomId != null) {
        await _deleteRoom(_roomId!);
      }
      
      // Reset state
      _roomId = null;
      _localPeerId = null;
      _isOfferingPeer = false;
      
      _logger.success('✅ Firestore signaling cleaned up');
    } catch (e) {
      _logger.error('❌ Error during cleanup: $e');
    }
  }

  /// Delete room document and all sub-collections
  Future<void> _deleteRoom(String roomId) async {
    try {
      final batch = _firestore.batch();
      
      // Delete candidates sub-collections
      final candidatesRef = _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('candidates');
      
      final candidatesDocs = await candidatesRef.get();
      for (final doc in candidatesDocs.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete room document
      final roomRef = _firestore.collection('rooms').doc(roomId);
      batch.delete(roomRef);
      
      await batch.commit();
      _logger.info('🗑️ Room deleted: $roomId');
    } catch (e) {
      _logger.error('❌ Failed to delete room: $e');
    }
  }

  /// Generate unique room ID
  String _generateRoomId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (1000 + (999 * (DateTime.now().microsecond / 1000000))).floor().toString();
  }

  /// Generate unique peer ID
  String _generatePeerId() {
    return 'peer_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  /// Disconnect from current room (alias for cleanup)
  void disconnect() {
    cleanup();
  }

  /// Dispose resources
  void dispose() {
    cleanup();
  }
}
