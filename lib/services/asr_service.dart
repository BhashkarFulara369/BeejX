import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class ASRService {
  final Dio dio = Dio();
  final String asrApi = "https://dhruva-api.bhashini.gov.in/asr/api/v1/recognise";
  final String userID = "<your-user-id>";
  final String token = "<your-bearer-token>";
  final String serviceId = "ai4bharat/conformer-hi-gpu--t4"; // or use Telugu/Marathi

  Future<String?> sendAudio(File audioFile) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(audioFile.path, filename: 'input.wav'),
      'language': 'hi', // or 'mr', 'te'
      'serviceId': serviceId,
    });

    try {
      final response = await dio.post(
        asrApi,
        data: formData,
        options: Options(
          headers: {
            "Authorization": "Bearer $token",
            "userID": userID,
          },
        ),
      );
      return response.data["output"]["source"];
    } catch (e) {
      print("ASR error: $e");
      return null;
    }
  }
}
