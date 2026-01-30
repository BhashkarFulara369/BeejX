import 'dart:convert';

class ExpenseRecord {
  final String itemName;
  final double amount;
  final String date;
  final String category;

  ExpenseRecord({
    required this.itemName,
    required this.amount,
    required this.date,
    required this.category,
  });

  // Factory to parse Gemini JSON output
  factory ExpenseRecord.fromJson(Map<String, dynamic> json) {
    return ExpenseRecord(
      itemName: json['itemName']?.toString() ?? 'Unknown Item',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: json['date']?.toString() ?? DateTime.now().toIso8601String().split('T')[0],
      category: json['category']?.toString() ?? 'Other',
    );
  }

  // To Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'itemName': itemName,
      'amount': amount,
      'date': date,
      'category': category,
    };
  }

  // Helper to parse from raw string (handling potential markdown wrapping)
  static ExpenseRecord? fromRawString(String raw) {
    try {
      String clean = raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> map = jsonDecode(clean);
      return ExpenseRecord.fromJson(map);
    } catch (e) {
      print("Error parsing Expense JSON: $e");
      return null;
    }
  }
  
  @override
  String toString() {
    return "Item: $itemName\nAmount: ₹$amount\nDate: $date\nCategory: $category";
  }
}
