import 'package:ekmek_teknesi/models/uretim_kaydi.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../helpers/db_helper.dart';
import '../models/siparis.dart';
import '../models/gider.dart';

// Müşteri performansını tutmak için basit bir yardımcı sınıf.
// GÜNCELLENDİ: Toplam ekmek adedi eklendi.
class MusteriPerformans {
  final String musteriAdi;
  int siparisSayisi;
  int toplamEkmek;

  MusteriPerformans({
    required this.musteriAdi,
    this.siparisSayisi = 0,
    this.toplamEkmek = 0,
  });
}

// GÜNCELLENDİ: Sıralama türlerini yönetmek için enum.
enum MusteriSiralamaTuru { siparisSayisi, ekmekSayisi }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

enum _LeaderboardSortType { byBreadCount, byOrderCount }

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Future<Map<String, dynamic>>? _reportDataFuture;
  _LeaderboardSortType _sortType = _LeaderboardSortType.byBreadCount;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _reportDataFuture = _getReportData();
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _getReportData() async {
    final siparislerData = await DBHelper.getData('siparisler');
    final giderlerData = await DBHelper.getData('giderler');

    final siparisler =
        siparislerData.map((item) => Siparis.fromMap(item)).toList();
    final giderler = giderlerData.map((item) => Gider.fromMap(item)).toList();

    // Müşteri Lider Tablosu Verisi
    final musteriVerisi = <String, Map<String, int>>{};
    for (var siparis in siparisler) {
      if (siparis.musteriAdi.toLowerCase() == 'hızlı satış') continue;

      if (!musteriVerisi.containsKey(siparis.musteriAdi)) {
        musteriVerisi[siparis.musteriAdi] = {'ekmek': 0, 'siparis': 0};
      }
      musteriVerisi[siparis.musteriAdi]!['ekmek'] =
          (musteriVerisi[siparis.musteriAdi]!['ekmek'] ?? 0) +
              siparis.ekmekAdedi;
      musteriVerisi[siparis.musteriAdi]!['siparis'] =
          (musteriVerisi[siparis.musteriAdi]!['siparis'] ?? 0) + 1;
    }

    return {
      'siparisler': siparisler,
      'giderler': giderler,
      'musteriVerisi': musteriVerisi,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 0.0, // Eklendi
        // title: const Text('Raporlar'), // Bu satır kaldırıldı
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false, // Değiştirildi
          labelColor: theme.colorScheme.onPrimary,
          unselectedLabelColor: theme.colorScheme.onPrimary.withOpacity(0.7),
          indicatorColor: theme.colorScheme.onPrimary,
          tabs: [
            Tab(
              icon: Icon(Icons.leaderboard),
              text: 'Müşteri Lider Tablosu',
            ),
            Tab(
              icon: Icon(Icons.pie_chart),
              text: 'Mali Özet',
            ),
            Tab(
              icon: Icon(Icons.analytics),
              text: 'İstatistikler',
            ),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _reportDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Veri bulunamadı.'));
          }

          final data = snapshot.data!;
          final musteriVerisi =
              data['musteriVerisi'] as Map<String, Map<String, int>>;

          return TabBarView(
            controller: _tabController,
            children: [
              _buildLeaderboard(musteriVerisi),
              _buildFinancialSummary(data['siparisler'], data['giderler']),
              _buildStatistics(data['siparisler'], data['giderler']),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLeaderboard(Map<String, Map<String, int>> musteriVerisi) {
    final siralamaListesi = musteriVerisi.entries.toList();
    if (_sortType == _LeaderboardSortType.byBreadCount) {
      siralamaListesi
          .sort((a, b) => b.value['ekmek']!.compareTo(a.value['ekmek']!));
    } else {
      siralamaListesi
          .sort((a, b) => b.value['siparis']!.compareTo(a.value['siparis']!));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SegmentedButton<_LeaderboardSortType>(
            segments: const [
              ButtonSegment(
                  value: _LeaderboardSortType.byBreadCount,
                  label: Text('Ekmek Adedi')),
              ButtonSegment(
                  value: _LeaderboardSortType.byOrderCount,
                  label: Text('Sipariş Sayısı')),
            ],
            selected: {_sortType},
            onSelectionChanged: (newSelection) {
              setState(() {
                _sortType = newSelection.first;
              });
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: siralamaListesi.length,
            itemBuilder: (context, index) {
              final musteriAdi = siralamaListesi[index].key;
              final veri = siralamaListesi[index].value;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: Text(musteriAdi),
                  trailing: Text(
                    '${veri['ekmek']} Ekmek / ${veri['siparis']} Sipariş',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialSummary(
      List<Siparis> siparisler, List<Gider> giderler) {
    double toplamGelir = siparisler.fold(0,
        (sum, s) => sum + (s.durum == SiparisDurum.TeslimEdildi ? s.tutar : 0));
    double toplamGider = giderler.fold(0, (sum, g) => sum + g.tutar);
    double kar = toplamGelir - toplamGider;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(
              'Toplam Gelir', '₺${toplamGelir.toStringAsFixed(2)}',
              icon: Icons.arrow_upward, color: Colors.green),
          _buildSummaryCard(
              'Toplam Gider', '₺${toplamGider.toStringAsFixed(2)}',
              icon: Icons.arrow_downward, color: Colors.red),
          _buildSummaryCard('Net Kar', '₺${kar.toStringAsFixed(2)}',
              icon: Icons.account_balance_wallet,
              color: kar >= 0 ? Colors.blue : Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatistics(List<Siparis> siparisler, List<Gider> giderler) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);

    final aylikSatislar = siparisler
        .where((s) =>
            s.durum == SiparisDurum.TeslimEdildi &&
            s.teslimTarihi.isAfter(currentMonth))
        .toList();

    final toplamSatisAdedi =
        siparisler.where((s) => s.durum == SiparisDurum.TeslimEdildi).length;

    // Toplam satılan ekmek adedi (Tüm Zamanlar)
    final toplamSatilanEkmekAdedi = siparisler
        .where((s) => s.durum == SiparisDurum.TeslimEdildi)
        .fold<int>(0, (sum, s) => sum + s.ekmekAdedi);

    // Bu ay satılan ekmek adedi
    final aylikSatilanEkmekAdedi =
        aylikSatislar.fold<int>(0, (sum, s) => sum + s.ekmekAdedi);

    final aylikUnGiderleri = giderler
        .where(
            (g) => g.giderTuru == GiderTuru.Un && g.tarih.isAfter(currentMonth))
        .fold<double>(0.0, (sum, g) => sum + g.tutar);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(
              'Bu Ayki Sipariş Sayısı', '${aylikSatislar.length} Adet',
              icon: Icons.calendar_month, color: Colors.purple),
          _buildSummaryCard(
              'Bu Ay Satılan Ekmek', '$aylikSatilanEkmekAdedi Adet',
              icon: Icons.bakery_dining_outlined,
              color: Colors.orange), // Yeni kart
          _buildSummaryCard(
              'Toplam Sipariş Sayısı (Tüm Zamanlar)', '$toplamSatisAdedi Adet',
              icon: Icons.receipt_long, color: Colors.teal),
          _buildSummaryCard('Toplam Satılan Ekmek (Tüm Zamanlar)',
              '$toplamSatilanEkmekAdedi Adet',
              icon: Icons.bakery_dining, color: Colors.deepOrange), // Yeni kart
          _buildSummaryCard(
              'Bu Aylık Un Gideri', '₺${aylikUnGiderleri.toStringAsFixed(2)}',
              icon: Icons.shopping_bag, color: Colors.brown),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value,
      {required IconData icon, required Color color}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: color, size: 40),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value,
            style: Theme.of(context)
                .textTheme
                .headlineSmall!
                .copyWith(color: color)),
      ),
    );
  }
}

// --- Mali Rapor Widget'ı ---
class _MaliRapor extends StatefulWidget {
  const _MaliRapor();
  @override
  State<_MaliRapor> createState() => _MaliRaporState();
}

class _MaliRaporState extends State<_MaliRapor> {
  DateTime _seciliAy = DateTime(DateTime.now().year, DateTime.now().month, 1);
  Future<Map<String, double>>? _raporVerisiFuture;

  @override
  void initState() {
    super.initState();
    _raporVerisiFuture = _veriCekVeHesapla(_seciliAy);
  }

  Future<Map<String, double>> _veriCekVeHesapla(DateTime ay) async {
    final ayinIlkGunu = DateTime(ay.year, ay.month, 1);
    final sonrakiAyinIlkGunu = DateTime(ay.year, ay.month + 1, 1);

    final siparislerData = await DBHelper.getData('siparisler');
    final giderlerData = await DBHelper.getData('giderler');
    final uretimlerData = await DBHelper.getData('uretim_kayitlari');

    final siparisler =
        siparislerData.map((item) => Siparis.fromMap(item)).toList();
    final giderler = giderlerData.map((item) => Gider.fromMap(item)).toList();
    final uretimler =
        uretimlerData.map((item) => UretimKaydi.fromMap(item)).toList();

    final buAykiTahsilatlar = siparisler
        .where(
          (s) =>
              (s.odemeAlindiMi || s.durum == SiparisDurum.TeslimEdildi) &&
              !s.teslimTarihi.isBefore(ayinIlkGunu) &&
              s.teslimTarihi.isBefore(sonrakiAyinIlkGunu),
        )
        .toList();
    final buAykiCiro = buAykiTahsilatlar.fold(
      0.0,
      (prev, s) => prev + (s.ekmekAdedi * 75.0),
    );

    final buAykiGiderler = giderler
        .where(
          (g) =>
              !g.tarih.isBefore(ayinIlkGunu) &&
              g.tarih.isBefore(sonrakiAyinIlkGunu),
        )
        .toList();
    final buAykiGider = buAykiGiderler.fold(0.0, (prev, g) => prev + g.tutar);

    final buAykiUretimler = uretimler
        .where(
          (u) =>
              !u.tarih.isBefore(ayinIlkGunu) &&
              u.tarih.isBefore(sonrakiAyinIlkGunu),
        )
        .toList();
    final buAykiUretim = buAykiUretimler.fold(0.0, (prev, u) => prev + u.adet);

    return {'ciro': buAykiCiro, 'gider': buAykiGider, 'uretim': buAykiUretim};
  }

  void _ayDegistir(int artis) {
    setState(() {
      _seciliAy = DateTime(_seciliAy.year, _seciliAy.month + artis, 1);
      _raporVerisiFuture = _veriCekVeHesapla(_seciliAy);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => _ayDegistir(-1),
              ),
              Text(
                DateFormat.yMMMM('tr_TR').format(_seciliAy),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: () => _ayDegistir(1),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: FutureBuilder<Map<String, double>>(
            future: _raporVerisiFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return Center(child: Text('Hata: ${snapshot.error}'));
              if (!snapshot.hasData)
                return const Center(child: Text('Rapor verisi bulunamadı.'));
              final data = snapshot.data!;
              final ciro = data['ciro']!;
              final gider = data['gider']!;
              final uretim = data['uretim']!;
              final netKar = ciro - gider;
              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildRaporKarti(
                    context,
                    'Toplam Ciro',
                    '₺${ciro.toStringAsFixed(2)}',
                    Icons.trending_up,
                    Colors.green,
                  ),
                  const SizedBox(height: 16),
                  _buildRaporKarti(
                    context,
                    'Bu Ayki Üretim',
                    '${uretim.toInt()} Adet',
                    Icons.bakery_dining,
                    Colors.brown,
                  ),
                  const SizedBox(height: 16),
                  _buildRaporKarti(
                    context,
                    'Toplam Gider',
                    '₺${gider.toStringAsFixed(2)}',
                    Icons.trending_down,
                    Colors.red,
                  ),
                  const SizedBox(height: 16),
                  const Divider(thickness: 2),
                  const SizedBox(height: 16),
                  _buildRaporKarti(
                    context,
                    'Net Durum (Kâr/Zarar)',
                    '₺${netKar.toStringAsFixed(2)}',
                    Icons.account_balance_wallet,
                    netKar >= 0 ? Colors.teal : Colors.orange,
                    isLarge: true,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRaporKarti(
    BuildContext context,
    String baslik,
    String deger,
    IconData ikon,
    Color renk, {
    bool isLarge = false,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(ikon, color: renk, size: isLarge ? 32 : 24),
                const SizedBox(width: 8),
                Text(
                  baslik,
                  style: isLarge
                      ? Theme.of(context).textTheme.titleLarge
                      : Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              deger,
              style: TextStyle(
                fontSize: isLarge ? 36 : 28,
                fontWeight: FontWeight.bold,
                color: renk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Müşteri Lider Tablosu Widget'ı ---
class _MusteriLiderTablosu extends StatefulWidget {
  const _MusteriLiderTablosu();
  @override
  State<_MusteriLiderTablosu> createState() => __MusteriLiderTablosuState();
}

class __MusteriLiderTablosuState extends State<_MusteriLiderTablosu> {
  DateTime _seciliAy = DateTime(DateTime.now().year, DateTime.now().month, 1);
  Future<List<MusteriPerformans>>? _liderTablosuFuture;
  // GÜNCELLENDİ: Sıralama türünü tutan state.
  MusteriSiralamaTuru _siralamaTuru = MusteriSiralamaTuru.siparisSayisi;

  @override
  void initState() {
    super.initState();
    _liderTablosuFuture = _liderTablosuVerisiCek(_seciliAy);
  }

  Future<List<MusteriPerformans>> _liderTablosuVerisiCek(DateTime ay) async {
    final ayinIlkGunu = DateTime(ay.year, ay.month, 1);
    final sonrakiAyinIlkGunu = DateTime(ay.year, ay.month + 1, 1);
    final siparislerData = await DBHelper.getData('siparisler');
    final siparisler =
        siparislerData.map((item) => Siparis.fromMap(item)).toList();
    final buAykiSiparisler = siparisler
        .where(
          (s) =>
              !s.teslimTarihi.isBefore(ayinIlkGunu) &&
              s.teslimTarihi.isBefore(sonrakiAyinIlkGunu),
        )
        .toList();

    // GÜNCELLENDİ: Hem sipariş sayısını hem de ekmek adedini hesaplayan mantık.
    final Map<String, MusteriPerformans> musteriPerformanslari = {};
    for (var siparis in buAykiSiparisler) {
      musteriPerformanslari.update(
        siparis.musteriAdi,
        (mevcut) {
          mevcut.siparisSayisi++;
          mevcut.toplamEkmek += siparis.ekmekAdedi;
          return mevcut;
        },
        ifAbsent: () => MusteriPerformans(
          musteriAdi: siparis.musteriAdi,
          siparisSayisi: 1,
          toplamEkmek: siparis.ekmekAdedi,
        ),
      );
    }

    final performansListesi = musteriPerformanslari.values.toList();

    // GÜNCELLENDİ: Seçili sıralama türüne göre listeyi sırala.
    performansListesi.sort((a, b) {
      if (_siralamaTuru == MusteriSiralamaTuru.siparisSayisi) {
        return b.siparisSayisi.compareTo(a.siparisSayisi);
      } else {
        return b.toplamEkmek.compareTo(a.toplamEkmek);
      }
    });

    return performansListesi;
  }

  void _ayDegistir(int artis) {
    setState(() {
      _seciliAy = DateTime(_seciliAy.year, _seciliAy.month + artis, 1);
      _liderTablosuFuture = _liderTablosuVerisiCek(_seciliAy);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Ay Seçim Paneli
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => _ayDegistir(-1),
              ),
              Text(
                DateFormat.yMMMM('tr_TR').format(_seciliAy),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: () => _ayDegistir(1),
              ),
            ],
          ),
        ),
        // GÜNCELLENDİ: Sıralama türü için seçim butonları eklendi.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SegmentedButton<MusteriSiralamaTuru>(
            segments: const <ButtonSegment<MusteriSiralamaTuru>>[
              ButtonSegment<MusteriSiralamaTuru>(
                value: MusteriSiralamaTuru.siparisSayisi,
                label: Text('Sipariş Sayısı'),
              ),
              ButtonSegment<MusteriSiralamaTuru>(
                value: MusteriSiralamaTuru.ekmekSayisi,
                label: Text('Ekmek Adedi'),
              ),
            ],
            selected: <MusteriSiralamaTuru>{_siralamaTuru},
            onSelectionChanged: (Set<MusteriSiralamaTuru> newSelection) {
              setState(() {
                _siralamaTuru = newSelection.first;
                _liderTablosuFuture = _liderTablosuVerisiCek(_seciliAy);
              });
            },
          ),
        ),
        const Divider(),
        // Lider Tablosu Listesi
        Expanded(
          child: FutureBuilder<List<MusteriPerformans>>(
            future: _liderTablosuFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return Center(child: Text('Hata: ${snapshot.error}'));
              if (!snapshot.hasData || snapshot.data!.isEmpty)
                return const Center(
                  child: Text(
                    'Bu ay için müşteri verisi bulunamadı.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                );

              final liderler = snapshot.data!;

              return ListView.builder(
                itemCount: liderler.length,
                itemBuilder: (ctx, index) {
                  final musteri = liderler[index];
                  final rank = index + 1;
                  IconData rankIcon;
                  Color rankColor;
                  switch (rank) {
                    case 1:
                      rankIcon = Icons.emoji_events;
                      rankColor = Colors.amber.shade700;
                      break;
                    case 2:
                      rankIcon = Icons.emoji_events;
                      rankColor = Colors.grey.shade500;
                      break;
                    case 3:
                      rankIcon = Icons.emoji_events;
                      rankColor = Colors.brown.shade400;
                      break;
                    default:
                      rankIcon = Icons.person;
                      rankColor = Colors.grey;
                  }

                  // GÜNCELLENDİ: Gösterilecek metin sıralama türüne göre değişiyor.
                  final trailingText =
                      _siralamaTuru == MusteriSiralamaTuru.siparisSayisi
                          ? '${musteri.siparisSayisi} Sipariş'
                          : '${musteri.toplamEkmek} Ekmek';

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(rankIcon, color: rankColor),
                          Text(
                            '$rank.',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      title: Text(
                        musteri.musteriAdi,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Text(
                        trailingText,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
