// notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

Future<void> scheduleReminderNotification(String title, DateTime eventDateTime) async {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  // Kalkulasi waktu 24 jam sebelumnya
  DateTime reminderTime = eventDateTime.subtract(const Duration(days: 1));

  // Log waktu untuk debugging
  print("Event time: ${eventDateTime.toString()}");
  print("Reminder time (24 jam sebelumnya): ${reminderTime.toString()}");

  try {
    print("Mencoba menjadwalkan notifikasi...");
    await _notificationsPlugin.zonedSchedule(
      0, // ID notifikasi
      title, // Judul notifikasi
      "$title is tomorrow! Prepare yourself!", // Pesan notifikasi
      tz.TZDateTime.from(reminderTime, tz.local), // Waktu notifikasi
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_id',
          'Reminder Notifications',
          channelDescription: 'Reminders for upcoming events',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    print("Notifikasi berhasil dijadwalkan untuk: $reminderTime");
  } catch (e) {
    print("Error scheduling reminder: $e");
    throw e;
  }
}

Future<void> scheduleToDoListNotification(String title, DateTime deadline) async {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  DateTime notificationTime;

  if (deadline.isAfter(DateTime.now().add(const Duration(days: 1)))) {
    // Deadline lebih dari 1 hari, notifikasi muncul H-1
    notificationTime = deadline.subtract(const Duration(days: 1));
  } else if (deadline.isAfter(DateTime.now())) {
    // Deadline tepat 1 hari dari sekarang, notifikasi muncul 12 jam sebelumnya
    notificationTime = DateTime.now().add(const Duration(hours: 12));
  } else {
    // Deadline sudah lewat atau kurang dari sekarang, tidak menjadwalkan notifikasi
    print("Deadline sudah terlewat atau terlalu dekat, notifikasi tidak dijadwalkan.");
    return;
  }

  try {
    await _notificationsPlugin.zonedSchedule(
      0, // ID notifikasi
      title, // Judul notifikasi
      "$title due soon. Do your task!!", // Pesan notifikasi
      tz.TZDateTime.from(notificationTime, tz.local), // Waktu notifikasi
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_id',
          'To-Do List Notifications',
          channelDescription: 'Notifications for to-do list reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    print("Notifikasi berhasil dijadwalkan untuk: $notificationTime");
  } catch (e) {
    print("Error scheduling notification: $e");
    throw e;
  }
}
