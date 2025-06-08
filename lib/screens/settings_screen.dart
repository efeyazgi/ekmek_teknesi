import 'dart:io';
import 'dart:typed_data'; // YENİ EKLENDİ: Byte işlemleri için
import 'package:ekmek_teknesi/helpers/notification_helper.dart';
import 'package:ekmek_teknesi/helpers/preferences_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart'; // YENİ EKLENDİ: file_saver paketi
import '../helpers/db_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ekmekFiyatiController = TextEditingController();
  final _unFiyatiController = TextEditingController();
  final _stokEsikController = TextEditingController();

  bool _isLoading = true;
  bool _isFiyatExpanded = true;
  bool _isBildirimExpanded = false;
  bool _isVeriExpanded = false;

  bool _notificationsEnabled = true;
  TimeOfDay _reportTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _ayarlariYukle();
  }

  Future<void> _ayarlariYukle() async {
    setState(() => _isLoading = true);

    final ekmekFiyati = await PreferencesHelper.getEkmekFiyati();
    final unFiyati = await PreferencesHelper.getUnFiyati();
    final notificationsEnabled =
        await PreferencesHelper.getNotificationsEnabled();
    final stockThreshold = await PreferencesHelper.getLowStockThreshold();
    final reportTimeData = await PreferencesHelper.getReportTime();
    if (mounted) {
      _ekmekFiyatiController.text = ekmekFiyati.toString();
      _unFiyatiController.text = unFiyati.toString();
      _stokEsikController.text = stockThreshold.toString();
      _notificationsEnabled = notificationsEnabled;
      _reportTime = TimeOfDay(
          hour: reportTimeData['hour']!, minute: reportTimeData['minute']!);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _ayarlariKaydet() async {
    await PreferencesHelper.setEkmekFiyati(
        double.tryParse(_ekmekFiyatiController.text) ?? 75.0);
    await PreferencesHelper.setUnFiyati(
        double.tryParse(_unFiyatiController.text) ?? 0.0);
    await PreferencesHelper.setNotificationsEnabled(_notificationsEnabled);
    await PreferencesHelper.setLowStockThreshold(
        int.tryParse(_stokEsikController.text) ?? 10);
    await PreferencesHelper.setReportTime(_reportTime.hour, _reportTime.minute);

    await NotificationHelper().cancelAllNotifications();
    if (_notificationsEnabled) {
      await NotificationHelper().scheduleDailyReportNotification(
          _reportTime.hour, _reportTime.minute);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ayarlar başarıyla kaydedildi!'),
          backgroundColor: Colors.green));
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? newTime = await showTimePicker(
      context: context,
      initialTime: _reportTime,
      builder: (context, child) => Localizations.override(
          context: context, locale: const Locale('tr', 'TR'), child: child),
    );
    if (newTime != null) setState(() => _reportTime = newTime);
  }

  // --- BU METOT TAMAMEN GÜNCELLENDİ ---
  Future<void> _verileriDisaAktar() async {
    // Depolama izni hala eski Android sürümleri için istenebilir.
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }

    if (status.isGranted) {
      try {
        // 1. Yedeklenecek veritabanı dosyasının yolunu al ve byte olarak oku.
        final dbPath = await DBHelper.getDatabasePath();
        final dbFile = File(dbPath);
        final Uint8List fileBytes = await dbFile.readAsBytes();

        // 2. Yedek dosyası için bir isim oluştur.
        final timestamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
        final fileName = 'ekmek_teknemiz_yedek_$timestamp';

        // 3. file_saver kullanarak kullanıcıya "Farklı Kaydet" diyaloğunu göster.
        String? savedPath = await FileSaver.instance.saveFile(
          name: fileName,
          bytes: fileBytes,
          ext: 'db', // dosya uzantısı
          mimeType: MimeType.other, // dosya tipi
        );

        if (mounted) {
          if (savedPath != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'Yedekleme başarılı! Dosya şuraya kaydedildi: $savedPath'),
                duration: const Duration(seconds: 5)));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Yedekleme işlemi iptal edildi.'),
                backgroundColor: Colors.orange));
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Yedekleme başarısız: $e'),
              backgroundColor: Colors.red));
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Dosya kaydetmek için depolama izni verilmedi.'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _verileriIceAktar() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null) return;
      final yedekDosya = File(result.files.single.path!);
      await DBHelper.close();
      final dbPath = await DBHelper.getDatabasePath();
      await yedekDosya.copy(dbPath);
      if (mounted) {
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
                  title: const Text('Geri Yükleme Başarılı'),
                  content: const Text(
                      'Veriler başarıyla geri yüklendi. Değişikliklerin tam olarak yansıması için lütfen uygulamayı kapatıp yeniden açın.'),
                  actions: [
                    TextButton(
                        onPressed: () => SystemNavigator.pop(),
                        child: const Text('Uygulamayı Kapat'))
                  ],
                ));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Geri yükleme başarısız: $e'),
            backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _ekmekFiyatiController.dispose();
    _unFiyatiController.dispose();
    _stokEsikController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Scaffold(
            body: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
              child: Column(
                children: [
                  ExpansionPanelList(
                    elevation: 2,
                    expansionCallback: (int index, bool isExpanded) {
                      setState(() {
                        if (index == 0) _isFiyatExpanded = !_isFiyatExpanded;
                        if (index == 1)
                          _isBildirimExpanded = !_isBildirimExpanded;
                        if (index == 2) _isVeriExpanded = !_isVeriExpanded;
                      });
                    },
                    children: [
                      _buildFiyatPaneli(),
                      _buildBildirimPaneli(),
                      _buildVeriYonetimiPaneli(),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Center(
                      child: Text('Efe YAZGI tarafından geliştirilmiştir.',
                          style: Theme.of(context).textTheme.bodySmall)),
                ],
              ),
            ),
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Tüm Ayarları Kaydet'),
                onPressed: _ayarlariKaydet,
                style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
          );
  }

  ExpansionPanel _buildFiyatPaneli() {
    return ExpansionPanel(
      canTapOnHeader: true,
      headerBuilder: (BuildContext context, bool isExpanded) {
        return const ListTile(
            title: Text('Fiyat Ayarları',
                style: TextStyle(fontWeight: FontWeight.bold)));
      },
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
        child: Column(children: [
          TextField(
              controller: _ekmekFiyatiController,
              decoration: const InputDecoration(
                  labelText: 'Ekmek Satış Fiyatı (TL)',
                  border: OutlineInputBorder()),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 16),
          TextField(
              controller: _unFiyatiController,
              decoration: const InputDecoration(
                  labelText: 'Un Çuval Fiyatı (TL)',
                  border: OutlineInputBorder()),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true)),
        ]),
      ),
      isExpanded: _isFiyatExpanded,
    );
  }

  ExpansionPanel _buildBildirimPaneli() {
    return ExpansionPanel(
      canTapOnHeader: true,
      headerBuilder: (BuildContext context, bool isExpanded) {
        return const ListTile(
            title: Text('Bildirim Ayarları',
                style: TextStyle(fontWeight: FontWeight.bold)));
      },
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
        child: Column(children: [
          SwitchListTile(
              title: const Text('Bildirimler Aktif'),
              value: _notificationsEnabled,
              onChanged: (val) => setState(() => _notificationsEnabled = val)),
          const Divider(),
          TextField(
              controller: _stokEsikController,
              decoration: const InputDecoration(
                  labelText: 'Düşük Stok Eşiği (Adet)',
                  border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
          const SizedBox(height: 16),
          ListTile(
              title: const Text('Günlük Rapor Saati'),
              subtitle: Text(
                  'Her gün saat ${_reportTime.format(context)} itibarıyla.'),
              trailing: const Icon(Icons.edit),
              onTap: _selectTime,
              contentPadding: EdgeInsets.zero),
          const SizedBox(height: 8),
          Center(
              child: TextButton(
                  onPressed: () => NotificationHelper()
                      .showLowStockNotification(
                          int.tryParse(_stokEsikController.text) ?? 10),
                  child: const Text('Test Bildirimi Gönder'))),
        ]),
      ),
      isExpanded: _isBildirimExpanded,
    );
  }

  ExpansionPanel _buildVeriYonetimiPaneli() {
    return ExpansionPanel(
      canTapOnHeader: true,
      headerBuilder: (BuildContext context, bool isExpanded) {
        return const ListTile(
            title: Text('Veri Yönetimi',
                style: TextStyle(fontWeight: FontWeight.bold)));
      },
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
        child: Column(children: [
          ListTile(
              leading: const Icon(Icons.download_for_offline),
              title: const Text('Verileri Dışa Aktar (Yedekle)'),
              onTap: _verileriDisaAktar,
              contentPadding: EdgeInsets.zero),
          ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Verileri İçe Aktar (Geri Yükle)'),
              onTap: _verileriIceAktar,
              contentPadding: EdgeInsets.zero),
        ]),
      ),
      isExpanded: _isVeriExpanded,
    );
  }
}
