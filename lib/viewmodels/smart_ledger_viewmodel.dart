import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_record.dart';

class SmartLedgerViewModel extends ChangeNotifier {
  // --- Infrastructure ---
  late final GenerativeModel _model;
  final ImagePicker _picker = ImagePicker();
  
  // Security: Loaded from .env
  static String get _geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  // --- State ---
  bool _isScanning = false;
  File? _scannedImage;
  String? _analysisError;
  ExpenseRecord? _extractedExpense; // Type-safe record

  // --- Getters ---
  bool get isScanning => _isScanning;
  File? get scannedImage => _scannedImage;
  String? get analysisError => _analysisError;
  ExpenseRecord? get extractedExpense => _extractedExpense;
  String? get formattedExpenseString => _extractedExpense?.toString();

  SmartLedgerViewModel() {
    _initGemini();
  }

  void _initGemini() {
    // Initialize Gemini 1.5 Pro (Vision)
    _model = GenerativeModel(
      model: 'gemini-1.5-pro', 
      apiKey: _geminiApiKey, 
    );
  }

  // --- Actions ---

  /// 1. Pick Image and Trigger Analysis
  Future<void> scanBill() async {
    try {
      _setScanning(true);
      _analysisError = null;

      final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      
      if (photo == null) {
        _setScanning(false);
        return;
      }

      _scannedImage = File(photo.path);
      notifyListeners();

      // Go to Gemini
      await _analyzeImageWithGemini(_scannedImage!);

    } catch (e) {
      _analysisError = "Scan failed: $e";
      _setScanning(false);
    }
  }

  /// 2. Analyze with Gemini
  Future<void> _analyzeImageWithGemini(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      
      // Strict JSON prompt
      final prompt = TextPart("Analyze this image of a farm receipt/bill. Extract data into a JSON structure with keys: 'itemName' (string), 'amount' (number), 'date' (string YYYY-MM-DD), 'category' (string: 'Seeds', 'Fertilizer', 'Tools', 'Labor', 'Other'). If date is missing use today. If unclear, amount 0.");
      
      final imagePart = DataPart('image/jpeg', imageBytes);
      
      final response = await _model.generateContent([
         Content.multi([prompt, imagePart])
      ]);

      if (response.text != null) {
        // Parse via Model
        final record = ExpenseRecord.fromRawString(response.text!);
        if (record != null) {
          _extractedExpense = record;
        } else {
          _analysisError = "Could not parse bill details.";
        }
      } else {
        _analysisError = "AI returned empty response.";
      }

    } catch (e) {
      _analysisError = "Gemini Error: $e";
    } finally {
      _setScanning(false);
    }
  }

  /// 3. Confirm and Save (Placeholder for Firestore)
  Future<void> saveExpense() async {
    if (_extractedExpense == null) return;
    
    // Convert Model -> Map
    final data = _extractedExpense!.toMap();

    // Here lies the Firestore/Supabase logic
    // await FirebaseFirestore.instance.collection('expenses').add(data);
    print("Saving to DB: $data");
    
    // Clear state after save
    clearState();
  }
  
  void clearState() {
    _scannedImage = null;
    _extractedExpense = null;
    _analysisError = null;
    notifyListeners();
  }

  void _setScanning(bool value) {
    _isScanning = value;
    notifyListeners();
  }
}
