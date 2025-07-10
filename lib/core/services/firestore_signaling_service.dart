import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../utils/app_logger.dart';

/// Firestore-based signaling service for P2P WebRTC connections
class FirestoreSignalingService {
  final _db = FirebaseFirestore.instance;
  final AppLogger _logger = AppLogger();

  /// Create a new room with proper schema and store the offer
  /// Returns the generated room ID
  Future<String> createRoom(RTCSessionDescription offer) async {
    try {
      _logger.info('🏠 Creating Firestore room');
      
      final roomRef = _db.collection('rooms').doc();          // auto-id
      await roomRef.set({
        'offer': offer.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      _logger.success('✅ Room created successfully: ${roomRef.id}');
      return roomRef.id;
    } catch (e) {
      _logger.error('❌ Failed to create room: $e');
      rethrow;
    }
  }

  /// Join an existing room by setting the answer and updating participant info
  Future<void> joinRoom(String roomId, RTCSessionDescription answer) async {
    try {
      _logger.info('🚪 Joining room $roomId');
      
      final roomRef = _db.collection('rooms').doc(roomId);
      await roomRef.update({
        'answer': answer.toMap(),
        'joinedAt': FieldValue.serverTimestamp(),
      });
      
      _logger.success('✅ Successfully joined room: $roomId');
    } catch (e) {
      _logger.error('❌ Failed to join room: $e');
      rethrow;
    }
  }

  /// Send ICE candidate using proper schema structure
  Future<void> sendIceCandidate(String roomId, RTCIceCandidate c, bool isCaller) async {
    try {
      _logger.info('🧊 Sending ICE candidate (isCaller: $isCaller)');
      
      await _db
          .collection('rooms')
          .doc(roomId)
          .collection('candidates')
          .doc(isCaller ? 'caller' : 'callee')
          .collection('list')
          .add(c.toMap());
      
      _logger.success('✅ ICE candidate sent');
    } catch (e) {
      _logger.error('❌ Failed to send ICE candidate: $e');
      rethrow;
    }
  }

  // --- listeners ---
  Stream<RTCSessionDescription> onRemoteOffer(String roomId) {
    _logger.info('👂 Listening for remote offer in room: $roomId');
    
    return _db.doc('rooms/$roomId').snapshots().where((s) =>
        s.data()?['offer'] != null).map((s) {
      _logger.info('📥 Received remote offer');
      return RTCSessionDescription(
        s['offer']['sdp'], s['offer']['type']);
    });
  }

  Stream<RTCSessionDescription> onRemoteAnswer(String roomId) {
    _logger.info('👂 Listening for remote answer in room: $roomId');
    
    return _db.doc('rooms/$roomId').snapshots().where((s) =>
        s.data()?['answer'] != null).map((s) {
      _logger.info('📥 Received remote answer');
      return RTCSessionDescription(
        s['answer']['sdp'], s['answer']['type']);
    });
  }

  Stream<RTCIceCandidate> onRemoteIce(String roomId, bool isCaller) {
    _logger.info('👂 Listening for remote ICE (isCaller: $isCaller)');
    
    return _db
        .collection('rooms/$roomId/candidates/${isCaller ? 'callee' : 'caller'}/list')
        .snapshots()
        .expand((q) => q.docChanges)
        .map((c) {
      _logger.info('🧊 Received remote ICE candidate');
      return RTCIceCandidate(
        c.doc['candidate'],
        c.doc['sdpMid'],
        c.doc['sdpMLineIndex'],
      );
    });
  }

  /// Close and cleanup room using proper schema
  Future<void> closeRoom(String roomId) async {
    try {
      _logger.info('🗑️ Closing room: $roomId');
      
      final roomRef = _db.collection('rooms').doc(roomId);
      await roomRef.delete();
      
      _logger.success('✅ Room closed: $roomId');
    } catch (e) {
      _logger.error('❌ Failed to close room: $e');
      rethrow;
    }
  }

  /// Check if room exists and get its status
  Future<Map<String, dynamic>?> getRoomInfo(String roomId) async {
    try {
      final doc = await _db.collection('rooms').doc(roomId).get();
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
      final doc = await _db.collection('rooms').doc(roomId).get();
      return doc.exists;
    } catch (e) {
      _logger.error('❌ Failed to check room existence: $e');
      return false;
    }
  }

  /// Get room status
  Future<String?> getRoomStatus(String roomId) async {
    try {
      final doc = await _db.collection('rooms').doc(roomId).get();
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