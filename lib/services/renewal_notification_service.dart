import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/server.dart';

class RenewalNotificationService {
  RenewalNotificationService._();

  static final RenewalNotificationService instance =
      RenewalNotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (kIsWeb || _initialized) {
      return;
    }

    tz_data.initializeTimeZones();
    await _setLocalTimezone();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
      linux: LinuxInitializationSettings(defaultActionName: 'Open'),
    );

    await _notifications.initialize(settings: initializationSettings);
    await _requestPermissions();
    _initialized = true;
  }

  Future<void> syncServerReminders(List<ManagedServer> servers) async {
    if (kIsWeb) {
      return;
    }

    await initialize();
    await _cancelPendingReminders();

    for (final server in servers) {
      final notificationId = _notificationId(server.id);
      if (server.needsRenewalReminder) {
        await _scheduleDailyReminder(server, notificationId);
      }
    }
  }

  Future<void> cancelServerReminder(String serverId) async {
    if (kIsWeb) {
      return;
    }

    await initialize();
    await _notifications.cancel(id: _notificationId(serverId));
  }

  Future<void> _scheduleDailyReminder(
    ManagedServer server,
    int notificationId,
  ) async {
    final days = server.daysUntilRenewal;
    final title = days < 0
        ? '${server.name} renewal is overdue'
        : '${server.name} renewal due soon';
    final body = days < 0
        ? '${server.assignedClient} renewal was due ${days.abs()} day(s) ago.'
        : '${server.assignedClient} renewal is due in $days day(s).';

    await _notifications.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: _nextReminderTime(),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'server_renewals',
          'Server renewal reminders',
          channelDescription:
              'Daily reminders for servers due soon or overdue.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextReminderTime() {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      9,
    );

    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  Future<void> _requestPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _notifications
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> _cancelPendingReminders() async {
    try {
      await _notifications.cancelAllPendingNotifications();
    } catch (_) {
      return;
    }
  }

  Future<void> _setLocalTimezone() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  int _notificationId(String serverId) {
    return serverId.codeUnits.fold<int>(
      1000,
      (value, codeUnit) => (value * 31 + codeUnit) & 0x7fffffff,
    );
  }
}
