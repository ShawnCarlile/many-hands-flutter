import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'firebase_options.dart';
import 'router.dart';
import 'services/auth_service.dart';
import 'services/data_service.dart';
import 'services/online.dart';
import 'theme.dart';
import 'widgets/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final theme = ThemeController();
  await theme.load();

  final configured = useEmulator || !DefaultFirebaseOptions.currentPlatform.apiKey.startsWith('YOUR_');
  if (!configured) {
    runApp(SetupNeededApp(theme: theme));
    return;
  }

  if (useEmulator) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: 'demo-key',
        appId: Platform.isIOS ? '1:000000000000:ios:0000000000000000' : '1:000000000000:android:0000000000000000',
        messagingSenderId: '000000000000',
        projectId: 'demo-many-hands',
      ),
    );
    // The Android emulator reaches the computer at 10.0.2.2; the iOS Simulator at localhost.
    final host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
    await FirebaseAuth.instance.useAuthEmulator(host, emulatorAuthPort);
    FirebaseFirestore.instance.useFirestoreEmulator(host, emulatorFirestorePort);
  } else {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  // Keeps the last-seen data on the device so the app still shows it when offline.
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);

  runApp(ManyHandsApp(theme: theme));
}

class ManyHandsApp extends StatefulWidget {
  const ManyHandsApp({super.key, required this.theme});
  final ThemeController theme;
  @override
  State<ManyHandsApp> createState() => _ManyHandsAppState();
}

class _ManyHandsAppState extends State<ManyHandsApp> {
  final auth = AuthService();
  final data = DataService();
  late final GoRouter router = buildRouter(auth);

  @override
  void initState() {
    super.initState();
    auth.addListener(_sync);
  }

  // Shared lists load only once the signed-in member is allowed in.
  void _sync() => data.setActive(auth.status == AuthStatus.ready);

  @override
  void dispose() {
    auth.removeListener(_sync);
    auth.dispose();
    data.dispose();
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: data),
        ChangeNotifierProvider.value(value: widget.theme),
        ChangeNotifierProvider.value(value: Online.instance),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) => MaterialApp.router(
          title: 'Many Hands',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: theme.mode,
          routerConfig: router,
        ),
      ),
    );
  }
}

/// Shown until lib/firebase_options.dart has real values from `flutterfire configure`.
class SetupNeededApp extends StatelessWidget {
  const SetupNeededApp({super.key, required this.theme});
  final ThemeController theme;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: theme.mode,
      home: Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const SizedBox(height: 32),
            const Center(child: Logo(size: 64)),
            const SizedBox(height: 16),
            const FormHead(title: 'Connect Firebase.', subtitle: 'This copy of Many Hands needs its own Firebase project.'),
            const Text('In a terminal, in this project folder, run:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
              child: const SelectableText(
                'flutterfire configure --project=<your-project-id> --platforms=android,ios',
                style: TextStyle(fontFamily: 'monospace', color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Then stop the app and run it again. See README.md for every step.'),
          ]),
        ),
      ),
    );
  }
}
