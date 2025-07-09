import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../utils/app_logger.dart';

/// Firestore-based signaling service for P2P WebRTC connections
/// Schema implementation:
/// rooms/{roomId}
///   offer        (Map)
///   answer       (Map)
///   createdBy    (String uid)
///   createdAt    (Timestamp)
///   status       (String: 'waiting' | 'connected' | 'closed')
///   candidates/
///       caller/{autoId}   (Map)
///       callee/{autoId}   (Map)
class FirestoreSignalingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppLogger _logger = AppLogger();

  /// Create a new room with proper schema and store the offer
  /// Returns the generated room ID
  Future<String> createRoom(RTCSessionDescription offer) async {
    try {
      _logger.info('🏠 Creating Firestore room');
      
      final roomRef = _firestore.collection('rooms').doc();
      final roomId = roomRef.id;
      
      await roomRef.set({
        'offer': {
          'sdp': offer.sdp,
          'type': offer.type,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'waiting',
        'createdBy': 'caller',
      });
      
      _logger.success('✅ Room created successfully: $roomId');
      return roomId;
    } catch (e) {
      _logger.error('❌ Failed to create room: $e');
      rethrow;
    }
  }

  /// Join an existing room by setting the answer and updating participant info
  Future<void> joinRoom(String roomId, RTCSessionDescription answer) async {
    try {
      _logger.info('🚪 Joining room $roomId');
      
      final roomRef = _firestore.collection('rooms').doc(roomId);
      
      await roomRef.update({
        'answer': {
          'sdp': answer.sdp,
          'type': answer.type,
        },
        'joinedAt': FieldValue.serverTimestamp(),
        'status': 'connected',
        'joinedBy': 'callee',
      });
      
      _logger.success('✅ Successfully joined room: $roomId');
    } catch (e) {
      _logger.error('❌ Failed to join room: $e');
      rethrow;
    }
  }

  /// Send ICE candidate using proper schema structure
  Future<void> sendIceCandidate(String roomId, RTCIceCandidate candidate, bool isCaller) async {
    try {
      _logger.info('🧊 Sending ICE candidate (isCaller: $isCaller)');
      
      final roomRef = _firestore.collection('rooms').doc(roomId);
      final candidateType = isCaller ? 'caller' : 'callee';
      
      await roomRef.collection('candidates').doc(candidateType).collection('list').add({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      _logger.success('✅ ICE candidate sent');
    } catch (e) {
      _logger.error('❌ Failed to send ICE candidate: $e');
      rethrow;
    }
  }

  /// Listen for remote offer using enhanced schema
  Stream<RTCSessionDescription> onRemoteOffer(String roomId) {
    _logger.info('👂 Listening for remote offer in room: $roomId');
    
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .snapshots()
        .where((snapshot) => snapshot.exists && snapshot.data()!.containsKey('offer'))
        .map((snapshot) {
          final data = snapshot.data()!;
          final offer = data['offer'] as Map<String, dynamic>;
          
          _logger.info('📥 Received remote offer');
          return RTCSessionDescription(
            offer['sdp'] as String,
            offer['type'] as String,
          );
        });
  }

  /// Listen for remote answer using enhanced schema
  Stream<RTCSessionDescription> onRemoteAnswer(String roomId) {
    _logger.info('👂 Listening for remote answer in room: $roomId');
    
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .snapshots()
        .where((snapshot) => snapshot.exists && snapshot.data()!.containsKey('answer'))
        .map((snapshot) {
          final data = snapshot.data()!;
          final answer = data['answer'] as Map<String, dynamic>;
          
          _logger.info('📥 Received remote answer');
          return RTCSessionDescription(
            answer['sdp'] as String,
            answer['type'] as String,
          );
        });
  }

  /// Listen for remote ICE candidates using proper schema structure
  Stream<RTCIceCandidate> onRemoteIce(String roomId, bool isCaller) {
    _logger.info('👂 Listening for remote ICE (isCaller: $isCaller)');
    
    // Listen to the opposite collection (caller listens to callee candidates and vice versa)
    final candidateType = isCaller ? 'callee' : 'caller';
    
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('candidates')
        .doc(candidateType)
        .collection('list')
        .snapshots()
        .expand((snapshot) => snapshot.docChanges)
        .where((change) => change.type == DocumentChangeType.added)
        .map((change) {
          final data = change.doc.data()!;
          
          _logger.info('🧊 Received remote ICE candidate');
          return RTCIceCandidate(
            data['candidate'] as String?,
            data['sdpMid'] as String?,
            data['sdpMLineIndex'] as int?,
          );
        });
  }

  /// Close and cleanup room using proper schema
  Future<void> closeRoom(String roomId) async {
    try {
      _logger.info('🗑️ Closing room with schema cleanup: $roomId');
      
      final roomRef = _firestore.collection('rooms').doc(roomId);
      
      // Update room status first
      await roomRef.update({
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
      });
      
      // Delete caller candidates
      final callerCandidates = await roomRef
          .collection('candidates')
          .doc('caller')
          .collection('list')
          .get();
      for (final doc in callerCandidates.docs) {
        await doc.reference.delete();
      }
      
      // Delete callee candidates
      final calleeCandidates = await roomRef
          .collection('candidates')
          .doc('callee')
          .collection('list')
          .get();
      for (final doc in calleeCandidates.docs) {
        await doc.reference.delete();
      }
      
      // Delete candidates structure
      await roomRef.collection('candidates').doc('caller').delete();
      await roomRef.collection('candidates').doc('callee').delete();
      
      // Finally delete the room document
      await roomRef.delete();
      
      _logger.success('✅ Room closed with full schema cleanup: $roomId');
    } catch (e) {
      _logger.error('❌ Failed to close room: $e');
      rethrow;
    }
  }

  /// Check if room exists and get its status
  Future<Map<String, dynamic>?> getRoomInfo(String roomId) async {
    try {
      final doc = await _firestore.collection('rooms').doc(roomId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      _logger.error('❌ Failed to get room info: $e');
      return null;
    }
  }

  /// Check if room exists
  Future<bool> roomExists(String roomId) async {
    try {
      final doc = await _firestore.collection('rooms').doc(roomId).get();
      return doc.exists;
    } catch (e) {
      _logger.error('❌ Failed to check room existence: $e');
      return false;
    }
  }

  /// Get room status
  Future<String?> getRoomStatus(String roomId) async {
    try {
      final doc = await _firestore.collection('rooms').doc(roomId).get();
      if (doc.exists) {
        return doc.data()?['status'] as String?;
      }
      return null;
    } catch (e) {
      _logger.error('❌ Failed to get room status: $e');
      return null;
    }
  }

  /// Dispose and cleanup resources
  void dispose() {
    _logger.info('🗑️ Disposing FirestoreSignalingService');
    // No specific cleanup needed for Firestore, but method is required by P2PManager
  }
}