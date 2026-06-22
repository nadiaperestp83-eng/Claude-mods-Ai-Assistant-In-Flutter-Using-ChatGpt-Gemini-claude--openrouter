import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../helper/global.dart';
import '../model/message.dart';

class MessageCard extends StatelessWidget {
  final Message message;

  const MessageCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return message.msgType == MessageType.bot
        ? _BotMessage(message: message)
        : _UserMessage(message: message);
  }
}

class _UserMessage extends StatelessWidget {
  final Message message;
  const _UserMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: mq.width * .75),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE67E22),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              message.msg,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotMessage extends StatelessWidget {
  final Message message;
  const _BotMessage({required this.message});

  bool get _isGeneratingVideo =>
      message.videoUrl == '' && message.msg.isEmpty;

  bool get _hasVideo =>
      message.videoUrl != null && message.videoUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    // Estado "gerando vídeo": só o anel pulsando, sem bolha de texto grande.
    if (_isGeneratingVideo) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 24, left: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: _PulsingRing(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: mq.width * .75),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: _AssistantLabel(),
                ),
                if (_hasVideo)
                  _VideoPlayerWidget(url: message.videoUrl!)
                else if (message.msg.isEmpty)
                  AnimatedTextKit(
                    animatedTexts: [
                      TypewriterAnimatedText(
                        'Buscando...',
                        textStyle: GoogleFonts.inter(
                          fontSize: 15,
                          color: Colors.white54,
                          height: 1.5,
                        ),
                        speed: const Duration(milliseconds: 50),
                      ),
                    ],
                    repeatForever: true,
                  )
                else
                  Text(
                    message.msg,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.92),
                      height: 1.6,
                    ),
                  ),
                if (message.msg.isNotEmpty && !_hasVideo)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: message.msg));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Texto copiado'),
                            duration: Duration(seconds: 1),
                            backgroundColor: Color(0xFF1E1E1E),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Anel pulsando exibido enquanto o vídeo está sendo gerado.
/// Substitui a bolha de texto grande — fica leve e discreto no chat.
class _PulsingRing extends StatefulWidget {
  const _PulsingRing();

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final scale = 0.8 + (0.3 * (1 - (_controller.value - 0.5).abs() * 2));
            final opacity = 0.4 + (0.6 * (1 - (_controller.value - 0.5).abs() * 2));
            return Opacity(
              opacity: opacity.clamp(0.3, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE67E22),
                      width: 3,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 10),
        Text(
          'Gerando vídeo...',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }
}

/// Player de vídeo embutido na bolha de resposta do assistente.
class _VideoPlayerWidget extends StatefulWidget {
  final String url;
  const _VideoPlayerWidget({required this.url});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      }).catchError((_) {
        if (mounted) setState(() => _failed = true);
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Text(
        'Não foi possível carregar o vídeo.',
        style: GoogleFonts.inter(fontSize: 14, color: Colors.white54),
      );
    }

    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFE67E22),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(c),
            GestureDetector(
              onTap: () {
                setState(() {
                  c.value.isPlaying ? c.pause() : c.play();
                });
              },
              child: AnimatedOpacity(
                opacity: c.value.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantLabel extends StatelessWidget {
  const _AssistantLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('✨', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 4),
        Text(
          'Assistente',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
