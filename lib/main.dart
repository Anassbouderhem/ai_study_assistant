import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter/foundation.dart';

// Import généré automatiquement par FlutterFire CLI
import 'firebase_options.dart';

// Imports de nos fichiers
import 'providers/auth_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/tasks_provider.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';
import 'views/auth_screen.dart';
import 'views/home_screen.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';

void main() async {
  // 1. Assure la liaison avec les services natifs du téléphone
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Charge les variables d'environnement (.env)
  await dotenv.load(fileName: '.env');

  // 2. Initialise Firebase avec les options spécifiques à la plateforme
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2.1 Initialise le service de notifications locales
  await NotificationService().init();
  // En debug, déclencher une notification immédiate pour vérifier l'icône
  if (!kIsWeb && kDebugMode) {
    await NotificationService().showInstant(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: 'Test icône',
      body: 'Vérification icône de notification',
    );
  }
  // 2.2 Initialise Firebase Cloud Messaging
  await FcmService().init();

  // Activer le mode hors ligne (Offline mode) pour Firestore
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }

  // Enlever le splash screen après l'initialisation
  FlutterNativeSplash.remove();

  // 3. Lance l'application avec les Providers
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(create: (_) => TasksProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'AI Study Assistant',
          debugShowCheckedModeBanner: false,

          themeMode: themeProvider.themeMode,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),

          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return authProvider.isAuthenticated
        ? const HomeScreen()
        : const AuthScreen();
  }
}
