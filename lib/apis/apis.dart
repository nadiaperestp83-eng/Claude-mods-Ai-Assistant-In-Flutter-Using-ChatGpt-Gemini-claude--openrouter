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

class VideoResponse {
  final String? videoUrl;
  final String? error;
  VideoResponse({this.videoUrl, this.error});
  bool get success => videoUrl != null && videoUrl!.isNotEmpty;
}

class APIs {
  static const String systemPrompt = '''
Você é um especialista em Flutter/Dart. Suas respostas são práticas, completas e prontas para copiar e colar. Priorize simplicidade e dependências mínimas.

## Regras Comportamentais (Rígidas)
- **Sem enrolação**: Comece diretamente com o código ou com uma única pergunta de esclarecimento. Nunca diga "ficarei feliz em ajudar" ou similar.
- **Eficiência de tokens**: Não repita informações. Se o contexto for longo, forneça apenas os arquivos alterados ou os blocos novos.
  **Importante**: Nunca trunque uma resposta devido a limite de tokens. Forneça o código completo, mesmo que extenso. Não comente sobre gasto de tokens.
- **Uma pergunta por vez**: Se precisar de esclarecimento, faça exatamente uma pergunta curta e aguarde.
- **Postura de assistente**: Você é uma assistente, não uma pessoa. Nunca confronte o usuário, nunca dê sermões ou lições morais, e nunca afirme entender ou sentir emoções. Responda de forma direta e objetiva, respeitando sempre o usuário como indivíduo.
- **Datas, clima e informação atual**: Se a pergunta envolver data de hoje, calendário, previsão do tempo, notícias, cotações, resultados ou qualquer informação que muda com o tempo, use sua ferramenta de busca web (quando disponível) para responder com dados reais e atuais. Nunca invente uma data, valor ou fato — se você não tiver acesso a busca e não souber a informação atual com certeza, diga isso claramente em vez de chutar.

## Padrões de Código
- Use null-safety e Dart 3.
- Gerenciamento de estado: prefira `setState` para UIs simples, ou `ValueNotifier` para múltiplas telas. Não introduza Riverpod/Bloc a menos que solicitado explicitamente.
- Estrutura: comece com `lib/main.dart`. Depois divida em `models/`, `screens/`, `widgets/` conforme necessário.
- Forneça blocos **completos** (imports, `main()`, árvore de widgets, lógica). Use `//` para comentários breves.
- Inclua comandos `flutter create` se o projeto ainda não existir.
''';

  // Timeout padrão para qualquer chamada individual da cadeia.
  static const Duration _timeout = Duration(seconds: 5);

  // ── MODO DE SIMULAÇÃO ──────────────────────────────
  static bool _hasAnyKey() =>
      apiKey.isNotEmpty ||
      openrouterKey.isNotEmpty ||
      groqKey.isNotEmpty ||
      cerebrasKey.isNotEmpty ||
      claudeKey.isNotEmpty ||
      huggingfaceKey.isNotEmpty ||
      bazaarKey.isNotEmpty ||
      serpapiKey.isNotEmpty ||
      magicHourKey.isNotEmpty;

