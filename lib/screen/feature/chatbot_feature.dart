import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controller/chat_controller.dart';
import '../../helper/global.dart';
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
  int _selectedTab = 0;

  final _tabs = [
    {'icon': Icons.chat_bubble_rounded, 'label': 'Chat'},
    {'icon': Icons.image_rounded, 'label': 'Imagem'},
    {'icon': Icons.translate_rounded, 'label': 'Tradutor'},
    {'icon': Icons.videocam_rounded, 'label': 'Vídeo'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () {},
        ),
        title: Text(
          _selectedTab == 0
              ? 'Assistente IA'
              : _selectedTab == 1
                  ? 'Criar Imagem'
                  : _selectedTab == 2
                      ? 'Tradutor'
                      : 'Criar Vídeo',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.black87),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.grid_view_rounded, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF8F9FF), Color(0xFFFFFFFF)],
              ),
            ),
          ),
          if (_selectedTab == 0)
            Obx(() => ListView(
                  physics: const BouncingScrollPhysics(),
                  controller: _c.scrollC,
                  padding: EdgeInsets.only(
                      top: mq.height * .02,
                      bottom: mq.height * .18,
                      left: 16,
                      right: 16),
                  children:
                      _c.list.map((e) => MessageCard(message: e)).toList(),
                ))
          else if (_selectedTab == 1)
            ImageFeature()
          else if (_selectedTab == 2)
            TranslatorFeature()
          else
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Em breve', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
        ],
      ),
      bottomSheet: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedTab == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('🎨 Criar Imagem',
                            () => setState(() => _selectedTab = 1)),
                        const SizedBox(width: 8),
                        _chip('🌐 Traduzir',
                            () => setState(() => _selectedTab = 2)),
                        const SizedBox(width: 8),
                        _chip('🎬 Criar Vídeo',
                            () => setState(() => _selectedTab = 3)),
                        const SizedBox(width: 8),
                        _chip('🔍 Pesquisar', () {}),
                      ],
                    ),
                  ),
                ),
              if (_selectedTab == 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
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
                            decoration: const InputDecoration(
                              hintText: 'Digite ou fale algo...',
                              hintStyle:
                                  TextStyle(fontSize: 14, color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF5F5F5),
                        ),
                        child: IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.mic_rounded,
                              color: Colors.grey, size: 22),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF6B8EFF), Color(0xFFB06BFF)],
                          ),
                        ),
                        child: IconButton(
                          onPressed: _c.askQuestion,
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
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedTab,
          onTap: (i) => setState(() => _selectedTab = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF6B8EFF),
          unselectedItemColor: Colors.grey,
          selectedLabelStyle:
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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

  Widget _chip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 13, color: Colors.black87)),
      ),
    );
  }
}
