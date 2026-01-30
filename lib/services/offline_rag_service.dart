
// Import onnxruntime and sqflite (implicit in imports)
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data'; 
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'model_manager.dart';

class WordPieceTokenizer {
  Map<String, int> vocab = {};
  
  // 1. Load Vocab on Init
  Future<void> loadVocab(String vocabPath) async {
    final file = File(vocabPath);
    if (await file.exists()) {
      final lines = await file.readAsLines();
      for (int i = 0; i < lines.length; i++) {
        vocab[lines[i]] = i;
      }
      print(" Loaded ${vocab.length} tokens.");
    } else {
      print(" Vocab file not found at $vocabPath");
    }
  }

  // 2. Tokenize Text
  List<int> tokenize(String text) {
    if (vocab.isEmpty) return List.filled(128, 0);

    List<int> tokens = [];
    
    // Add [CLS] token (usually 101 for BERT/MiniLM)
    tokens.add(vocab['[CLS]'] ?? 101);

    // Normalize: lowercase
    final normalized = text.toLowerCase();
    
    // Simple split by whitespace
    final words = normalized.split(RegExp(r'\s+'));

    for (var word in words) {
      if (word.isEmpty) continue;
      
      // Greedy Longest-Match Strategy
      // We limit to 128 total tokens max early to save partial processing
      if (tokens.length >= 127) break; 

      int start = 0;
      while (start < word.length) {
        int end = word.length;
        String curSubstr = "";
        bool found = false;

        while (start < end) {
          String sub = word.substring(start, end);
          if (start > 0) sub = "##$sub"; // WordPiece suffix marker

          if (vocab.containsKey(sub)) {
            tokens.add(vocab[sub]!);
            start = end;
            found = true;
            break;
          }
          end--;
        }
        if (!found) {
          // If unknown char, use [UNK] (usually 100)
          tokens.add(vocab['[UNK]'] ?? 100); 
          start++; 
        }
        if (tokens.length >= 127) break;
      }
    }

    // Add [SEP] token (usually 102)
    tokens.add(vocab['[SEP]'] ?? 102);
    
    // Pad to 128
    while (tokens.length < 128) {
      tokens.add(0); // [PAD]
    }
    
    return tokens.sublist(0, 128);
  }
}

class OfflineRAGService {
  OrtSession? _session;
  Database? _db;
  bool _isReady = false;
  
  final ModelManager _modelManager = ModelManager();
  final WordPieceTokenizer _tokenizer = WordPieceTokenizer();

  // Initialize: Load ONNX, Vocab & DB
  Future<void> initialize() async {
    try {
      if (!(await _modelManager.isModelDownloaded())) {
        print("Offline models not found. Please download them.");
        return;
      }
      
      // 1. Init ONNX
      OrtEnv.instance.init();
      final sessionOptions = OrtSessionOptions();
      final embeddingModelPath = await _modelManager.getEmbeddingModelPath();
      
      _session = OrtSession.fromFile(
        File(embeddingModelPath), 
        sessionOptions
      );

      // 2. Load Vocab
      await _loadVocab();

      // 3. Init SQLite
      await _initDatabase();
      
      _isReady = true;
      print("OfflineRAGService: Initialized (ONNX + Tokenizer + SQLite).");

    } catch (e) {
      print("OfflineRAG Init Error: $e");
    }
  }

  Future<void> _loadVocab() async {
     try {
       final vocabPath = await _modelManager.getVocabPath();
       await _tokenizer.loadVocab(vocabPath);
     } catch (e) {
       print("Vocab Load Error: $e");
     }
  }

