# 🔥 Firebase Setup Guide for Globgram P2P

## Quick Setup Steps

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create new project named "globgram-p2p"
3. Enable Google Analytics (optional)

### 2. Setup Firestore Database
1. Navigate to **Firestore Database**
2. Click **Create database**
3. Start in **test mode** (for development)
4. Choose location closest to users

### 3. Enable Web App
1. In Project Overview, click **Web** icon (</>)
2. Register app with nickname "Globgram Web"
3. Copy the configuration object

### 4. Enable Android App (if needed)
1. Click **Add app** → **Android**
2. Package name: `com.globgram.p2p`
3. Download `google-services.json`
4. Place in `android/app/`

### 5. Configure Flutter Project

#### Install FlutterFire CLI:
```bash
dart pub global activate flutterfire_cli
```

#### Generate firebase_options.dart:
```bash
flutterfire configure
```

#### Replace the template file:
- Replace `lib/firebase_options.dart` with the generated file

### 6. Security Rules for Firestore

In Firebase Console → Firestore → Rules, use:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // P2P rooms collection with enhanced schema
    match /rooms/{roomId} {
      allow read, write: if true; // در تولید باید محدود شود
      
      // ICE candidates subcollection
      match /candidates/{candidateType}/list/{candidateId} {
        allow read, write: if true;
      }
    }
  }
}
```

### 7. Firestore Schema Structure

The Firestore database uses this optimized schema:

```javascript
// Collection: rooms/{roomId}
{
  offer: {
    sdp: "v=0\r\no=...", 
    type: "offer"
  },
  answer: {
    sdp: "v=0\r\no=...",
    type: "answer"
  },
  createdBy: "user_123456",     // Unique user ID
  createdAt: Timestamp,
  joinedAt: Timestamp,          // When callee joined
  status: "waiting_for_answer", // waiting_for_answer | connected | closed
  participants: {
    caller: "user_123456",
    callee: "user_789012"       // null until someone joins
  }
}

// Subcollection: rooms/{roomId}/candidates/caller/list/{autoId}
{
  candidate: "candidate:...",
  sdpMid: "0",
  sdpMLineIndex: 0,
  type: "caller",
  createdAt: Timestamp
}

// Subcollection: rooms/{roomId}/candidates/callee/list/{autoId}
{
  candidate: "candidate:...",
  sdpMid: "0", 
  sdpMLineIndex: 0,
  type: "callee",
  createdAt: Timestamp
}
```

### 8. Test Connection
```bash
flutter run -d web-server --web-port 8080
```

## 🔒 Security Notes
- Change Firestore rules for production
- Use Firebase Auth for user identification
- Implement room access controls

## 📱 Platform Support
- ✅ Web (Chrome, Firefox, Safari)
- ✅ Android (API 21+)
- ❌ iOS (requires WebRTC setup)

## 🚀 Deployment
- Web: `flutter build web --release`
- Android: `flutter build apk --release`
