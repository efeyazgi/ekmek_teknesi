import 'package:ekmek_teknesi/models/uretim_kaydi.dart';
import 'package:ekmek_teknesi/screens/add_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../helpers/db_helper.dart';
import '../models/siparis.dart';
import '../helpers/notification_helper.dart';
import '../helpers/preferences_helper.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});
  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Future<List<Siparis>>? _siparislerFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Sekme değiştirildiğinde setState çağırarak TabBar'daki sayacın güncellenmesini sağlar.
    _tabController.addListener(() {
      if (mounted && _tabController.indexIsChanging) {
        _listeyiYenile();
      } else if (mounted) {
        setState(() {});
      }
    });
    _listeyiYenile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Bu ekran her görünür olduğunda (örneğin başka bir sekmeden geri dönüldüğünde)
  // listenin güncel kalmasını sağlar.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listeyiYenile();
  }

  void _listeyiYenile() {
    if (mounted) {
      setState(() {
        _siparislerFuture = _verileriCek();
      });
    }
  }

  Future<List<Siparis>> _verileriCek() async {
    final dataList = await DBHelper.getData('siparisler');
    return dataList.map((item) => Siparis.fromMap(item)).toList()
      ..sort((a, b) => b.teslimTarihi.compareTo(a.teslimTarihi));
  }

  void _yeniSiparisEkle() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (ctx) => const AddOrderScreen()))
        .then((_) => _listeyiYenile());
  }

  Future<void> _siparisDurumunuGuncelle(Siparis siparis) async {
    // Stok ve ayar verilerini çek
    final futures = [
      DBHelper.getData('siparisler'),
      DBHelper.getData('uretim_kayitlari'),
      PreferencesHelper.getNotificationsEnabled(),
      PreferencesHelper.getLowStockThreshold(),
    ];
    final results = await Future.wait(futures);

    final siparisler =
        (results[0] as List).map((item) => Siparis.fromMap(item)).toList();
    final uretimler =
        (results[1] as List).map((item) => UretimKaydi.fromMap(item)).toList();
    final areNotificationsEnabled = results[2] as bool;
    final threshold = results[3] as int;

    // Stokları hesapla
    final bugun = DateTime.now();
    final dun = bugun.subtract(const Duration(days: 1));

    final bugunUretilen = uretimler
        .where((u) =>
            u.tarih.year == bugun.year &&
            u.tarih.month == bugun.month &&
            u.tarih.day == bugun.day)
        .fold(0, (t, u) => t + u.adet);
    final dunUretilen = uretimler
        .where((u) =>
            u.tarih.year == dun.year &&
            u.tarih.month == dun.month &&
            u.tarih.day == dun.day)
        .fold(0, (t, u) => t + u.adet);

    final teslimEdilenler =
        siparisler.where((s) => s.durum == SiparisDurum.TeslimEdildi).toList();

    final bugunTazeSatilan = teslimEdilenler
        .where((s) =>
            s.satilanEkmekTuru == EkmekTuru.Taze &&
            s.teslimTarihi.year == bugun.year &&
            s.teslimTarihi.month == bugun.month &&
            s.teslimTarihi.day == bugun.day)
        .fold(0, (t, s) => t + s.ekmekAdedi);
    final dunTazeSatilan = teslimEdilenler
        .where((s) =>
            s.satilanEkmekTuru == EkmekTuru.Taze &&
            s.teslimTarihi.year == dun.year &&
            s.teslimTarihi.month == dun.month &&
            s.teslimTarihi.day == dun.day)
        .fold(0, (t, s) => t + s.ekmekAdedi);

    final duneDevreden = dunUretilen - dunTazeSatilan;

    final bugunDunkuSatilan = teslimEdilenler
        .where((s) =>
            s.satilanEkmekTuru == EkmekTuru.Dunku &&
            s.teslimTarihi.year == bugun.year &&
            s.teslimTarihi.month == bugun.month &&
            s.teslimTarihi.day == bugun.day)
        .fold(0, (t, s) => t + s.ekmekAdedi);

    final tazeStok = bugunUretilen - bugunTazeSatilan;
    final dunkuStok = duneDevreden - bugunDunkuSatilan;

    if (!mounted) return;

    EkmekTuru? secilenTur = await showDialog<EkmekTuru>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Teslim Edilen Ekmek Türü'),
        content: const Text('Bu siparişte hangi tür ekmek teslim edildi?'),
        actions: [
          TextButton(
              onPressed: tazeStok >= siparis.ekmekAdedi
                  ? () => Navigator.of(ctx).pop(EkmekTuru.Taze)
                  : null,
              child: Text('Taze Ekmek (${tazeStok > 0 ? tazeStok : 0} Adet)')),
          TextButton(
              onPressed: dunkuStok >= siparis.ekmekAdedi
                  ? () => Navigator.of(ctx).pop(EkmekTuru.Dunku)
                  : null,
              child:
                  Text('Dünkü Ekmek (${dunkuStok > 0 ? dunkuStok : 0} Adet)')),
        ],
      ),
    );

    if (secilenTur == null) return;

    final Map<String, Object?> guncellenecekVeri = {
      'durum': SiparisDurum.TeslimEdildi.name,
      'satilanEkmekTuru': secilenTur.name
    };
    if (!siparis.odemeAlindiMi) {
      guncellenecekVeri['odemeAlindiMi'] = 1;
    }

    await DBHelper.update('siparisler', siparis.id, guncellenecekVeri);

    if (areNotificationsEnabled) {
      final yeniTazeStok =
          tazeStok - (secilenTur == EkmekTuru.Taze ? siparis.ekmekAdedi : 0);
      if (yeniTazeStok < threshold && tazeStok >= threshold) {
        await NotificationHelper().showLowStockNotification(yeniTazeStok);
      }
    }
    _listeyiYenile();
  }

  void _siparisDuzenle(Siparis siparis) {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (ctx) => AddOrderScreen(siparis: siparis)))
        .then((_) => _listeyiYenile());
  }

  Future<void> _siparisSil(String id) async {
    await DBHelper.delete('siparisler', id);
    _listeyiYenile();
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sipariş silindi.'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: FutureBuilder<List<Siparis>>(
          future: _siparislerFuture,
          builder: (context, snapshot) {
            int bekleyenSayisi = 0;
            if (snapshot.hasData) {
              final bugun = DateTime.now();
              bekleyenSayisi = snapshot.data!
                  .where((s) =>
                      s.durum == SiparisDurum.Bekliyor &&
                      s.teslimTarihi.year == bugun.year &&
                      s.teslimTarihi.month == bugun.month &&
                      s.teslimTarihi.day == bugun.day)
                  .length;
            }
            return TabBar(
              controller: _tabController,
              tabs: [
                Tab(child: Text('BUGÜN BEKLEYENLER ($bekleyenSayisi)')),
                const Tab(text: 'GEÇMİŞ SİPARİŞLER'),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: _yeniSiparisEkle,
          heroTag: 'siparis-ekle-fab',
          child: const Icon(Icons.add)),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSiparisListesi(SiparisDurum.Bekliyor),
          _buildSiparisListesi(SiparisDurum.TeslimEdildi),
        ],
      ),
    );
  }

  Widget _buildSiparisListesi(SiparisDurum durum) {
    return FutureBuilder<List<Siparis>>(
      future: _siparislerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(child: Text('Hata: ${snapshot.error}'));

        List<Siparis> filtrelenmisSiparisler;
        String emptyMessage;

        if (durum == SiparisDurum.Bekliyor) {
          final bugun = DateTime.now();
          filtrelenmisSiparisler = snapshot.data
                  ?.where((s) =>
                      s.durum == SiparisDurum.Bekliyor &&
                      s.teslimTarihi.year == bugun.year &&
                      s.teslimTarihi.month == bugun.month &&
                      s.teslimTarihi.day == bugun.day)
                  .toList() ??
              [];
          emptyMessage = 'Bugün için bekleyen sipariş yok.';
        } else {
          filtrelenmisSiparisler = snapshot.data
                  ?.where((s) => s.durum == SiparisDurum.TeslimEdildi)
                  .toList() ??
              [];
          emptyMessage = 'Henüz teslim edilen sipariş yok.';
        }

        if (filtrelenmisSiparisler.isEmpty) {
          return Center(
              child: Text(emptyMessage,
                  style: const TextStyle(fontSize: 18, color: Colors.grey)));
        }

        return ListView.builder(
          itemCount: filtrelenmisSiparisler.length,
          itemBuilder: (ctx, index) {
            final siparis = filtrelenmisSiparisler[index];
            return Dismissible(
              key: ValueKey(siparis.id),
              background: Container(
                  color: Theme.of(context).colorScheme.error,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child:
                      const Icon(Icons.delete, color: Colors.white, size: 30)),
              direction: DismissDirection.endToStart,
              confirmDismiss: (direction) => showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                          title: const Text('Emin misiniz?'),
                          content: const Text(
                              'Bu siparişi kalıcı olarak silmek istediğinizden emin misiniz?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Hayır')),
                            TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Evet, Sil'))
                          ])),
              onDismissed: (direction) => _siparisSil(siparis.id),
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 4,
                child: ListTile(
                  onTap: () => _siparisDuzenle(siparis),
                  title: Text(
                      '${siparis.musteriAdi} - ${siparis.ekmekAdedi} Adet',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      'Teslim: ${DateFormat.yMMMMd('tr_TR').format(siparis.teslimTarihi)}'),
                  trailing: durum == SiparisDurum.Bekliyor
                      ? IconButton(
                          icon: const Icon(Icons.check_circle_outline,
                              color: Colors.green, size: 30),
                          tooltip: 'Teslim Edildi Olarak İşaretle',
                          onPressed: () => _siparisDurumunuGuncelle(siparis))
                      : (siparis.odemeAlindiMi
                          ? Icon(Icons.check_circle,
                              color: Colors.green.shade700)
                          : Icon(Icons.check_circle_outline,
                              color: Colors.grey)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