  Future<void> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'agri_knowledge.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE knowledge (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT,
            embedding TEXT, -- JSON string of List<double>
            metadata TEXT
          )
        ''');
        // On first create, ingest data
        await _ingestData(db);
      },
    );
  }

  Future<void> _ingestData(Database db) async {
    print("OfflineRAG: Ingesting initial data...");
    try {
        final String response = await rootBundle.loadString('assets/crops_data.json');
        final List<dynamic> data = json.decode(response);
        
        for (var item in data) {
           final content = "${item['crop_name']}: ${item['content']}";
           final vector = await _checkEmbedding(content); 
           
           if (vector != null) {
              await db.insert('knowledge', {
                'content': content,
                'embedding': jsonEncode(vector),
                'metadata': jsonEncode(item)
              });
           }
        }
        print("OfflineRAG: Ingested ${data.length} items.");
    } catch (e) {
      print("OfflineRAG Ingest Error: $e");
    }
  }

  // Generate Embedding using ONNX
  // Input: String -> Output: List<double> (384-dim for MiniLM)
  Future<List<double>?> _generateEmbedding(String text) async {
    if (_session == null) return null;

    try {
        final inputIdsList = _tokenizer.tokenize(text);
        final inputShape = [1, 128];
        final inputIds = Int64List.fromList(inputIdsList); 
        
        final inputOrt = OrtValueTensor.createTensorWithDataList(inputIds, inputShape);
        
        // Attention Mask (1 for real tokens, 0 for padding)
        final maskList = Int64List.fromList(inputIdsList.map((id) => id == 0 ? 0 : 1).toList());
        final maskOrt = OrtValueTensor.createTensorWithDataList(maskList, inputShape);
        
        // Token Type IDs (All 0 for single sentence)
        final typeList = Int64List.fromList(List.filled(128, 0));
        final typeOrt = OrtValueTensor.createTensorWithDataList(typeList, inputShape);
        
        final inputs = {
           'input_ids': inputOrt,
           'attention_mask': maskOrt,
           'token_type_ids': typeOrt
        };
        
        // Run Inference
        // OnnxRuntime Dart often needs run(inputs, outputNames)
        // MiniLM usually outputs 'last_hidden_state' or similar. 
        // We can pass empty list if usage implies inferring all outputs, or check plugin docs.
        // Common signature: run(inputs, outputs) or run(inputs). 
        // If error said "2 positional args required", it probably wants run(inputs, outputNames).
        final outputNames = ['last_hidden_state']; // Standard for HF models usually
        // Fix: run(OrtRunOptions options, Map<String, OrtValue> inputs, List<String> outputs)
        final runOptions = OrtRunOptions();
        final outputs = await _session!.run(runOptions, inputs, outputNames);
        runOptions.release(); // Always release C++ resources
        // Output[0] is usually last_hidden_state [1, seq_len, 384].
        
        final outputTensor = outputs[0]?.value as List<List<List<double>>>?; 
        
        if (outputTensor != null && outputTensor.isNotEmpty) {
             final sequence = outputTensor[0]; // [128, 384]
             
             // Mean Pooling
             List<double> pooled = List.filled(384, 0.0);
             int count = 0;
             for (int i=0; i<inputIdsList.length; i++) {
                if (maskList[i] == 1) { // Only attend to real tokens
                   for (int j=0; j<384; j++) {
                      pooled[j] += sequence[i][j];
                   }
                   count++;
                }
             }
             
             if (count > 0) {
                for(int j=0; j<384; j++) pooled[j] /= count;
             }
             
             // Cleanup
             inputOrt.release();
             maskOrt.release();
             typeOrt.release();
             
             return pooled;
        }
        
        // Fallback cleanup
        inputOrt.release();
        maskOrt.release();
        typeOrt.release();
        
        return null;

    } catch (e) {
      print("Embedding Error: $e");
      return null;
    }
  }
  
  // Wrapper 
  Future<List<double>?> _checkEmbedding(String text) async {
      try {
        final vec = await _generateEmbedding(text);
        if (vec != null) return vec;
        return _getDeterministicVector(text); // Fallback only on error/null
      } catch (e) {
        return _getDeterministicVector(text);
      }
  }
  
  List<double> _getDeterministicVector(String text) {
    final rng = Random(text.hashCode);
    return List.generate(384, (i) => rng.nextDouble());
  }

  // SEARCH
  Future<String> search(String query) async {
    if (!_isReady || _db == null) {
      await initialize();
      if (!_isReady) return "Offline Database not ready.";
    }

    final queryVector = await _checkEmbedding(query);
    if (queryVector == null) return "Could not vectorise query.";

    final List<Map<String, dynamic>> rows = await _db!.query('knowledge');
    
    final List<Map<String, dynamic>> results = [];
    
    for (var row in rows) {
       final List<double> vec = (jsonDecode(row['embedding'] as String) as List).cast<double>();
       final score = _cosineSimilarity(queryVector, vec);
       if (score > 0.4) { // Lower threshold slightly
         var res = Map<String, dynamic>.from(row);
         res['score'] = score;
         results.add(res);
       }
    }
    
    results.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    
    // Top 3
    final top = results.take(3);
    if (top.isEmpty) return "No relevant farming info found locally.";
    
    return top.map((e) => e['content']).join("\n---\n");
  }

  double _cosineSimilarity(List<double> vec1, List<double> vec2) {
    double dot = 0.0;
    double mag1 = 0.0;
    double mag2 = 0.0;
    for (int i = 0; i < vec1.length; i++) {
      dot += vec1[i] * vec2[i];
      mag1 += vec1[i] * vec1[i];
      mag2 += vec2[i] * vec2[i];
    }
    return dot / (sqrt(mag1) * sqrt(mag2));
  }
  
  void dispose() {
    _session?.release();
    _db?.close();
  }
}
