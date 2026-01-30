import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/chat_history_screen.dart';
import '../screens/market_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/voice_session_overlay.dart';
import '../screens/disease_detection_screen.dart';
import '../screens/lekha_screen.dart';
import '../screens/offline_chat_screen.dart';
import '../screens/bijuka_screen.dart';

import '../main.dart';

class PremiumDrawer extends StatelessWidget {
  const PremiumDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final AuthService authService = AuthService();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: Theme.of(context).drawerTheme.backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    backgroundImage: user?.photoURL != null 
                        ? NetworkImage(user!.photoURL!) 
                        : null,
                    child: user?.photoURL == null 
                        ? Icon(Icons.person, size: 30, color: Theme.of(context).colorScheme.primary) 
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? "Farmer",
                          style: GoogleFonts.outfit(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user?.email ?? "Free Plan",
                          style: GoogleFonts.outfit(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _buildDrawerItem(context, Icons.add_circle_outline, "New Chat", () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatScreen()),
                    );
                  }),
                  _buildDrawerItem(context, Icons.sd_storage, "Offline BeejX", () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OfflineChatScreen()),
                    );
                  }),
                  _buildDrawerItem(context, Icons.sensors, "Bijuka", () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BijukaScreen()),
                    );
                  }),
                  _buildDrawerItem(context, Icons.mic, "Samvaad (संवाद)", () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => VoiceSessionOverlay(
                        onClose: () => Navigator.pop(context),
                      ),
                    );
                  }),
                  _buildDrawerItem(context, Icons.camera_alt, "Vaidya (Crop Doctor)", () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DiseaseDetectionScreen()));
                  }),
                  _buildDrawerItem(context, Icons.verified_user, "Lekha Pay (Subsidy)", () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LekhaScreen()));
                  }),
                  _buildDrawerItem(context, Icons.history, "Chat History", () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatHistoryScreen()));
                  }),
                  _buildDrawerItem(context, Icons.store, "Market Insights", () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketScreen()));
                  }),
                  _buildDrawerItem(context, Icons.settings, "Settings", () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  }),
                ],
              ),
            ),

            const Divider(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: Theme.of(context).iconTheme.color),
                  title: Text(
                    isDark ? "Dark Mode" : "Light Mode",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                  ),
                  trailing: Switch(
                    value: isDark,
                    activeColor: Theme.of(context).primaryColor,
                    onChanged: (val) {
                       themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                    },
                  ),
                ),
              ),
            ),

            _buildDrawerItem(context, Icons.logout, "Sign Out", () async {
              await authService.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            }),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    final color = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
    return ListTile(
      leading: Icon(icon, color: color.withOpacity(0.7)),
      title: Text(
        title,
        style: GoogleFonts.outfit(color: color, fontSize: 16),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}
