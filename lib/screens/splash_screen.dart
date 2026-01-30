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
import 'dart:math' as math;

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
    await Future.delayed(const Duration(seconds: 4)); // Longer delay to admire the animation

    if (!mounted) return;

    Widget nextScreen = const LoginScreen();
    
    try {
      await Future.any([
        _performChecks().then((screen) => nextScreen = screen),
        Future.delayed(const Duration(milliseconds: 3000))
      ]);
    } catch (e) {
      // Error handling
    }

    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => nextScreen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  Future<Widget> _performChecks() async {
      try {
        final AuthService authService = AuthService();
        if (authService.currentUser == null) {
           return const LoginScreen();
        }
        
        bool isDeviceCapable = true;
        try {
            const platform = MethodChannel('com.beejx.agri/memory');
            final int totalMemory = await platform.invokeMethod('getTotalMemory');
            if (totalMemory < 3700000000) isDeviceCapable = false;
        } catch (_) {}
        
        if (!isDeviceCapable) return const ChatScreen();

        final ModelManager modelManager = ModelManager();
        bool isDownloaded = await modelManager.isModelDownloaded();
        return isDownloaded ? const ChatScreen() : const DownloadScreen();
      } catch (e) {
        return const LoginScreen();
      }
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF051108);
    const accent = Color(0xFF00E676);
    
    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // Background Grid
          Positioned.fill(
            child: CustomPaint(
              painter: GridPainter(),
            ),
          ),

          // Central Logo Construction
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(seconds: 3),
                  curve: Curves.easeOutExpo,
                  builder: (context, value, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glow
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accent.withOpacity(0.2 * value),
                                blurRadius: 60,
                                spreadRadius: 10,
                              )
                            ]
                          ),
                        ),
                        // The Math Logo
                        CustomPaint(
                          size: const Size(180, 180),
                          painter: BeejXNeuralSeedPainter(progress: value),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 60),

                // Brand Name
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLetter('B', 0),
                    _buildLetter('e', 1),
                    _buildLetter('e', 2),
                    _buildLetter('j', 3),
                    Text('X', style: GoogleFonts.chivo(fontSize: 48, fontWeight: FontWeight.bold, color: accent))
                    .animate().fadeIn(delay: 800.ms).scale(duration: 400.ms),
                  ],
                ),

                const SizedBox(height: 12),

                _TypingText(text: "SEED • SOIL • SYNAPSE"),

                const SizedBox(height: 8),
                Text(
                  'बीज से AI तक',
                  style: GoogleFonts.notoSansDevanagari(
                    fontSize: 14,
                    color: Colors.white70,
                    letterSpacing: 2.0,
                  ),
                ).animate().fadeIn(delay: 1.5.seconds),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLetter(String char, int index) {
    return Text(
      char,
      style: GoogleFonts.chivo(
        fontSize: 48,
        fontWeight: FontWeight.w300,
        color: Colors.white,
      ),
    ).animate().fadeIn(delay: (200 * index).ms).slideX(begin: -0.2, end: 0);
  }
}

// ---------------------------------------------------------
//  MATHEMATICAL LOGO PAINTER (Neural Seed)
// ---------------------------------------------------------
class BeejXNeuralSeedPainter extends CustomPainter {
  final double progress;
  BeejXNeuralSeedPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // 1. Draw the "Seed" Shape (Drop)
    // Bezier curve construction for a perfect tear-drop
    final seedPath = Path();
    seedPath.moveTo(w * 0.5, h * 0.1); // Top tip
    // Right curve
    seedPath.cubicTo(
      w * 0.9, h * 0.3, // Control point 1
      w * 0.9, h * 0.7, // Control point 2
      w * 0.5, h * 0.95 // Bottom point
    );
    // Left curve
    seedPath.cubicTo(
      w * 0.1, h * 0.7, // Control point 2
      w * 0.1, h * 0.3, // Control point 1
      w * 0.5, h * 0.1  // Back to Top tip
    );
    seedPath.close();

