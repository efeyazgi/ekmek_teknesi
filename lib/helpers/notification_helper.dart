import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationHelper {
  static final NotificationHelper _instance = NotificationHelper._internal();
  factory NotificationHelper() => _instance;
  NotificationHelper._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> showLowStockNotification(int stockCount) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'low_stock_channel', 'Düşük Stok Uyarıları',
        channelDescription:
            'Stok belirli bir seviyenin altına düştüğünde bildirim gönderir.',
        importance: Importance.max,
        priority: Priority.high);
    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(0, 'Düşük Stok Uyarısı!',
        'Taze ekmek stoğu azaldı. Kalan adet: $stockCount', platformDetails);
  }

  Future<void> scheduleDailyReportNotification(int hour, int minute) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
        1,
        'Günlük Raporunuz Hazır!',
        'Bir önceki günün satış, gider ve kâr özetini görüntülemek için dokunun.',
        _nextInstanceOf(hour, minute),
        const NotificationDetails(
            android: AndroidNotificationDetails(
                'daily_report_channel', 'Günlük Raporlar',
                channelDescription:
                    'Her gün belirli bir saatte rapor özeti gönderir.')),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time);
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
