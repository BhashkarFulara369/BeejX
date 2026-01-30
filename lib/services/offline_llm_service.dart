import 'dart:async';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

class OfflineLLMService {
  Llama? _llama;
  String? _modelPath;
  
  // Status check
  bool get isModelLoaded => _llama != null;
  String? get currentModelPath => _modelPath;

  /// Loads the model with optimized settings for low-end devices (e.g., Vivo 1820)
  /// Throws exception if loading fails
  Future<void> loadModel(String filePath) async {
    try {
      if (_llama != null) {
        dispose();
      }

      // Memory-safe parameters for 2GB RAM device
      final contextParams = ContextParams();
      contextParams.nCtx = 1024; // Lower context to save RAM (safe for 270M model)
      // contextParams.seed = -1; // Removed: API mismatch in v0.2.2
      contextParams.nThreads = 4; // Max 4 threads to prevent UI freeze on quad-core/weak CPUs
      contextParams.nBatch = 512;

      final modelParams = ModelParams();
      modelParams.nGpuLayers = 0; // Force CPU only
      // modelParams.useMlock = false; // Removed: API mismatch
      modelParams.vocabOnly = false;

      _llama = Llama(
        filePath,
        modelParams: modelParams,
        contextParams: contextParams,
      );

      _modelPath = filePath;
      print("Offline Model loaded successfully: $filePath");
    } catch (e) {
      print("Error loading model: $e");
      _llama = null;
      _modelPath = null;
      rethrow;
    }
  }

  /// Generates response as a stream
  Stream<String> generateStream(String prompt) async* {
    if (_llama == null) {
      yield "Error: No model loaded. Please load a model first.";
      return;
    }

    try {
      // Format prompt for instruction tuned models if needed
      // For user's Gemma 270M IT, standard chat formatting is ideal but raw prompt works for testing
      // Format: <start_of_turn>user\n{prompt}<end_of_turn>\n<start_of_turn>model\n
      
      // Simplified prompt with minimal Identity (Requested by User)
      final formattedPrompt = "<start_of_turn>user\nYou are BeejX, a smart agricultural assistant.\n\n$prompt<end_of_turn>\n<start_of_turn>model\n";
      
      _llama!.setPrompt(formattedPrompt);

      // Consume the stream (fixed API)
      await for (final token in _llama!.generateText()) {
        yield token;
      }
    } catch (e) {
      yield "\n[Error generating response: $e]";
    }
  }

  /// Explicitly free memory
  void dispose() {
    try {
      _llama?.dispose();
    } catch (e) {
      print("Error disposing model: $e");
    }
    _llama = null;
    _modelPath = null;
  }
}
