import 'dart:io';
import 'package:ekmek_teknesi/helpers/notification_helper.dart';
import 'package:ekmek_teknesi/helpers/preferences_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
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

  Future<void> _verileriDisaAktar() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yedek dosyası oluşturuluyor...')));
    }
    try {
      final dbPath = await DBHelper.getDatabasePath();
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final fileName = 'ekmek_teknemiz_yedek_$timestamp.db';

      final xFile = XFile(dbPath, name: fileName);
      await Share.shareXFiles([xFile], text: 'Ekmek Teknesi Veri Yedeği');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Yedekleme başarısız: $e'),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Geri yükleme başarısız: $e'),
            backgroundColor: Colors.red));
      }
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
            appBar: AppBar(
              title: const Text('Ayarlar'),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
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
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Hakkında'),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Hakkında'),
                          content: const Text(
                              'Bu uygulama Efe Yazgı tarafından geliştirilmiştir.\nİletişim: efeyazgi@yahoo.com'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Kapat'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Gizlilik Politikası'),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Gizlilik Politikası'),
                          content: const Text(
                              'Uygulama, müşteri adı ve telefon gibi verileri sadece cihazınızda saklar ve üçüncü şahıslarla paylaşmaz. Her türlü soru için efeyazgi@yahoo.com adresine ulaşabilirsiniz.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Kapat'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildTextFieldWithLabel(
              'Ekmek Satış Fiyatı (TL)', _ekmekFiyatiController,
              isDecimal: true),
          const SizedBox(height: 16),
          _buildTextFieldWithLabel('Un Çuval Fiyatı (TL)', _unFiyatiController,
              isDecimal: true),
        ]),
      ),
      isExpanded: _isFiyatExpanded,
    );
  }

  Widget _buildTextFieldWithLabel(
      String label, TextEditingController controller,
      {bool isDecimal = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          keyboardType: isDecimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          inputFormatters: isDecimal
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))]
              : [FilteringTextInputFormatter.digitsOnly],
        ),
      ],
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
          _buildTextFieldWithLabel(
              'Düşük Stok Eşiği (Adet)', _stokEsikController),
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
              leading: const Icon(Icons.ios_share),
              title: const Text('Verileri Dışa Aktar (Yedekle)'),
              onTap: _verileriDisaAktar,
              contentPadding: EdgeInsets.zero),
          ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: const Text('Verileri İçe Aktar (Geri Yükle)'),
              onTap: _verileriIceAktar,
              contentPadding: EdgeInsets.zero),
        ]),
      ),
      isExpanded: _isVeriExpanded,
    );
  }
}
