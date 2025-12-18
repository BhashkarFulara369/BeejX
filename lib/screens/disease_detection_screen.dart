import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/vision_service.dart';

class DiseaseDetectionScreen extends StatefulWidget {
  const DiseaseDetectionScreen({super.key});

  @override
  State<DiseaseDetectionScreen> createState() => _DiseaseDetectionScreenState();
}

class _DiseaseDetectionScreenState extends State<DiseaseDetectionScreen> with SingleTickerProviderStateMixin {
  final VisionService _visionService = VisionService();
  final ImagePicker _picker = ImagePicker();
  
  File? _selectedImage;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _result;
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _visionService.initialize();
    _scanController = AnimationController(
        duration: const Duration(milliseconds: 2000), vsync: this)..repeat(reverse: true);
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _result = null;
        _isAnalyzing = true;
      });
      // Start the scan
      _scanController.repeat(reverse: true);
      await _analyze();
    }
  }

  Future<void> _analyze() async {
    if (_selectedImage == null) return;
    
    // Simulate "Scanning" time to show off the animation
    await Future.delayed(const Duration(milliseconds: 2000)); 
    
    final res = await _visionService.analyzeImage(_selectedImage!.path);
    
    if (mounted) {
      setState(() {
        _result = res;
        _isAnalyzing = false;
      });
      _scanController.stop(); // Stop scanning when done
    }
  }

  void _reset() {
    setState(() {
      _selectedImage = null;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text("Vaidya AI (वैद्य) 🩺", style: GoogleFonts.outfit(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Instructions
            if (_selectedImage == null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.qr_code_scanner, size: 60, color: Colors.green),
                    const SizedBox(height: 16),
                    Text(
                      "Scan Your Crop",
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "AI Detection Active. Point at the leaf.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Image Preview MASTER STACK
            if (_selectedImage != null)
              Container(
                 height: 400, // Fixed height for scanner look
                 width: double.infinity,
                 decoration: BoxDecoration(
                   borderRadius: BorderRadius.circular(20),
                   color: Colors.black, // Dark background for contrast
                   boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15, offset: const Offset(0, 5))],
                 ),
                 child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 1. The Image
                        Image.file(_selectedImage!, fit: BoxFit.cover),
                        
                        // 2. The Scanner Overlay (Active during analyzing)
                        if (_isAnalyzing)
                          AnimatedBuilder(
                            animation: _scanController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: ScannerPainter(_scanController.value),
                              );
                            },
                          ),

                        // 3. The "YOLO" Bounding Box (Active after result)
                        if (_result != null)
                          _buildYoloBox(_result!),
                          
                        // 4. Close Button (Top Right)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: InkWell(
                            onTap: _reset,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                 ),
              ),

            const SizedBox(height: 30),

            // Detailed Result (Shown below for extra info)
            if (_result != null)
              _buildResultCard(_result!),

            const SizedBox(height: 30),

            // Buttons
            if (_selectedImage == null)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.center_focus_strong, color: Colors.white),
                      label: Text("Scan Leaf", style: GoogleFonts.outfit(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.green[700]!),
                      ),
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: Icon(Icons.image, color: Colors.green[700]),
                      label: Text("Gallery", style: GoogleFonts.outfit(color: Colors.green[700], fontSize: 16)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Mimics Yolo Box on the center of the image
  Widget _buildYoloBox(Map<String, dynamic> result) {
    bool isHealthy = result['is_healthy'] == true;
    Color boxColor = isHealthy ? Colors.greenAccent : Colors.redAccent;
    String label = result['label'];
    int conf = (result['confidence'] * 100).toInt();

    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          border: Border.all(color: boxColor, width: 3),
          borderRadius: BorderRadius.circular(4), // Slightly rounded corners like YOLO
        ),
        child: Stack(
          clipBehavior: Clip.none, // Allow text to overflow top
          children: [
            Positioned(
              top: -28, // Move label ABOVE the box
              left: -3, // Align with border
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: boxColor,
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                ),
                child: Text(
                  "$label  $conf%",
                  style: GoogleFonts.robotoMono(
                    color: Colors.black, 
                    fontWeight: FontWeight.bold,
                    fontSize: 14
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> result) {
    final isHealthy = result['is_healthy'] == true;
    final color = isHealthy ? Colors.green : Colors.red;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isHealthy ? Icons.check_circle : Icons.warning_amber_rounded, color: color, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result['label'],
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!isHealthy) ...[
            Text("Suggested Remedy", style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              result['remedy'],
              style: GoogleFonts.outfit(fontSize: 16, color: Colors.black87),
            ),
          ] else 
            Text(
              "Your crop looks healthy! Keep maintaining good irrigation.",
              style: GoogleFonts.outfit(fontSize: 16, color: Colors.green[700]),
            ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _visionService.dispose();
    _scanController.dispose();
    super.dispose();
  }
}

// Painter for the Laser Scan Effect
class ScannerPainter extends CustomPainter {
  final double scanValue; // 0.0 to 1.0

  ScannerPainter(this.scanValue);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Paint laserPaint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.8)
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.greenAccent.withOpacity(0.0),
          Colors.greenAccent.withOpacity(0.5),
          Colors.greenAccent.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 50));

    // Draw Corner Brackets (Viewfinder)
    double cornerSize = 40;
    // Top Left
    canvas.drawPath(Path()..moveTo(0, cornerSize)..lineTo(0, 0)..lineTo(cornerSize, 0), paint);
    // Top Right
    canvas.drawPath(Path()..moveTo(size.width - cornerSize, 0)..lineTo(size.width, 0)..lineTo(size.width, cornerSize), paint);
    // Bottom Left
    canvas.drawPath(Path()..moveTo(0, size.height - cornerSize)..lineTo(0, size.height)..lineTo(cornerSize, size.height), paint);
    // Bottom Right
    canvas.drawPath(Path()..moveTo(size.width - cornerSize, size.height)..lineTo(size.width, size.height)..lineTo(size.width, size.height - cornerSize), paint);

    // Draw Laser Line
    double yPos = size.height * scanValue;
    canvas.drawLine(Offset(20, yPos), Offset(size.width - 20, yPos), paint..color = Colors.redAccent..strokeWidth=2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
