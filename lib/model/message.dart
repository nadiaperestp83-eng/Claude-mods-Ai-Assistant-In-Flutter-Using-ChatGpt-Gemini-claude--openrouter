class Message {
  String msg;
  final MessageType msgType;
  final String? aiProvider;
  final String? videoUrl;
  final String? imageBase64;

  Message({
    required this.msg,
    required this.msgType,
    this.aiProvider,
    this.videoUrl,
    this.imageBase64,
  });
}

enum MessageType { user, bot }
