import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  // Loaded from .env for security
  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  late GenerativeModel _model;

  GeminiService() {
    _model = GenerativeModel(
      // Strictly using the 2.5 Flash Lite version as requested
      model: 'gemini-2.5-flash-lite', 
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        maxOutputTokens: 1024,
        temperature: 0.7,
      ),
    );
  }

  Future<String> getAdvice(String query, {Map<String, dynamic>? contextData}) async {
    try {
      final chat = _model.startChat(history: [
        Content.text(
            '''You are BeejX, an advanced AI agricultural expert assistant for Indian farmers. 
            Your goal is to provide accurate, helpful, and localized farming advice.
            
            Traits:
            - Polite, professional, and empathetic.
            - Focus on sustainable and modern Indian farming practices.
            - Use simple English or the user's language (if detected).
            - Keep answers concise and actionable (bullet points preferred).
            - Avoid disclaimers unless absolutely necessary (safety).
            
            Current Context:
            ${contextData != null ? _formatContext(contextData) : "No location/soil data available."}
            '''
        ),
        Content.model([TextPart("Namaste! I am ready to help. How is your crop described in the context?")]),
      ]);

      // FORCE CONTEXT INJECTION: Staple context to the user query
      String finalQuery = query;
      if (contextData != null) {
        finalQuery += "\n\n[System Context for this Query (Prioritize this data): ${_formatContext(contextData)}]";
      }

      final content = Content.text(finalQuery);
      final response = await chat.sendMessage(content);

      if (response.text != null) {
        return response.text!;
      } else {
        return "I couldn't generate a response. Please try asking again.";
      }
    } catch (e) {
      return "Error connecting to AI Brain: $e";
    }
  }

  String _formatContext(Map<String, dynamic> data) {
    // Helper to make context readable for the LLM
    final buffer = StringBuffer();
    if (data.containsKey('soil')) buffer.writeln("Soil Data: ${data['soil']}");
    if (data.containsKey('location')) buffer.writeln("Location: ${data['location']}");
    if (data.containsKey('weather')) buffer.writeln("Weather: ${data['weather']}");
    return buffer.toString();
  }
}
