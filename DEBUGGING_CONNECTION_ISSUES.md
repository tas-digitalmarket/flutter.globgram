# Debugging WebRTC Connection Issues

## Common Issues and Solutions

### 1. Peers Stuck in "Connecting" State

#### Check Browser Developer Console
```javascript
// Open Chrome DevTools (F12) and check for errors in both windows
// Look for WebRTC-related errors:
// - ICE gathering failed
// - STUN/TURN server errors
// - DataChannel creation errors
```

#### Enable WebRTC Debug Logging
Add this to your browser console for detailed WebRTC logs:
```javascript
// Enable detailed WebRTC logging
window.localStorage.setItem('webRtcDebug', 'true');
```

#### Check Network Connectivity
```bash
# Test STUN server connectivity
curl -I https://stun.l.google.com:19302
# Should return some response, not timeout
```

### 2. Firestore Permission Issues

#### Verify Firestore Rules
Ensure your `firestore.rules` allows read/write:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

#### Check Firestore Console
1. Go to Firebase Console → Firestore Database
2. Look for created rooms under `/rooms` collection
3. Verify offer/answer documents are being created
4. Check if ICE candidates are being stored

### 3. WebRTC Configuration Issues

#### Current STUN/TURN Servers
```dart
// In _initializeWebRTC() method:
final configuration = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    {
      'urls': 'turn:relay.metered.ca:80',
      'username': 'webrtc',
      'credential': 'webrtc',
    },
  ]
};
```

#### Alternative STUN Servers (if current ones fail)
```dart
'iceServers': [
  {'urls': 'stun:stun1.l.google.com:19302'},
  {'urls': 'stun:stun2.l.google.com:19302'},
  {'urls': 'stun:stun3.l.google.com:19302'},
]
```

### 4. Browser Compatibility

#### Supported Browsers
- ✅ Chrome/Chromium (recommended)
- ✅ Firefox
- ✅ Safari (with limitations)
- ❌ Internet Explorer (not supported)

#### Required Browser Permissions
- Microphone access (for WebRTC)
- Camera access (for WebRTC)
- Allow pop-ups and redirects

### 5. Debug Steps

#### Step 1: Check Console Logs
1. Open DevTools in both browser windows
2. Look for these log messages:
   - "🏠 Creating room as caller"
   - "🚪 Joining room as callee"
   - "🎉 P2P connection established!"
   - "📡 Data channel opened"

#### Step 2: Monitor Network Activity
1. Go to Network tab in DevTools
2. Look for Firestore requests
3. Verify SDP offer/answer exchange
4. Check ICE candidate exchanges

#### Step 3: WebRTC Internals
1. Open `chrome://webrtc-internals/` in Chrome
2. Monitor ICE candidate gathering
3. Check connection state transitions
4. Verify DataChannel creation

### 6. Manual Testing Commands

#### Test Firestore Connection
```bash
# Check if Firebase project is properly configured
firebase projects:list

# Test Firestore rules
firebase firestore:rules:get
```

#### Test Flutter Web Build
```bash
# Ensure clean build
flutter clean
flutter pub get
flutter build web --debug

# Check for any WebRTC plugin issues
flutter doctor -v
```

### 7. Quick Fix Attempts

#### If Connection Fails:
1. **Refresh both browser windows**
2. **Try different browsers** (Chrome recommended)
3. **Check internet connection** stability
4. **Disable browser extensions** that might block WebRTC
5. **Try connecting from different networks** (mobile hotspot)

#### If Messages Don't Send:
1. Check if DataChannel is open (see console logs)
2. Verify connection state is "connected"
3. Check if message format is correct in DataChannel

### 8. Advanced Debugging

#### Enable Flutter Web Debug Mode
```bash
flutter run -d web-server --web-port 8080 --dart-define=FLUTTER_WEB_DEBUG=true
```

#### Add More Logging
Temporarily add more debug logs to:
- `lib/core/services/p2p_connection_manager.dart`
- `lib/core/services/firestore_signaling_service.dart`
- `lib/core/services/modern_webrtc_service.dart`

## Expected Timeline

- **Room Creation**: < 2 seconds
- **Room Joining**: < 3 seconds  
- **ICE Gathering**: 5-10 seconds
- **Connection Established**: 10-15 seconds maximum

If connection takes longer than 30 seconds, there's likely a network or configuration issue.
