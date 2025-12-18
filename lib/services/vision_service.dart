import 'dart:io';
import 'package:flutter/services.dart';
import 'classifier.dart';
import 'disease_localizer.dart';

class VisionService {
  late Classifier _classifier;
  bool _isDataLoaded = false;

  Future<void> initialize() async {
    try {
      _classifier = Classifier();
      // Giving it a moment to load model/labels asynchronously in its constructor
      // Ideally Classifier should have an async init, but constructor based is what was requested.
      // We assume it loads fast enough or checks internally.
      
      _isDataLoaded = true;
      print("VisionService: Classifier initialized.");
    } catch (e) {
      print("VisionService Error: $e");
      _isDataLoaded = false;
    }
  }

  Future<Map<String, dynamic>> analyzeImage(String imagePath) async {
    if (!_isDataLoaded) {
       // Try initializing again if not loaded
       await initialize();
       if (!_isDataLoaded) {
        return {
          "label": "Error: Service not ready",
          "confidence": 0.0,
          "remedy": "Please restart the app.",
          "is_healthy": false
        };
       }
    }

    try {
      // 1. Get Prediction from Classifier
      final prediction = await _classifier.predict(File(imagePath));
      final String rawLabel = prediction['label'];
      final double confidence = prediction['confidence'];

      // 2. Localize the Label
      final String displayLabel = DiseaseLocalizer.getLabel(rawLabel);

      // 3. Determine Health Status
      // Dictionary check for "healthy" or "good"
      bool isHealthy = rawLabel.toLowerCase().contains("healthy") || 
                       rawLabel.toLowerCase().contains("good");

      // 4. Determine Remedy (Placeholder logic for now)
      String remedy = "Consult a local agricultural expert for adequate treatment.";
      if (isHealthy) {
        remedy = "Keep maintaining good irrigation and soil nutrition.";
      }

      return {
        "label": displayLabel,
        "confidence": confidence,
        "remedy": remedy,
        "is_healthy": isHealthy,
        "raw_label": rawLabel // Useful for debugging
      };

    } catch (e) {
      print("Inference Error: $e");
      return {
        "label": "Error Analyzing",
        "confidence": 0.0,
        "remedy": "Technical Error: $e",
        "is_healthy": false
      };
    }
  }

  void dispose() {
    // classifier.close() if we added that method
    _classifier.close();
  }
}
