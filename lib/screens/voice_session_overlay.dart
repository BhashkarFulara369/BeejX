import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/bhashini_service.dart';
import '../services/llm_service.dart';

class VoiceSessionOverlay extends StatefulWidget {
  final VoidCallback onClose;

  const VoiceSessionOverlay({super.key, required this.onClose});

  @override
  State<VoiceSessionOverlay> createState() => _VoiceSessionOverlayState();
}

class _VoiceSessionOverlayState extends State<VoiceSessionOverlay> {
  final BhashiniService _bhashiniService = BhashiniService();
  final LLMService _llmService = LLMService(); // Replaces direct LocalRAGService
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  String _status = "Tap to Speak"; // Initial state
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isPlaying = false;
  
  String? _recognizedText;
  String? _translatedText;
  late String _voiceSessionId; // Maintain context for this session

  @override
  void initState() {
    super.initState();
    _voiceSessionId = DateTime.now().millisecondsSinceEpoch.toString(); // Simple ID
    _initBhashini();
  }

  void _initBhashini() async {
    try {
      await _bhashiniService.initialize();
      // Play Namaste Greeting
      await _playNamaste();
    } catch (e) {
      debugPrint("Error initializing Bhashini: $e");
      if(mounted) setState(() => _status = "Error initializing");
    }
  }

  Future<void> _playNamaste() async {
    if(!mounted) return;
    setState(() => _status = "Namaste!");
    
    // Hindi Greeting 
    final audioContent = await _bhashiniService.generateTTS(
      "नमस्ते! बीज एक्स में आपका स्वागत है। पूछिए, क्या पूछना है?", 
      'hi'
    );
    
    if (audioContent != null && mounted) {
      await _playResponse(audioContent);
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isProcessing || _isPlaying) return;

    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/bhashini_audio.wav';
        
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ), 
          path: path
        );
        
        setState(() {
          _isRecording = true;
          _status = "Listening...";
          _recognizedText = null;
          _translatedText = null;
        });
      }
    } catch (e) {
      debugPrint("Error starting recording: $e");
      setState(() => _status = "Error recording");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _status = "Processing...";
        _isProcessing = true;
      });

      if (path != null) {
        await _processAudio(path);
      }
    } catch (e) {
      debugPrint("Error stopping recording: $e");
      setState(() {
        _status = "Error stopping";
        _isProcessing = false;
      });
    }
  }

  Future<void> _processAudio(String path) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final base64Audio = base64Encode(bytes);

      setState(() => _status = "Identifying Language...");
      
      // 1. Detect Language
      String sourceLang = 'en'; // Default
      final detectedLang = await _bhashiniService.detectLanguage(base64Audio);
      
      if (detectedLang != null && detectedLang != 'unknown') {
        sourceLang = detectedLang;
        setState(() => _status = "Detected: $sourceLang. Processing...");
      } else {
        sourceLang = 'en'; // Explicit fallback
        setState(() => _status = "Language Unknown. Using English...");
      }

      // 2. Determine Target Language (Multilingual Mode)
      // Answer in the SAME language the user spoke.
      String targetLang = sourceLang; 

      // 3. Compute (ASR + Translation + TTS)
      // We mainly need ASR here. 
      final response = await _bhashiniService.compute(
        sourceLanguage: sourceLang,
        targetLanguage: targetLang, // Echo back for ASR accuracy
        audioBase64: base64Audio,
      );

      final pipelineResponse = response['pipelineResponse'];
      
      // Parse Response
      String? asrOutput;
      String? translationOutput;
      String? ttsAudioContent;

      if (pipelineResponse != null && pipelineResponse.isNotEmpty) {
        // ASR
        if (pipelineResponse.length > 0) {
           asrOutput = pipelineResponse[0]['output']?[0]['source'];
        }
      }

      // --- SMART ONLINE VOICE AGENT (Gemini) ---
      if (asrOutput != null) {
        setState(() => _status = "Asking Gemini ($sourceLang)...");
        
        // Use Online Backend (Gemini) which now has Soil/Weather Context
        // Pass 'false' for isOffline.
        final aiResponse = await _llmService.generateResponse(
          asrOutput, 
          false, 
          chatId: _voiceSessionId // Maintain History!
        ); 
        
        print("Gemini Voice Answer: $aiResponse");

        setState(() {
          _recognizedText = asrOutput;
          _translatedText = aiResponse; 
          _status = "Speaking Answer...";
        });

        // Generate TTS for the AI Answer in the SAME language
        ttsAudioContent = await _bhashiniService.generateTTS(aiResponse, targetLang);
      }
      // ---------------------------------------------

      setState(() {
        _recognizedText = asrOutput;
        if (_translatedText == null) _translatedText = translationOutput; // Only if RAG didn't overwrite
        _status = (_translatedText != null) ? "Speaking..." : "Finished";
        _isProcessing = false;
      });

      if (ttsAudioContent != null) {
        await _playResponse(ttsAudioContent);
      } else {
        setState(() => _status = "Tap to Speak");
      }

    } catch (e) {
      debugPrint("Error processing audio: $e");
      setState(() {
        _status = "Error: $e";
         _isProcessing = false;
      });
    }
  }

  Future<void> _playResponse(String base64Audio) async {
    try {
      final bytes = base64Decode(base64Audio);
      // Currently AudioPlayers might not support playing bytes directly easily without a file or specialized source
      // So we write to file
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/bhashini_response.wav';
      await File(path).writeAsBytes(bytes);

      setState(() => _isPlaying = true);
      await _audioPlayer.play(DeviceFileSource(path));
      
      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _status = "Tap to Speak";
          });
        }
      });
    } catch (e) {
      debugPrint("Error playing audio: $e");
      setState(() {
         _status = "Error playing";
         _isPlaying = false;
      });
    }
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Text Display
                  if (_recognizedText != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        _recognizedText!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16),
                      ),
                    ),
                  
                  if (_translatedText != null) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        _translatedText!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: Colors.greenAccent, 
                          fontSize: 20, 
                          fontWeight: FontWeight.w600
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),

                  // Glowing Orb / Mic Button
                  GestureDetector(
                    onTap: _toggleRecording,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording ? Colors.redAccent : (_isPlaying ? Colors.green : Colors.white),
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording ? Colors.red : Colors.blue).withOpacity(0.5),
                            blurRadius: _isRecording || _isPlaying ? 50 : 30,
                            spreadRadius: _isRecording || _isPlaying ? 20 : 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : (_isPlaying ? Icons.volume_up : Icons.mic),
                        size: 50,
                        color: _isRecording || _isPlaying ? Colors.white : Colors.black,
                      ),
                    )
                    .animate(target: _isProcessing ? 1 : 0)
                    .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1000.ms, curve: Curves.easeInOut)
                    .then(delay: 0.ms).scale(begin: const Offset(1.1, 1.1), end: const Offset(1, 1)),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Status Text
                  Text(
                    _status,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                    ),
                  ).animate().fadeIn(duration: 500.ms),
                  
                  if (_isProcessing)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
