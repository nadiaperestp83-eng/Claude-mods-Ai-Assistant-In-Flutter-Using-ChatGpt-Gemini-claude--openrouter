import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../apis/apis.dart';
import '../helper/my_dialog.dart';
import '../model/message.dart';

class ChatController extends GetxController {
  final textC = TextEditingController();
  final scrollC = ScrollController();

  final list = <Message>[
    Message(msg: 'Hello, How can I help you?', msgType: MessageType.bot)
  ].obs;

  Future<void> askQuestion() async {
    if (textC.text.trim().isEmpty) {
      MyDialog.info('Ask Something!');
      return;
    }

    final question = textC.text;
    list.add(Message(msg: question, msgType: MessageType.user));
    textC.text = '';

    if (APIs.isVideoRequest(question)) {
      await _askVideo(question);
      return;
    }

    final classified = await APIs.classifyTranslationIntent(question);
    if (classified.isTranslation) {
      await _askTranslation(classified.text, classified.targetLanguage);
      return;
    }

    await _askText(question);
  }

  Future<void> _askTranslation(String text, String targetLanguage) async {
    list.add(Message(msg: '', msgType: MessageType.bot));
    _scrollDown();

    try {
      final translated = await APIs.translate(
        text: text,
        targetLanguageNameOrCode: targetLanguage,
      );
      list.removeLast();
      list.add(Message(
        msg: translated,
        msgType: MessageType.bot,
        aiProvider: 'Tradutor',
      ));
    } catch (e) {
      list.removeLast();
      list.add(Message(
        msg: 'Exceção ao traduzir: $e',
        msgType: MessageType.bot,
      ));
    }

    _scrollDown();
  }

  Future<void> _askText(String question) async {
    list.add(Message(msg: '', msgType: MessageType.bot));
    _scrollDown();

    try {
      final res = await APIs.getAnswer(question);
      list.removeLast();
      list.add(Message(
        msg: res.text.isEmpty ? 'Resposta vazia — provider: ${res.provider}' : res.text,
        msgType: MessageType.bot,
        aiProvider: res.provider,
      ));
    } catch (e) {
      list.removeLast();
      list.add(Message(
        msg: 'Exceção no controller: $e',
        msgType: MessageType.bot,
      ));
    }

    _scrollDown();
  }

  Future<void> _askVideo(String question) async {
    // Mensagem vazia sem texto marca o estado "gerando vídeo" para o
    // MessageCard mostrar o anel pulsando em vez do texto/typewriter.
    list.add(Message(msg: '', msgType: MessageType.bot, videoUrl: ''));
    _scrollDown();

    try {
      final res = await APIs.generateVideo(question);
      list.removeLast();
      if (res.success) {
        list.add(Message(
          msg: '',
          msgType: MessageType.bot,
          videoUrl: res.videoUrl,
          aiProvider: 'Magic Hour',
        ));
      } else {
        list.add(Message(
          msg: res.error ?? 'Não foi possível gerar o vídeo.',
          msgType: MessageType.bot,
        ));
      }
    } catch (e) {
      list.removeLast();
      list.add(Message(
        msg: 'Exceção ao gerar vídeo: $e',
        msgType: MessageType.bot,
      ));
    }

    _scrollDown();
  }

  void _scrollDown() {
    scrollC.animateTo(scrollC.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500), curve: Curves.ease);
  }
}
