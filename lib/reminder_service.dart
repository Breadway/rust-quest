import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app_state.dart';

/// Daily reminder. Android schedules a repeating local notification; Linux
/// shows one from a timer while the app is open, because the plugin has no
/// scheduler on that platform.
class ReminderService {
  ReminderService(this.state);

  final AppState state;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Timer? _timer;
  bool _ready = false;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'rust_quest_daily',
      'Daily study reminder',
      channelDescription: 'A daily nudge to keep the streak going',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    linux: LinuxNotificationDetails(),
  );

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Keep the default location; scheduling still works with UTC.
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      linux: LinuxInitializationSettings(defaultActionName: 'Open Rust Quest'),
    );
    try {
      await _plugin.initialize(settings: settings);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
    if (Platform.isLinux) {
      _timer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _maybeShowDesktop(),
      );
    }
    await reschedule();
    _maybeShowDesktop();
  }

  Future<void> reschedule() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: 0);
      if (!state.remindersEnabled) return;
      if (!Platform.isAndroid) return;

      final parts = state.reminderTime.split(':');
      final hour = int.tryParse(parts.first) ?? 19;
      final minute = int.tryParse(parts.last) ?? 0;
      final now = tz.TZDateTime.now(tz.local);
      var next = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (!next.isAfter(now)) next = next.add(const Duration(days: 1));

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      await _plugin.zonedSchedule(
        id: 0,
        title: 'Rust Quest',
        body: "Time for today's questions",
        scheduledDate: next,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      // A missing permission or an unsupported host must not break the app.
    }
  }

  Future<void> _maybeShowDesktop() async {
    if (!_ready || !Platform.isLinux || !state.remindersEnabled) return;
    if (state.todayQuestions >= state.dailyGoal) return;
    final now = DateTime.now();
    final today = _day(now);
    if (state.lastReminderDay == today) return;
    final parts = state.reminderTime.split(':');
    final minutes =
        (int.tryParse(parts.first) ?? 19) * 60 +
        (int.tryParse(parts.last) ?? 0);
    if (now.hour * 60 + now.minute < minutes) return;
    try {
      await _plugin.show(
        id: 1,
        title: 'Rust Quest',
        body: "Time for today's questions",
        notificationDetails: _details,
      );
      await state.markReminderShown();
    } catch (_) {
      // Notification daemons can be absent; stay quiet.
    }
  }

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  void dispose() {
    _timer?.cancel();
  }
}
