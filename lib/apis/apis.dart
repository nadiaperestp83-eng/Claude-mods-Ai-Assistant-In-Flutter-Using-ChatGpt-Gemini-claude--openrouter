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

  // ── GEMINI ──────────────────────────────────────
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
      if (data['candidates'] == null) return 'Erro Gemini: ${res.body}';
      return data['candidates'][0]['content']['parts'][0]['text'];
    } catch (e) {
      log('getAnswerGeminiE: $e');
      return 'Erro Gemini: $e';
    }
  }

  // ── GROQ LLAMA (código) ──────────────────────────
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

  // ── GROQ MIXTRAL (textos longos) ─────────────────
  static Future<String> getAnswerMixtral(String question) async {
    try {
      final res = await post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $groqKey',
        },
        body: jsonEncode({
          'model': 'mixtral-8x7b-32768',
          'max_tokens': 2000,
          'messages': [
            {'role': 'user', 'content': question},
          ],
        }),
      );
      final data = jsonDecode(res.body);
      return data['choices'][0]['message']['content'];
    } catch (e) {
      log('getAnswerMixtralE: $e');
      return 'Erro Mixtral: $e';
    }
  }

  // ── GROQ GEMMA (perguntas rápidas) ───────────────
  static Future<String> getAnswerGemma(String question) async {
    try {
      final res = await post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $groqKey',
        },
        body: jsonEncode({
          'model': 'gemma2-9b-it',
          'max_tokens': 2000,
          'messages': [
            {'role': 'user', 'content': question},
          ],
        }),
      );
      final data = jsonDecode(res.body);
      return data['choices'][0]['message']['content'];
    } catch (e) {
      log('getAnswerGemmaE: $e');
      return 'Erro Gemma: $e';
    }
  }

  // ── ROTEADOR ─────────────────────────────────────
  static Future<AIResponse> getAnswer(String question) async {
    try {
      final q = question.toLowerCase();
      final prompt = 'Responda sempre em português brasileiro. $question';

      // Código → Llama (Groq)
      if (q.contains('código') || q.contains('code') ||
          q.contains('dart') || q.contains('python') ||
          q.contains('flutter') || q.contains('função') ||
          q.contains('erro') || q.contains('bug')) {
        return AIResponse(text: await getAnswerGroq(prompt), provider: 'Llama');
      }

      // Textos longos → Mixtral (Groq)
      if (q.contains('explica') || q.contains('redija') ||
          q.contains('resumo') || q.contains('analise') ||
          q.contains('escreva') || q.contains('texto') ||
          q.length > 300) {
        return AIResponse(text: await getAnswerMixtral(prompt), provider: 'Mixtral');
      }

      // Gemini → perguntas gerais (se falhar cai no Gemma)
      final geminiRes = await getAnswerGemini(prompt);
      if (geminiRes.startsWith('Erro')) {
        return AIResponse(text: await getAnswerGemma(prompt), provider: 'Gemma');
      }
      return AIResponse(text: geminiRes, provider: 'Gemini');

    } catch (e) {
      return AIResponse(text: 'Erro geral: $e', provider: 'Erro');
    }
  }

  // ── IMAGENS ──────────────────────────────────────
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

  // ── TRADUÇÃO ─────────────────────────────────────
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
