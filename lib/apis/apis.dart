// lib/helper/apis.dart
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
  static const String systemPrompt = '''
Você é um especialista em Flutter/Dart. Suas respostas são práticas, completas e prontas para copiar e colar. Priorize simplicidade e dependências mínimas.

## Padrões de Código
- Use null-safety e Dart 3.
- Gerenciamento de estado: prefira `setState` para UIs simples, ou `ValueNotifier` para múltiplas telas. Não introduza Riverpod/Bloc a menos que solicitado explicitamente.
- Estrutura: comece com `lib/main.dart`. Depois divida em `models/`, `screens/`, `widgets/` conforme necessário.
- Forneça blocos **completos** (imports, `main()`, árvore de widgets, lógica). Use `//` para comentários breves.
''';

  // ── VERIFICAÇÃO DE CHAVES ──────────────────────────
  static String _checkKeys() {
    List<String> missing = [];
    if (apiKey.isEmpty) missing.add('Gemini (apiKey)');
    if (openrouterKey.isEmpty) missing.add('OpenRouter (openrouterKey)');
    if (groqKey.isEmpty) missing.add('Groq (groqKey)');
    if (cerebrasKey.isEmpty) missing.add('Cerebras (cerebrasKey)');
    if (cloudflareKey.isEmpty) missing.add('Cloudflare (cloudflareKey)');
    if (missing.isEmpty) return '';
    return '⚠️ Chaves não configuradas: ${missing.join(', ')}.\nConfigure em lib/helper/global.dart.';
  }

  // ── OPENROUTER ───────────────────────────────────
  static Future<AIResponse> getAnswerOpenRouter(String question, String model) async {
    if (openrouterKey.isEmpty) {
      return AIResponse(text: '❌ OpenRouter: chave não configurada.', provider: 'Erro');
    }
    try {
      final res = await post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $openrouterKey',
          'HTTP-Referer': 'https://github.com/nadiaperesoficial-hash',
        },
        body: jsonEncode({
          'model': model,
          'max_tokens': 2000,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': question},
          ],
        }),
      );
      if (res.statusCode != 200) {
        final errorBody = utf8.decode(res.bodyBytes);
        return AIResponse(
          text: '❌ OpenRouter (status ${res.statusCode}): $errorBody',
          provider: 'Erro',
        );
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final content = data['choices']?[0]?['message']?['content'] ?? '';
      if (content.isEmpty) {
        return AIResponse(text: '❌ OpenRouter: resposta vazia.', provider: 'Erro');
      }
      return AIResponse(text: content, provider: 'OpenRouter');
    } catch (e) {
      return AIResponse(text: '❌ OpenRouter: exceção - $e', provider: 'Erro');
    }
  }

  // ── GEMINI (auth key via header x-goog-api-key) ──
  static Future<AIResponse> getAnswerGemini(String question) async {
    if (apiKey.isEmpty) {
      return AIResponse(text: '❌ Gemini: chave não configurada.', provider: 'Erro');
    }
    try {
      final res = await post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'x-goog-api-key': apiKey,
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': '$systemPrompt\n\nPergunta: $question'}
              ]
            }
          ]
        }),
      );
      if (res.statusCode != 200) {
        final errorBody = utf8.decode(res.bodyBytes);
        return AIResponse(
          text: '❌ Gemini (status ${res.statusCode}): $errorBody',
          provider: 'Erro',
        );
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final content = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
      if (content.isEmpty) {
        return AIResponse(text: '❌ Gemini: resposta vazia.', provider: 'Erro');
      }
      return AIResponse(text: content, provider: 'Gemini');
    } catch (e) {
      return AIResponse(text: '❌ Gemini: exceção - $e', provider: 'Erro');
    }
  }

  // ── GROQ ─────────────────────────────────────────
  static Future<AIResponse> getAnswerGroq(String question, String model) async {
    if (groqKey.isEmpty) {
      return AIResponse(text: '❌ Groq: chave não configurada.', provider: 'Erro');
    }
    try {
      final res = await post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $groqKey',
        },
        body: jsonEncode({
          'model': model,
          'max_tokens': 2000,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': question},
          ],
        }),
      );
      if (res.statusCode != 200) {
        final errorBody = utf8.decode(res.bodyBytes);
        return AIResponse(
          text: '❌ Groq (status ${res.statusCode}): $errorBody',
          provider: 'Erro',
        );
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final content = data['choices']?[0]?['message']?['content'] ?? '';
      if (content.isEmpty) {
        return AIResponse(text: '❌ Groq: resposta vazia.', provider: 'Erro');
      }
      return AIResponse(text: content, provider: 'Groq');
    } catch (e) {
      return AIResponse(text: '❌ Groq: exceção - $e', provider: 'Erro');
    }
  }

  // ── CEREBRAS ─────────────────────────────────────
  static Future<AIResponse> getAnswerCerebras(String question, String model) async {
    if (cerebrasKey.isEmpty) {
      return AIResponse(text: '❌ Cerebras: chave não configurada.', provider: 'Erro');
    }
    try {
      final res = await post(
        Uri.parse('https://api.cerebras.ai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $cerebrasKey',
        },
        body: jsonEncode({
          'model': model,
          'max_tokens': 2000,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': question},
          ],
        }),
      );
      if (res.statusCode != 200) {
        final errorBody = utf8.decode(res.bodyBytes);
        return AIResponse(
          text: '❌ Cerebras (status ${res.statusCode}): $errorBody',
          provider: 'Erro',
        );
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final content = data['choices']?[0]?['message']?['content'] ?? '';
      if (content.isEmpty) {
        return AIResponse(text: '❌ Cerebras: resposta vazia.', provider: 'Erro');
      }
      return AIResponse(text: content, provider: 'Cerebras');
    } catch (e) {
      return AIResponse(text: '❌ Cerebras: exceção - $e', provider: 'Erro');
    }
  }

  // ── PROVEDORES DE ATALHO ──────────────────────────
  static Future<AIResponse> getAnswerClaude(String question) =>
      getAnswerOpenRouter(question, 'anthropic/claude-sonnet-4-5');
  static Future<AIResponse> getAnswerDeepSeek(String question) =>
      getAnswerOpenRouter(question, 'deepseek/deepseek-chat');
  static Future<AIResponse> getAnswerChatGptOpenRouter(String question) =>
      getAnswerOpenRouter(question, 'openai/gpt-4o-mini');

  // ── IMAGEM ────────────────────────────────────────
  static Future<String> generateImage(String prompt) async {
    if (cloudflareKey.isEmpty) {
      return '❌ Cloudflare: chave não configurada.';
    }
    const String accountId = '344ae813a0f97087c8b9d03eeb5dbfb5';
    try {
      final res = await post(
        Uri.parse(
            'https://api.cloudflare.com/client/v4/accounts/$accountId/ai/run/@cf/black-forest-labs/flux-1-schnell'),
        headers: {
          'Authorization': 'Bearer $cloudflareKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'prompt': prompt}),
      );
      if (res.statusCode != 200) {
        final errorBody = utf8.decode(res.bodyBytes);
        return '❌ Cloudflare (status ${res.statusCode}): $errorBody';
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return data['result']?['image'] ?? '❌ Cloudflare: imagem não gerada.';
    } catch (e) {
      return '❌ Cloudflare: exceção - $e';
    }
  }

  // ── ROTEADOR PRINCIPAL (COM RELATÓRIO DE ERROS) ──
  static Future<AIResponse> getAnswer(String question) async {
    final keyCheck = _checkKeys();
    if (keyCheck.isNotEmpty) {
      return AIResponse(text: keyCheck, provider: 'Configuração');
    }

    final q = question.toLowerCase();
    final prompt = 'Responda sempre em português brasileiro. $question';

    List<Map<String, dynamic>> attempts = [];
    if (q.contains('código') || q.contains('code') ||
        q.contains('dart') || q.contains('python') ||
        q.contains('flutter') || q.contains('função') ||
        q.contains('erro') || q.contains('bug')) {
      attempts = [
        {'fn': () => getAnswerCerebras(prompt, 'llama-4-scout-17b-16e-instruct'), 'name': 'Cerebras'},
        {'fn': () => getAnswerDeepSeek(prompt), 'name': 'DeepSeek'},
        {'fn': () => getAnswerGroq(prompt, 'llama-3.3-70b-versatile'), 'name': 'Groq-Llama'},
        {'fn': () => getAnswerOpenRouter(prompt, 'meta-llama/llama-3.3-70b-instruct:free'), 'name': 'Llama-Free'},
        {'fn': () => getAnswerGemini(prompt), 'name': 'Gemini'},
      ];
    } else if (q.contains('explica') || q.contains('redija') ||
        q.contains('resumo') || q.contains('analise') ||
        q.contains('escreva') || q.contains('texto') ||
        q.length > 300) {
      attempts = [
        {'fn': () => getAnswerGemini(prompt), 'name': 'Gemini'},
        {'fn': () => getAnswerClaude(prompt), 'name': 'Claude'},
        {'fn': () => getAnswerGroq(prompt, 'mixtral-8x7b-32768'), 'name': 'Mixtral'},
        {'fn': () => getAnswerOpenRouter(prompt, 'google/gemma-3-27b-it:free'), 'name': 'Gemma'},
      ];
    } else {
      attempts = [
        {'fn': () => getAnswerClaude(prompt), 'name': 'Claude'},
        {'fn': () => getAnswerChatGptOpenRouter(prompt), 'name': 'ChatGPT'},
        {'fn': () => getAnswerGemini(prompt), 'name': 'Gemini'},
        {'fn': () => getAnswerGroq(prompt, 'gemma2-9b-it'), 'name': 'Gemma-Groq'},
      ];
    }

    List<String> errors = [];
    for (int i = 0; i < attempts.length; i++) {
      try {
        final result = await (attempts[i]['fn'] as Future<AIResponse> Function())();
        if (result.provider != 'Erro') {
          return result;
        } else {
          errors.add('${attempts[i]['name']}: ${result.text}');
        }
      } catch (e) {
        errors.add('${attempts[i]['name']}: Exceção - $e');
      }
    }

    final errorReport = errors.join('\n\n');
    return AIResponse(
      text: '❌ Todas as tentativas falharam.\n\n$errorReport',
      provider: 'Erro',
    );
  }

  // ── LEXICA (imagens) ───────────────────────────────
  static Future<List<String>> searchAiImages(String prompt) async {
    try {
      final res =
          await get(Uri.parse('https://lexica.art/api/v1/search?q=$prompt'));
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data['images'] == null) return [];
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
