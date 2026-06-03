enum MessageRole { user, assistant }

class Message {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;

  const Message({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  Message copyWith({
    String? id,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
  }) {
    return Message(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      role: MessageRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => MessageRole.user,
      ),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
