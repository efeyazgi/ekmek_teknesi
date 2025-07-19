import 'package:ekmek_teknesi/models/uretim_kaydi.dart';
import 'package:ekmek_teknesi/screens/add_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../helpers/db_helper.dart';
import '../models/siparis.dart';
import '../helpers/notification_helper.dart';
import '../helpers/preferences_helper.dart';
import '../models/uretim_kaydi.dart';
import '../models/stok_hareketi.dart';
import '../helpers/stok_helper.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});
  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Future<List<Siparis>>? _siparislerFuture;
  final Map<String, int> _stokDurumu = {'tazeStok': 0, 'dunkuStok': 0};

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
    _getStok().then((_) {
      if (mounted) {
        setState(() {
          _siparislerFuture = _verileriCek();
        });
      }
    });
  }

  Future<void> _getStok() async {
    final stoklar = await StokHelper.calculateStock();
    if (mounted) {
      setState(() {
        _stokDurumu['tazeStok'] = stoklar['tazeStok'] ?? 0;
        _stokDurumu['dunkuStok'] = stoklar['dunkuStok'] ?? 0;
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
    final tazeStok = _stokDurumu['tazeStok'] ?? 0;
    final dunkuStok = _stokDurumu['dunkuStok'] ?? 0;

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

    final guncellenecekVeri = {
      'durum': SiparisDurum.TeslimEdildi.name,
      'satilanEkmekTuru': secilenTur.name,
      'odemeAlindiMi': 1,
    };

    await DBHelper.update('siparisler', siparis.id, guncellenecekVeri);

    final areNotificationsEnabled =
        await PreferencesHelper.getNotificationsEnabled();
    if (areNotificationsEnabled) {
      final threshold = await PreferencesHelper.getLowStockThreshold();
      final yeniTazeStok =
          tazeStok - (secilenTur == EkmekTuru.Taze ? siparis.ekmekAdedi : 0);
      if (yeniTazeStok < threshold && tazeStok >= threshold) {
        await NotificationHelper().showLowStockNotification(yeniTazeStok);
      }
    }
    _listeyiYenile();
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sipariş silindi.'), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: FutureBuilder<List<Siparis>>(
          future: _siparislerFuture,
          builder: (context, snapshot) {
            int bekleyenEkmekSayisi = 0;
            if (snapshot.hasData) {
              final bugun = DateTime.now();
              bekleyenEkmekSayisi = snapshot.data!
                  .where((s) =>
                      s.durum == SiparisDurum.Bekliyor &&
                      s.teslimTarihi.year == bugun.year &&
                      s.teslimTarihi.month == bugun.month &&
                      s.teslimTarihi.day == bugun.day)
                  .fold(0, (sum, s) => sum + s.ekmekAdedi);
            }
            return TabBar(
              controller: _tabController,
              labelStyle: const TextStyle(
                  fontSize: 12), // Yazı boyutunu biraz küçültebiliriz
              tabs: [
                Tab(
                  child: FittedBox(
                    // Metin taşmasını önlemek için FittedBox eklendi
                    fit: BoxFit.scaleDown,
                    child: Text('BUGÜN BEKLEYEN ($bekleyenEkmekSayisi Ekmek)'),
                  ),
                ),
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('Sipariş bulunamadı.'));
        }

        List<Siparis> filtrelenmisSiparisler;
        String emptyMessage;

        if (durum == SiparisDurum.Bekliyor) {
          filtrelenmisSiparisler = snapshot.data!
              .where((s) => s.durum == SiparisDurum.Bekliyor)
              .toList();
          emptyMessage = 'Bekleyen sipariş bulunmamaktadır.';
        } else {
          filtrelenmisSiparisler = snapshot.data!
              .where((s) => s.durum == SiparisDurum.TeslimEdildi)
              .toList();
          emptyMessage = 'Geçmiş sipariş bulunmamaktadır.';
        }

        if (filtrelenmisSiparisler.isEmpty) {
          return Center(child: Text(emptyMessage));
        }

        return ListView.builder(
          itemCount: filtrelenmisSiparisler.length,
          itemBuilder: (ctx, index) {
            final siparis = filtrelenmisSiparisler[index];
            return Card(
              margin: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              child: ListTile(
                leading: Icon(
                  durum == SiparisDurum.Bekliyor
                      ? Icons.pending_actions_outlined // Bekleyen sipariş ikonu
                      : Icons
                          .check_circle_outline, // Teslim edilmiş sipariş ikonu
                  color: durum == SiparisDurum.Bekliyor
                      ? Theme.of(context).colorScheme.secondary
                      : Colors.green,
                  size: 36,
                ),
                title: Text(siparis.musteriAdi),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Teslim Tarihi: ${DateFormat('dd.MM.yyyy').format(siparis.teslimTarihi)}',
                    ),
                    Text('Adet: ${siparis.ekmekAdedi}'),
                    if (siparis.aciklama != null &&
                        siparis.aciklama!.isNotEmpty)
                      Text('Açıklama: ${siparis.aciklama}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (durum == SiparisDurum.Bekliyor)
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline),
                        onPressed: () => _siparisDurumunuGuncelle(siparis),
                        color: Colors.green,
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _siparisDuzenle(siparis),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _siparisSil(siparis.id),
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
