import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart';
import 'package:translator_plus/translator_plus.dart';

import '../helper/global.dart';

class AIResponse {
  final String text;
  final String provider;
  AIResponse({required this.text, required this.provider});
}

class APIs {

  static Future<String> getAnswerGemini(String question) async {
    try {
      final res = await post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': question}
              ]
            }
          ]
        }),
      );
      final data = jsonDecode(res.body);
      log('Gemini response: ${res.body}');
      if (data['candidates'] == null) return 'Erro Gemini: ${res.body}';
      return data['candidates'][0]['content']['parts'][0]['text'];
    } catch (e) {
      log('getAnswerGeminiE: $e');
      return 'Erro Gemini: $e';
    }
  }

  static Future<String> getAnswerClaude(String question) async {
    try {
      final res = await post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': claudeKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-sonnet-4-5',
          'max_tokens': 2000,
          'messages': [
            {'role': 'user', 'content': question},
          ],
        }),
      );
      final data = jsonDecode(res.body);
      log('Claude response: ${res.body}');
      if (data['content'] == null) return 'Erro Claude: ${res.body}';
      return data['content'][0]['text'];
    } catch (e) {
      log('getAnswerClaudeE: $e');
      return 'Erro Claude: $e';
    }
  }

  static Future<String> getAnswerGroq(String question) async {
    try {
      final res = await post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $groqKey',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'max_tokens': 2000,
          'messages': [
            {'role': 'user', 'content': question},
          ],
        }),
      );
      final data = jsonDecode(res.body);
      return data['choices'][0]['message']['content'];
    } catch (e) {
      log('getAnswerGroqE: $e');
      return 'Erro Groq: $e';
    }
  }

  static Future<AIResponse> getAnswer(String question) async {
    try {
      final q = question.toLowerCase();
      final prompt = 'Responda sempre em português brasileiro. $question';

      if (q.contains('código') || q.contains('code') ||
          q.contains('dart') || q.contains('python') ||
          q.contains('flutter') || q.contains('função') ||
          q.contains('erro') || q.contains('bug')) {
        return AIResponse(text: await getAnswerGroq(prompt), provider: 'Groq');
      }

      if (q.contains('explica') || q.contains('redija') ||
          q.contains('resumo') || q.contains('analise') ||
          q.contains('escreva') || q.contains('texto') ||
          q.length > 300) {
        return AIResponse(text: await getAnswerClaude(prompt), provider: 'Claude');
      }

      return AIResponse(text: await getAnswerGemini(prompt), provider: 'Gemini');
    } catch (e) {
      return AIResponse(text: 'Erro geral: $e', provider: 'Erro');
    }
  }

  static Future<List<String>> searchAiImages(String prompt) async {
    try {
      final res =
          await get(Uri.parse('https://lexica.art/api/v1/search?q=$prompt'));
      final data = jsonDecode(res.body);
      return List.from(data['images']).map((e) => e['src'].toString()).toList();
    } catch (e) {
      log('searchAiImagesE: $e');
      return [];
    }
  }

  static Future<String> googleTranslate({
    required String from,
    required String to,
    required String text,
  }) async {
    try {
      final res = await GoogleTranslator().translate(text, from: from, to: to);
      return res.text;
    } catch (e) {
      log('googleTranslateE: $e');
      return 'Algo deu errado!';
    }
  }
}
