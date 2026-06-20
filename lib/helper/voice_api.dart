import 'dart:developer';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class VoiceApi {
  // Troque pela URL real do seu Space (formato: https://SEU-USUARIO-NOME-DO-SPACE.hf.space)
  static const String _baseUrl = 'https://laylaprs-voz-razo-api.hf.space';

  // Se você criar a Secret API_SECRET no Space, coloque a mesma senha aqui.
  // Deixe vazio ('') se o Space não tiver nenhuma senha configurada.
  static const String _apiSecret = '';

  /// Busca o áudio .wav da voz Razo para o texto informado.
  /// Retorna os bytes do áudio, ou null se falhar.
  static Future<Uint8List?> synthesize(String text) async {
    if (text.trim().isEmpty) return null;

    try {
      final headers = <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
      };
      if (_apiSecret.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_apiSecret';
      }

      final res = await http
          .post(
            Uri.parse('$_baseUrl/tts'),
            headers: headers,
            body: '{"text": ${_jsonEscape(text)}}',
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        return res.bodyBytes;
      } else {
        log('VoiceApi: status ${res.statusCode} - ${res.body}');
        return null;
      }
    } catch (e) {
      log('VoiceApiE: $e');
      return null;
    }
  }

  static String _jsonEscape(String text) {
    final escaped = text
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');
    return '"$escaped"';
  }
}
