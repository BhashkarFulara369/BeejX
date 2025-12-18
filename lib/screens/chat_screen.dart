import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:flutter_markdown/flutter_markdown.dart'; // For Markdown Rendering
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/llm_service.dart';
import '../services/bhashini_service.dart';
import '../services/network_service.dart';
import '../services/soil_service.dart';
import '../services/database_helper.dart';
import '../services/supabase_service.dart';
import '../services/model_manager.dart'; // Import Model Manager
import '../widgets/premium_drawer.dart';
import 'voice_session_overlay.dart';
import '../utils/constants.dart';

class ChatScreen extends StatefulWidget {
  final String? chatId;
  final bool? isLocal; 

  const ChatScreen({super.key, this.chatId, this.isLocal});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final LLMService _llmService = LLMService();
  final BhashiniService _bhashiniService = BhashiniService();
  final NetworkService _networkService = NetworkService();
  final SoilService _soilService = SoilService();
  final SupabaseService _supabaseService = SupabaseService();
  final ModelManager _modelManager = ModelManager(); // Model Manager Instance
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late String _currentChatId;
  
  // _isOfflineMode: The User Preference Switch
  // If true => Force Offline Stack.
  // If false => Try Cloud (Fall back if network fails).
  bool _isOfflineMode = false;
  
  bool _isLoading = false;
  bool _isDeviceOffline = false; // Actual Network Status
  bool _showSoilHeader = true;
  Map<String, dynamic>? _soilData;
  double _downloadProgress = 0.0;
  bool _isDownloading = false;

  final StreamController<List<Map<String, dynamic>>> _localStreamController = StreamController<List<Map<String, dynamic>>>.broadcast();

  @override
  void initState() {
    super.initState();
    _currentChatId = widget.chatId ?? const Uuid().v4();
    
    // Init Network Listener
    _initNetworkListener();
    _initMode();
    
    // If it's a local chat (legacy arg), we might map it to offline mode?
    // For now, new logic supersedes.
    _refreshLocalMessages();
    
    _controller.addListener(() {
      if (_controller.text.isNotEmpty && _showSoilHeader) {
        setState(() => _showSoilHeader = false);
      } else if (_controller.text.isEmpty && !_showSoilHeader) {
        setState(() => _showSoilHeader = true);
      }
    });

    // Check availability of models on startup
    _checkModelAvailability();
  }
  
  void _initMode() async {
     _isDeviceOffline = await _networkService.checkOffline();
     setState(() {
       _isOfflineMode = _isDeviceOffline; // Default to actual status on launch
     });
  }

  void _checkModelAvailability() async {
    // Check if models downloaded. If not and we switch to offline, we might prompt.
    // Also init the LLM Service if files are there.
    if (await _modelManager.isModelDownloaded()) { // Update to new method name
      _llmService.initializeOfflineModel();
    }
  }

