import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_helper.dart';
import '../services/supabase_service.dart';
import 'chat_screen.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SupabaseService _supabaseService = SupabaseService();
  
  // Combined List of Chats
  List<Map<String, dynamic>> _allChats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllChats();
    _syncIfNeeded();
  }
  
  Future<void> _syncIfNeeded() async {
    await _supabaseService.syncPendingChats();
    if(mounted) _loadAllChats();
  }

  Future<void> _loadAllChats() async {
    setState(() => _isLoading = true);
    List<Map<String, dynamic>> combined = [];

    // 1. Fetch Local Chats (SQLite)
    final localChats = await _dbHelper.getChats();
    for (var chat in localChats) {
      combined.add({
        'id': chat['id'],
        'title': chat['title'],
        'last_updated': DateTime.fromMillisecondsSinceEpoch(chat['last_updated']),
        'source': 'local', // Even synced chats are 'local' for offline access
        'is_synced': chat['is_synced'] == 1,
      });
    }
    
    // We prioritize local cache for standard usage, but you could merge Cloud stream here if needed for multi-device.
    // Ideally, SyncEngine puts cloud chats INTO local DB so we just read DB.
    // For now, let's keep it simple: Show Local DB (which contains synced + unsynced).

    // 3. Sort by Date (Newest First)
    combined.sort((a, b) {
        final dA = a['last_updated'] as DateTime;
        final dB = b['last_updated'] as DateTime;
        return dB.compareTo(dA);
    });

    if (mounted) {
      setState(() {
        _allChats = combined;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteChat(String chatId) async {
    // 1. Delete from Supabase (Soft Delete)
    await _supabaseService.deleteChat(chatId);
    
    // 2. Delete from Local DB
    await _dbHelper.deleteChat(chatId);
    
    _loadAllChats(); // Refresh list
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          "History",
          style: GoogleFonts.outfit(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.blue),
            onPressed: () {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Syncing...")));
               _syncIfNeeded();
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allChats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        "No chat history yet.",
                        style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _allChats.length,
                  itemBuilder: (context, index) {
                    final chat = _allChats[index];
                    final date = chat['last_updated'] as DateTime;
                    final isSynced = chat['is_synced'] == true;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: isSynced ? Colors.green.shade50 : Colors.orange.shade50,
                          child: Icon(
                            isSynced ? Icons.cloud_done : Icons.cloud_upload,
                            color: isSynced ? Colors.green : Colors.orange,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          chat['title'],
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          "${date.day}/${date.month}/${date.year} • ${isSynced ? 'Synced' : 'Offline'}",
                          style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteChat(chat['id']),
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                chatId: chat['id'],
                                isLocal: true, // Always load from local for speed
                              ),
                            ),
                          );
                          _loadAllChats(); // Refresh list on return
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
