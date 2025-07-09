# 🔍 Debugging Guide - Connection State "Connecting"

## Problem: App stuck in "Connecting" state

### Root Cause Analysis

The most common reason for being stuck in "Connecting" state is **Firebase configuration issue**.

### 1. Check Firebase Configuration

**Problem**: The current `lib/firebase_options.dart` contains fake/demo configuration.

**Solution**: Replace it with your real Firebase project configuration.

#### Steps to Fix:

1. **Create Firebase Project**:
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create new project named "globgram-p2p"
   - Enable Firestore Database in test mode

2. **Generate Real Configuration**:
   ```bash
   # Install FlutterFire CLI
   dart pub global activate flutterfire_cli
   
   # Generate real firebase_options.dart
   flutterfire configure
   ```

3. **Replace the fake file**:
   - Replace `lib/firebase_options.dart` with the generated file
   - The current file contains demo keys that won't work

### 2. Check Browser Console

Open browser DevTools (F12) and check for errors:

#### Expected Firebase Errors:
- `FirebaseError: Firebase: No Firebase App '[DEFAULT]' has been created`
- `FirebaseError: Firebase: Error (auth/invalid-api-key)`
- `FirebaseError: PERMISSION_DENIED: Missing or insufficient permissions`

#### Expected WebRTC Errors:
- `Failed to execute 'createOffer' on RTCPeerConnection`
- `InvalidStateError: Failed to execute 'setLocalDescription'`

### 3. Debug Output

The app now includes detailed logging:

```
🏠 Creating room as caller
🔧 Initializing WebRTC...
✅ WebRTC initialized
📡 Creating data channel...
✅ Data channel created
📤 Creating offer...
✅ Offer created and set
🏠 Creating room in Firestore...
❌ Failed to create room: [FirebaseError]
```

### 4. Temporary Local Testing

If you want to test without Firebase:

1. **Mock the signaling service**:
   - Comment out Firebase initialization in `main.dart`
   - Create a local mock implementation

2. **Use localStorage for testing**:
   - Replace Firestore with browser localStorage
   - Test WebRTC connections locally

### 5. Firestore Security Rules

Make sure your Firestore rules allow read/write:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /rooms/{roomId} {
      allow read, write: if true; // For testing only
    }
  }
}
```

### 6. WebRTC STUN/TURN Servers

Current configuration uses:
- `stun:stun.l.google.com:19302` (free)
- `turn:relay.metered.ca:80` (free tier)

If connection fails, try:
- `stun:stun1.l.google.com:19302`
- `stun:stun2.l.google.com:19302`

### 7. Network Connectivity

Check if your network blocks WebRTC:
- Try on different network
- Check corporate firewall settings
- Test on mobile hotspot

### 8. Browser Compatibility

Ensure you're using supported browser:
- ✅ Chrome/Chromium
- ✅ Firefox
- ✅ Safari (with limitations)
- ❌ Internet Explorer

### 9. Quick Fix Steps

1. **Replace firebase_options.dart** with real configuration
2. **Check browser console** for errors
3. **Test Firebase connection** separately
4. **Verify Firestore rules**
5. **Try different network**

### 10. Expected Working Flow

When everything works correctly:

1. User clicks "Create Room"
2. WebRTC initializes
3. Firebase creates room document
4. App shows "Waiting for peer"
5. When peer joins → "Connected"

Current issue: Step 3 fails due to Firebase configuration.
