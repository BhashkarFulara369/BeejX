import 'package:http/http.dart' as http;

class ChatService {
  final String apiUrl = "https://beejx-backend-default.hf.space/chat"; // Secure Endpoint

  Future<String> sendMessage(String message) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {'query': message},
      );

      if (response.statusCode == 200) {
        return response.body.split(':')[1].replaceAll(RegExp(r'[}"\\]'), '').trim();
      } else {
        return "Server error: ${response.statusCode}";
      }
    } catch (e) {
      return "Failed: $e";
    }
  }
}
