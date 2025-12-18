import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../services/model_manager.dart';
import 'onboarding_screen.dart'; 

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final ModelManager _modelManager = ModelManager();
  bool _isDownloading = false;
  double _progress = 0.0;
  String _status = "BeejX needs to download the offline brain (1.5GB) to work without internet.";

  void _startDownload() {
    setState(() {
      _isDownloading = true;
      _status = "Downloading... Please do not close the app.";
    });

    _modelManager.downloadModel().listen(
      (progress) {
        // Progress is a Map<String, dynamic> { 'progress': double, 'status': String }
        final double val = (progress['progress'] as num?)?.toDouble() ?? 0.0;
        final String status = progress['status'] as String? ?? "";
        
        // LOG FOR USER VERIFICATION
        print("📥 Download Progress: ${(val * 100).toStringAsFixed(1)}% - $status");

        setState(() {
          _progress = val;
        });
        
        if (val >= 1.0) {
          print("✅ Download Complete! Verifying integrity...");
          setState(() {
            _status = "Download Complete!";
          });
          // Navigate to Onboarding Screen
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
        }
      },
      onError: (e) {
        setState(() {
          _isDownloading = false;
          _status = "Error: $e. Please try again.";
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_download_rounded, size: 100, color: Colors.green),
                const SizedBox(height: 30),
                const Text(
                  "Setup BeejX Offline",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                Text(
                  "Size: ~1.5 GB",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber)
                  ),
                  child: const Text(
                    "⚠️ Note: Requires 4GB+ RAM. If your phone is slow, please Skip.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.amber, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 40),
                if (_isDownloading)
                  Column(
                    children: [
                      LinearPercentIndicator(
                        lineHeight: 24.0,
                        percent: _progress,
                        center: Text(
                          "${(_progress * 100).toStringAsFixed(1)}%",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        barRadius: const Radius.circular(12),
                        progressColor: Colors.green,
                        backgroundColor: Colors.green.shade100,
                        animation: true,
                        animateFromLastPercent: true,
                      ),
                      const SizedBox(height: 10),
                      const Text("This may take a while...", style: TextStyle(color: Colors.grey)),
                    ],
                  )
                else
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: _startDownload,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          elevation: 5,
                        ),
                        child: const Text(
                          "Download Model", 
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
                        },
                        child: const Text(
                          "Skip for now (Online Only)",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
