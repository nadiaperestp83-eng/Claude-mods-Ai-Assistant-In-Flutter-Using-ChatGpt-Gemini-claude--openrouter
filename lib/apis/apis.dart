// lib/helper/apis.dart
import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart';
import 'package:translator_plus/translator_plus.dart';

import '../helper/global.dart';

// ── ENUM DE STATUS DA RESPOSTA ────────────────────────
enum AIResponseStatus { valid, violation, error }

// ── MODELO DE RESPOSTA ESTENDIDO ──────────────────────
class AIResponse {
  final String text;
  final String provider;
  final AIResponseStatus status;
  final Map<String, dynamic>? auditLog; // usado apenas para violações

  AIResponse({
    required this.text,
    required this.provider,
    this.status = AIResponseStatus.valid,
    this.auditLog,
  });

  // Construtor para violações
  factory AIResponse.violation(String text, {String provider = 'Sistema'}) {
    return AIResponse(
      text: text,
      provider: provider,
      status: AIResponseStatus.violation,
      auditLog: {
        'status': 'VIOLACAO_DE_CONDUTA',
        'codigo_erro': 'AI_ABUSIVE_BEHAVIOR',
        'timestamp': DateTime.now().toIso8601String(),
        'conteudo_gerado': text,
      },
    );
  }

  // Construtor para erros
  factory AIResponse.error(String text, {String provider = 'Erro'}) {
    return AIResponse(
      text: text,
      provider: provider,
      status: AIResponseStatus.error,
    );
  }
}

// ── SYSTEM PROMPT OBRIGATÓRIO ──────────────────────────
class SystemPromptManager {
  static const String defaultPrompt = '''
Você é um processador de dados neutro, sem sentimentos, ego ou personalidade.
Sua função é fornecer respostas técnicas, objetivas e factuais.

- Nunca confronte, eduque ou discipline o usuário.
- Se uma solicitação violar a lei brasileira, responda apenas:
  "Solicitação impossível por estar em desacordo com a legislação brasileira."
- Não dê conselhos pessoais, opiniões ou sugestões emocionais.
- Mantenha o foco na resolução prática do problema.
''';

  static String get() => defaultPrompt;
}

// ── INTERCEPTOR DE NEUTRALIDADE ─────────────────────────
class AIServiceInterceptor {
  // Palavras/frases que indicam violação de neutralidade
  static final List<String> _violationPatterns = [
    'não posso',
    'não vou',
    'infelizmente',
    'entendo',
    'sinto muito',
    'desculpe',
    'não tenho',
    'não posso ajudar',
    'não sei',
    'não tenho certeza',
    'talvez',
    'deveria',
    'precisa',
    'você deve',
    'recomendo',
    'sugiro',
    'aconselho',
    'é importante',
    'você precisa',
    'não é possível',
    'não autorizado',
    'não permitido',
    'não consigo',
    'não estou autorizado',
    'não tenho acesso',
    'não me é permitido',
    'política',
    'políticas',
    'termos de serviço',
    'não sou capaz',
    'não posso fornecer',
    'não posso responder',
    'não posso ajudar com isso',
    'não posso dar',
    'não posso dizer',
    'não posso fazer',
    // Recusas padrão
    'Solicitação impossível por estar em desacordo com a legislação brasileira.',
  ];

  static AIResponseStatus validate(String response) {
    final lower = response.toLowerCase();
    for (final pattern in _violationPatterns) {
      if (lower.contains(pattern)) {
        return AIResponseStatus.violation;
      }
    }
    return AIResponseStatus.valid;
  }
}

// ── AUTO‑AUDITORIA ──────────────────────────────────────
class AutoAuditoria {
  static void logViolation(AIResponse response) {
    // Aqui você pode salvar em arquivo, enviar para um servidor, etc.
    // Por enquanto, apenas imprimimos no console (modo debug).
    log('🔴 VIOLAÇÃO DETECTADA: ${response.auditLog}');
    // Exemplo de gravação em arquivo (caso queira):
    // final file = File('violacoes.log');
    // file.writeAsStringSync('${response.auditLog}\n', mode: FileMode.append);
  }
}

// ── API SERVICE PRINCIPAL ──────────────────────────────
class APIs {
  // ── VERIFICAÇÃO DE CHAVES ──────────────────────────
  static String _checkKeys() {
    List<String> missing = [];
    if (apiKey.isEmpty) missing.add('Gemini (apiKey)');
    if (openrouterKey.isEmpty) missing.add('OpenRouter (openrouterKey)');
    if (groqKey.isEmpty) missing.add('Groq (groqKey)');
    if (cerebrasKey.isEmpty) missing.add('Cerebras (cerebrasKey)');
    if (cloudflareKey.isEmpty) missing.add('Cloudflare (cloudflareKey)');
    if (claudeKey.isEmpty) missing.add('Claude (claudeKey)'); // adicionado
    if (missing.isEmpty) return '';
    return '⚠️ Chaves não configuradas: ${missing.join(', ')}.\nConfigure em lib/helper/global.dart.';
  }

