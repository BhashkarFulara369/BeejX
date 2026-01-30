import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/llm_service.dart';

class VoiceSessionOverlay extends StatefulWidget {
  final VoidCallback onClose;

  const VoiceSessionOverlay({super.key, required this.onClose});

  @override
  State<VoiceSessionOverlay> createState() => _VoiceSessionOverlayState();
}

class _VoiceSessionOverlayState extends State<VoiceSessionOverlay> {
  final LLMService _llmService = LLMService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  
  String _status = "Initializing...";
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  
  String _recognizedText = "Tap the mic to speak";
  String? _aiResponseText;
  late String _sessionId;

  @override
  void initState() {
    super.initState();
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _initVoiceServices();
  }

  void _initVoiceServices() async {
    // 1. Request Permissions
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if(mounted) setState(() => _status = "Mic Permission Denied");
      return;
    }

    // 2. Init STT
    bool available = await _speech.initialize(
      onStatus: (val) => _onSpeechStatus(val),
      onError: (val) => _onSpeechError(val),
    );

    // 3. Init TTS
    await _flutterTts.setLanguage("hi-IN"); // Default to Hindi
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5); // Slower for clarity
    
    _flutterTts.setCompletionHandler(() {
       if(mounted) {
         setState(() {
           _isSpeaking = false;
           _status = "Tap to Reply";
         });
         // If we just finished the greeting, auto-listen?
         // User flow: App speaks greeting -> Users listens -> Users speaks.
         // Let's safe bet: Let user tap OR auto-listen if it was the greeting.
         // For now, simple state reset.
       }
    });

    if (available && mounted) {
      setState(() => _status = "Ready");
      _greetUser();
    } else {
      if(mounted) setState(() => _status = "Voice Engine Failed");
    }
  }

  void _onSpeechStatus(String status) {
    print('STT Status: $status');
    if (status == 'notListening' && _isListening) {
      if(mounted) setState(() => _isListening = false);
    }
  }

  void _onSpeechError(dynamic error) {
    print('STT Error: $error');
    if(mounted) {
      setState(() {
        _isListening = false;
        _status = "Error: Try Again";
      });
    }
  }

  Future<void> _greetUser() async {
    // Specific Hindi Greeting requested by User
    const greeting = "नमस्ते! बीज एक्स में आपका स्वागत है। पूछिए, आप क्या पूछना चाहते हैं?";
    await _speak(greeting);
    
    // Auto-start listening after greeting finishes
    // Note: _speak sets _isSpeaking=true, acts async. 
    // We rely on completion handler to reset state, but for smoother UX we can trigger listen here.
  }

  Future<void> _speak(String text) async {
    if(text.isEmpty) return;
    
    // Force Hindi voice for the greeting to sound natural
    // For other text, try auto-detect or default to Hindi as it's an Agri app
    await _flutterTts.setLanguage("hi-IN"); 
    
    if(mounted) {
      setState(() {
        _isSpeaking = true;
        _status = "Speaking...";
      });
    }
    await _flutterTts.speak(text);
  }

  String _cleanTextForSpeech(String text) {
    // Remove Markdown (*, #, _, -)
    // Replace **bold** with just bold
    return text.replaceAll('*', '')
               .replaceAll('#', '')
               .replaceAll('_', '')
               .replaceAll('-', '')
               .replaceAll('`', '');
  }

  Future<void> _toggleListening() async {
    if (_isProcessing || _isSpeaking) {
      await _flutterTts.stop();
      if(mounted) setState(() => _isSpeaking = false);
      return;
    }

    if (_isListening) {
      _speech.stop();
      if(mounted) setState(() => _isListening = false);
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    if(mounted) {
      setState(() {
        _isListening = true;
        _status = "Listening...";
        _recognizedText = ""; 
        _aiResponseText = null;
      });
    }

    await _speech.listen(
      onResult: (val) {
        if(mounted) {
          setState(() {
            _recognizedText = val.recognizedWords;
          });
          
          if (val.finalResult) {
             _processQuery(val.recognizedWords);
          }
        }
      },
      localeId: "hi_IN", // Priorities Hindi input
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      cancelOnError: true,
      listenMode: stt.ListenMode.search, // Better for queries
    );
  }

  Future<void> _processQuery(String query) async {
    if (query.trim().isEmpty) return;
    
    if(mounted) {
      setState(() {
        _isListening = false;
        _isProcessing = true;
        _status = "Asking BeejX Brain...";
      });
    }

    try {
      // Call Backend (Gemini)
      // isOfflineMode = false (Maximize Quality)
      final response = await _llmService.generateResponse(
        query, 
        false, 
        chatId: _sessionId
      );

        setState(() {
          _isProcessing = false;
          _aiResponseText = response;
          _status = "Answer Ready";
        });
        await _speak(_cleanTextForSpeech(response));
    } catch (e) {
      if(mounted) {
        setState(() {
           _isProcessing = false;
           _status = "Error: $e";
        });
      }
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.95),
      body: SafeArea(
        child: Stack(
          children: [
            // Close Button
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: widget.onClose,
              ),
            ),
            
            // Main Content
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Mic Animation / Button
                    GestureDetector(
                      onTap: _toggleListening,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening ? Colors.redAccent : (_isSpeaking ? Colors.green : Colors.blueAccent),
                          boxShadow: [
                            BoxShadow(
                              color: (_isListening ? Colors.red : Colors.blue).withOpacity(0.5),
                              blurRadius: _isListening || _isSpeaking ? 50 : 20,
                              spreadRadius: _isListening || _isSpeaking ? 10 : 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListening ? Icons.mic : (_isSpeaking ? Icons.volume_up : Icons.mic_none),
                          size: 50,
                          color: Colors.white,
                        ),
                      )
                      .animate(target: _isListening ? 1 : 0)
                      .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 600.ms, curve: Curves.easeInOut)
                      .then(delay: 0.ms).scale(begin: const Offset(1.2, 1.2), end: const Offset(1, 1)),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Recognized Text (User)
                    Text(
                      _recognizedText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white70, 
                        fontSize: 22,
                        fontWeight: FontWeight.w300
                      ),
                    ),

                    const SizedBox(height: 20),

                    // AI Response
                    if (_aiResponseText != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24)
                        ),
                        child: Text(
                          _aiResponseText!,
                          textAlign: TextAlign.center,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: Colors.greenAccent, 
                            fontSize: 18, 
                            fontWeight: FontWeight.w500
                          ),
                        ),
                      ).animate().fadeIn().slideY(begin: 0.2, end: 0),

                    const SizedBox(height: 40),

                    // Status
                    Text(
                      _status,
                      style: GoogleFonts.outfit(
                         color: Colors.white54,
                         fontSize: 16
                      ),
                    ),
                    
                    if (_isProcessing)
                      const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: LinearProgressIndicator(color: Colors.greenAccent),
                      )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
