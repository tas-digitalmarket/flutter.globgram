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
      _logger.debug('🔍 Offer SDP length: ${offer.sdp?.length ?? 0}');
      _logger.debug('🔍 Offer type: ${offer.type}');
      
      final roomRef = _db.collection('rooms').doc();          // auto-id
      final roomData = {
        'offer': offer.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'waiting_for_answer',
      };
      
      _logger.debug('🔍 Room data to save: ${roomData.keys.toList()}');
      await roomRef.set(roomData);
      
      // Verify the data was saved
      final savedDoc = await roomRef.get();
      if (savedDoc.exists) {
        final data = savedDoc.data();
        _logger.success('✅ Room data verified in Firestore:');
        _logger.debug('  📊 Has offer: ${data?['offer'] != null}');
        _logger.debug('  📊 Status: ${data?['status']}');
        _logger.debug('  📊 Created at: ${data?['createdAt']}');
      } else {
        _logger.error('❌ Room document not found after creation!');
      }
      
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
      _logger.debug('🔍 Answer SDP length: ${answer.sdp?.length ?? 0}');
      _logger.debug('🔍 Answer type: ${answer.type}');
      
      final roomRef = _db.collection('rooms').doc(roomId);
      
      // First check if room exists
      final roomDoc = await roomRef.get();
      if (!roomDoc.exists) {
        throw Exception('Room $roomId does not exist');
      }
      
      final roomData = roomDoc.data();
      _logger.debug('🔍 Room before join:');
      _logger.debug('  📊 Has offer: ${roomData?['offer'] != null}');
      _logger.debug('  📊 Has answer: ${roomData?['answer'] != null}');
      _logger.debug('  📊 Status: ${roomData?['status']}');
      
      await roomRef.update({
        'answer': answer.toMap(),
        'joinedAt': FieldValue.serverTimestamp(),
        'status': 'answer_provided',
      });
      
      // Verify the answer was saved
      final updatedDoc = await roomRef.get();
      final updatedData = updatedDoc.data();
      _logger.success('✅ Room updated in Firestore:');
      _logger.debug('  📊 Has offer: ${updatedData?['offer'] != null}');
      _logger.debug('  📊 Has answer: ${updatedData?['answer'] != null}');
      _logger.debug('  📊 Status: ${updatedData?['status']}');
      
      _logger.success('✅ Successfully joined room: $roomId');
    } catch (e) {
      _logger.error('❌ Failed to join room: $e');
      rethrow;
    }
  }

  /// Send ICE candidate using proper schema structure
  Future<void> sendIceCandidate(String roomId, RTCIceCandidate c, bool isCaller) async {
    try {
      _logger.info('🧊 Sending ICE candidate: ${isCaller ? "caller" : "callee"} -> room: $roomId');
      _logger.debug('🔍 ICE candidate: ${c.candidate}');
      _logger.debug('🔍 ICE sdpMid: ${c.sdpMid}');
      _logger.debug('🔍 ICE sdpMLineIndex: ${c.sdpMLineIndex}');
      
      await _db
          .collection('rooms')
          .doc(roomId)
          .collection('candidates')
          .doc(isCaller ? 'caller' : 'callee')
          .collection('list')
          .add(c.toMap());
          
      _logger.success('✅ ICE candidate sent successfully');
    } catch (e) {
      _logger.error('❌ Failed to send ICE candidate: $e');
      rethrow;
    }
  }

  // --- listeners ---
  Stream<RTCSessionDescription> onRemoteOffer(String roomId) {
    _logger.info('👂 Listening for remote offer in room: $roomId');
    
    // First, check if offer already exists, then listen for changes
    return _db.doc('rooms/$roomId').snapshots()
        .where((s) => s.exists && s.data() != null && s.data()!['offer'] != null)
        .take(1) // Only take the first valid offer
        .map((s) {
      final data = s.data()!;
      _logger.success('📥 Found remote offer in Firestore!');
      _logger.debug('📊 Offer data keys: ${data['offer']?.keys?.toList() ?? []}');
      _logger.debug('📊 SDP length: ${data['offer']?['sdp']?.length ?? 0}');
      _logger.debug('📊 SDP type: ${data['offer']?['type']}');
      
      return RTCSessionDescription(
        data['offer']['sdp'], data['offer']['type']);
    });
  }

  Stream<RTCSessionDescription> onRemoteAnswer(String roomId) {
    _logger.info('👂 Listening for remote answer in room: $roomId');
    
    return _db.doc('rooms/$roomId').snapshots()
        .where((s) => s.exists && s.data() != null && s.data()!['answer'] != null)
        .map((s) {
      final data = s.data()!;
      _logger.success('📥 Found remote answer in Firestore!');
      _logger.debug('📊 Answer data keys: ${data['answer']?.keys?.toList() ?? []}');
      _logger.debug('📊 SDP length: ${data['answer']?['sdp']?.length ?? 0}');
      _logger.debug('📊 SDP type: ${data['answer']?['type']}');
      
      return RTCSessionDescription(
        data['answer']['sdp'], data['answer']['type']);
    });
  }

  Stream<RTCIceCandidate> onRemoteIce(
    String roomId, bool isCaller) {
    _logger.info('👂 Listening for remote ICE candidates: ${isCaller ? "callee" : "caller"} -> room: $roomId');
    
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('candidates')
        .doc(isCaller ? 'callee' : 'caller')
        .collection('list')
        .snapshots()
        .map((querySnapshot) {
          _logger.info('🧊 ICE snapshot received with ${querySnapshot.docs.length} docs');
          return querySnapshot.docChanges;
        })
        .expand((changes) => changes)
        .map((chg) {
          _logger.success('📥 Received remote ICE candidate: ${chg.doc.data()}');
          return RTCIceCandidate(
                chg.doc['candidate'],
                chg.doc['sdpMid'],
                chg.doc['sdpMLineIndex'],
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

  /// Generate a room ID without creating the room yet
  /// This allows setting _currentRoomId before ICE gathering starts
  String generateRoomId() {
    return _db.collection('rooms').doc().id;
  }

  /// Create a room with a pre-generated ID and offer
  Future<void> createRoomWithId(String roomId, RTCSessionDescription offer) async {
    try {
      _logger.info('🏠 Creating Firestore room with ID: $roomId');
      _logger.debug('🔍 Offer SDP length: ${offer.sdp?.length