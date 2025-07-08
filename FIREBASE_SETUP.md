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
    // Allow read/write to P2P rooms
    match /rooms/{roomId} {
      allow read, write: if true;
      match /candidates/{candidateId} {
        allow read, write: if true;
      }
    }
  }
}
```

### 7. Test Connection
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
