# Globgram P2P Chat Application

A serverless peer-to-peer chat application built with Flutter and Firebase Firestore signaling. This application enables real-time messaging between users without requiring a custom backend server.

## Features

- 🔥 **Firebase Firestore Signaling**: Real-time signaling using Cloud Firestore
- 🌐 **WebRTC P2P Communication**: Direct peer-to-peer messaging via data channels
- 📱 **Cross-Platform**: Supports Android and Web (Chrome, Edge)
- 🌍 **Multilingual**: English, Persian (Farsi), and Spanish support
- 🎯 **STUN/TURN Servers**: Configured for reliable connection establishment
- 📡 **Offline-First**: Local message storage with Hive database
- 🎨 **Modern UI**: Clean, responsive design with dark/light theme support

## Architecture

- **Clean Architecture** with BLoC state management
- **Firebase Firestore** for signaling (offers, answers, ICE candidates)
- **WebRTC** for direct peer-to-peer data channel communication
- **Hive** for local message persistence
- **Easy Localization** for internationalization

## Prerequisites

1. **Flutter SDK** (>=3.10.0)
2. **Firebase Project** with Firestore enabled
3. **FlutterFire CLI** for Firebase configuration

## Setup Instructions

### 1. Clone and Install Dependencies

```bash
git clone <repository-url>
cd globgram-p2p-chat
flutter pub get
```

### 2. Firebase Configuration

#### Install FlutterFire CLI:
```bash
dart pub global activate flutterfire_cli
```

#### Configure Firebase:
```bash
flutterfire configure
```

This will:
- Create a new Firebase project (or select existing)
- Enable required services (Firestore)
- Generate `lib/firebase_options.dart`

#### Enable Firestore:
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to Firestore Database
4. Click "Create database"
5. Choose "Start in test mode" (for development)

### 3. Firestore Security Rules

Update your Firestore security rules for development:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read/write for rooms and candidates collections
    match /rooms/{roomId} {
      allow read, write: if true;
      match /candidates/{candidateId} {
        allow read, write: if true;
      }
    }
  }
}
```

**⚠️ Important**: These rules are for development only. Implement proper authentication and security rules for production.

## Building and Running

### Web Development
```bash
flutter run -d chrome --web-port 8080
```

### Android Development
```bash
flutter run -d android
```

### Production Web Build
```bash
flutter build web --release
```

## Deployment

### GitHub Pages Deployment

1. **Build for web:**
   ```bash
   flutter build web --release --base-href="/your-repository-name/"
   ```

2. **Deploy to GitHub Pages:**
   ```bash
   # Copy build/web contents to gh-pages branch
   cp -r build/web/* docs/
   git add docs/
   git commit -m "Deploy to GitHub Pages"
   git push origin main
   ```

3. **Enable GitHub Pages:**
   - Go to repository Settings → Pages
   - Set source to "Deploy from a branch"
   - Select "main" branch and "/docs" folder
   - Your app will be available at: `https://username.github.io/repository-name/`

### Firebase Hosting (Alternative)

```bash
npm install -g firebase-tools
firebase login
firebase init hosting
firebase deploy
```

## How to Use

### Creating/Joining a Room

1. **Start the application**
2. **Enter a Room ID** (any string, e.g., "room123")
3. **Click "Join Room"**
4. **Share the Room ID** with other users
5. **Start chatting** when peers connect

### Multi-Device Testing

1. **Open two browser tabs/windows**
2. **Use the same Room ID** in both
3. **Send messages** from either tab
4. **Messages appear in real-time** on both tabs

## Technical Details

### STUN/TURN Servers
- **STUN**: `stun:stun.l.google.com:19302`
- **TURN**: `turn:relay.metered.ca:80`
  - Username: `webrtc`
  - Credential: `webrtc`

### Firestore Structure
```
/rooms/{roomId}
├── participants: [array of peer IDs]
├── offer: {from, to, sdp, timestamp}
├── answer: {from, to, sdp, timestamp}
├── created_at: timestamp
└── /candidates/{candidateId}
    ├── from: peer ID
    ├── to: target peer ID
    ├── candidate: ICE candidate data
    └── timestamp: timestamp
```

### Message Flow
1. **Peer A joins room** → Updates Firestore participants
2. **Peer B joins room** → Detects Peer A, initiates WebRTC offer
3. **Offer/Answer exchange** → Via Firestore real-time listeners
4. **ICE candidates** → Exchanged through Firestore subcollection
5. **P2P connection established** → Messages sent via WebRTC data channel
6. **Real-time chat** → Direct peer-to-peer communication

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── firebase_options.dart              # Firebase configuration
├── core/
│   ├── models/p2p_models.dart         # Data models
│   ├── services/
│   │   ├── firebase_signaling_service.dart    # Firestore signaling
│   │   ├── modern_webrtc_service.dart          # WebRTC management
│   │   └── p2p_manager.dart                    # Main P2P coordinator
│   ├── theme/app_theme.dart           # UI theming
│   └── utils/app_logger.dart          # Logging utility
└── features/
    └── chat/
        └── presentation/
            ├── bloc/p2p_bloc.dart     # State management
            └── pages/               # UI pages
```

## Development Notes

- **No custom backend required** - uses Firebase infrastructure
- **Real connection states** - no fake "connected" simulation
- **Data channel only** - all messages via WebRTC, not signaling
- **Clean architecture** - separation of concerns
- **Cross-platform** - single codebase for web and mobile

## Troubleshooting

### Connection Issues
- Check Firestore security rules
- Verify STUN/TURN server accessibility
- Test with multiple browser tabs first

### Build Issues
- Run `flutter clean && flutter pub get`
- Ensure Firebase project is properly configured
- Check `firebase_options.dart` exists

### Firestore Permission Errors
- Verify Firestore is enabled in Firebase Console
- Check security rules allow read/write
- Ensure Firebase project is active

## License

This project is open source and available under the [MIT License](LICENSE).

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Support

For issues and questions:
- Create an issue in the GitHub repository
- Check existing issues for solutions
- Review Firebase and WebRTC documentation
