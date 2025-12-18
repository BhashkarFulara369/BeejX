import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class WeatherService {
  Future<Map<String, dynamic>> getWeather(double lat, double lon) async {
    try {
      // Use configured endpoint (http://192.../api/v1/weather)
      final response = await http.get(
        Uri.parse('${ApiConstants.weatherEndpoint}?lat=$lat&lon=$lon'),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load weather');
      }
    } catch (e) {
      // Return fallback data if API fails
      return {
        "temp": 28,
        "condition": "Sunny (Offline)",
        "humidity": 65,
        "wind": 12,
        "location": "Uttarakhand"
      };
    }
  }
}
