/// Notificación in-app para padres e hijos.
class AppNotification {
  final String id;
  final String userId;
  final String type; // link_request | link_accepted | coins_received
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id:        json['id']        as String,
      userId:    json['user_id']   as String,
      type:      json['type']      as String,
      title:     json['title']     as String,
      body:      json['body']      as String,
      data:      (json['data']     as Map<String, dynamic>?) ?? {},
      isRead:    json['is_read']   as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Emoji según el tipo de notificación.
  String get typeIcon => switch (type) {
    'link_request'   => '🔗',
    'link_accepted'  => '✅',
    'link_rejected'  => '❌',
    'coins_received' => '🪙',
    _                => '📢',
  };

  /// Cuánto tiempo hace (para mostrar "hace 5 min").
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1)   return 'ahora mismo';
    if (diff.inMinutes < 60)  return 'hace ${diff.inMinutes} min';
    if (diff.inHours   < 24)  return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} días';
  }
}
