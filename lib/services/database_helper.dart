import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'beejx_offline.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Table for Chat Sessions
    await db.execute('''
      CREATE TABLE chats(
        id TEXT PRIMARY KEY,
        title TEXT,
        created_at INTEGER,
        last_updated INTEGER,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // Table for Messages
    await db.execute('''
      CREATE TABLE messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chat_id TEXT,
        role TEXT,
        text TEXT,
        timestamp INTEGER,
        FOREIGN KEY(chat_id) REFERENCES chats(id) ON DELETE CASCADE
      )
    ''');
  }

  // --- Chat Operations ---

  Future<void> createChat(String chatId, String title) async {
    final db = await database;
    await db.insert(
      'chats',
      {
        'id': chatId,
        'title': title,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
        'is_synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getChats() async {
    final db = await database;
    return await db.query('chats', orderBy: 'last_updated DESC');
  }
  
  // Sync Methods
  Future<List<Map<String, dynamic>>> getUnsyncedChats() async {
    final db = await database;
    return await db.query('chats', where: 'is_synced = 0');
  }

  Future<void> markChatAsSynced(String chatId) async {
    final db = await database;
    await db.update(
      'chats',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [chatId],
    );
  }

  Future<void> deleteChat(String chatId) async {
    final db = await database;
    await db.delete('chats', where: 'id = ?', whereArgs: [chatId]);
    await db.delete('messages', where: 'chat_id = ?', whereArgs: [chatId]);
  }

  // --- Message Operations ---

  Future<void> addMessage(String chatId, String role, String text) async {
    final db = await database;
    
    // Ensure chat exists (update timestamp if it does)
    final chatExists = await db.query('chats', where: 'id = ?', whereArgs: [chatId]);
    if (chatExists.isEmpty) {
      await createChat(chatId, text.length > 30 ? "${text.substring(0, 30)}..." : text);
    } else {
      await db.update(
        'chats',
        {
          'last_updated': DateTime.now().millisecondsSinceEpoch,
          'is_synced': 0 // Mark as dirty/unsynced on new message
        },
        where: 'id = ?',
        whereArgs: [chatId],
      );
    }

    await db.insert(
      'messages',
      {
        'chat_id': chatId,
        'role': role,
        'text': text,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    final db = await database;
    return await db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'timestamp ASC',
    );
  }
}
