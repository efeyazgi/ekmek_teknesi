import 'package:shared_preferences/shared_preferences.dart';

class PreferencesHelper {
  static const String ekmekFiyatiKey = 'ekmek_fiyati';
  static const String unFiyatiKey = 'un_fiyati';
  static const String notificationsEnabledKey = 'notifications_enabled';
  static const String lowStockThresholdKey = 'low_stock_threshold';
  static const String reportHourKey = 'report_hour';
  static const String reportMinuteKey = 'report_minute';

  static Future<double> getEkmekFiyati() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(ekmekFiyatiKey) ?? 75.0;
  }

  static Future<void> setEkmekFiyati(double fiyat) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(ekmekFiyatiKey, fiyat);
  }

  static Future<double> getUnFiyati() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(unFiyatiKey) ?? 0.0;
  }

  static Future<void> setUnFiyati(double fiyat) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(unFiyatiKey, fiyat);
  }

  static Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(notificationsEnabledKey) ?? true;
  }

  static Future<void> setNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(notificationsEnabledKey, value);
  }

  static Future<int> getLowStockThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(lowStockThresholdKey) ?? 10;
  }

  static Future<void> setLowStockThreshold(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(lowStockThresholdKey, value);
  }

  static Future<Map<String, int>> getReportTime() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'hour': prefs.getInt(reportHourKey) ?? 9,
      'minute': prefs.getInt(reportMinuteKey) ?? 0
    };
  }

  static Future<void> setReportTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(reportHourKey, hour);
    await prefs.setInt(reportMinuteKey, minute);
  }
}