  void _checkInitialNetworkStatus() async {
     bool isOffline = await _networkService.checkOffline();
     setState(() {
        _isDeviceOffline = isOffline;
        // Optionally update _isOfflineMode if strictly following network
     });
     if (isOffline) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You are currently enabled on Offline Mode")));
     } else {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Back Online!")));
     }
  }

  void _refreshLocalMessages() async {
    final dbHelper = DatabaseHelper();
    final messages = await dbHelper.getMessages(_currentChatId);
    _localStreamController.add(messages);
  }

  void _initNetworkListener() async {
    _isDeviceOffline = await _networkService.checkOffline();
    if (mounted) setState(() {});

    _networkService.isOffline.listen((offline) {
      if (mounted) {
        setState(() {
          _isDeviceOffline = offline;
          // Auto-switch ONLY if we lost connection and were in Cloud mode
          if (offline && !_isOfflineMode) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("Connection lost. Switching to Offline Mode.")),
             );
             _isOfflineMode = true;
          }
        });
      }
    });
  }

  void _loadSoilInfo() async {
    final info = await _soilService.getSoilInfo();
    if (mounted && info != null) {
      setState(() {
        _soilData = info;
      });
    }
  }

  @override
  void dispose() {
    _llmService.dispose();
    _localStreamController.close();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _validateInput(String text) {
    final RegExp offensivePattern = RegExp(
      r'\b(kill|suicide|hate|bomb|terror|abuse)\b', 
      caseSensitive: false
    );
    return !offensivePattern.hasMatch(text);
  }
  
  // Download Logic
  void _startModelDownload() async {
    if (!await _modelManager.isHighEndDevice()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your device does not meet the requirements (4GB+ RAM) for Offline AI models.")),
      );
      return;
    }

    setState(() => _isDownloading = true);
    
    _modelManager.downloadAllModels().listen((status) {
       setState(() {
          _downloadProgress = status['progress'];
       });
       if (_downloadProgress >= 1.0) {
          setState(() => _isDownloading = false);
          _llmService.initializeOfflineModel();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Offline Brain Downloaded Successfully!")),
          );
       }
    }, onError: (e) {
       setState(() => _isDownloading = false);
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Download Failed: $e")));
    });
  }

  void _sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    if (!_validateInput(message)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Safety guidelines restrict this query."), backgroundColor: Colors.red));
      _controller.clear();
      return;
    }
    
    // Check if Offline Mode selected but models missing
    if (_isOfflineMode) {
       if (!await _modelManager.isModelDownloaded() && await _modelManager.isHighEndDevice()) {
          // Prompt for download
           showDialog(
             context: context, 
             builder: (ctx) => AlertDialog(
               title: const Text("Download Offline Brain?"),
               content: const Text("To use intelligent offline features, we need to download ~1.5GB of AI models. Continue?"),
               actions: [
                 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                 TextButton(onPressed: () { Navigator.pop(ctx); _startModelDownload(); }, child: const Text("Download")),
               ],
             )
           );
           return;
       }
    }

    setState(() {
      _isLoading = true;
      _controller.clear();
      _showSoilHeader = true; 
    });
    
    // Optimistic UI
    final dbHelper = DatabaseHelper();
    await dbHelper.addMessage(_currentChatId, 'user', message);
    _refreshLocalMessages();
    _scrollToBottom(); 

    // Metadata Sync (Cloud only)
    if (!_isOfflineMode) {
      _supabaseService.createChat(_currentChatId, message.length > 30 ? "${message.substring(0, 30)}..." : message);
    }

    // Generate
    await _llmService.generateResponse(message, _isOfflineMode, chatId: _currentChatId);

    _refreshLocalMessages(); // Update UI

    setState(() {
      _isLoading = false;
    });
    _scrollToBottom();
  }

  Future<void> _pickImage(ImageSource source) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Image analysis available in Cloud Mode only (Coming Soon).")));
  }

  void _openVoiceSession() {
    if (_isOfflineMode) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Voice is not available in Offline Mode.")));
      return;
    }
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => VoiceSessionOverlay(onClose: () => Navigator.pop(context)),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _reportMessage(String messageId) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reported.")));
  }

  Stream<List<Map<String, dynamic>>> _getChatStream() {
    _refreshLocalMessages();
    return _localStreamController.stream;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, 
      drawer: const PremiumDrawer(),
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: theme.appBarTheme.iconTheme,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "BeejX",
              style: GoogleFonts.outfit(
                color: theme.textTheme.titleLarge?.color,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            // MODE TOGGLE BADGE
            GestureDetector(
              onTap: () {
                setState(() => _isOfflineMode = !_isOfflineMode);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isOfflineMode ? "Switched to Offline (Edge) Mode" : "Switched to Cloud Mode"),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isOfflineMode ? Colors.amber.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isOfflineMode ? Colors.amber : Colors.blue,
                    width: 1
                  )
                ),
                child: Row(
                  children: [
                    Icon(
                      _isOfflineMode ? Icons.bolt : Icons.cloud, 
                      size: 14, 
                      color: _isOfflineMode ? Colors.amber : Colors.blue
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isOfflineMode ? "OFFLINE" : "CLOUD",
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _isOfflineMode ? Colors.amber[800] : Colors.blue[800], // Darker text for readability
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.iconTheme.color),
            onPressed: () {
               _checkInitialNetworkStatus();
            },
          )
        ],
      ),
      body: Column(
        children: [
           // DOWNLOADING PROGRESS BAR
           if (_isDownloading)
             Container(
               color: Colors.blue.shade50,
               padding: const EdgeInsets.all(8),
               child: Row(
                 children: [
                   const SizedBox(width: 16),
                   Expanded(
                     child: LinearProgressIndicator(value: _downloadProgress),
                   ),
                   const SizedBox(width: 16),
                   Text("${(_downloadProgress * 100).toInt()}%"),
                 ],
               ),
             ),

           // Connectivity Warning
           if (_isDeviceOffline && !_isOfflineMode)
            Container(
              color: Colors.red.shade100,
              padding: const EdgeInsets.symmetric(vertical: 4),
              width: double.infinity,
              child: Text(
                "No Internet. Please switch to Offline Mode.",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.red.shade900, fontSize: 12),
              ),
            ),

          // Collapsible Soil Header
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: SizedBox(
              height: _showSoilHeader ? null : 0,
              child: GestureDetector(
                onTap: _soilData == null ? _loadSoilInfo : null, 
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _soilData == null 
                          ? [const Color(0xFF4CAF50), const Color(0xFF81C784)]
                          : [const Color(0xFF2E7D32), const Color(0xFF43A047)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _soilData == null 
                      ? Row( 
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.touch_app, color: Colors.white, size: 24),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                "Tap to Localize Soil & Farm Data",
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.white, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  _soilData?['location'] ?? "Locating...",
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSoilStat("Type", _soilData?['soil_type'] ?? "--"),
                                _buildSoilStat("pH", _soilData?['ph'] ?? "--"),
                                _buildSoilStat("Nitrogen", "${_soilData?['nitrogen'] ?? '--'} g/kg"),
                                _buildSoilStat("Clay", "${_soilData?['clay'] ?? '--'}%"),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getChatStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final messages = snapshot.data!;
                
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.spa, size: 48, color: Colors.green),
                        const SizedBox(height: 16),
                        Text(
                          "Namaste! I am BeejX.\n\nAsk me about crops, weather, and mandi prices.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.green),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }

                    final msgData = messages[index];
                    final isUser = msgData['role'] == 'user';
                    final text = msgData['text'] ?? '';

                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                            decoration: BoxDecoration(
                              color: isUser 
                                  ? theme.colorScheme.primary 
                                  : theme.cardColor,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                                bottomLeft: Radius.circular(isUser ? 20 : 4),
                                bottomRight: Radius.circular(isUser ? 4 : 20),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: isUser
                                ? Text(
                                    text,
                                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, height: 1.5),
                                  )
                                : MarkdownBody(
                                    data: text,
                                    styleSheet: MarkdownStyleSheet(
                                      p: GoogleFonts.outfit(color: theme.textTheme.bodyLarge?.color, fontSize: 16, height: 1.5),
                                      strong: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                                      blockSpacing: 8,
                                    ),
                                    selectable: true,
                                  ),
                          ),
                          if (!isUser) Padding(
                             padding: const EdgeInsets.only(bottom: 16, left: 4),
                             child: Row(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 InkWell(
                                   onTap: () {
                                      Clipboard.setData(ClipboardData(text: text));
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied!")));
                                   },
                                   child: Row(children: [Icon(Icons.copy, size: 14, color: Colors.grey[600]), const SizedBox(width: 4), Text("Copy", style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600]))]),
                                 ),
                               ],
                             ),
                          )
                        ],
                      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
                    );
                  },
                );
              },
            ),
          ),
          
          // Disclaimer
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              "BeejX can make mistakes. Verify with experts.",
              style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor, 
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.add_circle_outline, color: theme.iconTheme.color?.withOpacity(0.5)),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                  
                  IconButton(
                    icon: Icon(Icons.camera_alt_outlined, color: theme.iconTheme.color?.withOpacity(0.5)),
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),

                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        style: GoogleFonts.outfit(fontSize: 16, color: theme.textTheme.bodyLarge?.color),
                        decoration: InputDecoration(
                          hintText: _isOfflineMode ? 'Ask offline (Text only)...' : 'Ask BeejX...',
                          border: InputBorder.none,
                          hintStyle: GoogleFonts.outfit(color: theme.hintColor),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Voice / Send Button
                  GestureDetector(
                    onTap: _isLoading ? null : (_controller.text.isEmpty ? _openVoiceSession : _sendMessage),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_isOfflineMode && _controller.text.isEmpty) ? Colors.grey : // Offline + Empty = Disabled Mic
                               (_controller.text.isEmpty ? theme.colorScheme.secondary : theme.colorScheme.primary),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]
                      ),
                      child: Icon(
                        _controller.text.isEmpty ? Icons.mic : Icons.arrow_upward,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoilStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
