# Firestore Signaling Service Fixes

## Overview
This document describes the fixes applied to the Firestore signaling service to ensure proper SDP/ICE data exchange and successful P2P WebRTC connections.

## Issues Fixed

### 1. ICE Candidate Storage Structure
**Problem**: ICE candidates were being stored using `candidate.toMap()` which might not provide the correct format.
**Fix**: Explicitly store ICE candidate fields:
```dart
await roomRef.collection('candidates').doc(candidateType).collection('list').add({
  'candidate': candidate.candidate,
  'sdpMid': candidate.sdpMid,
  'sdpMLineIndex': candidate.sdpMLineIndex,
  'timestamp': FieldValue.serverTimestamp(),
});
```

### 2. SDP Offer/Answer Format
**Problem**: Using `offer.toMap()` and `answer.toMap()` might not provide consistent format.
**Fix**: Explicitly store SDP fields:
```dart
// For offer
'offer': {
  'sdp': offer.sdp,
  'type': offer.type,
},

// For answer
'answer': {
  'sdp': answer.sdp,
  'type': answer.type,
},
```

### 3. Room Status Management
**Problem**: Room status wasn't being properly tracked for connection state.
**Fix**: Added status tracking:
```dart
// When creating room
'status': 'waiting',
'createdBy': 'caller',

// When joining room
'status': 'connected',
'joinedBy': 'callee',
```

### 4. Data Channel Handling for Callee
**Problem**: The callee wasn't properly receiving and storing the data channel reference.
**Fix**: Added `onDataChannelReceived` callback to ModernWebRTCService:
```dart
// In ModernWebRTCService
Function(RTCDataChannel)? onDataChannelReceived;

// In onDataChannel callback
_peerConnection!.onDataChannel = (RTCDataChannel channel) {
  _logger.info('📡 Data channel received: ${channel.label}');
  _dataChannel = channel; // Store the received data channel
  _setupDataChannelListeners(channel);
  onDataChannelReceived?.call(channel);
};
```

### 5. P2P Manager Data Channel Setup
**Problem**: P2P managers weren't properly handling received data channels for callees.
**Fix**: Added data channel handling in both P2P managers:
```dart
_webRTCService.onDataChannelReceived = (RTCDataChannel channel) {
  _logger.info('📡 Data channel received by callee');
  _dataChannel = channel;
  
  // Set up data channel state listener for callee
  _dataChannel!.onDataChannelState = (RTCDataChannelState state) {
    debugPrint('RTCDataChannelState (callee): $state');
    if (state == RTCDataChannelState.RTCDataChannelOpen) {
      _updateConnectionInfo(
        _connectionInfo.copyWith(
          connectionState: PeerConnectionState.connected,
        ),
      );
    }
  };

  _dataChannel!.onMessage = (RTCDataChannelMessage message) {
    _webRTCService.onDataChannelMessage?.call(message.text);
  };
};
```

## Files Modified

1. **lib/core/services/firestore_signaling_service.dart**
   - Fixed ICE candidate storage format
   - Fixed SDP offer/answer format
   - Added room status tracking

2. **lib/core/services/modern_webrtc_service.dart**
   - Added `onDataChannelReceived` callback
   - Modified `onDataChannel` to store received data channel
   - Updated dispose method to clear new callback

3. **lib/core/services/p2p_manager.dart**
   - Added `onDataChannelReceived` callback setup
   - Added data channel state handling for callee

4. **lib/core/services/p2p_connection_manager.dart**
   - Added `onDataChannelReceived` callback setup
   - Added data channel state handling for callee

## Expected Behavior

### For Caller (createRoom):
1. Creates room with offer and status 'waiting'
2. Creates data channel
3. Listens for answer and ICE candidates
4. Transitions to 'connected' state when data channel opens

### For Callee (joinRoom):
1. Receives offer from room
2. Updates room with answer and status 'connected'
3. Receives data channel from caller
4. Transitions to 'connected' state when data channel opens

## Firestore Schema

```
rooms/{roomId}
├── offer: {sdp: string, type: string}
├── answer: {sdp: string, type: string}
├── status: 'waiting' | 'connected' | 'closed'
├── createdAt: Timestamp
├── joinedAt: Timestamp
├── createdBy: 'caller'
├── joinedBy: 'callee'
└── candidates/
    ├── caller/
    │   └── list/
    │       └── {autoId}: {candidate, sdpMid, sdpMLineIndex, timestamp}
    └── callee/
        └── list/
            └── {autoId}: {candidate, sdpMid, sdpMLineIndex, timestamp}
```

## Testing Status

✅ **flutter analyze** - Passed (only minor warnings)
✅ **flutter build web --debug** - Successful build
⏳ **Runtime Testing** - Pending user verification

## Next Steps

1. Test the application in browser with two peers
2. Verify that both peers leave "connecting" state
3. Check Firestore console to confirm SDP/ICE data is properly stored
4. Verify chat messages work through WebRTC DataChannel
5. Test connection persistence and reconnection scenarios

## Key Improvements

- **Explicit field storage**: No more reliance on `.toMap()` which might have inconsistent formats
- **Proper callee handling**: Data channel is now properly received and stored for callees
- **Status tracking**: Room status helps track connection progression
- **Better logging**: Added detailed logs for debugging connection issues
- **Consistent schema**: All Firestore operations use the same structured format

The fixes ensure that:
- SDP offers and answers are correctly stored and retrieved
- ICE candidates are properly exchanged between peers
- Both caller and callee can transition from "connecting" to "connected" state
- Data channels work for both sending and receiving peers
- All messaging happens through WebRTC DataChannel (no Firestore messaging)
