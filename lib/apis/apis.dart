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

  // ── CLAUDE (API DIRETA DA ANTHROPIC) ──────────────
  static Future<AIResponse> getAnswerClaudeDirect(String question) async {
    if (claudeKey.isEmpty) {
      return AIResponse(text: '❌ Claude direto: chave não configurada.', provider: 'Erro');
    }
    try {
      final res = await post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': claudeKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-sonnet-4-6',
          'max_tokens': 2000,
          'messages': [
            {'role': 'user', 'content': question},
          ],
          // Permite que o Claude busque na web quando achar necessário.
          // Ele decide sozinho; não busca em toda pergunta. max_uses
          // limita o número de buscas numa única resposta.
          'tools': [
            {
              'type': 'web_search_20250305',
              'name': 'web_search',
              'max_uses': 3,
            }
          ],
        }),
      );
      if (res.statusCode != 200) {
        final errorBody = utf8.decode(res.bodyBytes);
        return AIResponse(
          text: '❌ Claude direto (status ${res.statusCode}): $errorBody',
          provider: 'Erro',
        );
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      // Com web_search, o content pode ter múltiplos blocos (texto + uso de
      // ferramenta). Pegamos o último bloco de texto, que é a resposta final.
      final contentBlocks = data['content'] as List? ?? [];
      final textBlocks = contentBlocks.where((b) => b['type'] == 'text').toList();
      final content = textBlocks.isNotEmpty ? (textBlocks.last['text'] ?? '') : '';
      if (content.isEmpty) {
        return AIResponse(text: '❌ Claude direto: resposta vazia.', provider: 'Erro');
      }
      return AIResponse(text: content, provider: 'Claude');
    } catch (e) {
      return AIResponse(text: '❌ Claude direto: exceção - $e', provider: 'Erro');
    }
  }

  // ── CLAUDE com fallback (direto -> OpenRouter) ────
  static Future<AIResponse> getAnswerClaude(String question) async {
    final direct = await getAnswerClaudeDirect(question);
    if (direct.provider != 'Erro') return direct;
    return getAnswerOpenRouter(question, 'anthropic/claude-sonnet-4-6');
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
                {'text': question}
              ]
            }
          ],
          // Permite que o Gemini busque no Google quando achar necessário
          // (ex: data atual, notícias, fatos que mudam com o tempo).
          // Ele decide sozinho quando usar; não busca em toda pergunta.
          'tools': [
            {'google_search': {}}
          ],
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

  // ── ROTEADOR PRINCIPAL: 2 GRUPOS COM FALLBACK ────
  // Grupo 1 (simples/dia a dia): Gemini -> fallback Groq
  // Grupo 2 (complexo/textos/código): Cerebras -> Groq -> Claude (direto+OpenRouter)
  static Future<AIResponse> getAnswer(String question) async {
    final keyCheck = _checkKeys();
    if (keyCheck.isNotEmpty) {
      return AIResponse(text: keyCheck, provider: 'Configuração');
    }

    final q = question.toLowerCase();

    final isComplex = q.contains('código') || q.contains('code') ||
        q.contains('dart') || q.contains('python') ||
        q.contains('flutter') || q.contains('função') ||
        q.contains('erro') || q.contains('bug') ||
        q.contains('explica') || q.contains('redija') ||
        q.contains('resumo') || q.contains('analise') ||
        q.contains('escreva') || q.contains('texto') ||
        q.length > 300;

    List<Map<String, dynamic>> attempts;

    if (isComplex) {
      // GRUPO 2: complexo
      attempts = [
        {'fn': () => getAnswerCerebras(question, 'llama-4-scout-17b-16e-instruct'), 'name': 'Cerebras'},
        {'fn': () => getAnswerGroq(question, 'groq/compound'), 'name': 'Groq'},
        {'fn': () => getAnswerClaude(question), 'name': 'Claude'},
        {'fn': () => getAnswerGemini(question), 'name': 'Gemini'},
      ];
    } else {
      // GRUPO 1: simples/dia a dia
      attempts = [
        {'fn': () => getAnswerGemini(question), 'name': 'Gemini'},
        {'fn': () => getAnswerGroq(question, 'groq/compound'), 'name': 'Groq'},
        {'fn': () => getAnswerCerebras(question, 'llama-4-scout-17b-16e-instruct'), 'name': 'Cerebras'},
        {'fn': () => getAnswerClaude(question), 'name': 'Claude'},
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
