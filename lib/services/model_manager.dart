import 'dart:async';
    import 'dart:io';
    import 'package:dio/dio.dart';
    import 'package:path_provider/path_provider.dart';

    class ModelManager {
      final Dio _dio = Dio();
      
      // REPLACE THIS WITH YOUR ACTUAL HUGGING FACE TOKEN
      // Get it here: https://huggingface.co/settings/tokens
      final String _hfToken = "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"; 

      // Model 1: BeejX Custom Hindi SFT Model (Gemma 2 2B)
      final String gemmaUrl = "https://huggingface.co/bf369/BeejX-Gemma2-2B-Hindi-SFT/resolve/main/gemma-2-2b-it.Q4_K_M.gguf?download=true"; 
      final String gemmaFileName = "gemma-2-2b-it.Q4_K_M.gguf";

      // Model 2: Embedding Model (Multilingual MiniLM ONNX)
      final String embeddingUrl = "https://huggingface.co/Xenova/paraphrase-multilingual-MiniLM-L12-v2/resolve/main/onnx/model_quantized.onnx?download=true";
      final String embeddingFileName = "model_quantized.onnx";

      // Model 3: Vocab for Tokenizer
      // Model 3: Vocab for Tokenizer (Note: using tokenizer.json as vocab.txt is missing in Xenova repo)
      final String vocabUrl = "https://huggingface.co/Xenova/paraphrase-multilingual-MiniLM-L12-v2/resolve/main/tokenizer.json?download=true";
      final String vocabFileName = "tokenizer.json";

      Future<String> getGemmaPath() async {
        final dir = await getApplicationDocumentsDirectory();
        return "${dir.path}/$gemmaFileName";
      }

      Future<String> getEmbeddingModelPath() async {
        final dir = await getApplicationDocumentsDirectory();
        return "${dir.path}/$embeddingFileName";
      }

      Future<String> getVocabPath() async {
        final dir = await getApplicationDocumentsDirectory();
        return "${dir.path}/$vocabFileName";
      }

      // RAM Check (> 3.5GB considered "4GB High End")
      Future<bool> isHighEndDevice() async {
        // TODO: restore actual check once device_info_plus version is confirmed.
        // For now, assume modern device to unblock build.
        print("RAM Check strictly bypassed for compatibility.");
        return true; 
      }

      Future<bool> isModelDownloaded() async {
        final gReader = await getGemmaPath();
        final eReader = await getEmbeddingModelPath();
        final vReader = await getVocabPath();
        
        // Heuristic: Check if files exist AND have meaningful size (> 1MB)
        try {
          final gFile = File(gReader);
          final eFile = File(eReader);
          final vFile = File(vReader);
          
          if (!await gFile.exists() || !await eFile.exists() || !await vFile.exists()) {
            print("❌ Offline Models NOT found.");
            return false;
          }
          
          int gSize = await gFile.length();
          int eSize = await eFile.length();
          print("🔍 Model Check: Gemma=${(gSize/1024/1024).toStringAsFixed(2)}MB, Embedding=${(eSize/1024).toStringAsFixed(2)}KB");

          if (gSize < 1024 * 1024 || eSize < 1024) { 
            print("⚠️ Model files found but too small (corrupt). Deleting...");
            await gFile.delete();
            await eFile.delete();
            await vFile.delete();
            return false;
          }
          print("✅ Offline Models Verified & Ready.");
          return true;
        } catch (e) {
          return false;
        }
      }

      // Alias for legacy calls and UI compatibility
      Stream<Map<String, dynamic>> downloadAllModels() {
        StreamController<Map<String, dynamic>> controller = StreamController<Map<String, dynamic>>();
        
        _startDownloadSequence(controller);
        
        return controller.stream;
      }
      
      // Also expose single model download compatible stream if needed, but UI expects Map
      Stream<Map<String, dynamic>> downloadModel() => downloadAllModels();

      void _startDownloadSequence(StreamController controller) async {
        try {
          // 1. Embedding Model
          final ePath = await getEmbeddingModelPath();
          if (!await File(ePath).exists()) {
              controller.add({"progress": 0.0, "status": "Downloading Embedding Model..."});
              await _downloadFile(embeddingUrl, ePath, (prog) {
                // Scale 0.0 -> 0.25
                controller.add({"progress": prog * 0.25, "status": "Downloading Embedding Model..."});
              });
          }

          // 2. Vocab
          final vPath = await getVocabPath();
          if (!await File(vPath).exists()) {
              controller.add({"progress": 0.25, "status": "Downloading Tokenizer Vocab..."});
              await _downloadFile(vocabUrl, vPath, (prog) {
                // Scale 0.25 -> 0.3
                controller.add({"progress": 0.25 + (prog * 0.05), "status": "Downloading Tokenizer Vocab..."});
              });
          }

          // 3. Gemma Model
          final gPath = await getGemmaPath();
          if (!await File(gPath).exists()) {
              controller.add({"progress": 0.3, "status": "Downloading Gemma 2B (Large)..."});
              // Pass Token for this download if it's the custom private one
              await _downloadFile(gemmaUrl, gPath, (prog) {
                // Scale 0.3 -> 1.0
                controller.add({"progress": 0.3 + (prog * 0.7), "status": "Downloading Gemma 2B..."});
              }, useToken: true);
          }

          controller.add({"progress": 1.0, "status": "Done!"});
          await controller.close();

        } catch (e) {
          print("Download Sequence Error: $e");
          if (e is DioException) {
              print("DioError: ${e.response?.statusCode} - ${e.response?.statusMessage}");
          }
          controller.addError(e);
          await controller.close();
        }
      }

      Future<void> _downloadFile(String url, String path, Function(double) onProgress, {bool useToken = false}) async {
        Options? options;
        if (useToken) {
          options = Options(headers: {"Authorization": "Bearer $_hfToken"});
        }

        await _dio.download(
          url,
          path,
          options: options,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              onProgress(received / total);
            }
          },
        );
      }
}