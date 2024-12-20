import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'kalender_page.dart';
import 'todo_list.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings androidInitSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings =
      InitializationSettings(android: androidInitSettings);

  await notificationsPlugin.initialize(initSettings);

  tz.initializeTimeZones();
  runApp(MyApp(notificationsPlugin: notificationsPlugin));
}

class MyApp extends StatefulWidget {
  final FlutterLocalNotificationsPlugin notificationsPlugin;
  const MyApp({super.key, required this.notificationsPlugin});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _checkNotificationPermission();
    _checkExactAlarmPermission();
    _initializeApp();
    _initializeNotifications();
    _loadThemePreference();
  }

  Future<void> _initializeApp() async {
    if (Platform.isAndroid && Platform.version.contains("12")) {
      final permissionStatus = await Permission.scheduleExactAlarm.status;
      if (permissionStatus.isDenied) {
        _showPermissionDialog(
          "Izin Exact Alarm Dibutuhkan",
          "Aplikasi memerlukan izin Exact Alarm agar fitur dapat berjalan dengan baik.",
        ); // Tampilkan dialog izin
      }
    }
  }

  Future<void> _checkExactAlarmPermission() async {
    print("Memeriksa izin Exact Alarm...");
    if (Platform.isAndroid && Platform.version.contains("12")) {
      final permissionStatus = await Permission.scheduleExactAlarm.status;

      print("Status izin Exact Alarm: $permissionStatus");

      if (permissionStatus.isDenied || permissionStatus.isPermanentlyDenied) {
        print("Izin Exact Alarm ditolak.");
        // Tampilkan dialog untuk meminta pengguna membuka pengaturan
        _showPermissionDialog("Izin Exact Alarm",
            "Aplikasi memerlukan izin Exact Alarm untuk menjadwalkan notifikasi.");
      } else {
        print("Exact Alarm tidak diperlukan di platform ini.");
      }
    } else {
      print("Exact Alarm tidak diperlukan di platform ini.");
    }
  }

  void _showPermissionDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings(); // Buka pengaturan aplikasi
            },
            child: const Text("Pengaturan"),
          ),
        ],
      ),
    );
  }

  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      final result = await Permission.notification.request();
      if (result.isGranted) {
        print("Izin notifikasi diberikan.");
      } else {
        print("Izin notifikasi ditolak.");
      }
    } else if (status.isPermanentlyDenied) {
      _showPermissionDialog(
        "Izin Notifikasi Dibutuhkan",
        "Aplikasi memerlukan izin notifikasi agar fitur dapat berfungsi dengan baik.",
      );
    }
  }


  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: androidInitializationSettings);

    final bool? initialized =
        await _notificationsPlugin.initialize(initializationSettings);

    print("Notification plugin initialized: $initialized");
    tz.initializeTimeZones();
  }

  Future<void> _showNotification(
      String title, String body, DateTime dateTime) async {
    try {
      await _notificationsPlugin.zonedSchedule(
        0,
        title,
        body,
        tz.TZDateTime.from(dateTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'channel_id',
            'channel_name',
            channelDescription: 'Notification channel for calendar app',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      print("Error scheduling notification: $e");
    }
  }


  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool('isDarkMode') ?? false;
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
    prefs.setBool('isDarkMode', _themeMode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kalender Event',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          // backgroundColor: Colors.white, // Warna untuk light mode
          foregroundColor: Colors.black, // Teks dan ikon untuk light mode
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black, // Warna untuk dark mode
          foregroundColor: Colors.white, // Teks dan ikon untuk dark mode
        ),
      ),
      themeMode: _themeMode,
      home: KalenderPage(onToggleTheme: _toggleTheme, notificationsPlugin: widget.notificationsPlugin),
      routes: {
        '/todo': (context) => ToDoListPage(
          notificationsPlugin: _notificationsPlugin,
        ),
      },
    );
  }
}
