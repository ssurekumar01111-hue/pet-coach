import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class HydrationService extends GetxService {
  static const _enabledKey = 'hydration_reminders_enabled';
  static const _channelId = 'hydration_reminders';
  static const _channelName = 'Hydration reminders';
  static const _daytimeHours = <int>[7, 9, 11, 13, 15, 17, 19, 21];

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final isEnabled = false.obs;
  late SharedPreferences _preferences;

  Future<HydrationService> init() async {
    tz_data.initializeTimeZones();
    final timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
    _preferences = await SharedPreferences.getInstance();
    await _notifications.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ));
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Helpful daytime reminders to drink water.',
      importance: Importance.defaultImportance,
    );
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    isEnabled.value = _preferences.getBool(_enabledKey) ?? false;
    if (isEnabled.value) await _scheduleDaytimeReminders();
    return this;
  }

  Future<bool> setEnabled(bool enabled) async {
    if (enabled && !await _requestPermission()) return false;
    isEnabled.value = enabled;
    await _preferences.setBool(_enabledKey, enabled);
    if (enabled) {
      await _scheduleDaytimeReminders();
    } else {
      await _notifications.cancelAll();
    }
    return true;
  }

  Future<void> notifyRunCompleted() async {
    if (!isEnabled.value) return;
    await _notifications.show(
      9001,
      'Great run!',
      'Remember to rehydrate.',
      _notificationDetails,
    );
  }

  Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      final granted = await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      return granted ?? true;
    }
    if (Platform.isIOS) {
      final granted = await _notifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return false;
  }

  Future<void> _scheduleDaytimeReminders() async {
    await _notifications.cancelAll();
    final now = tz.TZDateTime.now(tz.local);
    for (final hour in _daytimeHours) {
      var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
      if (!scheduled.isAfter(now)) scheduled = scheduled.add(const Duration(days: 1));
      await _notifications.zonedSchedule(
        hour,
        'Time to hydrate!',
        'Stay ready for your next PET session.',
        scheduled,
        _notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Helpful daytime reminders to drink water.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );
}
