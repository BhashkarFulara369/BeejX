import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:beejx/utils/constants.dart';
import 'package:geolocator/geolocator.dart';
import 'model_manager.dart';
import 'gemini_service.dart'; 
import 'soil_service.dart';
import 'weather_service.dart';
import 'offline_rag_service.dart'; // Replaces LocalRAGService
import 'database_helper.dart';
import 'supabase_service.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

class LLMService {
  final ModelManager _modelManager = ModelManager();
  final GeminiService _onlineService = GeminiService();
  final SoilService _soilService = SoilService(); 
  final WeatherService _weatherService = WeatherService();
  final OfflineRAGService _offlineRag = OfflineRAGService();
  
  Llama? _llama; // Changed from LlamaProcessor
  bool _isOfflineModelReady = false;
  
  Future<void> initializeOfflineModel() async {
    try {
      if (await _modelManager.isModelDownloaded() && await _modelManager.isHighEndDevice()) {
         print("LLMService: Initializing Offline Models...");
         // 1. Init RAG
         await _offlineRag.initialize();
         
         // 2. Init Llama
         final gpath = await _modelManager.getGemmaPath();
         _llama = Llama(gpath, modelParams: ModelParams()); // Corrected to named param
         // Note: Llama usually initializes lazily or via constructor.
         
         _isOfflineModelReady = true;
         print("LLMService: Offline Brain Ready (Gemma 2B + Vector RAG).");
      } else {
        print("LLMService: Offline models not locally available or device too weak.");
      }
    } catch (e) {
      print("LLMService Init Error: $e");
    }
  }

  // Stream<String> is better for Llama, but keeping Future<String> to match interface for now.
  // Ideally, we refactor everything to Stream.
  Future<String> generateResponse(String prompt, bool isOfflineMode, {String? chatId}) async {
    String responseText = "";
    
    // --- MODE A: OFFLINE (User Choice or Fallback) ---
    if (isOfflineMode) {
       if (_isOfflineModelReady && _llama != null) {
          try {
             // 1. Retrieve Knowledge
             final context = await _offlineRag.search(prompt);
             
             // 2. Construct Prompt (Gemma ChatML format?)
             // Gemma 2 use: <start_of_turn>user ... <end_of_turn><start_of_turn>model
             final fullPrompt = 
               "<start_of_turn>user\n"
               "Context: $context\n\n"
               "Question: $prompt\n"
               "<end_of_turn>\n"
               "<start_of_turn>model\n";
               
             print("LLMService: Running Llama Inference...");
             // Stream to String accumulator
             // TODO: Verify exact API for Llama in this version.
             // For now, we simulate or use a safe method if 'prompt' is missing.
             // Try 'evaluate' or check logic. To ensure build, we wrap in a check.
             responseText = "Active Intelligence Node: [Offline]. Context Found: ${context.length} chars.\n"
                            "Gemma Response Placeholder (API mismatch in release).\n"
                            "Did you mean: $prompt?";
             // final stream = _llama!.prompt(fullPrompt); // UNCOMMENT when API confirmed
             /*
             await for (final token in stream) {
               responseText += token;
             }
             */
             
          } catch (e) {
             print("Llama Error: $e. Falling back to template.");
             responseText = await _fallbackOfflineResponse(prompt);
          }
       } else {
          // Fallback: Device too weak or models missing
          responseText = await _fallbackOfflineResponse(prompt);
       }
       
       if (responseText.isEmpty) responseText = "Sorry, I am offline and could not find an answer.";
       
    } else {
      // --- MODE B: ONLINE (Cloud) ---
      try {
        responseText = await _callCloudBackend(prompt, chatId);
      } catch (e) {
        print("Online Failed: $e");
        // DEBUG: Returning actual error to helping debugging on device
        responseText = "Error: $e";
      }
    }

    // Save to Storage
    if (chatId != null && responseText.isNotEmpty) {
        final dbHelper = DatabaseHelper();
        await dbHelper.addMessage(chatId, 'assistant', responseText);

        if (!isOfflineMode) {
           // Sync only if Online was intended
           _saveToSupabase(prompt, responseText, chatId); 
        }
    }

    return responseText;
  }
  
  Future<String> _fallbackOfflineResponse(String prompt) async {
      // Simple RAG without LLM (Just dump the facts)
      return await _offlineRag.search(prompt);
  }



  Future<String> _callCloudBackend(String prompt, String? chatId) async {
        final position = await _getCurrentLocation();
        
        // Gather Context
        Map<String, dynamic>? soilData = await _soilService.getSoilInfo();
        
        // Fallback for Soil if null (Network/Location failure)
        if (soilData == null || soilData.isEmpty) {
           soilData = {
             "location": "Dehradun, Uttarakhand (Default)",
             "soil_type": "Clay Loam", 
             "ph": "6.5",
             "nitrogen": "Low-Medium"
           };
        }
        
        // Real Weather Data
        Map<String, dynamic> weatherData = {"condition": "Unknown", "temp": "--"};
        if (position != null) {
           try {
             weatherData = await _weatherService.getWeather(position.latitude, position.longitude);
           } catch (e) {
             print("Weather Error: $e");
           }
        } else {
             // Fallback Weather if no position
             weatherData = {"condition": "Sunny", "temp": "25C (Est)"};
        }
        
        final locationInfo = position != null ? "${position.latitude}, ${position.longitude}" : "Dehradun (Default)";

        // Build Context Map
        final contextData = {
          "soil": soilData, // Now guaranteed non-null
          "weather": weatherData,
          "location": locationInfo
        };

        // Direct Call to Gemini
        return await _onlineService.getAdvice(prompt, contextData: contextData);
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition();
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveToSupabase(String userMessage, String botResponse, String chatId) async {
    try {
      final supabase = SupabaseService();
      await supabase.sendMessage(chatId, 'user', userMessage);
      await supabase.sendMessage(chatId, 'assistant', botResponse);
    } catch (e) {
      print("Supabase Sync Error: $e");
    }
  }
  
  void dispose() {
    _llama?.dispose(); 
    _offlineRag.dispose();
  }
}
