class ConversationSummary {
  ConversationSummary({
    required this.id,
    required this.otherId,
    required this.otherName,
    this.otherAvatarUrl,
    this.lastPreview,
    required this.lastMessageAt,
  });

  final String id;
  final String otherId;
  final String otherName;
  final String? otherAvatarUrl;
  final String? lastPreview;
  final DateTime lastMessageAt;

  /// "Active" threads had a message in the last 30 days; older ones are listed under Past.
  bool get isActive => DateTime.now().difference(lastMessageAt).inDays < 30;

  factory ConversationSummary.fromMap(Map<String, dynamic> m) => ConversationSummary(
        id: m['id'] as String,
        otherId: m['other_id'] as String,
        otherName: (m['other_name'] as String?) ?? 'User',
        otherAvatarUrl: m['other_avatar_url'] as String?,
        lastPreview: m['last_message_preview'] as String?,
        lastMessageAt: DateTime.tryParse('${m['last_message_at']}')?.toLocal() ?? DateTime.now(),
      );
}

class ChatMessage {
  ChatMessage({required this.id, required this.senderId, required this.body, required this.createdAt});

  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id: m['id'] as String,
        senderId: m['sender_id'] as String,
        body: (m['body'] as String?) ?? '',
        createdAt: DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
      );
}

/// "3:05 pm", "Yesterday", or "12 Nov" depending on how old the time is.
String shortTime(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'am' : 'pm'}';
  }
  if (diff == 1) return 'Yesterday';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${t.day} ${m[t.month - 1]}';
}
