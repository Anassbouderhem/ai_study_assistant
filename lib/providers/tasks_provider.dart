import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/task_item.dart';
import '../services/notification_service.dart';

class TasksProvider with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _notif = NotificationService();

  Stream<List<TaskItem>> streamTasks(String userId) {
    return _db
        .collection('tasks')
        .where('userId', isEqualTo: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(TaskItem.fromDoc).toList());
  }

  Future<void> addTask({
    required String userId,
    required String title,
    required String description,
    required int priority,
    DateTime? reminderAt,
  }) async {
    final now = DateTime.now();
    final ref = await _db.collection('tasks').add({
      'userId': userId,
      'title': title,
      'description': description,
      'priority': priority,
      'isDone': false,
      'completedAt': null,
      'reminderAt': reminderAt != null ? Timestamp.fromDate(reminderAt) : null,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    // Programmer la notification de rappel
    if (reminderAt != null && reminderAt.isAfter(now)) {
      final notifId = NotificationService.idFromString(ref.id);
      await _db.collection('tasks').doc(ref.id).update({
        'notificationId': notifId,
      });
      await _notif.scheduleAt(
        id: notifId,
        title: '⏰ Rappel : $title',
        body: description.isNotEmpty
            ? description
            : 'Votre tâche vous attend !',
        scheduledTime: reminderAt,
      );
    }
  }

  Future<void> updateTask({
    required String taskId,
    required String title,
    required String description,
    required int priority,
    DateTime? reminderAt,
    int? oldNotificationId,
  }) async {
    // Annuler l'ancienne notification si elle existait
    if (oldNotificationId != null) {
      await _notif.cancel(oldNotificationId);
    }

    int? newNotifId;
    if (reminderAt != null && reminderAt.isAfter(DateTime.now())) {
      newNotifId = NotificationService.idFromString(taskId);
      await _notif.scheduleAt(
        id: newNotifId,
        title: '⏰ Rappel : $title',
        body: description.isNotEmpty
            ? description
            : 'Votre tâche vous attend !',
        scheduledTime: reminderAt,
      );
    }

    await _db.collection('tasks').doc(taskId).update({
      'title': title,
      'description': description,
      'priority': priority,
      'reminderAt': reminderAt != null ? Timestamp.fromDate(reminderAt) : null,
      'notificationId': newNotifId,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> toggleDone({
    required String taskId,
    required bool isDone,
  }) async {
    final docRef = _db.collection('tasks').doc(taskId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) return;
    final data = snapshot.data()!;

    final title = (data['title'] as String?) ?? '';
    final notificationId = data['notificationId'] as int?;

    await docRef.update({
      'isDone': isDone,
      'completedAt': isDone ? Timestamp.fromDate(DateTime.now()) : null,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    if (isDone) {
      if (notificationId != null) {
        await _notif.cancel(notificationId);
      }
      await _notif.showInstant(
        id: NotificationService.idFromString('done_$taskId'),
        title: '✅ Tâche terminée !',
        body: '"$title" a été marquée comme complétée. Bravo !',
      );
    }
  }

  Future<void> deleteTask(String taskId, {int? notificationId}) async {
    if (notificationId != null) {
      await _notif.cancel(notificationId);
    }
    await _db.collection('tasks').doc(taskId).delete();
  }
}
