import 'package:cloud_firestore/cloud_firestore.dart';

class TaskItem {
  final String id;
  final String userId;
  final String title;
  final String description;
  final int priority;
  final bool isDone;
  final DateTime? completedAt;
  final DateTime? reminderAt;
  final int? notificationId;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.priority,
    required this.isDone,
    this.completedAt,
    this.reminderAt,
    this.notificationId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskItem.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TaskItem(
      id: doc.id,
      userId: (data['userId'] ?? '') as String,
      title: (data['title'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      priority: (data['priority'] ?? 1) as int,
      isDone: (data['isDone'] ?? false) as bool,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      reminderAt: (data['reminderAt'] as Timestamp?)?.toDate(),
      notificationId: (data['notificationId'] as int?),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'priority': priority,
      'isDone': isDone,
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt!),
      'reminderAt': reminderAt == null ? null : Timestamp.fromDate(reminderAt!),
      'notificationId': notificationId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
