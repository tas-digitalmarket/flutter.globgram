import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
// import 'package:firebase_core/firebase_core.dart';

// import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/chat/presentation/pages/room_selection_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase - Disabled for BroadcastChannel testing
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );

  // Initialize Easy Localization
  await EasyLocalization.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('fa'),
        Locale('es'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      useOnlyLangCode:
          true, // This avoids looking for country-specific files like en-US.json
      child: const GlobgramApp(),
    ),
  );
}

class GlobgramApp extends StatelessWidget {
  const GlobgramApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Globgram P2P',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const RoomSelectionPage(),
    );
  }
}
