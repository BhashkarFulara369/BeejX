import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'bhashini_config.dart';

class BhashiniService {
  String? _computeUrl;
  Map<String, String>? _computeAuthHeader;
  
  // Master Map for Service IDs
  // Key format: 
  // ASR: "asr/<sourceLang>"
  // Translation: "translation/<sourceLang>/<targetLang>"
  // TTS: "tts/<targetLang>"
  final Map<String, String> _serviceIdMap = {};
  
  bool _isConfigConfigured = false;

  // Custom client to ignore SSL errors
  http.Client _getClient() {
    final ioc = HttpClient();
    ioc.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return IOClient(ioc);
  }

  void _log(String message) {
    print('[BhashiniService] $message');
  }

  Future<void> initialize() async {
    // Proactively fetch config on init to be ready
    try {
      await _ensureConfig();
    } catch (e) {
      _log("Init warning: $e");
    }
  }

  /// Fetches the GENERIC full config for the pipeline.
  /// This avoids "400 Sequence not supported" because we don't ask for a specific sequence.
  /// We ask for "Everything you have".
  Future<void> _ensureConfig() async {
    if (_isConfigConfigured) return;

    _log("Fetching Generic Pipeline Config...");
    
    // Empty payload request to get ALL details
    final body = {
      "pipelineTasks": [
         // Sending empty list or minimal generic request often returns full config
         // But per docs, to "discover", we might just send the pipelineID.
         // Let's try sending common tasks WITHOUT language constraints to see all options.
         // ACTUALLY, the doc says "Request sent without configuration parameter" (Tab 1)
         // returns "config": [...] for each task. This is what we want!
         { "taskType": "asr" },
         { "taskType": "translation" },
         { "taskType": "tts" }
      ],
      "pipelineRequestConfig": {
        "pipelineId": BhashiniConfig.pipelineId
      }
    };

    final url = Uri.parse(BhashiniConfig.getPipelineUrl);
    final headers = {
      'Content-Type': 'application/json',
      'userID': BhashiniConfig.userId,
      'ulcaApiKey': BhashiniConfig.apiKey,
    };
    
    final client = _getClient();
    try {
      final response = await client.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        _log('Config Response (Summary): Status 200'); // Log full body only if debugging, it's huge
        final data = jsonDecode(response.body);
        
        // 1. Setup Auth
        final inferenceEndPoint = data['pipelineInferenceAPIEndPoint'];
        _computeUrl = inferenceEndPoint['callbackUrl'];
        final authKey = inferenceEndPoint['inferenceApiKey'];
        _computeAuthHeader = {
          authKey['name']: authKey['value'], 
        };
        
        // 2. Parse EVERYTHING into _serviceIdMap
        final pipelineResponseConfig = data['pipelineResponseConfig'] as List<dynamic>;
        
        for (var taskConfig in pipelineResponseConfig) {
          final taskType = taskConfig['taskType'];
          final configList = taskConfig['config'] as List<dynamic>;
          
          for (var configItem in configList) {
            final serviceId = configItem['serviceId'];
            final language = configItem['language'];
            
            if (taskType == 'asr') {
              // Key: asr/en
              final src = language['sourceLanguage'];
              _serviceIdMap["asr/$src"] = serviceId;
            } else if (taskType == 'translation') {
              // Key: translation/en/hi
              final src = language['sourceLanguage'];
              final tgt = language['targetLanguage'];
              _serviceIdMap["translation/$src/$tgt"] = serviceId;
            } else if (taskType == 'tts') {
              // Key: tts/hi
              // TTS config usually has sourceLanguage as the language to speak
              final src = language['sourceLanguage']; 
              _serviceIdMap["tts/$src"] = serviceId;
            }
          }
        }
        
        _isConfigConfigured = true;
        _log("Config Parsed. Loaded ${_serviceIdMap.length} Service IDs.");
        
      } else {
        throw Exception('Failed to get generic pipeline config: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error getting pipeline config: $e');
      rethrow;
    } finally {
      client.close();
    }
  }

