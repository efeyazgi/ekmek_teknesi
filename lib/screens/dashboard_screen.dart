import 'package:ekmek_teknesi/models/gider.dart';
import 'package:ekmek_teknesi/models/uretim_kaydi.dart';
import 'package:ekmek_teknesi/helpers/preferences_helper.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'add_order_screen.dart';
import 'add_expense_screen.dart';
import '../helpers/db_helper.dart';
import '../models/siparis.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, dynamic>> _dashboardDataFuture;
  @override
  void initState() {
    super.initState();
    _verileriYenile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _verileriYenile();
  }

  void _verileriYenile() {
    if (mounted) {
      setState(() {
        _dashboardDataFuture = _verileriHesapla();
      });
    }
  }

  Future<Map<String, dynamic>> _verileriHesapla() async {
    final futures = [
      DBHelper.getData('siparisler'),
      DBHelper.getData('uretim_kayitlari'),
      DBHelper.getData('giderler'),
      PreferencesHelper.getEkmekFiyati()
    ];
    final List<Object> results = await Future.wait(futures);

    final siparisler =
        (results[0] as List).map((item) => Siparis.fromMap(item)).toList();
    final uretimler =
        (results[1] as List).map((item) => UretimKaydi.fromMap(item)).toList();
    final giderler =
        (results[2] as List).map((item) => Gider.fromMap(item)).toList();
    final guncelEkmekFiyati = results[3] as double;

    final bugun = DateTime.now();
    final ayinIlkGunu = DateTime(bugun.year, bugun.month, 1);
    final sonrakiAyinIlkGunu = (bugun.month == 12)
        ? DateTime(bugun.year + 1, 1, 1)
        : DateTime(bugun.year, bugun.month + 1, 1);

    final bugunkuBekleyenSiparisler = siparisler
        .where((s) =>
            s.durum == SiparisDurum.Bekliyor &&
            s.teslimTarihi.year == bugun.year &&
            s.teslimTarihi.month == bugun.month &&
            s.teslimTarihi.day == bugun.day)
        .toList();
    final bugunkuBekleyenAdet =
        bugunkuBekleyenSiparisler.fold(0, (prev, s) => prev + s.ekmekAdedi);

    final buAykiSiparisler = siparisler
        .where((s) =>
            !s.teslimTarihi.isBefore(ayinIlkGunu) &&
            s.teslimTarihi.isBefore(sonrakiAyinIlkGunu))
        .toList();
    final buAykiTahsilatlar = buAykiSiparisler
        .where((s) => s.odemeAlindiMi || s.durum == SiparisDurum.TeslimEdildi)
        .toList();
    final buAykiCiro = buAykiTahsilatlar.fold(
        0.0, (prev, s) => prev + (s.ekmekAdedi * guncelEkmekFiyati));

    final buAykiGiderler = giderler
        .where((g) =>
            !g.tarih.isBefore(ayinIlkGunu) &&
            g.tarih.isBefore(sonrakiAyinIlkGunu))
        .toList();
    final buAykiGider = buAykiGiderler.fold(0.0, (prev, g) => prev + g.tutar);

    final toplamUretim = uretimler.fold(0, (prev, u) => prev + u.adet);
    final toplamTeslimEdilen = siparisler
        .where((s) => s.durum == SiparisDurum.TeslimEdildi)
        .fold(0, (prev, s) => prev + s.ekmekAdedi);
    final toplamBekleyen = siparisler
        .where((s) => s.durum == SiparisDurum.Bekliyor)
        .fold(0, (prev, s) => prev + s.ekmekAdedi);
    final mevcutStok = toplamUretim - toplamTeslimEdilen - toplamBekleyen;

    return {
      'bugunkuSiparisSayisi': bugunkuBekleyenSiparisler.length,
      'bugunkuEkmekSayisi': bugunkuBekleyenAdet,
      'buAykiCiro': buAykiCiro,
      'buAykiGider': buAykiGider,
      'mevcutStok': mevcutStok > 0 ? mevcutStok : 0
    };
  }

  void _yeniSiparisEklemeSayfasiniAc() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (c) => const AddOrderScreen()))
      .then((_) => _verileriYenile());

  void _uretimGirDialogGoster() {/* ... */}

  void _yeniGiderEklemeSayfasiniAc() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (c) => const AddExpenseScreen()))
      .then((_) => _verileriYenile());

  void _hizliSatisDialogGoster() async {
    final data = await _verileriHesapla();
    final mevcutStok = data['mevcutStok'] as int;
    if (mevcutStok <= 0) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Satılabilir stok yok! Lütfen üretim girin.'),
            backgroundColor: Colors.red));
      return;
    }
    final adetController = TextEditingController(text: '1');
    if (!mounted) return;
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Hızlı Satış'),
              content: TextField(
                  controller: adetController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                      labelText: 'Satılan Ekmek Adedi (Max: $mevcutStok)')),
              actions: [
                TextButton(
                    child: const Text('İptal'),
                    onPressed: () => Navigator.of(ctx).pop()),
                ElevatedButton(
                    child: const Text('Sat'),
                    onPressed: () async {
                      final adet = int.tryParse(adetController.text);
                      if (adet == null || adet <= 0) return;
                      if (adet > mevcutStok) return;
                      final hizliSatisSiparisi = Siparis(
                          id: const Uuid().v4(),
                          musteriAdi: 'Hızlı Satış',
                          ekmekAdedi: adet,
                          teslimTarihi: DateTime.now(),
                          odemeAlindiMi: true,
                          durum: SiparisDurum.TeslimEdildi,
                          satilanEkmekTuru: EkmekTuru.Taze);
                      await DBHelper.insert(
                          'siparisler', hizliSatisSiparisi.toMap());
                      if (mounted) Navigator.of(ctx).pop();
                      _verileriYenile();
                    }),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(child: Text('Hata: ${snapshot.error}'));
        if (!snapshot.hasData)
          return const Center(child: Text('Veri bulunamadı.'));
        final data = snapshot.data!;
        final netKar =
            (data['buAykiCiro'] as double) - (data['buAykiGider'] as double);
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
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
                          value: '${data['mevcutStok']} Adet',
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
                      onPressed: _yeniSiparisEklemeSayfasiniAc),
                  const SizedBox(height: 12),
                  ActionButton(
                      icon: Icons.flash_on,
                      label: 'Hızlı Satış',
                      onPressed: _hizliSatisDialogGoster,
                      color: Colors.deepPurple),
                  const SizedBox(height: 12),
                  ActionButton(
                      icon: Icons.add_shopping_cart,
                      label: 'Bugünkü Üretimi Gir',
                      onPressed: _uretimGirDialogGoster),
                  const SizedBox(height: 12),
                  ActionButton(
                      icon: Icons.receipt_long,
                      label: 'Yeni Gider Ekle',
                      onPressed: _yeniGiderEklemeSayfasiniAc),
                ]),
          ),
        );
      },
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
