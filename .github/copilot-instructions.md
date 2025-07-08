# Globgram P2P Chat Application

<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

## Project Overview
This is a Flutter project for building a peer-to-peer chat application called Globgram. The app operates with absolutely no backend domain or server; all logic runs on-device.

## Architecture Guidelines
- Use Clean Architecture + BLoC (or Cubit) pattern
- Target platform: Android first (include iOS setup if trivial)
- All code, comments, and documentation should be written in natural, idiomatic English
- Implement RTL-aware UI for multilingual support

## Key Requirements
1. **P2P Connectivity**: Use flutter_webrtc for peer-to-peer audio/data channels
2. **Voice Messages**: Implement with flutter_sound for recording & playback
3. **Local Storage**: Use Hive for persistence (MessageModel with id, timestamp, type, content/path)
4. **Multilingual**: Support en, fa, es locales using easy_localization
5. **Permissions**: Handle RECORD_AUDIO, READ/WRITE_EXTERNAL_STORAGE properly
6. **Offline-first**: Queue unsent messages locally; sync when peer connects

## Technical Stack
- flutter_webrtc: P2P communication
- flutter_sound: Audio recording/playback
- hive: Local database
- easy_localization: Internationalization
- bloc: State management
- permission_handler: Runtime permissions

## Code Quality Standards
- Write comprehensive unit tests for BLoCs and Hive models
- Include proper error handling and edge cases
- Optimize for APK size (target: under 30 MB)
- Follow Flutter best practices and conventions
