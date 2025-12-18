import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';

class Classifier {
  Interpreter? _interpreter;
  List<String> _labels = [];

  Classifier() {
    _loadModel();
    _loadLabels();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      print('Model loaded successfully');
    } catch (e) {
      print('Error loading model: $e');
    }
  }

  Future<void> _loadLabels() async {
    try {
      final labelData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelData.split('\n').where((s) => s.isNotEmpty).toList();
      print('Labels loaded: ${_labels.length}');
    } catch (e) {
      print('Error loading labels: $e');
    }
  }

  Future<Map<String, dynamic>> predict(File imageFile) async {
    if (_interpreter == null) return {"label": "Error: Model not loaded", "confidence": 0.0};

    // 1. Preprocess Image (Resize to 224x224)
    var image = img.decodeImage(imageFile.readAsBytesSync())!;
    image = img.copyResize(image, width: 224, height: 224);

    // 2. Convert to float32 List [1, 224, 224, 3]
    var input = List.generate(1, (i) => List.generate(224, (y) => List.generate(224, (x) {
      var pixel = image.getPixel(x, y);
      return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
    })));

    // 3. Run Inference
    // Adjust output shape based on model
    // Assuming [1, 50] based on labels count
    var output = List.filled(1 * 50, 0.0).reshape([1, 50]);
    _interpreter!.run(input, output);

    // 4. Find Best Class
    var highestProb = 0.0;
    var bestLabelIndex = 0;
    
    for (int i = 0; i < output[0].length; i++) {
        if (output[0][i] > highestProb) {
            highestProb = output[0][i];
            bestLabelIndex = i;
        }
    }

    if (bestLabelIndex < _labels.length) {
      return {
        "label": _labels[bestLabelIndex],
        "confidence": highestProb
      };
    } else {
      return {
        "label": "Unknown",
        "confidence": 0.0
      };
    }
  }
  
  void close() {
    _interpreter?.close();
  }
}
