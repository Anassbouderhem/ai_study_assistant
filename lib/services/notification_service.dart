import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Canaux Android
  static const _channelGeneral = AndroidNotificationDetails(
    'general',
    'Général',
    channelDescription: 'Notifications générales de l\'application',
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_notification',
  );

  static const _channelReminders = AndroidNotificationDetails(
    'reminders',
    'Rappels de tâches',
    channelDescription: 'Rappels pour vos tâches planifiées',
    importance: Importance.max,
    priority: Priority.high,
    icon: 'ic_notification',
  );

  static const _channelDaily = AndroidNotificationDetails(
    'daily_reminder',
    'Rappel quotidien',
    channelDescription: 'Rappel quotidien pour réviser vos études',
    importance: Importance.high,
    priority: Priority.defaultPriority,
    icon: 'ic_notification',
  );

  Future<void> init() async {
    if (_initialized) return;

    // The flutter_local_notifications plugin is not supported on web. Skip
    // initialization when running in a browser so the app can start normally.
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (_) {},
    );

    // Demander la permission sur Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Notification immédiate
  Future<void> showInstant({
    required int id,
    required String title,
    required String body,
    bool isReminder = false,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: isReminder ? _channelReminders : _channelGeneral,
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  /// Notification programmée à une date/heure précise
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    if (kIsWeb) return;
    if (scheduledTime.isBefore(DateTime.now())) return;
    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      const NotificationDetails(
        android: _channelReminders,
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Rappel quotidien récurrent
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) return;
    await _plugin.zonedSchedule(
      9999,
      '📚 Heure de révision !',
      'N\'oubliez pas de consulter vos tâches et notes du jour.',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: _channelDaily,
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // Backward-compatible API used by providers/services.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) {
    return showInstant(id: id, title: title, body: body, payload: payload);
  }

  // Backward-compatible API used by providers/services.
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) {
    return scheduleAt(
      id: id,
      title: title,
      body: body,
      scheduledTime: scheduledDate,
      payload: payload,
    );
  }

  /// Annuler une notification par son ID
  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }

  Future<void> cancelDailyReminder() async {
    if (kIsWeb) return;
    await _plugin.cancel(9999);
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Générer un ID unique depuis un taskId string
  static int idFromString(String s) => s.hashCode.abs() % 100000;
}
