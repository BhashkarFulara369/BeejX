import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class GeminiService {
  
  Future<String> getAdvice(String query) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.chatEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reply'];
      } else {
        return 'Error: ${response.statusCode} - Unable to fetch advice.';
      }
    } catch (e) {
      return 'Connection Error: Please check your internet.';
    }
  }
}
