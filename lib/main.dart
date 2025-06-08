import 'package:ekmek_teknesi/helpers/notification_helper.dart';
import 'package:ekmek_teknesi/screens/main_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() async {
  // Flutter binding'lerinin hazır olduğundan emin ol
  WidgetsFlutterBinding.ensureInitialized();

  // Gerekli izinleri uygulamanın en başında iste
  await _requestInitialPermissions();

  // Zaman dilimi ve bildirim ayarları
  tz.initializeTimeZones();
  try {
    final String localTimezoneName = tz.local.name;
    tz.setLocalLocation(tz.getLocation(localTimezoneName));
  } catch (e) {
    // Hata durumunda konsola yazdır (isteğe bağlı)
    // print("Saat dilimi ayarlanamadı: $e");
  }

  // Bildirim ve tarih formatlama ayarları
  await NotificationHelper().init();
  await initializeDateFormatting('tr_TR', null);

  // Uygulamayı çalıştır
  runApp(const MyApp());
}

/// Uygulama başlangıcında gerekli izinleri kontrol eder ve ister.
Future<void> _requestInitialPermissions() async {
  // Depolama iznini kontrol et ve gerekirse iste.
  // Bu, özellikle eski Android sürümleri için ve dosya kaydetme özelliğinin
  // sorunsuz çalışması için önemlidir.
  if (await Permission.storage.isDenied) {
    await Permission.storage.request();
  }

  // Bildirim iznini kontrol et ve gerekirse iste (Android 13+ için zorunlu).
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ekmek Teknesi',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
      ],
      locale: const Locale('tr', 'TR'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.orange,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.orange.shade800,
          unselectedItemColor: Colors.grey.shade600,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: const MainScreen(),
    );
  }
}