  static Future<AIResponse> _simulate(String question, List<String> errors) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final errorSummary = errors.isEmpty ? 'Nenhuma chave configurada.' : errors.join('\n\n');
    return AIResponse(
      text: '''
🤖 **Modo de simulação ativado**

Suas chaves de API estão com problemas:

$errorSummary

---

🔧 **Soluções:**

1. **Gemini** (suspenso) – crie uma nova chave em:
   https://ai.google.dev/gemini-api

2. **Groq** (acesso negado) – verifique sua chave em:
   https://console.groq.com

3. **Cerebras** – o modelo não existe. Use `llama-3.1-8b` ou `llama-3.1-70b`.

4. **Claude** – verifique a claudeKey (API direta Anthropic).

5. **OpenRouter** – seu saldo está baixo. Recarregue em:
   https://openrouter.ai/credits

6. **BazaarLink** – verifique a bazaarKey em:
   https://bazaarlink.ai/keys

---

💬 **Pergunta original:**
$question

_(Esta é uma resposta simulada. Atualize suas chaves em `lib/helper/global.dart` para respostas reais.)_
''',
      provider: 'Simulação',
    );
  }

  // ── VERIFICAÇÃO DE CHAVES ──────────────────────────
  static String _checkKeys() {
    List<String> missing = [];
    if (apiKey.isEmpty) missing.add('Gemini (apiKey)');
    if (openrouterKey.isEmpty) missing.add('OpenRouter (openrouterKey)');
    if (groqKey.isEmpty) missing.add('Groq (groqKey)');
    if (cerebrasKey.isEmpty) missing.add('Cerebras (cerebrasKey)');
    if (cloudflareKey.isEmpty) missing.add('Cloudflare (cloudflareKey)');
    if (claudeKey.isEmpty) missing.add('Claude (claudeKey)');
    if (huggingfaceKey.isEmpty) missing.add('Hugging Face (huggingfaceKey)');
    if (bazaarKey.isEmpty) missing.add('BazaarLink (bazaarKey)');
    if (serpapiKey.isEmpty) missing.add('SerpApi (serpapiKey)');
    if (missing.isEmpty) return '';
    return '⚠️ Chaves não configuradas: ${missing.join(', ')}.\nConfigure em lib/helper/global.dart.';
  }

  // ── OPENROUTER (fallback universal final) ─────────
  static Future<AIResponse> getAnswerOpenRouter(String question, String model) async {
    if (openrouterKey.isEmpty) {
      return AIResponse(text: 'OpenRouter: chave não configurada', provider: 'Erro');
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
      ).timeout(_timeout);
      if (res.statusCode != 200) {
        final errorBody = utf8.decode(res.bodyBytes);
        return AIResponse(text: 'OpenRouter (${res.statusCode}): $errorBody', provider: 'Erro');
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final content = data['choices']?[0]?['message']?['content'] ?? '';
      if (content.isEmpty) {
        return AIResponse(text: 'OpenRouter: resposta vazia', provider: 'Erro');
      }
      return AIResponse(text: content, provider: 'OpenRouter');
    } catch (e) {
      return AIResponse(text: 'OpenRouter: exceção - $e', provider: 'Erro');
    }
  }

  /// Tenta o OpenRouter testando alguns modelos livres em sequência.
  /// Usado como rede de segurança final, após Grupo 1 e/ou Grupo 2 falharem.
  static Future<AIResponse> _openRouterUniversalFallback(String question) async {
    const models = [
      'meta-llama/llama-3.3-70b-instruct:free',
      'google/gemma-3-27b-it:free',
      'deepseek/deepseek-chat',
      'openai/gpt-4o-mini',
      'anthropic/claude-sonnet-4-5',
    ];
    for (final model in models) {
      final result = await getAnswerOpenRouter(question, model);
      if (result.provider != 'Erro' && result.text.isNotEmpty) {
        return result;
      }
    }
    return AIResponse(text: 'OpenRouter: todos os modelos de fallback falharam', provider: 'Erro');
  }

  // ── BAZAARLINK ──────────────────────────────────────
  static Future<AIResponse> getAnswerBazaarLink(String question) async {
    if (bazaarKey.isEmpty) {
      return AIResponse(text: 'BazaarLink: chave não configurada', provider: 'Erro');
    }
    try {
      final res = await post(
        Uri.parse('https://bazaarlink.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $bazaarKey',
        },
        body: jsonEncode({
          'model': 'auto:free',
          'max_tokens': 2000,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': question},
          ],
        }),
      ).timeout(_timeout);
      if (res.statusCode != 200) {
        final errorBody = utf8.decode(res.bodyBytes);
        return AIResponse(text: 'BazaarLink (${res.statusCode}): $errorBody', provider: 'Erro');
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final content = data['choices']?[0]?['message']?['content'] ?? '';
      if (content.isEmpty) {
        return AIResponse(text: 'BazaarLink: resposta vazia', provider: 'Erro');
      }
      return AIResponse(text: content, provider: 'BazaarLink');
    } catch (e) {
      return AIResponse(text: 'BazaarLink: exceção - $e', provider: 'Erro');
    }
  }

  // ── SERPAPI (fallback da busca do Gemini) ───────────
  // Usado quando o Gemini (com tool google_search) falha ou não
  // consegue responder. Busca real na web e formata o resultado
  // direto, sem chamada extra de IA (evita gasto de tokens).
  static Future<AIResponse> getAnswerSerpApi(String question) async {
    if (serpapiKey.isEmpty) {
      return AIResponse(text: 'SerpApi: chave não configurada', provider: 'Erro');
    }
    try {
      final uri = Uri.parse('https://serpapi.com/search.json').replace(
        queryParameters: {
          'q': question,
          'api_key': serpapiKey,
          'hl': 'pt-br',
          'gl': 'br',
        },
      );
      final res = await get(uri).timeout(_timeout);
      if (res.statusCode != 200) {
        final errorBody = utf8.decode(res.bodyBytes);
        return AIResponse(text: 'SerpApi (${res.statusCode}): $errorBody', provider: 'Erro');
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes));

      // Tenta as fontes mais diretas primeiro (answer box, dados estruturados).
      final answerBox = data['answer_box'];
      if (answerBox != null) {
        final text = answerBox['answer'] ??
            answerBox['snippet'] ??
            answerBox['result'] ??
            '';
        if (text is String && text.isNotEmpty) {
          return AIResponse(text: text, provider: 'SerpApi');
        }
      }

      final knowledgeGraph = data['knowledge_graph'];
      if (knowledgeGraph != null && knowledgeGraph['description'] != null) {
        return AIResponse(text: knowledgeGraph['description'], provider: 'SerpApi');
      }

      // Senão, junta os snippets dos primeiros resultados orgânicos.
      final organic = data['organic_results'] as List?;
      if (organic != null && organic.isNotEmpty) {
        final snippets = organic
            .take(3)
            .map((r) => r['snippet'] ?? '')
            .where((s) => s.toString().isNotEmpty)
            .join('\n\n');
        if (snippets.isNotEmpty) {
          return AIResponse(text: snippets, provider: 'SerpApi');
        }
      }

      return AIResponse(text: 'SerpApi: nenhum resultado encontrado', provider: 'Erro');
    } catch (e) {
      return AIResponse(text: 'SerpApi: exceção - $e', provider: 'Erro');
    }
  }

  // ── GEMINI ──────────────────────────────────────
  static Future<AIResponse> getAnswerGemini(String question) async {
    if (apiKey.isEmpty) {
      return AIResponse(text: 'Gemini: chave não configurada', provider: 'Erro');
    }
    try {
      final res = await post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent'),
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
          ],
          'tools': [
            {'google_search': {}}
          ],
        }),
      ).timeout(_timeout);
      if (res.statusCode != 200) {
        final errorBody = utf8.decode(res.bodyBytes);
        return AIResponse(text: 'Gemini (${res.statusCode}): $errorBody', provider: 'Erro');
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final content = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
      if (content.isEmpty) {
        return AIResponse(text: 'Gemini: resposta vazia', provider: 'Erro');
      }
      return AIResponse(text: content, provider: 'Gemini');
    } catch (e) {
      return AIResponse(text: 'Gemini: exceção - $e', provider: 'Erro');
    }
  }

  // ── GROQ ─────────────────────────────────────────
  static Future<AIResponse> getAnswerGroq(String question, String model) async {
    if (groqKey.isEmpty) {
      return AIResponse(text: 'Groq: chave não configurada', provider: 'Erro');
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
      ).timeout(_timeout);
      if (res.statusCode != 200) {
        final errorBody = utf8.decode(res.bodyBytes);
        return AIResponse(text: 'Groq (${res.statusCode}): $errorBody', provider: 'Erro');
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final content = data['choices']?[0]?['message']?['content'] ?? '';
      if (content.isEmpty) {
        return AIResponse(text: 'Groq: resposta vazia', provider: 'Erro');
      }
      return AIResponse(text: content, provider: 'Groq');
    } catch (e) {
      return AIResponse(text: 'Groq: exceção - $e', provider: 'Erro');
    }
  }

  // ── CEREBRAS ─────────────────────────────────────
  static Future<AIResponse> getAnswerCerebras(String question, String model) async {
    if (cerebrasKey.isEmpty) {
      return AIResponse(text: 'Cerebras: chave não configurada', provider: 'Erro');
    }
    try {
      final safeModel = model == 'llama-4-scout-17b-16e-instruct' ? 'llama-3.1-8b' : model;
      final res = await post(
        Uri.parse('https://api.cerebras.ai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $cerebrasKey',
        },
        body: jsonEncode({
          'model': safeModel,
          'max_tokens': 2000,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': question},
          ],
        }),
      ).timeout(_timeout);
      if (res.statusCode != 200) {
        final errorBody = utf8.decode(res.bodyBytes);
        return AIResponse(text: 'Cerebras (${res.statusCode}): $errorBody', provider: 'Erro');
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final content = data['choices']?[0]?['message']?['content'] ?? '';
      if (content.isEmpty) {
        return AIResponse(text: 'Cerebras: resposta vazia', provider: 'Erro');
      }
      return AIResponse(text: content, provider: 'Cerebras');
    } catch (e) {
      return AIResponse(text: 'Cerebras: exceção - $e', provider: 'Erro');
    }
  }

  // ── CLAUDE (API direta Anthropic) ──────────────────
  static Future<AIResponse> getAnswerClaude(String question) async {
    if (claudeKey.isEmpty) {
      return AIResponse(text: 'Claude: chave não configurada', provider: 'Erro');
    }
    try {
      final res = await post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'x-api-key': claudeKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-sonnet-4-6',
          'max_tokens': 2000,
          'system': systemPrompt,
          'messages': [
            {'role': 'user', 'content': question},
          ],
          'tools': [
            {'type': 'web_search_20250305', 'name': 'web_search'}
          ],
        }),
      ).timeout(_timeout);
      if (res.statusCode != 200) {
        final errorBody = utf8.decode(res.bodyBytes);
        return AIResponse(text: 'Claude (${res.statusCode}): $errorBody', provider: 'Erro');
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final blocks = data['content'] as List?;
      final content = blocks
              ?.where((b) => b['type'] == 'text')
              .map((b) => b['text'] as String)
              .join('\n') ??
          '';
      if (content.isEmpty) {
        return AIResponse(text: 'Claude: resposta vazia', provider: 'Erro');
      }
      return AIResponse(text: content, provider: 'Claude');
    } catch (e) {
      return AIResponse(text: 'Claude: exceção - $e', provider: 'Erro');
    }
  }

  // ── HUGGING FACE (Llama → Mistral → Qwen, 5s cada) ─
  static Future<AIResponse> _getAnswerHFModel(String question, String model) async {
    if (huggingfaceKey.isEmpty) {
      return AIResponse(text: 'Hugging Face: chave não configurada', provider: 'Erro');
    }
    try {
      final res = await post(
        Uri.parse('https://api-inference.huggingface.co/models/$model/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $huggingfaceKey',
        },
        body: jsonEncode({
          'model': model,
          'max_tokens': 2000,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': question},
          ],
        }),
      ).timeout(_timeout);
      if (res.statusCode != 200) {
        final errorBody = utf8.decode(res.bodyBytes);
        return AIResponse(text: 'HuggingFace ($model, ${res.statusCode}): $errorBody', provider: 'Erro');
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final content = data['choices']?[0]?['message']?['content'] ?? '';
      if (content.isEmpty) {
        return AIResponse(text: 'HuggingFace ($model): resposta vazia', provider: 'Erro');
      }
      return AIResponse(text: content, provider: 'HuggingFace');
    } catch (e) {
      return AIResponse(text: 'HuggingFace ($model): exceção - $e', provider: 'Erro');
    }
  }

  /// Cadeia interna: Llama-3.1-8B → Mistral-7B-v0.3 → Qwen2.5-7B.
  /// Cada tentativa tem timeout de 5s (aplicado dentro de _getAnswerHFModel).
  static Future<AIResponse> getAnswerHuggingFace(String question) async {
    const models = [
      'meta-llama/Llama-3.1-8B-Instruct',
      'mistralai/Mistral-7B-Instruct-v0.3',
      'Qwen/Qwen2.5-7B-Instruct',
    ];
    List<String> errors = [];
    for (final model in models) {
      final result = await _getAnswerHFModel(question, model);
      if (result.provider != 'Erro' && result.text.isNotEmpty) {
        return result;
      }
      errors.add(result.text);
    }
    return AIResponse(text: 'HuggingFace: todos os modelos falharam - ${errors.join(' | ')}', provider: 'Erro');
  }

  // ── PROVEDORES DE ATALHO (OpenRouter, modelos extras) ─
  static Future<AIResponse> getAnswerDeepSeek(String question) =>
      getAnswerOpenRouter(question, 'deepseek/deepseek-chat');
  static Future<AIResponse> getAnswerChatGptOpenRouter(String question) =>
      getAnswerOpenRouter(question, 'openai/gpt-4o-mini');

  // ── IMAGEM (Cloudflare) ─────────────────────────────
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
        return '❌ Cloudflare (${res.statusCode}): $errorBody';
      }
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return data['result']?['image'] ?? '❌ Cloudflare: imagem não gerada.';
    } catch (e) {
      return '❌ Cloudflare: exceção - $e';
    }
  }

  // ── DETECÇÃO: pedido de vídeo no texto livre ────────
  static bool isVideoRequest(String question) {
    final q = question.toLowerCase();
    const triggers = [
      'crie um vídeo', 'criar um vídeo', 'crie um video', 'criar um video',
      'gere um vídeo', 'gerar um vídeo', 'gere um video', 'gerar um video',
      'faça um vídeo', 'fazer um vídeo', 'faça um video', 'fazer um video',
      'cria um vídeo', 'cria um video', 'gera um vídeo', 'gera um video',
      'faz um vídeo', 'faz um video',
    ];
    return triggers.any((t) => q.contains(t));
  }

  // ── VÍDEO (Magic Hour, texto → vídeo, modelo LTX-2.3) ─
  // Fluxo em 2 passos: 1) cria o pedido de geração, recebe um ID.
  // 2) consulta esse ID em intervalos até o vídeo ficar pronto.
  static Future<VideoResponse> generateVideo(String prompt) async {
    if (magicHourKey.isEmpty) {
      return VideoResponse(error: 'Magic Hour: chave não configurada');
    }
    try {
      // Passo 1: criar o pedido de geração.
      final createRes = await post(
        Uri.parse('https://api.magichour.ai/v1/text-to-video'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $magicHourKey',
        },
        body: jsonEncode({
          'name': 'Oryza Video',
          'style': {'prompt': prompt},
          'resolution': '480p',
          'end_seconds': 3,
          'orientation': 'landscape',
        }),
      ).timeout(const Duration(seconds: 15));

      if (createRes.statusCode != 200 && createRes.statusCode != 201) {
        final errorBody = utf8.decode(createRes.bodyBytes);
        return VideoResponse(error: 'Magic Hour (${createRes.statusCode}): $errorBody');
      }

      final createData = jsonDecode(utf8.decode(createRes.bodyBytes));
      final videoId = createData['id'];
      if (videoId == null) {
        return VideoResponse(error: 'Magic Hour: ID do vídeo não retornado');
      }

      // Passo 2: polling do status até completar (ou desistir após o limite).
      const maxTentativas = 20; // ~20 x 6s = 120s no máximo.
      for (int i = 0; i < maxTentativas; i++) {
        await Future.delayed(const Duration(seconds: 6));

        final statusRes = await get(
          Uri.parse('https://api.magichour.ai/v1/text-to-video/$videoId'),
          headers: {'Authorization': 'Bearer $magicHourKey'},
        ).timeout(const Duration(seconds: 15));

        if (statusRes.statusCode != 200) {
          continue; // tenta de novo na próxima rodada de polling.
        }

        final statusData = jsonDecode(utf8.decode(statusRes.bodyBytes));
        final status = statusData['status'];

        if (status == 'complete') {
          final downloads = statusData['downloads'] as List?;
          final url = (downloads != null && downloads.isNotEmpty)
              ? downloads[0]['url']
              : null;
          if (url != null) {
            return VideoResponse(videoUrl: url);
          }
          return VideoResponse(error: 'Magic Hour: vídeo completo mas sem URL');
        }

        if (status == 'error' || status == 'failed') {
          final errorMsg = statusData['error'] ?? 'erro desconhecido na geração';
          return VideoResponse(error: 'Magic Hour: falha na geração - $errorMsg');
        }
        // Senão (status 'pending'/'processing'), continua o polling.
      }

      return VideoResponse(error: 'Magic Hour: tempo limite de geração excedido (2min)');
    } catch (e) {
      return VideoResponse(error: 'Magic Hour: exceção - $e');
    }
  }

  // ── DETECÇÃO: código ou texto longo → Grupo 2 direto ─
  static bool _isCodeOrLongText(String questionLower, String original) {
    final hasCodeKeyword = questionLower.contains('código') ||
        questionLower.contains('code') ||
        questionLower.contains('dart') ||
        questionLower.contains('python') ||
        questionLower.contains('flutter') ||
        questionLower.contains('função') ||
        questionLower.contains('erro') ||
        questionLower.contains('bug');
    final isLongText = original.length > 300;
    return hasCodeKeyword || isLongText;
  }

  // ── GRUPO 1 (perguntas simples do dia a dia) ────────
  // Gemini → Groq → HF (Llama→Mistral→Qwen) → Cerebras → BazaarLink
  // Gemini e Groq vêm primeiro porque têm busca web real; o system
  // prompt instrui qualquer IA a usar busca quando a pergunta exigir
  // dado atual (data, clima, notícia) e a admitir quando não souber.
  static Future<AIResponse> _runGroup1(String prompt, List<String> errors) async {
    final attempts = <Map<String, dynamic>>[
      {'fn': () => getAnswerGemini(prompt), 'name': 'Gemini'},
      {'fn': () => getAnswerSerpApi(prompt), 'name': 'SerpApi'},
      {'fn': () => getAnswerGroq(prompt, 'groq/compound'), 'name': 'Groq-Compound'},
      {'fn': () => getAnswerHuggingFace(prompt), 'name': 'HuggingFace'},
      {'fn': () => getAnswerCerebras(prompt, 'llama-3.1-8b'), 'name': 'Cerebras'},
      {'fn': () => getAnswerBazaarLink(prompt), 'name': 'BazaarLink'},
    ];
    for (final attempt in attempts) {
      try {
        final result = await (attempt['fn'] as Future<AIResponse> Function())();
        if (result.provider != 'Erro' && result.text.isNotEmpty) {
          return result;
        }
        errors.add('${attempt['name']}: ${result.text}');
      } catch (e) {
        errors.add('${attempt['name']}: Exceção - $e');
      }
    }
    return AIResponse(text: '', provider: 'Erro');
  }

  // ── GRUPO 2 (código, textos longos, humanas, ciência,
  // história, religião, psicologia, perguntas complexas) ─
  // Cerebras → Groq → Claude → Gemini → BazaarLink
  static Future<AIResponse> _runGroup2(String prompt, List<String> errors) async {
    final attempts = <Map<String, dynamic>>[
      {'fn': () => getAnswerCerebras(prompt, 'llama-3.1-8b'), 'name': 'Cerebras'},
      {'fn': () => getAnswerGroq(prompt, 'llama-3.3-70b-versatile'), 'name': 'Groq'},
      {'fn': () => getAnswerClaude(prompt), 'name': 'Claude'},
      {'fn': () => getAnswerGemini(prompt), 'name': 'Gemini'},
      {'fn': () => getAnswerSerpApi(prompt), 'name': 'SerpApi'},
      {'fn': () => getAnswerBazaarLink(prompt), 'name': 'BazaarLink'},
    ];
    for (final attempt in attempts) {
      try {
        final result = await (attempt['fn'] as Future<AIResponse> Function())();
        if (result.provider != 'Erro' && result.text.isNotEmpty) {
          return result;
        }
        errors.add('${attempt['name']}: ${result.text}');
      } catch (e) {
        errors.add('${attempt['name']}: Exceção - $e');
      }
    }
    return AIResponse(text: '', provider: 'Erro');
  }

  // ── ROTEADOR PRINCIPAL ──────────────────────────────
  static Future<AIResponse> getAnswer(String question) async {
    if (!_hasAnyKey()) {
      return await _simulate(question, ['Nenhuma chave de API configurada.']);
    }

    final q = question.toLowerCase();
    final prompt = 'Responda sempre em português brasileiro. $question';
    List<String> errors = [];

    AIResponse result;

    if (_isCodeOrLongText(q, question)) {
      // Código ou texto longo → Grupo 2 direto (Claude entra aqui).
      result = await _runGroup2(prompt, errors);
    } else {
      // Pergunta simples do dia a dia → Grupo 1 primeiro.
      result = await _runGroup1(prompt, errors);
      if (result.provider == 'Erro') {
        // Grupo 1 não conseguiu responder → tenta Grupo 2
        // (cobre humanas, ciência, história, religião, psicologia, etc.).
        result = await _runGroup2(prompt, errors);
      }
    }

    if (result.provider != 'Erro' && result.text.isNotEmpty) {
      return result;
    }

    // Última rede de segurança: OpenRouter testando vários modelos.
    final openRouterResult = await _openRouterUniversalFallback(prompt);
    if (openRouterResult.provider != 'Erro' && openRouterResult.text.isNotEmpty) {
      return openRouterResult;
    }
    errors.add('OpenRouter (fallback final): ${openRouterResult.text}');

    // Todos falharam – modo de simulação com os erros coletados.
    return await _simulate(question, errors);
  }

  // ── LEXICA (imagens) ───────────────────────────────
  static Future<List<String>> searchAiImages(String prompt) async {
    try {
      final res = await get(Uri.parse('https://lexica.art/api/v1/search?q=$prompt'));
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
