import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../helper/my_dialog.dart';

import '../../controller/chat_controller.dart';
import '../../helper/global.dart';
import '../../helper/voice_api.dart';
import '../../widget/message_card.dart';
import 'image_feature.dart';
import 'translator_feature.dart';

class ChatBotFeature extends StatefulWidget {
  const ChatBotFeature({super.key});

  @override
  State<ChatBotFeature> createState() => _ChatBotFeatureState();
}

class _ChatBotFeatureState extends State<ChatBotFeature> {
  final _c = ChatController();
  final _tts = FlutterTts();
  final _stt = SpeechToText();
  final _player = AudioPlayer();
  int _selectedTab = 0;
  bool _isListening = false;
  bool _ttsEnabled = true;

  final _tabs = [
    {'icon': Icons.chat_bubble_rounded, 'label': 'Chat'},
    {'icon': Icons.image_rounded, 'label': 'Imagem'},
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() async {
    await _tts.setLanguage('pt-BR');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  /// Voz principal: Razo (servidor neural online).
  /// Se falhar por qualquer motivo, cai no flutter_tts local (fallback).
  void _speak(String text) async {
    if (!_ttsEnabled || text.isEmpty) return;

    await _tts.stop();
    await _player.stop();

    final audioBytes = await VoiceApi.synthesize(text);

    if (audioBytes != null && audioBytes.isNotEmpty) {
      try {
        await _player.play(BytesSource(audioBytes));
        return;
      } catch (e) {
        // Se a reprodução falhar, segue para o fallback abaixo.
      }
    }

    // Fallback: voz neural local do dispositivo.
    await _tts.speak(text);
  }

  void _startListening() async {
    final available = await _stt.initialize();
    if (available) {
      setState(() => _isListening = true);
      _stt.listen(
        onResult: (result) {
          _c.textC.text = result.recognizedWords;
          if (result.finalResult) {
            setState(() => _isListening = false);
            if (_c.textC.text.isNotEmpty) {
              _c.askQuestion().then((_) {
                final last = _c.list.lastWhere(
                    (m) => m.msgType.name == 'bot' && m.msg.isNotEmpty,
                    orElse: () => _c.list.last);
                _speak(last.msg);
              });
            }
          }
        },
        localeId: 'pt_BR',
      );
    } else {
      MyDialog.info('Microfone não disponível!');
    }
  }

  void _stopListening() {
    _stt.stop();
    setState(() => _isListening = false);
  }

  @override
  void dispose() {
    _tts.stop();
    _stt.stop();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF121212),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {},
        ),
        title: Text(
          _selectedTab == 0 ? 'Assistente IA' : 'Criar Imagem',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_selectedTab == 0)
            IconButton(
              icon: Icon(
                _ttsEnabled ? Icons.volume_up : Icons.volume_off,
                color: _ttsEnabled ? const Color(0xFF6B8EFF) : Colors.grey,
              ),
              onPressed: () {
                setState(() => _ttsEnabled = !_ttsEnabled);
                if (!_ttsEnabled) {
                  _tts.stop();
                  _player.stop();
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFF121212),
        child: _selectedTab == 0
            ? Obx(() => ListView(
                  physics: const BouncingScrollPhysics(),
                  controller: _c.scrollC,
                  padding: EdgeInsets.only(
                      top: mq.height * .02,
                      bottom: mq.height * .22,
                      left: 16,
                      right: 16),
                  children:
                      _c.list.map((e) => MessageCard(message: e)).toList(),
                ))
            : ImageFeature(),
      ),
      bottomSheet: _selectedTab == 0
          ? Container(
              decoration: const BoxDecoration(
                color: Color(0xFF121212),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Input
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.camera_alt_outlined,
                                color: Colors.grey, size: 22),
                          ),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: TextFormField(
                                controller: _c.textC,
                                onTapOutside: (e) =>
                                    FocusScope.of(context).unfocus(),
                                style: const TextStyle(color: Colors.black87),
                                decoration: InputDecoration(
                                  hintText: _isListening
                                      ? 'Ouvindo...'
                                      : 'Digite ou fale algo...',
                                  hintStyle: TextStyle(
                                    fontSize: 14,
                                    color: _isListening
                                        ? const Color(0xFF6B8EFF)
                                        : Colors.grey,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Botão microfone
                          GestureDetector(
                            onTapDown: (_) => _startListening(),
                            onTapUp: (_) => _stopListening(),
                            onTapCancel: () => _stopListening(),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isListening
                                    ? const Color(0xFF6B8EFF)
                                    : const Color(0xFFF5F5F5),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                color: _isListening
                                    ? Colors.white
                                    : Colors.grey,
                                size: 22,
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Botão enviar
                          Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF6B8EFF),
                                  Color(0xFFB06BFF)
                                ],
                              ),
                            ),
                            child: IconButton(
                              onPressed: () {
                                _c.askQuestion().then((_) {
                                  final msgs = _c.list
                                      .where((m) =>
                                          m.msgType.name == 'bot' &&
                                          m.msg.isNotEmpty)
                                      .toList();
                                  if (msgs.isNotEmpty) {
                                    _speak(msgs.last.msg);
                                  }
                                });
                              },
                              icon: const Icon(Icons.arrow_upward_rounded,
                                  color: Colors.white, size: 22),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF121212),
          border: Border(top: BorderSide(color: Color(0xFF1E1E1E))),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedTab,
          onTap: (i) => setState(() => _selectedTab = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF121212),
          selectedItemColor: const Color(0xFF6B8EFF),
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          elevation: 0,
          items: _tabs
              .map((t) => BottomNavigationBarItem(
                    icon: Icon(t['icon'] as IconData),
                    label: t['label'] as String,
                  ))
              .toList(),
        ),
      ),
    );
  }
}
