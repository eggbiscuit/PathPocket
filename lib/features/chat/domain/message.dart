enum MessageRole { user, assistant }

enum MessageStatus { streaming, done, stopped, error }

enum Feedback { none, thumbsUp, thumbsDown }

class Citation {
  const Citation({
    required this.id,
    required this.title,
    required this.snippet,
    this.source,
    this.url,
  });

  final String id;
  final String title;
  final String snippet;
  final String? source;
  final String? url;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'snippet': snippet,
        if (source != null) 'source': source,
        if (url != null) 'url': url,
      };

  factory Citation.fromJson(Map<String, dynamic> json) => Citation(
        id: json['id'] as String,
        title: json['title'] as String,
        snippet: json['snippet'] as String,
        source: json['source'] as String?,
        url: json['url'] as String?,
      );
}

class ImageAttachment {
  const ImageAttachment({
    required this.id,
    required this.uri,
    this.mimeType,
    this.width,
    this.height,
    this.roi,
  });

  final String id;
  final String uri;
  final String? mimeType;
  final int? width;
  final int? height;
  final Map<String, double>? roi;

  Map<String, dynamic> toJson() => {
        'id': id,
        'uri': uri,
        if (mimeType != null) 'mimeType': mimeType,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (roi != null) 'roi': roi,
      };

  factory ImageAttachment.fromJson(Map<String, dynamic> json) =>
      ImageAttachment(
        id: json['id'] as String,
        uri: json['uri'] as String,
        mimeType: json['mimeType'] as String?,
        width: json['width'] as int?,
        height: json['height'] as int?,
        roi: (json['roi'] as Map?)?.map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ),
      );
}

class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.status = MessageStatus.done,
    this.images = const [],
    this.citations = const [],
    this.feedback = Feedback.none,
  });

  final String id;
  final String conversationId;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final MessageStatus status;
  final List<ImageAttachment> images;
  final List<Citation> citations;
  final Feedback feedback;

  bool get isStreaming => status == MessageStatus.streaming;
  bool get wasInterrupted =>
      status == MessageStatus.stopped || status == MessageStatus.error;

  Message copyWith({
    String? id,
    String? conversationId,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    MessageStatus? status,
    List<ImageAttachment>? images,
    List<Citation>? citations,
    Feedback? feedback,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      images: images ?? this.images,
      citations: citations ?? this.citations,
      feedback: feedback ?? this.feedback,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'role': role.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'status': status.name,
        'images': images.map((e) => e.toJson()).toList(),
        'citations': citations.map((e) => e.toJson()).toList(),
        'feedback': feedback.name,
      };

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String? ?? '',
      role: MessageRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => MessageRole.user,
      ),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: MessageStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => MessageStatus.done,
      ),
      images: (json['images'] as List? ?? [])
          .map((e) => ImageAttachment.fromJson(e as Map<String, dynamic>))
          .toList(),
      citations: (json['citations'] as List? ?? [])
          .map((e) => Citation.fromJson(e as Map<String, dynamic>))
          .toList(),
      feedback: Feedback.values.firstWhere(
        (f) => f.name == json['feedback'],
        orElse: () => Feedback.none,
      ),
    );
  }
}
