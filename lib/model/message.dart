class Message {
  String msg;
  final MessageType msgType;
  final String? aiProvider;
  final String? videoUrl;

  Message({
    required this.msg,
    required this.msgType,
    this.aiProvider,
    this.videoUrl,
  });
}

enum MessageType { user, bot }
