import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/offline_llm_service.dart';
import '../widgets/premium_drawer.dart';

class OfflineChatScreen extends StatefulWidget {
  const OfflineChatScreen({super.key});

  @override
  State<OfflineChatScreen> createState() => _OfflineChatScreenState();
}

class _OfflineChatScreenState extends State<OfflineChatScreen> {
  final OfflineLLMService _llmService = OfflineLLMService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<Map<String, String>> _messages = [];
  
  bool _isLoading = false;
  String? _currentModelName;
  bool _isGenerating = false;
  
  Timer? _resourceTimer;
  String _ramUsage = "Loading...";
  static const platform = MethodChannel('com.beejx.agri/memory');

  @override
  void initState() {
    super.initState();
    _startResourceMonitoring();
  }

  void _startResourceMonitoring() {
    _resourceTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
       try {
         final int totalMem = await platform.invokeMethod('getTotalMemory');
         final int availMem = await platform.invokeMethod('getAvailableMemory');
         
         final totalMB = (totalMem / (1024 * 1024)).toStringAsFixed(0);
         final availMB = (availMem / (1024 * 1024)).toStringAsFixed(0);
         
         if (mounted) {
           setState(() {
             _ramUsage = "$availMB MB Free / $totalMB MB";
           });
         }
       } catch (e) {
         _ramUsage = "--";
       }
    });
  }

  @override
  void dispose() {
    _resourceTimer?.cancel();
    _llmService.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickModel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select GGUF Model',
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        
        setState(() => _isLoading = true);
        
        // Critical: Allow UI to render the loading screen before blocking operation
        await Future.delayed(const Duration(milliseconds: 600));

        await _llmService.loadModel(path);
        
        setState(() {
          _currentModelName = result.files.single.name;
          _isLoading = false;
          _messages.add({
             'role': 'system',
             'text': 'Model loaded: $_currentModelName. Ready to chat.'
          });
        });

        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Success"),
              content: Text("Model '$_currentModelName' loaded successfully!\nYou can now chat offline."),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    if (!_llmService.isModelLoaded) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please load a model first.")));
       return;
    }

    _controller.clear();
    
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isGenerating = true;
      // Add a special "Thinking" state
      _messages.add({'role': 'assistant', 'text': '__THINKING__'}); 
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    
    // Smooth delay for "Thinking" feel
    await Future.delayed(const Duration(milliseconds: 600));
    
    try {
      String responseBuffer = "";
      final stream = _llmService.generateStream(text);
      
      bool firstToken = true;
      
      await for (final token in stream) {
         if (firstToken) {
           responseBuffer = ""; 
           firstToken = false;
         }
         responseBuffer += token;
         
         if (mounted) {
           setState(() {
              _messages.last['text'] = responseBuffer;
           });
         }
         
         if (responseBuffer.length % 3 == 0) _scrollToBottom(); // Smooth scroll
      }
    } catch (e) {
       if (mounted) {
         setState(() {
           _messages.last['text'] = "Error generating response: $e";
         });
       }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          children: [
            Text("BeejX Offline", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            if (_currentModelName != null)
              Text("Running: $_currentModelName", style: const TextStyle(fontSize: 10, color: Colors.green))
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _isGenerating ? null : _pickModel,
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Container(
             color: Colors.black12,
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text("$_ramUsage", style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold)),
                 Text("CPU: ${Platform.numberOfProcessors} Cores", style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold)),
                 Text("Ctx: 1024", style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold)),
               ],
             ),
          ),
        ),
      ),
      drawer: const PremiumDrawer(),
      body: Stack(
        children: [
          // Chat Body
          Column(
            children: [
              if (_currentModelName == null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.psychology, size: 64, color: Colors.grey).animate().fade().scale(),
                        const SizedBox(height: 16),
                        Text("No Brain Loaded", style: GoogleFonts.outfit(fontSize: 20)),
                        const SizedBox(height: 8),
                         Text(
                          "Tap the folder icon to load a GGUF model.",
                          style: GoogleFonts.outfit(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['role'] == 'user';
                      final isSystem = msg['role'] == 'system';
                      
                      if (isSystem) {
                        return Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                            child: Text(msg['text']!, style: const TextStyle(fontSize: 10)),
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                            decoration: BoxDecoration(
                              color: isUser ? Colors.black87 : Colors.white,
                              borderRadius: BorderRadius.circular(20).copyWith(
                                bottomRight: isUser ? Radius.zero : const Radius.circular(20),
                                bottomLeft: !isUser ? Radius.zero : const Radius.circular(20),
                              ),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                              border: !isUser ? Border.all(color: Colors.grey.shade200) : null,
                            ),
                            child: msg['text'] == '__THINKING__'
                                ? const _ThinkingAnimation()
                                : Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: msg['text']!,
                                          style: GoogleFonts.outfit(
                                            color: isUser ? Colors.white : Colors.black87,
                                            fontSize: 16,
                                            height: 1.4,
                                          ),
                                        ),
                                        // Blinking Cursor for Bot (only on last message if generating)
                                        if (!isUser && index == _messages.length - 1 && _isGenerating)
                                          WidgetSpan(
                                            child: Container(
                                              margin: const EdgeInsets.only(left: 4),
                                              width: 8,
                                              height: 16,
                                              color: Colors.green,
                                            ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 300.ms).fadeOut(duration: 300.ms),
                                          )
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0);
                    },
                  ),
                ),
                
              // Input Area
              if (_currentModelName != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)]),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: "Ask BeejX Offline...",
                            hintStyle: GoogleFonts.outfit(color: Colors.grey[400]),
                            border: InputBorder.none,
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.green.withOpacity(0.5))),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                          enabled: !_isGenerating,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                        child: IconButton(
                          icon: _isGenerating 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                              : const Icon(Icons.arrow_upward, color: Colors.white),
                          onPressed: _isGenerating ? null : _sendMessage,
                        ),
                      )
                    ],
                  ),
                ),
            ],
          ),

          // Enhanced Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Container(
                  width: 250,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 20)]
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 50, height: 50,
                        child: CircularProgressIndicator(color: Colors.green, strokeWidth: 4),
                      ),
                      const SizedBox(height: 24),
                      Text("Initializing Neural Core", style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text("Loading tensors into RAM...\nPlease wait.", textAlign: TextAlign.center, style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn(),
              ),
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
//  ANIMATED WIDGETS
// -------------------------------------------------------------

class _ThinkingAnimation extends StatelessWidget {
  const _ThinkingAnimation();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.psychology, size: 16, color: Colors.green),
        const SizedBox(width: 8),
        Text("Thinking", style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(width: 4),
        ...List.generate(3, (index) => 
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: const Icon(Icons.circle, size: 4, color: Colors.green)
                .animate(onPlay: (c) => c.repeat())
                .scale(delay: (index * 200).ms, duration: 600.ms)
                .fade(delay: (index * 200).ms, duration: 600.ms),
          )
        )
      ],
    );
  }
}
