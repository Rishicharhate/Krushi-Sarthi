/// Notification item model.
class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String category; // 'Soil Alerts', 'Environmental Alerts', etc.
  final DateTime timestamp;
  final bool isRead;
  final String? icon;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.timestamp,
    this.isRead = false,
    this.icon,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      category: json['category'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['is_read'] as bool? ?? false,
      icon: json['icon'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'category': category,
    'timestamp': timestamp.toIso8601String(),
    'is_read': isRead,
    'icon': icon,
  };

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      title: title,
      message: message,
      category: category,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      icon: icon,
    );
  }
}