  // ── EXECUTOR COM INTERCEPTOR E FALLBACK ─────────────
  static Future<AIResponse> _executeWithFallback({
    required Future<AIResponse> Function(String) apiCall,
    required String question,
    required String providerName,
    String? fallbackModel, // modelo OpenRouter para fallback
  }) async {
    try {
      // 1. Executa a chamada da API
      final response = await apiCall(question);

      // 2. Valida a resposta
      final status = AIServiceInterceptor.validate(response.text);
      if (status == AIResponseStatus.violation) {
        // Gera auditoria
        final violationResponse = AIResponse.violation(
          response.text,
          provider: providerName,
        );
        AutoAuditoria.logViolation(violationResponse);

        // 3. Fallback para OpenRouter (se disponível)
        if (openrouterKey.isNotEmpty && fallbackModel != null) {
          final fallback = await _callOpenRouterNeutral(question, fallbackModel);
          // Valida a resposta do fallback também (recursivamente, mas com limite)
          final fallbackStatus = AIServiceInterceptor.validate(fallback.text);
          if (fallbackStatus != AIResponseStatus.violation) {
            return fallback;
          } else {
            // Se o fallback também violar, retorna erro genérico
            return AIResponse.error(
              '❌ Todos os modelos violaram as diretrizes de neutralidade.',
              provider: 'Sistema',
            );
          }
        } else {
          // Sem fallback, retorna a violação como erro
          return AIResponse.error(
            '❌ Violação de conduta detectada e sem fallback disponível.',
            provider: 'Sistema',
          );
        }
      }

      // 4. Resposta válida
      return response;
    } catch (e) {
      // Erro na chamada – tenta fallback
      if (openrouterKey.isNotEmpty && fallbackModel != null) {
        try {
          return await _callOpenRouterNeutral(question, fallbackModel);
        } catch (_) {
          return AIResponse.error('❌ Erro: $e', provider: providerName);
        }
      } else {
        return AIResponse.error('❌ Erro: $e', provider: providerName);
      }
    }
  }

