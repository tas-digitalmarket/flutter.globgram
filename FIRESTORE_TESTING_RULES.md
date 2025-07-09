# Firestore Security Rules for Testing

## Overview
During development and testing of the P2P WebRTC signaling, we need to use permissive Firestore security rules to allow unrestricted access to the rooms collection and ICE candidates.

## Testing Rules

### Current Testing Rules (Use for Development)
```javascript
rules_version = '2';
service cloud.firestore {
  match /{document=**} { 
    allow read, write: if true; 
  }
}
```

⚠️ **WARNING**: These rules allow anyone to read and write to your entire Firestore database. Use ONLY for development and testing.

## How to Apply Testing Rules

### 1. Firebase Console Method
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Firestore Database**
4. Click on the **Rules** tab
5. Replace the existing rules with the testing rules above
6. Click **Publish**

### 2. Firebase CLI Method
```bash
# Save rules to firestore.rules file
echo 'rules_version = "2";
service cloud.firestore {
  match /{document=**} { 
    allow read, write: if true; 
  }
}' > firestore.rules

# Deploy rules
firebase deploy --only firestore:rules
```

## Testing Workflow

### Phase 1: Deploy Testing Rules
1. Apply the permissive rules above
2. Verify deployment in Firebase Console
3. Ensure rules are active (may take a few minutes)

### Phase 2: Test P2P Connection
1. **Open two browser windows/tabs**
2. **Caller Window**: 
   - Create room
   - Note the room ID
   - Status should show "Connecting..."
3. **Callee Window**:
   - Join room with the room ID
   - Status should show "Connecting..." initially
   - Both should transition to "Connected" within 10 seconds

### Phase 3: Verify Firestore Data
Check Firebase Console for:
```
rooms/{roomId}
├── offer: {sdp: "v=0...", type: "offer"}
├── answer: {sdp: "v=0...", type: "answer"}
├── status: "connected"
├── createdBy: "caller"
├── joinedBy: "callee"
├── createdAt: Timestamp
├── joinedAt: Timestamp
└── candidates/
    ├── caller/
    │   └── list/
    │       └── {autoId}: {candidate: "...", sdpMid: "0", sdpMLineIndex: 0}
    └── callee/
        └── list/
            └── {autoId}: {candidate: "...", sdpMid: "0", sdpMLineIndex: 0}
```

### Phase 4: Test Messaging
1. Send messages between peers
2. Verify messages appear in both windows
3. Confirm NO message data appears in Firestore (only signaling data)

## Production Rules (Apply After Testing)

### Secure Rules for Production
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read/write to rooms collection
    match /rooms/{roomId} {
      allow read, write: if true; // TODO: Add proper authentication
      
      // Allow read/write to candidates subcollection
      match /candidates/{candidateType}/list/{candidateId} {
        allow read, write: if true; // TODO: Add proper authentication
      }
    }
  }
}
```

### Enhanced Security Rules (Future)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Rooms collection with time-based access
    match /rooms/{roomId} {
      allow read, write: if request.time < resource.data.createdAt + duration.value(1, 'h');
      
      // ICE candidates with room-based access
      match /candidates/{candidateType}/list/{candidateId} {
        allow read, write: if request.time < get(/databases/$(database)/documents/rooms/$(roomId)).data.createdAt + duration.value(1, 'h');
      }
    }
  }
}
```

## Troubleshooting Rules Issues

### Issue: Permission Denied Errors
**Symptoms**: 
- Console errors about permission denied
- Signaling fails to work
- No data appears in Firestore

**Solutions**:
1. Verify rules are deployed correctly
2. Check Firebase Console Rules tab
3. Wait 2-3 minutes for rules to propagate
4. Clear browser cache and reload

### Issue: Rules Not Taking Effect
**Symptoms**:
- Old rules still active
- Changes not reflected in behavior

**Solutions**:
1. Check deployment status in Firebase Console
2. Verify rules syntax (no syntax errors)
3. Use Firebase CLI to force redeploy
4. Check Firebase project is correct

## Rule Validation Commands

### Test Rules with Firebase CLI
```bash
# Test read operation
firebase firestore:rules:test --data-file=test-data.json

# Test write operation  
firebase firestore:rules:test --data-file=test-data.json --operation=write
```

### Example Test Data (`test-data.json`)
```json
{
  "auth": null,
  "request": {
    "time": "2025-01-09T10:00:00Z",
    "resource": {
      "data": {
        "offer": {"sdp": "v=0...", "type": "offer"},
        "createdAt": "2025-01-09T10:00:00Z",
        "status": "waiting"
      }
    }
  }
}
```

## Security Considerations

### During Testing
- ✅ Use testing rules for development
- ✅ Test with multiple browser windows
- ✅ Verify all signaling data flows correctly
- ⚠️ Do not use testing rules in production

### For Production
- 🔒 Implement proper authentication
- 🔒 Add time-based access controls
- 🔒 Restrict access to specific collections
- 🔒 Add rate limiting for writes
- 🔒 Validate data structure and content

## Quick Setup Commands

```bash
# 1. Set up Firebase project (if not done)
firebase login
firebase init firestore

# 2. Apply testing rules
echo 'rules_version = "2";
service cloud.firestore {
  match /{document=**} { allow read, write: if true; }
}' > firestore.rules

# 3. Deploy rules
firebase deploy --only firestore:rules

# 4. Start Flutter web app
flutter run -d web-server --web-port 8080
```

## Expected Behavior with Testing Rules

✅ **Create Room**: Should work without authentication
✅ **Join Room**: Should work without authentication  
✅ **ICE Exchange**: Should work without restrictions
✅ **Data Persistence**: All signaling data should be stored
✅ **Room Cleanup**: Should work without permissions issues

The testing rules remove all security barriers, allowing you to focus on verifying the P2P connection logic works correctly before implementing proper authentication and security measures.