  /// COMPUTE: Uses Local Lookup
  Future<Map<String, dynamic>> compute({
    required String sourceLanguage,
    required String targetLanguage,
    required String audioBase64,
  }) async {
    
    await _ensureConfig();
    
    // Lookup IDs
    final asrId = _serviceIdMap["asr/$sourceLanguage"];
    final transId = _serviceIdMap["translation/$sourceLanguage/$targetLanguage"];
    final ttsId = _serviceIdMap["tts/$targetLanguage"];
    
    if (asrId == null) throw Exception("ASR not supported for $sourceLanguage");
    // Translations might be missing, but standard pairs usually exist.

    final url = Uri.parse(_computeUrl!);
    final headers = {
      'Content-Type': 'application/json',
      ...?_computeAuthHeader, 
    };

    // Build Tasks based on availability
    List<Map<String, dynamic>> tasks = [];
    
    // 1. ASR
    tasks.add({
      "taskType": "asr",
      "config": {
        "language": { "sourceLanguage": sourceLanguage },
        "serviceId": asrId, 
        "audioFormat": "wav"
      }
    });

    // 2. Translation (Only if ID found and languages differ)
    if (transId != null && sourceLanguage != targetLanguage) {
      tasks.add({
        "taskType": "translation",
        "config": {
          "language": { 
             "sourceLanguage": sourceLanguage,
             "targetLanguage": targetLanguage
          },
          "serviceId": transId
        }
      });
    }

    // 3. TTS (Only if ID found)
    if (ttsId != null) {
      tasks.add({
        "taskType": "tts",
        "config": {
          "language": { "sourceLanguage": targetLanguage },
          "serviceId": ttsId
        }
      });
    }

    final body = {
      "pipelineTasks": tasks,
      "inputData": {
        "audio": [
          { "audioContent": audioBase64 }
        ]
      }
    };

    final client = _getClient();
    try {
      _log('Compute Request: ${jsonEncode(body)}');
      final response = await client.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        _log('Compute Response: ${response.body}');
        return jsonDecode(response.body);
      } else {
        _log('Compute Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to compute: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error computing: $e');
      rethrow;
    } finally {
      client.close();
    }
  }

  /// TTS: Uses Local Lookup
  Future<String?> generateTTS(String text, String language) async {
    await _ensureConfig();
    
    final ttsId = _serviceIdMap["tts/$language"];
    if (ttsId == null) {
      _log("Warning: No TTS Service ID found for $language");
       return null;
    }
    
    final url = Uri.parse(_computeUrl!);
    final headers = {
      'Content-Type': 'application/json',
      ...?_computeAuthHeader, 
    };

    final body = {
      "pipelineTasks": [
        {
          "taskType": "tts",
          "config": {
            "language": { "sourceLanguage": language },
            "serviceId": ttsId
          }
        }
      ],
      "inputData": {
        "input": [
          { "source": text }
        ]
      }
    };

    final client = _getClient();
    try {
      _log('TTS Request: ${jsonEncode(body)}');
      final response = await client.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _log('TTS Response: ${response.body}');
        final pipelineResponse = data['pipelineResponse'];
        if (pipelineResponse != null && pipelineResponse.isNotEmpty) {
           return pipelineResponse[0]['audio']?[0]['audioContent'];
        }
        return null;
      } else {
        _log('TTS Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error generating TTS: $e');
      return null;
    } finally {
      client.close();
    }
  }
  
  Future<String?> detectLanguage(String audioBase64) async {
    if (_computeUrl == null) await _ensureConfig();
    
    final url = Uri.parse(_computeUrl!);
    final headers = {
      'Content-Type': 'application/json',
      ...?_computeAuthHeader, 
    };
    
    // Hardcoded Detect Service (Shared across most pipelines)
    final body = {
      "pipelineTasks": [
        {
          "taskType": "audio-lang-detection",
          "config": {
            "serviceId": "bhashini/iitmandi/audio-lang-detection/gpu"
          }
        }
      ],
      "inputData": {
        "audio": [
          { "audioContent": audioBase64 }
        ]
      }
    };

    final client = _getClient();
    try {
      _log('Detect Language Request: ${jsonEncode(body)}');
      final response = await client.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _log('Detect Language Response: ${response.body}');
        
        final pipelineResponse = data['pipelineResponse'];
        if (pipelineResponse != null && pipelineResponse.isNotEmpty) {
           final output = pipelineResponse[0]['output'];
           if (output != null && output.isNotEmpty) {
             final langPrediction = output[0]['langPrediction'];
             if (langPrediction != null && langPrediction.isNotEmpty) {
               final detectedLang = langPrediction[0]['langCode'];
               
            // Validation: Do we have an ASR model for this?
               if (_serviceIdMap.containsKey("asr/$detectedLang")) {
                 return detectedLang;
               } else if (detectedLang == 'hi-en') {
                  // Special case for Hinglish -> Treat as Hindi ASR (usually works best)
                  return 'hi';
               } else {
                 _log("Warning: Detected '$detectedLang' but no ASR model found. Falling back to 'hi'");
                 // Fallback to Hindi (most common) or English, to prevent crash
                 return 'hi';
               }
             }
           }
        }
        return 'hi'; // Default fallback if detection returns empty but 200 OK
      } else {
        _log('Detect Language Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error detecting language: $e');
      return null;
    } finally {
      client.close();
    }
  }
}
