/// Presentation-independent conversation transcript for a chat-style UI.
/// The designer may animate messages without influencing game simulation.
enum ChatRole { player, world, npc, system }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.day,
    required this.role,
    required this.text,
    this.speaker,
    this.sourceEventId,
  });

  final String id;
  final int day;
  final ChatRole role;
  final String text;
  final String? speaker;
  final String? sourceEventId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'day': day,
        'role': role.name,
        'text': text,
        'speaker': speaker,
        'sourceEventId': sourceEventId,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String? ?? 'unknown',
        day: (json['day'] as num?)?.toInt() ?? 1,
        role: ChatRole.values.firstWhere(
          (role) => role.name == json['role'],
          orElse: () => ChatRole.system,
        ),
        text: json['text'] as String? ?? '',
        speaker: json['speaker'] as String?,
        sourceEventId: json['sourceEventId'] as String?,
      );
}