    // Fill Gradient
    final seedGradient = ui.Gradient.linear(
      Offset(w * 0.5, 0),
      Offset(w * 0.5, h),
      [
        const Color(0xFF00E676), // Bright Green
        const Color(0xFF1B5E20), // Dark Green
      ],
    );
    
    final seedPaint = Paint()
      ..shader = seedGradient
      ..style = PaintingStyle.fill;
    
    if (progress > 0.1) {
       // Draw Shadow
       canvas.drawShadow(seedPath, Colors.black, 10, true);
       canvas.drawPath(seedPath, seedPaint);
       
       // Draw outline
       final outlinePaint = Paint()
         ..color = Colors.white.withOpacity(0.3)
         ..style = PaintingStyle.stroke
         ..strokeWidth = 2;
       canvas.drawPath(seedPath, outlinePaint);
    }

    // 2. Draw "Neural Circuits" (The 'AI' Brain inside the seed)
    if (progress > 0.4) {
      final circuitPaint = Paint()
        ..color = Colors.white.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      final nodePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      // Define neural nodes roughly within the seed shape
      final nodes = [
        Offset(w * 0.5, h * 0.3),  // A (Top)
        Offset(w * 0.35, h * 0.45),// B (Left)
        Offset(w * 0.65, h * 0.45),// C (Right)
        Offset(w * 0.5, h * 0.6),  // D (Center)
        Offset(w * 0.4, h * 0.75), // E (Low Left)
        Offset(w * 0.6, h * 0.75), // F (Low Right)
      ];

      // Draw Connections (Synapses)
      // Connect Top to others
      _drawAnimatedLine(canvas, nodes[0], nodes[1], circuitPaint, progress);
      _drawAnimatedLine(canvas, nodes[0], nodes[2], circuitPaint, progress);
      _drawAnimatedLine(canvas, nodes[1], nodes[3], circuitPaint, progress);
      _drawAnimatedLine(canvas, nodes[2], nodes[3], circuitPaint, progress);
      _drawAnimatedLine(canvas, nodes[3], nodes[4], circuitPaint, progress);
      _drawAnimatedLine(canvas, nodes[3], nodes[5], circuitPaint, progress);
      
      // Draw 'X' Cross
      _drawAnimatedLine(canvas, nodes[1], nodes[5], circuitPaint, progress); // Cross 1
      _drawAnimatedLine(canvas, nodes[2], nodes[4], circuitPaint, progress); // Cross 2

      // Draw Nodes
      if (progress > 0.6) {
        for (final node in nodes) {
           canvas.drawCircle(node, 4, nodePaint);
           // Pulse
           double pulse = math.sin(DateTime.now().millisecondsSinceEpoch * 0.005 + node.dy) * 2;
           canvas.drawCircle(node, 4 + pulse.abs(), nPaint(Colors.white.withOpacity(0.3)));
        }
      }
    }
  }

  void _drawAnimatedLine(Canvas canvas, Offset p1, Offset p2, Paint paint, double progress) {
     // Animate line drawing
     // Simple check: if progress is high enough, draw full line
     // For a real "trace" effect we'd need per-line animation logic, but we'll stick to alpha/length
     canvas.drawLine(p1, p2, paint);
  }

  Paint nPaint(Color c) => Paint()..color = c;

  @override
  bool shouldRepaint(covariant BeejXNeuralSeedPainter oldDelegate) => true;
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _TypingText extends StatefulWidget {
  final String text;
  const _TypingText({required this.text});

  @override
  State<_TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<_TypingText> {
  String _displayed = "";
  
  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() async {
    await Future.delayed(const Duration(seconds: 1));
    for (int i = 0; i < widget.text.length; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 100));
      setState(() {
        _displayed = widget.text.substring(0, i + 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayed + "_",
      style: GoogleFonts.robotoMono(
        fontSize: 12,
        color: const Color(0xFF69F0AE),
        letterSpacing: 3.0,
      ),
    );
  }
}