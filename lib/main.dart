import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/splash_screen.dart';
import 'utils/constants.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';

// Top-level background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

// Global Theme Notifier for simple state management
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Security: Load Env
  try {
    await dotenv.load(fileName: "assets/.env");
  } catch (e) {
    print("Warning: .env not found. Security functions may fail.");
  }

  try {
    await Firebase.initializeApp();
  } catch (e) {
    print("Warning: Firebase Init Failed ($e). App continues.");
  }
  
  // Set background handler
  try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (_) {}

  // Initialize Supabase (Safe Mode)
  try {
    await SupabaseService.initialize(); 
  } catch (e) {
    print("Warning: Supabase init failed ($e). App will run in offline mode.");
  }
  
  // Init Notifications (Fire-and-forget, don't await/block main thread)
  NotificationService().initialize().then((_) {
    print("Notification Service: Initialized");
  }).catchError((e) {
    print("Notification Service: Init Warning ($e)");
  });

  runApp(const BeejXApp());
}

class BeejXApp extends StatelessWidget {
  const BeejXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          // Light Theme (Organic Modern)
          theme: ThemeData(
            primaryColor: AppColors.primary,
            scaffoldBackgroundColor: AppColors.background,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              secondary: AppColors.secondary,
              background: AppColors.background,
              surface: AppColors.surface,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            textTheme: GoogleFonts.outfitTextTheme(),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              iconTheme: IconThemeData(color: Colors.black87),
            ),
            drawerTheme: const DrawerThemeData(
              backgroundColor: Colors.white,
            ),
          ),
          // Dark Theme (Deep Emerald)
          darkTheme: ThemeData(
            primaryColor: AppColors.primary,
            scaffoldBackgroundColor: const Color(0xFF121212),
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              secondary: AppColors.primary,
              background: const Color(0xFF121212),
              surface: const Color(0xFF1E1E1E),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E),
              surfaceTintColor: Color(0xFF1E1E1E),
              iconTheme: IconThemeData(color: Colors.white),
            ),
            drawerTheme: const DrawerThemeData(
              backgroundColor: Color(0xFF1E1E1E),
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
