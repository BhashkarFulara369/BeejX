import 'package:flutter_test/flutter_test.dart';
import 'package:beejx/models/sensor_data.dart';
import 'package:beejx/models/expense_record.dart';

void main() {
  group('SensorData Model', () {
    test('Should parse Firebase structure correctly', () {
      final raw = {
        'hydro': {'temp': 25.5, 'humidity': 60, 'pH': 6.5},
        'led': {'state': 0}, // ON
        'second': {'state': 1} // OFF
      };
      
      final data = SensorData.fromMap(raw);
      
      expect(data.temperature, 25.5);
      expect(data.humidity, 60.0); // int -> double conversion
      expect(data.ph, 6.5);
      expect(data.isMainPumpOn, true); // 0 = ON
      expect(data.isAuxLightOn, false); // 1 = OFF
    });

    test('Should handle missing/null data safely', () {
      final raw = <String, dynamic>{}; // Empty
      final data = SensorData.fromMap(raw);
      
      expect(data.temperature, 0.0);
      expect(data.isMainPumpOn, false); // Default 1 (OFF) -> false
    });
  });

  group('ExpenseRecord Model', () {
    test('Should parse clean JSON String', () {
      final jsonStr = '{"itemName": "Seeds", "amount": 500, "date": "2024-01-01", "category": "Seeds"}';
      final record = ExpenseRecord.fromRawString(jsonStr);
      
      expect(record?.itemName, "Seeds");
      expect(record?.amount, 500.0);
    });

    test('Should strip Markdown code blocks', () {
      final mdJson = '```json\n{"itemName": "Tool", "amount": 100}\n```';
      final record = ExpenseRecord.fromRawString(mdJson);
      
      expect(record?.itemName, "Tool");
      expect(record?.amount, 100.0);
    });
  });
}
