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

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.account_balance), text: 'Mali Özet'),
            Tab(icon: Icon(Icons.leaderboard), text: 'Müşteri Lider Tablosu'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_MaliRapor(), _MusteriLiderTablosu()],
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

    final siparisler = siparislerData
        .map((item) => Siparis.fromMap(item))
        .toList();
    final giderler = giderlerData.map((item) => Gider.fromMap(item)).toList();
    final uretimler = uretimlerData
        .map((item) => UretimKaydi.fromMap(item))
        .toList();

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
    final siparisler = siparislerData
        .map((item) => Siparis.fromMap(item))
        .toList();
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
