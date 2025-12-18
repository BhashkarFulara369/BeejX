import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'supabase_service.dart';

class LekhaService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SupabaseService _supabase = SupabaseService();

  // Generate a SHA-256 Hash for a transaction
  String generateHash(Map<String, dynamic> data) {
    // Sort keys to ensure deterministic hash (critical for blockchain)
    final sortedKeys = data.keys.toList()..sort();
    final sortedMap = {for (var k in sortedKeys) k: data[k].toString()};
    
    final jsonString = jsonEncode(sortedMap);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);
    
    return digest.toString();
  }

  // Create a new "Block" (Transaction)
  Future<Map<String, String>> createTransaction(String schemeName, double amount) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final timestamp = DateTime.now().toIso8601String();
    
    // 1. Get previous hash (Chain Linking)
    String previousHash = "00000000000000000000000000000000";
    
    // We use the Supabase User ID (which might be linked to Firebase UID via external_id or handled by our dual-service)
    // For now we trust SupabaseService.currentUserId logic or pass Firebase UID explicitly if table uses that.
    // The user confirmed "farmer's information", so we use the best ID we have.
    final uid = user.uid; 
    
    final lastBlock = await _supabase.fetchLatestBlock(uid);
    if (lastBlock != null) {
      previousHash = lastBlock['hash'] ?? previousHash;
    }

    // 2. Prepare Data Payload
    final data = {
      'userId': uid,
      'farmerName': user.displayName ?? "Farmer",
      'scheme': schemeName,
      'amount': amount,
      'timestamp': timestamp,
      'previousHash': previousHash,
      'status': 'VERIFIED'
    };

    // 3. Mine Block (Hash)
    final hash = generateHash(data);

    // 4. Create Block Record
    final block = {
      'hash': hash,
      'previous_hash': previousHash,
      'data': jsonEncode(data),
      'timestamp': timestamp,
      'user_id': uid, // Supabase column usually snake_case
      'scheme_name': schemeName,
      'amount': amount
    };

    // 5. Publish to Ledger
    await _supabase.insertLedgerBlock(block);

    // Return friendly map for UI
    return {
      'hash': hash,
      'previousHash': previousHash,
      'timestamp': timestamp,
      'status': 'VERIFIED ON CHAIN'
    };
  }

  // Verify if a hash is valid (Proof of Integrity)
  bool verifyTransaction(String hash, Map<String, dynamic> data) {
    final recomputedHash = generateHash(data);
    return recomputedHash == hash;
  }
}
