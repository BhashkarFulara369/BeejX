import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'chat_screen.dart';
import 'download_screen.dart';
import 'login_screen.dart';
import '../services/model_manager.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  
  @override
  void initState() {
    super.initState();
    _handleNavigation();
  }

  Future<void> _handleNavigation() async {
    // Artificial delay to show off the animation (min 3.5s)
    await Future.delayed(const Duration(milliseconds: 3500)); 

    if (!mounted) return;

    final AuthService authService = AuthService();
    final ModelManager modelManager = ModelManager();
    
    // RAM Check Logic
    bool isDeviceCapable = true;
    try {
        const platform = MethodChannel('com.beejx.agri/memory');
        final int totalMemory = await platform.invokeMethod('getTotalMemory');
        // 4GB = ~4e9 bytes. Safety buffer: 3.7GB
        if (totalMemory < 3700000000) isDeviceCapable = false;
    } catch (e) {
      // Fail safe: assume capable
    }

    Widget nextScreen;
    if (authService.currentUser == null) {
      nextScreen = const LoginScreen();
    } else {
      try {
        if (!isDeviceCapable) {
           nextScreen = const ChatScreen(); 
        } else {
           bool isDownloaded = await modelManager.isModelDownloaded();
           nextScreen = isDownloaded ? const ChatScreen() : const DownloadScreen();
        }
      } catch (e) {
        nextScreen = const ChatScreen();
      }
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => nextScreen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 1000), // Slower, premium fade
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Premium Color Palette
    const bgDark = Color(0xFF0D1F12); // Very Dark Green
    const bgLight = Color(0xFF194D25); // Rich Forest Green
    const accent = Color(0xFF4CAF50);  // BeejX Green

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // 1. Ambient Background Glows
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                boxShadow: [
                  BoxShadow(
                    color: bgLight.withOpacity(0.4),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .scale(duration: 4.seconds, begin: const Offset(1,1), end: const Offset(1.2,1.2)),
          ),
          
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                 boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.15),
                    blurRadius: 80,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .scale(duration: 5.seconds, begin: const Offset(1,1), end: const Offset(1.3,1.3)),
          ),

          // 2. Glassmorphism / Frosted Overlay (Subtle)
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30), // Blends the blobs
            child: Container(color: Colors.transparent),
          ),

          // 3. Center Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Composition
                Stack(
                  alignment: Alignment.center,
                  children: [
                     // Outer Ring/Glow
                     Container(
                       width: 140,
                       height: 140,
                       decoration: BoxDecoration(
                         shape: BoxShape.circle,
                         color: accent.withOpacity(0.2),
                         boxShadow: [
                           BoxShadow(
                             color: accent.withOpacity(0.4),
                             blurRadius: 40,
                             spreadRadius: 2,
                           )
                         ]
                       ),
                     ).animate()
                      .scale(duration: 1.5.seconds, curve: Curves.easeOutBack)
                      .fadeIn(duration: 1.seconds),

                     // The Icon
                     Container(
                       width: 100,
                       height: 100,
                       decoration: const BoxDecoration(
                         shape: BoxShape.circle,
                         // Premium shadow
                         boxShadow: [
                           BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 10))
                         ]
                       ),
                       child: ClipOval(
                         child: Image.asset('assets/icon.png', fit: BoxFit.cover),
                       ),
                     ).animate()
                      .scale(delay: 200.ms, duration: 1.2.seconds, curve: Curves.elasticOut)
                      .fadeIn(duration: 800.ms),
                  ],
                ),

                const SizedBox(height: 40),

                // Staggered Text Animation
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _animatedLetter('B', 0),
                    _animatedLetter('e', 1),
                    _animatedLetter('e', 2),
                    _animatedLetter('j', 3),
                    _animatedLetter('X', 4),
                  ],
                ),

                const SizedBox(height: 16),

                // Tagline with "Typewriter" or Fade feel
                Text(
                  'SEED  •  SOIL  •  AI',
                  style: GoogleFonts.robotoMono( 
                    fontSize: 12,
                    color: Colors.white60,
                    letterSpacing: 3.0,
                    fontWeight: FontWeight.w500,
                  ),
                ).animate()
                 .fadeIn(delay: 1.seconds, duration: 800.ms)
                 .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),

                 const SizedBox(height: 8),

                 Text(
                  'बीज से AI तक',
                  style: GoogleFonts.notoSansDevanagari(
                    fontSize: 14,
                    color: accent, // Use brand color for accent
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ).animate()
                 .fadeIn(delay: 1.4.seconds, duration: 800.ms)
                 .shimmer(delay: 2.seconds, duration: 1.5.seconds, color: Colors.white), 
              ],
            ),
          ),
          
          // 4. Subtle Footer / Loader
          Positioned(
             bottom: 60,
             left: 0, 
             right: 0,
             child: Center(
               child: SizedBox(
                 width: 24,
                 height: 24,
                 child: CircularProgressIndicator(
                   strokeWidth: 2,
                   valueColor: AlwaysStoppedAnimation<Color>(Colors.white24),
                 ),
               ),
             ).animate().fadeIn(delay: 2.seconds),
          )
        ],
      ),
    );
  }

  Widget _animatedLetter(String letter, int index) {
    return Text(
      letter,
      style: GoogleFonts.outfit(
        fontSize: 42,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: -1.0,
      ),
    ).animate()
     .fadeIn(delay: (400 + (index * 100)).ms, duration: 600.ms)
     .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuad);
  }
}