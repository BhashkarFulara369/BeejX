import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppColors {
  // Organic Modern Palette
  static const Color primary = Color(0xFF2E7D32); // Forest Green (Trustworthy, Growth)
  static const Color secondary = Color(0xFF81C784); // Soft Green
  static const Color accent = Color(0xFFFFB74D); // Harvest Gold (Warmth, Energy)
  static const Color background = Color(0xFFFAFAFA); // Warm White/Cream (Paper-like, Human)
  static const Color surface = Colors.white; // Pure White for Cards
  
  static const Color textPrimary = Color(0xFF1B1B1B); // Soft Black (High Contrast but not harsh)
  static const Color textSecondary = Color(0xFF757575); // Earthy Grey
  
  // Keep legacy for compatibility if needed, but mapped to new system
  static const Color darkBackground = Color(0xFF121212);
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1E1E1E);
  static const Color textLight = textPrimary;
  static const Color textDark = Colors.white70;
}

class AppStrings {
  static const String appName = 'BeejX';
  static const String tagline = 'बीज से AI तक';
  
  // Onboarding
  static const String onboardingTitle1 = 'Smart Farming';
  static const String onboardingDesc1 = 'Get real-time advice for your crops using BeejX.';
  static const String onboardingTitle2 = 'Disease Detection';
  static const String onboardingDesc2 = 'Scan your plants to detect diseases instantly.';
  static const String onboardingTitle3 = 'Market Insights';
  static const String onboardingDesc3 = 'Stay updated with the latest market prices.';
  
  static const String getStarted = 'Get Started';
  static const String skip = 'Skip';
  static const String next = 'Next';
}

class ApiConstants {
  // Replace with your actual local IP if running on device, or localhost for emulator
  // For Android Emulator use 10.0.2.2
  // For Physical Device use 192.168.1.6 (PC LAN IP)
  // USE THIS FLAG TO OVERRIDE: flutter run --dart-define=API_URL=https://your-url.com
  static const String baseUrl = String.fromEnvironment('API_URL', defaultValue: 'https://beejx-brainb.onrender.com'); 
  
  static const String chatEndpoint = '$baseUrl/api/v1/chat';
  static const String schemesDiscoveryEndpoint = '$baseUrl/api/v1/schemes/discover';
  static const String weatherEndpoint = '$baseUrl/api/v1/weather';
  static const String marketEndpoint = '$baseUrl/api/v1/mandi';
  
  // Supabase Config
  static const String supabaseUrl = 'https://kqqlrxtimamsuodhsevt.supabase.co';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
}
