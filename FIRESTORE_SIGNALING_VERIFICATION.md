# Firestore Signaling Verification Guide

## Overview
This guide helps verify that the Firestore signaling service fixes are working correctly and that peers successfully leave the "connecting" state.

## Setup Requirements

### 1. Firebase Console Access
- Open [Firebase Console](https://console.firebase.google.com/)
- Navigate to your project
- Go to **Firestore Database**
- Ensure you can see the `rooms` collection

### 2. Two Browser Windows/Tabs
- **Caller Window**: Will create the room
- **Callee Window**: Will join the room

## Testing Steps

### Phase 1: Room Creation (Caller)
1. Open the app in the first browser window
2. Click "Create Room" or equivalent button
3. **Verify in Firebase Console**:
   - New document appears in `rooms` collection
   - Document contains:
     ```json
     {
       "offer": {
         "sdp": "v=0\r\no=...",
         "type": "offer"
       },
       "status": "waiting",
       "createdBy": "caller",
       "createdAt": "2025-01-XX..."
     }
     ```
4. **Verify in App**:
   - Room ID is displayed
   - Status shows "Connecting..."
   - No errors in browser console

### Phase 2: Room Joining (Callee)
1. Copy the room ID from the caller window
2. Open the app in the second browser window
3. Enter the room ID and click "Join Room"
4. **Verify in Firebase Console**:
   - Same room document now contains:
     ```json
     {
       "offer": {...},
       "answer": {
         "sdp": "v=0\r\no=...",
         "type": "answer"
       },
       "status": "connected",
       "createdBy": "caller",
       "joinedBy": "callee",
       "createdAt": "2025-01-XX...",
       "joinedAt": "2025-01-XX..."
     }
     ```
5. **Verify in App**:
   - Callee status shows "Connecting..." initially
   - Both peers should show "Connected" status within 5-10 seconds

### Phase 3: ICE Candidate Exchange
1. **Verify in Firebase Console**:
   - `candidates` subcollection appears under the room
   - Contains `caller` and `callee` documents
   - Each contains `list` subcollection with ICE candidates:
     ```json
     {
       "candidate": "candidate:1 1 UDP 2130706431 192.168.1.100 54400 typ host",
       "sdpMid": "0",
       "sdpMLineIndex": 0,
       "timestamp": "2025-01-XX..."
     }
     ```

### Phase 4: Data Channel Connection
1. **Verify in Browser Console**:
   - Look for messages like:
     ```
     📡 Data channel received: chat
     RTCDataChannelState: open
     🎉 P2P connection established!
     ```

2. **Verify in App UI**:
   - Both peers show "Connected" status
   - Message input field is enabled
   - Connection indicator is green/active

### Phase 5: Message Exchange
1. Send a message from caller to callee
2. Send a message from callee to caller
3. **Verify in App**:
   - Messages appear in both windows
   - Messages are NOT stored in Firestore (only in UI)
   - No new documents appear in Firebase Console

## Troubleshooting

### Issue: Peers Stay in "Connecting" State
**Possible Causes**:
1. ICE candidates not being exchanged
2. Data channel not opening properly
3. STUN/TURN server issues

**Debug Steps**:
1. Check browser console for WebRTC errors
2. Verify ICE candidates in Firestore
3. Test on different networks
4. Check if TURN server is accessible

### Issue: No Data in Firestore
**Possible Causes**:
1. Firestore security rules too restrictive
2. Firebase not properly initialized
3. Network connectivity issues

**Debug Steps**:
1. Check Firestore security rules
2. Verify Firebase configuration
3. Test with different browsers

### Issue: Messages Not Sent/Received
**Possible Causes**:
1. Data channel not established
2. Message format issues
3. Event handlers not properly set up

**Debug Steps**:
1. Verify data channel state in console
2. Check message format in network logs
3. Verify event handlers are registered

## Expected Firestore Structure

```
rooms/
└── {roomId}/
    ├── offer: {sdp, type}
    ├── answer: {sdp, type}
    ├── status: "connected"
    ├── createdBy: "caller"
    ├── joinedBy: "callee"
    ├── createdAt: Timestamp
    ├── joinedAt: Timestamp
    └── candidates/
        ├── caller/
        │   └── list/
        │       ├── {autoId1}: {candidate, sdpMid, sdpMLineIndex, timestamp}
        │       └── {autoId2}: {candidate, sdpMid, sdpMLineIndex, timestamp}
        └── callee/
            └── list/
                ├── {autoId1}: {candidate, sdpMid, sdpMLineIndex, timestamp}
                └── {autoId2}: {candidate, sdpMid, sdpMLineIndex, timestamp}
```

## Success Criteria

✅ **SDP Exchange**: Offer and answer properly stored in Firestore
✅ **ICE Exchange**: ICE candidates appear in both caller and callee collections
✅ **Status Transition**: Both peers move from "connecting" to "connected"
✅ **Data Channel**: Messages can be sent and received
✅ **No Firestore Messaging**: Only signaling data in Firestore, no chat messages

## Performance Expectations

- **Connection Time**: Should connect within 5-10 seconds
- **Message Latency**: Messages should appear instantly (P2P direct connection)
- **Firestore Usage**: Only for signaling, not for message storage

## Browser Console Commands

```javascript
// Check WebRTC connection state
console.log('PeerConnection state:', pc.connectionState);

// Check data channel state
console.log('DataChannel state:', dataChannel.readyState);

// Monitor ICE candidates
pc.onicecandidate = (event) => {
  if (event.candidate) {
    console.log('ICE candidate:', event.candidate);
  }
};
```

## Common Issues and Solutions

1. **CORS Issues**: Ensure proper web server setup
2. **Network Restrictions**: Test on different networks
3. **Browser Compatibility**: Test on Chrome/Firefox/Safari
4. **Firebase Limits**: Check Firestore quotas and limits
5. **WebRTC Support**: Verify browser WebRTC support

By following this guide, you should be able to verify that the Firestore signaling service is working correctly and that peers successfully establish P2P connections.
