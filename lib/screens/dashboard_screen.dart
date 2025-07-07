import 'package:ekmek_teknesi/models/gider.dart';
import 'package:ekmek_teknesi/models/uretim_kaydi.dart';
import 'package:ekmek_teknesi/helpers/preferences_helper.dart';
import 'package:ekmek_teknesi/helpers/notification_helper.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'add_order_screen.dart';
import 'add_expense_screen.dart';
import '../helpers/db_helper.dart';
import '../models/siparis.dart';
import '../models/stok_hareketi.dart';
import 'package:intl/intl.dart';
import '../screens/stok_yonetimi_screen.dart';
import 'package:ekmek_teknesi/helpers/stok_helper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<Map<String, dynamic>>? _dashboardDataFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  void _loadData() {
    if (mounted) {
      setState(() {
        _dashboardDataFuture = _getDashboardData();
      });
    }
  }

  Future<Map<String, dynamic>> _getDashboardData() async {
    // Stokları merkezi helper'dan çek
    final stoklar = await StokHelper.calculateStock();

    // Diğer verileri çek
    final siparislerData = await DBHelper.getData('siparisler');
    final siparisler =
        siparislerData.map((item) => Siparis.fromMap(item)).toList();

    final giderlerData = await DBHelper.getData('giderler');
    final giderler = giderlerData.map((e) => Gider.fromMap(e)).toList();

    final guncelEkmekFiyati = await PreferencesHelper.getEkmekFiyati();

    final bugun = DateTime.now();
    final ayinIlkGunu = DateTime(bugun.year, bugun.month, 1);

    // Kart Verileri
    final bugunkuBekleyenSiparisler = siparisler
        .where((s) =>
            s.durum == SiparisDurum.Bekliyor &&
            _isSameDay(s.teslimTarihi, bugun))
        .toList();
    final bugunkuBekleyenAdet =
        bugunkuBekleyenSiparisler.fold(0, (t, s) => t + s.ekmekAdedi);

    final buAyTeslimEdilenler = siparisler
        .where((s) =>
            s.durum == SiparisDurum.TeslimEdildi &&
            !s.teslimTarihi.isBefore(ayinIlkGunu))
        .toList();
    final buAykiCiro = buAyTeslimEdilenler.fold(0.0, (t, s) => t + s.tutar);

    final buAykiGiderler = giderler
        .where((g) => !g.tarih.isBefore(ayinIlkGunu))
        .fold(0.0, (t, g) => t + g.tutar);

    return {
      'tazeStok': stoklar['tazeStok'] ?? 0,
      'dunkuStok': stoklar['dunkuStok'] ?? 0,
      'bugunkuSiparisSayisi': bugunkuBekleyenSiparisler.length,
      'bugunkuEkmekSayisi': bugunkuBekleyenAdet,
      'buAykiCiro': buAykiCiro,
      'buAykiGider': buAykiGiderler,
    };
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  void _uretimEkleDialogGoster() async {
    final controller = TextEditingController();
    final adet = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Taze Üretim Ekle'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Üretilen Ekmek Adedi'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            child: const Text('İptal'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: const Text('Ekle'),
            onPressed: () =>
                Navigator.of(ctx).pop(int.tryParse(controller.text)),
          ),
        ],
      ),
    );

    if (adet != null && adet > 0) {
      final yeniUretim = StokHareketi(
        tarih: DateTime.now(),
        adet: adet,
        tip: StokHareketiTipi.Uretim,
        ekmekTuru: EkmekTuru.Taze,
        aciklama: 'Ana ekrandan üretim eklendi',
      );
      await DBHelper.insert('stok_hareketleri', yeniUretim.toMap());
      _loadData();
    }
  }

  void _hizliSatisDialogGoster() async {
    final stoklar = await _getDashboardData();
    final tazeStok = stoklar['tazeStok'] ?? 0;
    final dunkuStok = stoklar['dunkuStok'] ?? 0;

    if (tazeStok <= 0 && dunkuStok <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Satılabilir stok yok!'),
            backgroundColor: Colors.red));
      }
      return;
    }

    final adetController = TextEditingController(text: '1');
    if (!mounted) return;

    final sonuc = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text("Hızlı Satış"),
            content: TextField(
                controller: adetController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration:
                    const InputDecoration(labelText: 'Satılan Ekmek Adedi')),
            actions: [
              TextButton(
                onPressed: tazeStok > 0
                    ? () => Navigator.of(ctx).pop({
                          'tur': EkmekTuru.Taze,
                          'adet': int.tryParse(adetController.text) ?? 1
                        })
                    : null,
                child: Text('Taze Ekmek ($tazeStok)'),
              ),
              TextButton(
                onPressed: dunkuStok > 0
                    ? () => Navigator.of(ctx).pop({
                          'tur': EkmekTuru.Dunku,
                          'adet': int.tryParse(adetController.text) ?? 1
                        })
                    : null,
                child: Text('Dünkü Ekmek ($dunkuStok)'),
              )
            ],
          );
        });

    if (sonuc != null) {
      final EkmekTuru secilenTur = sonuc['tur'];
      final int adet = sonuc['adet'];

      if (adet <= 0) return;

      final stokMiktari = secilenTur == EkmekTuru.Taze ? tazeStok : dunkuStok;
      if (adet > stokMiktari) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Stoktan fazla satış yapılamaz! ($stokMiktari adet mevcut)'),
              backgroundColor: Colors.red));
        }
        return;
      }

      final ekmekFiyati = await PreferencesHelper.getEkmekFiyati();
      final tutar = adet * ekmekFiyati;

      final hizliSatisSiparisi = Siparis(
        musteriAdi: 'Hızlı Satış',
        ekmekAdedi: adet,
        teslimTarihi: DateTime.now(),
        tutar: tutar,
        durum: SiparisDurum.TeslimEdildi,
        satilanEkmekTuru: secilenTur,
        odemeAlindiMi: true,
      );
      await DBHelper.insert('siparisler', hizliSatisSiparisi.toMap());

      final areNotificationsEnabled =
          await PreferencesHelper.getNotificationsEnabled();
      if (areNotificationsEnabled) {
        final threshold = await PreferencesHelper.getLowStockThreshold();
        if (secilenTur == EkmekTuru.Taze) {
          final yeniStok = tazeStok - adet;
          if (yeniStok < threshold && tazeStok >= threshold) {
            await NotificationHelper().showLowStockNotification(yeniStok);
          }
        }
      }
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Veri bulunamadı.'));
          }

          final data = snapshot.data!;
          final toplamStok =
              (data['tazeStok'] as int) + (data['dunkuStok'] as int);
          final netKar =
              (data['buAykiCiro'] as double) - (data['buAykiGider'] as double);

          return RefreshIndicator(
            onRefresh: () async => _loadData(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      SummaryCard(
                          icon: Icons.calendar_today,
                          title: 'Bekleyen Sipariş',
                          valueWidget: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('${data['bugunkuSiparisSayisi']} Sipariş',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        color: Colors.blue.shade800)),
                                Text('${data['bugunkuEkmekSayisi']} Ekmek',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        color: Colors.blue.shade800))
                              ]),
                          color: Colors.blue.shade100,
                          iconColor: Colors.blue.shade800),
                      SummaryCard(
                          icon: Icons.bakery_dining,
                          title: 'Satılabilir Stok',
                          value: '$toplamStok Adet',
                          color: Colors.brown.shade100,
                          iconColor: Colors.brown.shade800),
                      SummaryCard(
                          icon: Icons.trending_up,
                          title: 'Bu Ayki Ciro',
                          value:
                              '₺${(data['buAykiCiro'] as double).toStringAsFixed(0)}',
                          color: Colors.green.shade100,
                          iconColor: Colors.green.shade800),
                      SummaryCard(
                          icon: Icons.trending_down,
                          title: 'Bu Ayki Gider',
                          value:
                              '₺${(data['buAykiGider'] as double).toStringAsFixed(0)}',
                          color: Colors.red.shade100,
                          iconColor: Colors.red.shade800),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: netKar >= 0
                        ? Colors.teal.shade100
                        : Colors.red.shade200,
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(children: [
                        Text('BU AYKİ NET DURUM',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: netKar >= 0
                                    ? Colors.teal.shade900
                                    : Colors.red.shade900)),
                        const SizedBox(height: 8),
                        Text('₺${netKar.abs().toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: netKar >= 0
                                    ? Colors.teal.shade700
                                    : Colors.red.shade700)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ActionButton(
                      icon: Icons.add_circle_outline,
                      label: 'Yeni Sipariş Ekle',
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute(
                              builder: (c) => const AddOrderScreen()))
                          .then((_) => _loadData())),
                  const SizedBox(height: 12),
                  ActionButton(
                      icon: Icons.flash_on,
                      label: 'Hızlı Satış',
                      onPressed: _hizliSatisDialogGoster,
                      color: Colors.deepPurple),
                  const SizedBox(height: 12),
                  ActionButton(
                      icon: Icons.add_shopping_cart,
                      label: 'Yeni Üretim Ekle',
                      onPressed: _uretimEkleDialogGoster),
                  const SizedBox(height: 12),
                  ActionButton(
                      icon: Icons.receipt_long,
                      label: 'Yeni Gider Ekle',
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute(
                              builder: (c) => const AddExpenseScreen()))
                          .then((_) => _loadData())),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final Widget? valueWidget;
  final Color color;
  final Color iconColor;
  const SummaryCard({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.valueWidget,
    required this.color,
    required this.iconColor,
  }) : assert(value != null || valueWidget != null,
            'value veya valueWidget\'tan biri sağlanmalıdır.');
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: iconColor),
              const SizedBox(height: 8),
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                      fontSize: 14)),
              const SizedBox(height: 4),
              if (valueWidget != null)
                valueWidget!
              else
                Text(value!,
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: iconColor,
                        fontSize: 20)),
            ]),
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;
  const ActionButton(
      {super.key,
      required this.icon,
      required this.label,
      required this.onPressed,
      this.color});
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white),
      label: Text(label,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Colors.orange.shade700,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(double.infinity, 50)),
    );
  }
}