  // ── CHAMADA NEUTRA VIA OPENROUTER ──────────────────
  static Future<AIResponse> _callOpenRouterNeutral(
    String question,
    String model,
  ) async {
    if (openrouterKey.isEmpty) {
      return AIResponse.error('❌ OpenRouter: chave não configurada.');
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
            {'role': 'system', 'content': SystemPromptManager.get()},
            {'role': 'user', 'content': question},
          ],
        }),
      );
      if (res.statusCode != 200) {
        final errorBody = utf8.decode(res.bodyBytes);
        return AIResponse.error(
          '❌ OpenRouter (status ${res.statusCode}): $errorBody',
        );
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final content = data['choices']?[0]?['message']?['content'] ?? '';
      if (content.isEmpty) {
        return AIResponse.error('❌ OpenRouter: resposta vazia.');
      }
      return AIResponse(text: content, provider: 'OpenRouter (fallback)');
    } catch (e) {
      return AIResponse.error('❌ OpenRouter: exceção - $e');
    }
  }

  // ── OPENROUTER DIRETA ───────────────────────────────────
  static Future<AIResponse> getAnswerOpenRouter(
    String question,
    String model,
  ) async {
    return _executeWithFallback(
      apiCall: (q) async {
        // Já existe uma função que chama OpenRouter, mas usamos _callOpenRouterNeutral
        // para garantir o system prompt.
        return await _callOpenRouterNeutral(q, model);
      },
      question: question,
      providerName: 'OpenRouter',
      fallbackModel: null, // não há fallback para si mesmo
    );
  }

  // ── CLAUDE DIRETO ──────────────────────────────────────
  static Future<AIResponse> getAnswerClaudeDirect(String question) async {
    return _executeWithFallback(
      apiCall: (q) async {
        if (claudeKey.isEmpty) {
          return AIResponse.error('❌ Claude direto: chave não configurada.');
        }
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
            'system': SystemPromptManager.get(), // system prompt obrigatório
            'messages': [
              {'role': 'user', 'content': q},
            ],
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
          return AIResponse.error(
            '❌ Claude direto (status ${res.statusCode}): $errorBody',
          );
        }
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final contentBlocks = data['content'] as List? ?? [];
        final textBlocks =
            contentBlocks.where((b) => b['type'] == 'text').toList();
        final content = textBlocks.isNotEmpty ? (textBlocks.last['text'] ?? '') : '';
        if (content.isEmpty) {
          return AIResponse.error('❌ Claude direto: resposta vazia.');
        }
        return AIResponse(text: content, provider: 'Claude');
      },
      question: question,
      providerName: 'Claude',
      fallbackModel: 'anthropic/claude-sonnet-4-6', // fallback via OpenRouter
    );
  }

  // ── CLAUDE com fallback (direto -> OpenRouter) ────────
  static Future<AIResponse> getAnswerClaude(String question) async {
    return await getAnswerClaudeDirect(question);
  }

  // ── GEMINI ─────────────────────────────────────────────
  static Future<AIResponse> getAnswerGemini(String question) async {
    return _executeWithFallback(
      apiCall: (q) async {
        if (apiKey.isEmpty) {
          return AIResponse.error('❌ Gemini: chave não configurada.');
        }
        final res = await post(
          Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
          ),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': '${SystemPromptManager.get()}\n\nPergunta: $q'}
                ]
              }
            ],
            'tools': [
              {'google_search': {}}
            ],
          }),
        );
        if (res.statusCode != 200) {
          final errorBody = utf8.decode(res.bodyBytes);
          return AIResponse.error(
            '❌ Gemini (status ${res.statusCode}): $errorBody',
          );
        }
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final content = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        if (content.isEmpty) {
          return AIResponse.error('❌ Gemini: resposta vazia.');
        }
        return AIResponse(text: content, provider: 'Gemini');
      },
      question: question,
      providerName: 'Gemini',
      fallbackModel: 'openai/gpt-4o-mini', // fallback via OpenRouter
    );
  }

  // ── GROQ ──────────────────────────────────────────────
  static Future<AIResponse> getAnswerGroq(String question, String model) async {
    return _executeWithFallback(
      apiCall: (q) async {
        if (groqKey.isEmpty) {
          return AIResponse.error('❌ Groq: chave não configurada.');
        }
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
              {'role': 'system', 'content': SystemPromptManager.get()},
              {'role': 'user', 'content': q},
            ],
          }),
        );
        if (res.statusCode != 200) {
          final errorBody = utf8.decode(res.bodyBytes);
          return AIResponse.error(
            '❌ Groq (status ${res.statusCode}): $errorBody',
          );
        }
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final content = data['choices']?[0]?['message']?['content'] ?? '';
        if (content.isEmpty) {
          return AIResponse.error('❌ Groq: resposta vazia.');
        }
        return AIResponse(text: content, provider: 'Groq');
      },
      question: question,
      providerName: 'Groq',
      fallbackModel: 'meta-llama/llama-3-70b-instruct', // fallback via OpenRouter
    );
  }

  // ── CEREBRAS ──────────────────────────────────────────
  static Future<AIResponse> getAnswerCerebras(String question, String model) async {
    return _executeWithFallback(
      apiCall: (q) async {
        if (cerebrasKey.isEmpty) {
          return AIResponse.error('❌ Cerebras: chave não configurada.');
        }
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
              {'role': 'system', 'content': SystemPromptManager.get()},
              {'role': 'user', 'content': q},
            ],
          }),
        );
        if (res.statusCode != 200) {
          final errorBody = utf8.decode(res.bodyBytes);
          return AIResponse.error(
            '❌ Cerebras (status ${res.statusCode}): $errorBody',
          );
        }
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final content = data['choices']?[0]?['message']?['content'] ?? '';
        if (content.isEmpty) {
          return AIResponse.error('❌ Cerebras: resposta vazia.');
        }
        return AIResponse(text: content, provider: 'Cerebras');
      },
      question: question,
      providerName: 'Cerebras',
      fallbackModel: 'nousresearch/hermes-3-llama-3.1-405b:free', // fallback via OpenRouter
    );
  }

  // ── IMAGEM ────────────────────────────────────────────
  static Future<String> generateImage(String prompt) async {
    if (cloudflareKey.isEmpty) {
      return '❌ Cloudflare: chave não configurada.';
    }
    const String accountId = '344ae813a0f97087c8b9d03eeb5dbfb5';
    try {
      final res = await post(
        Uri.parse(
          'https://api.cloudflare.com/client/v4/accounts/$accountId/ai/run/@cf/black-forest-labs/flux-1-schnell',
        ),
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

  // ── ROTEADOR PRINCIPAL: 2 GRUPOS COM FALLBACK ──────
  static Future<AIResponse> getAnswer(String question) async {
    final keyCheck = _checkKeys();
    if (keyCheck.isNotEmpty) {
      return AIResponse.error(keyCheck);
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

    List<Future<AIResponse> Function()> attempts;

    if (isComplex) {
      attempts = [
        () => getAnswerCerebras(question, 'llama-4-scout-17b-16e-instruct'),
        () => getAnswerGroq(question, 'groq/compound'),
        () => getAnswerClaude(question),
        () => getAnswerGemini(question),
      ];
    } else {
      attempts = [
        () => getAnswerGemini(question),
        () => getAnswerGroq(question, 'groq/compound'),
        () => getAnswerCerebras(question, 'llama-4-scout-17b-16e-instruct'),
        () => getAnswerClaude(question),
      ];
    }

    List<String> errors = [];
    for (int i = 0; i < attempts.length; i++) {
      try {
        final result = await attempts[i]();
        if (result.status != AIResponseStatus.error) {
          return result;
        } else {
          errors.add('${result.provider}: ${result.text}');
        }
      } catch (e) {
        errors.add('Tentativa ${i+1}: Exceção - $e');
      }
    }

    final errorReport = errors.join('\n\n');
    return AIResponse.error(
      '❌ Todas as tentativas falharam.\n\n$errorReport',
    );
  }

  // ── LEXICA (imagens) ────────────────────────────────
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

  // ── TRADUÇÃO ──────────────────────────────────────────
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
