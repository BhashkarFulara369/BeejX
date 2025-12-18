import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  String _language = "English";

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          "Settings",
          style: GoogleFonts.outfit(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Section
          _buildSectionHeader("Account"),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline, color: Colors.green),
                  title: Text("Name", style: GoogleFonts.outfit()),
                  subtitle: Text(user?.displayName ?? "Farmer", style: GoogleFonts.outfit(color: Colors.grey)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.email_outlined, color: Colors.green),
                  title: Text("Email", style: GoogleFonts.outfit()),
                  subtitle: Text(user?.email ?? "Not signed in", style: GoogleFonts.outfit(color: Colors.grey)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.star_outline, color: Colors.orange),
                  title: Text("Plan", style: GoogleFonts.outfit()),
                  subtitle: Text("Free Tier", style: GoogleFonts.outfit(color: Colors.grey)),
                  trailing: TextButton(
                    onPressed: () {},
                    child: Text("Upgrade", style: GoogleFonts.outfit(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // App Settings
          _buildSectionHeader("App Settings"),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined, color: Colors.purple),
                  title: Text("Dark Mode", style: GoogleFonts.outfit()),
                  value: _darkMode,
                  activeColor: Colors.green,
                  onChanged: (val) {
                    setState(() => _darkMode = val);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Dark Mode coming soon!")),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language, color: Colors.blue),
                  title: Text("Language", style: GoogleFonts.outfit()),
                  subtitle: Text(_language, style: GoogleFonts.outfit(color: Colors.grey)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    setState(() {
                      _language = _language == "English" ? "Hindi" : "English";
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Data & Storage
          _buildSectionHeader("Data & Storage"),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text("Clear Chat History", style: GoogleFonts.outfit(color: Colors.red)),
                  onTap: () {
                    // TODO: Implement clear history
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("History cleared locally.")),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download_for_offline_outlined, color: Colors.teal),
                  title: Text("Offline Model", style: GoogleFonts.outfit()),
                  subtitle: Text("Downloaded (1.5 GB)", style: GoogleFonts.outfit(color: Colors.grey)),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // About
          Center(
            child: Column(
              children: [
                Text(
                  "BeejX v1.0.0",
                  style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  "Made for Indian Farmers",
                  style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}
