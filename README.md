# 🌍 Globgram P2P Chat Application

A **true peer-to-peer chat application** built with Flutter, WebRTC, and Firebase Firestore signaling. Enables real-time encrypted messaging between users without storing any chat messages on servers.

## ✨ Features

- 🔥 **Firebase Firestore Signaling**: WebRTC handshake only (offers, answers, ICE candidates)
- 💬 **Pure WebRTC Messaging**: ALL chat messages via encrypted RTCDataChannel
- 🌐 **Cross-Platform**: Web (Chrome, Edge, Firefox) and Android 
- 🎵 **Voice Messages**: Record and send voice messages via WebRTC data channels
- 🌍 **Multilingual**: English, Persian (Farsi), and Spanish support
- 🎯 **STUN/TURN Servers**: Reliable connection with Google STUN + Metered TURN
- 📡 **Offline-First**: Local message storage with Hive database
- 🎨 **Modern UI**: Clean, responsive design with RTL support
- 🔒 **Serverless**: Zero backend dependencies - true P2P architecture
- 🚫 **No BroadcastChannel**: Completely removed deprecated signaling methods

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Globgram P2P Architecture                │
│                     (Pure WebRTC + Firestore)              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   Browser A     │    │   Browser B     │                │
│  │                 │    │                 │                │
│  │ ┌─────────────┐ │    │ ┌─────────────┐ │                │
│  │ │ Flutter App │ │    │ │ Flutter App │ │                │
│  │ │             │ │    │ │             │ │                │
│  │ │   WebRTC    │◄┼────┼─┤   WebRTC    │ │                │
│  │ │ DataChannel │ │    │ │ DataChannel │ │                │
│  │ │             │ │    │ │             │ │                │
│  │ └─────────────┘ │    │ └─────────────┘ │                │
│  │       │         │    │       │         │                │
│  └───────┼─────────┘    └───────┼─────────┘                │
│          │                      │                          │
│          │                      │                          │
│    ┌─────▼──────────────────────▼─────┐                    │
│    │        Firestore Database        │                    │
│    │                                  │                    │
│    │  • WebRTC Signaling Only        │                    │
│    │  • Offer/Answer Exchange        │                    │
│    │  • ICE Candidate Exchange       │                    │
│    │  • NO Chat Messages             │                    │
│    │                                  │                    │
│    └──────────────────────────────────┘                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Key Points:**
- 📡 **Firestore** = WebRTC signaling ONLY (offers/answers/ICE)
- 💬 **Chat Messages** = WebRTC DataChannel ONLY (end-to-end encrypted)
- 🔒 **Privacy** = No chat messages stored on any server
- ⚡ **Real-time** = Direct browser-to-browser communication

## 📋 Prerequisites

1. **Flutter SDK** (>=3.10.0)
2. **Firebase Project** with Firestore enabled  
3. **FlutterFire CLI** for Firebase configuration
4. **HTTPS domain** for Web deployment (required for WebRTC)

## 🚀 Quick Start

### 1. Clone and Install Dependencies

```bash
git clone https://github.com/tas-digitalmarket/flutter.globgram
cd globgramflutter01
flutter pub get
```

### 2. Firebase Setup (Required)

#### Step 1: Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create new project named "globgram-p2p"
3. Enable Firestore Database in **test mode**

#### Step 2: Configure Flutter Project
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase for your project
flutterfire configure
```

#### Step 3: Replace Firebase Options
- Copy the generated `firebase_options.dart` 
- Replace `lib/firebase_options.dart` in this project

#### Step 4: Setup Firestore Security Rules
In Firebase Console → Firestore → Rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /rooms/{roomId} {
      allow read, write: if true; // Change for production
      
      match /candidates/{candidateType}/list/{candidateId} {
        allow read, write: if true;
      }
    }
  }
}
```

### 3. Build and Run

#### Web (Development)
```bash
flutter run -d chrome --web-port 8080
```

#### Web (Production Build)
```bash
flutter build web --release
```

#### Android (Debug)
```bash
flutter run -d android
```

#### Android (Release APK)
```bash
flutter build apk --release
```

## 🎮 How to Use

### Creating a Room
1. Open the app
2. Click **"Create Room"**
3. Share the generated **Room ID** or **QR Code** with your peer
4. Wait for connection (status shows "Connected")

### Joining a Room
1. Open the app on another device/browser
2. Click **"Join Room"**
3. Enter the **Room ID** received from peer
4. Wait for connection establishment

### Messaging
- Once **connectionState = connected**, start chatting
- All messages are sent via **encrypted WebRTC DataChannel**
- Messages are **NOT stored** on any server
- Real-time delivery between connected peers

## 🌐 Web Deployment

### GitHub Pages (Recommended)
1. Build for production:
   ```bash
   flutter build web --release
   ```

2. Deploy to GitHub Pages:
   ```bash
   # Copy build/web contents to gh-pages branch
   cp -r build/web/* docs/
   git add docs/
   git commit -m "Deploy to GitHub Pages"
   git push origin main
   ```

3. Enable GitHub Pages in repository settings
4. Use **Custom Domain** with HTTPS (required for WebRTC)

### Firebase Hosting
```bash
npm install -g firebase-tools
firebase login
firebase init hosting
firebase deploy
```

### Netlify/Vercel
- Upload `build/web` folder
- Ensure HTTPS is enabled
- Configure redirects for Flutter routes

## 🧪 Testing Multi-Device Connection

1. **Build and serve:**
   ```bash
   flutter build web --release
   cd build/web
   python -m http.server 8080
   ```

2. **Test setup:**
   - Browser A: `http://localhost:8080` → Create Room
   - Browser B: `http://localhost:8080` (incognito) → Join Room
   - Mobile: Use same local IP address

3. **Verify connection:**
   - Check **connectionState = connected** 
   - Send test messages both ways
   - Confirm real-time delivery

## 🔧 Configuration

### STUN/TURN Servers
```dart
final iceServers = [
  {'urls': 'stun:stun.l.google.com:19302'},
  {
    'urls': 'turn:relay.metered.ca:80',
    'username': 'webrtc',
    'credential': 'webrtc'
  },
];
```

**Note:** For production, replace with your own TURN servers for better reliability.

## 📚 Documentation

- **[📋 FIREBASE_SETUP.md](./FIREBASE_SETUP.md)** - Detailed Firebase configuration
- **[🎯 STAGE_C_COMPLETION.md](./STAGE_C_COMPLETION.md)** - Pure WebRTC implementation notes
- **[🧪 Testing Guides](./P2P_TEST_GUIDE.md)** - Multi-device testing procedures

## 🛠️ Tech Stack

- **Flutter** - Cross-platform framework
- **WebRTC** - Peer-to-peer communication (RTCDataChannel for ALL messaging)
- **Firebase Firestore** - WebRTC signaling only
- **BLoC** - State management
- **Hive** - Local storage
- **Easy Localization** - Multi-language support

## 🏆 Development Status

- ✅ **Stage A**: Firebase Firestore signaling implementation
- ✅ **Stage B**: WebRTC wiring and method alignment  
- ✅ **Stage C**: Pure WebRTC messaging (BroadcastChannel removed)
- ✅ **Stage D**: STUN/TURN configuration and documentation

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Flutter team for the excellent WebRTC plugin
- Firebase for real-time database capabilities
- Metered.ca for free TURN server testing

---

**🚀 Ready to build true peer-to-peer chat applications!**

*No servers, no data collection, just pure P2P communication.* 🔒
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
