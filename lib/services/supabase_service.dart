import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart'; // Added for MD5
import 'package:beejx/utils/constants.dart';
import 'database_helper.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // External User ID (for Firebase Auth users)
  String? _externalUserId;

  void setExternalUserId(String? id) {
    _externalUserId = id;
  }
  
  // Helper to get current valid ID (Supabase or External)
  String? get currentUserId {
     final sbUser = _client.auth.currentUser;
     if (sbUser != null) return sbUser.id;
     
     if (_externalUserId != null) {
       // Convert Firebase UID (String) to a deterministic UUID (Postgres Compatible)
       // Algorithm: MD5(uid) -> Hex String (32 chars) -> Insert Hyphens (8-4-4-4-12)
       final bytes = utf8.encode(_externalUserId!);
       final digest = md5.convert(bytes);
       final hex = digest.toString(); // 32 chars
       
       // Format as UUID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
       return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
     }
     return null;
  }

  // Initialize Supabase
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: ApiConstants.supabaseUrl,
      anonKey: ApiConstants.supabaseAnonKey,
    );
  }

  // --- Auth Methods ---
  
  User? get currentUser => _client.auth.currentUser;
  
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<bool> signInWithGoogle() async {
    // Note: This creates the URL for OAuth. 
    // In a real app, you'd use deep linking.
    // For simplicity in this demo, we might need a webview or valid redirect scheme.
    // However, the standard way for native is using the `google_sign_in` package 
    // and passing the idToken to Supabase.
    
    // For now, we will assume standard Supabase OAuth flow or use the native generic method if configured.
    // Implementation depends on deep link setup (io.supabase.flutterdemo://login-callback).
    
    // Simplified Native Google Sign In flow (requires setup):
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutterdemo://login-callback', // Replace with your scheme
      );
      return true;
    } catch(e) {
      print("Google Sign In Error: $e");
      return false;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // --- Sync Engine ---

  /// Syncs offline chats to Supabase when online
  Future<void> syncPendingChats() async {
    final userId = currentUserId;
    if (userId == null) return; // Cannot sync if not logged in

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    try {
      final unsyncedChats = await _dbHelper.getUnsyncedChats();
      if (unsyncedChats.isEmpty) return;

      print("Syncing ${unsyncedChats.length} chats to Supabase...");

      for (var chat in unsyncedChats) {
        final messages = await _dbHelper.getMessages(chat['id']);
        
        // 1. Upsert Chat
        await _client.from('chats').upsert({
          'id': chat['id'],
          'user_id': userId,
          'title': chat['title'],
          'is_local_only': true, // Origin flag
          'created_at': DateTime.fromMillisecondsSinceEpoch(chat['created_at']).toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        // 2. Upsert Messages
        final messagesPayload = messages.map((msg) => {
          'chat_id': chat['id'],
          'role': msg['role'],
          'content': msg['text'],
          'created_at': DateTime.fromMillisecondsSinceEpoch(msg['timestamp']).toIso8601String(),
        }).toList();

        if (messagesPayload.isNotEmpty) {
           await _client.from('messages').upsert(messagesPayload);
        }

        // 3. Mark as Synced Locally
        await _dbHelper.markChatAsSynced(chat['id']);
      }
      print("Sync Complete.");
    } catch (e) {
      print("Sync Failed: $e");
    }
  }

  // --- CRUD Operations ---

  /// Create chat in Supabase (if logged in)
  Future<void> createChat(String id, String title) async {
    final userId = currentUserId;
    if (userId == null) {
      print("Guest Mode: Skipping Supabase chat creation");
      return;
    }

    try {
      await _client.from('chats').insert({
        'id': id,
        'user_id': userId,
        'title': title,
      });
    } catch (e) {
      print("Supabase Create Chat Error: $e");
      // Fallback: Local DB handles it, Sync Engine will pick it up later
    }
  }

  /// Send message to Supabase (if logged in)
  Future<void> sendMessage(String chatId, String role, String content) async {
    final userId = currentUserId;
    if (userId == null) {
      // Guest mode - do strictly local
      return;
    }
    
    try {
      await _client.from('messages').insert({
        'chat_id': chatId,
        'role': role,
        'content': content,
      });
    } catch (e) {
      print("Supabase Send Message Error: $e");
    }
  }

  Future<void> deleteChat(String chatId) async {
    try {
      // Soft Delete
      await _client.from('chats').update({
        'deleted_at': DateTime.now().toIso8601String()
      }).eq('id', chatId);
    } catch (e) {
       print("Supabase Delete Error: $e");
    }
  }

  Stream<List<Map<String, dynamic>>> getChatsStream() {
    return _client
        .from('chats')
        .stream(primaryKey: ['id'])
        .eq('user_id', _client.auth.currentUser!.id)
        .order('updated_at')
        .map((data) => data.where((chat) => chat['deleted_at'] == null).toList());
  }
  // --- Lekha Pay (Blockchain Ledger) ---

  Future<void> insertLedgerBlock(Map<String, dynamic> blockData) async {
    try {
      await _client.from('ledger').insert(blockData);
    } catch (e) {
      print("Supabase Ledger Insert Error: $e");
      throw Exception("Blockchain Sync Failed: $e");
    }
  }

  Future<Map<String, dynamic>?> fetchLatestBlock(String userId) async {
    try {
      final response = await _client
          .from('ledger')
          .select()
          .eq('user_id', userId)
          .order('timestamp', ascending: false)
          .limit(1)
          .maybeSingle();
      return response;
    } catch (e) {
      print("Supabase Ledger Fetch Error: $e");
      return null;
    }
  }

  // --- Schemes Data ---
  Future<List<Map<String, dynamic>>> fetchSchemes() async {
    try {
      final response = await _client
          .from('schemes')
          .select()
          .order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("Supabase Schemes Fetch Error: $e");
      return []; // Return empty list on error
    }
  }

  // --- AI Scheme Discovery ---
  Future<List<Map<String, dynamic>>> discoverSchemes(String region) async {
    // Call the Python Backend AI to find fresh schemes
    try {
      // Uses centralized constant
      final url = Uri.parse("${ApiConstants.schemesDiscoveryEndpoint}?region=$region");
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
           final schemes = List<Map<String, dynamic>>.from(data['schemes']);
           
           // Optional: Save discovered schemes to Supabase for caching?
           // For now, we return them directly to UI to show "AI Findings"
           return schemes;
        }
      }
      return [];
    } catch (e) {
      print("AI Discovery Error: $e");
      return [];
    }
  }
}
