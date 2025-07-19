import 'package:ekmek_teknesi/models/stok_hareketi.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart'; // fl_chart kütüphanesini ekliyoruz
import '../helpers/db_helper.dart';
import '../models/siparis.dart';
import '../models/gider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Future<Map<String, dynamic>>? _reportDataFuture;

  // Tarih aralığı için state'ler
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDataForDateRange(); // Verileri ilk başta yükle
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Belirtilen tarih aralığına göre verileri getiren fonksiyon
  void _loadDataForDateRange() {
    setState(() {
      _reportDataFuture = _getReportData(_startDate, _endDate);
    });
  }

  Future<Map<String, dynamic>> _getReportData(
      DateTime baslangic, DateTime bitis) async {
    // Bitiş tarihini gün sonu olarak ayarlıyoruz ki o günkü veriler de dahil olsun.
    final sonTarih = DateTime(bitis.year, bitis.month, bitis.day, 23, 59, 59);

    final siparislerData = await DBHelper.getData('siparisler');
    final giderlerData = await DBHelper.getData('giderler');
    final stokHareketleriData = await DBHelper.getData('stok_hareketleri');

    final tumSiparisler =
        siparislerData.map((item) => Siparis.fromMap(item)).toList();
    final tumGiderler =
        giderlerData.map((item) => Gider.fromMap(item)).toList();
    final tumStokHareketleri =
        stokHareketleriData.map((item) => StokHareketi.fromMap(item)).toList();

    // Verileri tarih aralığına göre filtrele
    final siparisler = tumSiparisler
        .where((s) =>
            s.teslimTarihi.isAfter(baslangic) &&
            s.teslimTarihi.isBefore(sonTarih))
        .toList();
    final giderler = tumGiderler
        .where((g) => g.tarih.isAfter(baslangic) && g.tarih.isBefore(sonTarih))
        .toList();
    final stokHareketleri = tumStokHareketleri
        .where((h) => h.tarih.isAfter(baslangic) && h.tarih.isBefore(sonTarih))
        .toList();

    // Müşteri Lider Tablosu Verisi
    final musteriVerisi = <String, Map<String, int>>{};
    for (var siparis in siparisler) {
      if (siparis.musteriAdi.toLowerCase() == 'hızlı satış') continue;
      if (siparis.durum != SiparisDurum.TeslimEdildi) continue;

      if (!musteriVerisi.containsKey(siparis.musteriAdi)) {
        musteriVerisi[siparis.musteriAdi] = {'ekmek': 0, 'siparis': 0};
      }
      musteriVerisi[siparis.musteriAdi]!['ekmek'] =
          (musteriVerisi[siparis.musteriAdi]!['ekmek'] ?? 0) +
              siparis.ekmekAdedi;
      musteriVerisi[siparis.musteriAdi]!['siparis'] =
          (musteriVerisi[siparis.musteriAdi]!['siparis'] ?? 0) + 1;
    }

    // Toplam üretilen ekmek sayısını hesapla
    final uretilenEkmekSayisi = stokHareketleri
        .where((h) => h.tip == StokHareketiTipi.Uretim)
        .fold<int>(0, (sum, h) => sum + h.adet);

    return {
      'siparisler': siparisler,
      'giderler': giderler,
      'stokHareketleri': stokHareketleri,
      'musteriVerisi': musteriVerisi,
      'uretilenEkmek': uretilenEkmekSayisi,
    };
  }

  // Tarih aralığı seçme fonksiyonu
  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null &&
        (picked.start != _startDate || picked.end != _endDate)) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadDataForDateRange();
    }
  }

  // build fonksiyonu sadece ana widget'ı dönecek
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raporlar'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Tarih Aralığı Seç',
            onPressed: () => _selectDateRange(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.7),
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.leaderboard), text: 'Lider Tablosu'),
            Tab(icon: Icon(Icons.pie_chart), text: 'Mali Özet'),
            Tab(icon: Icon(Icons.analytics), text: 'İstatistikler'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              '${DateFormat.yMd('tr_TR').format(_startDate)} - ${DateFormat.yMd('tr_TR').format(_endDate)}',
              style: theme.textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _reportDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Hata:  {snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data == null) {
                  return const Center(child: Text('Veri bulunamadı.'));
                }

                final data = snapshot.data!;
                final musteriVerisi =
                    data['musteriVerisi'] as Map<String, Map<String, int>>;
                final siparisler = data['siparisler'] as List<Siparis>;
                final giderler = data['giderler'] as List<Gider>;
                final stokHareketleri =
                    data['stokHareketleri'] as List<StokHareketi>;
                final uretilenEkmek = data['uretilenEkmek'] as int;

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLeaderboard(musteriVerisi),
                    _buildFinancialSummary(
                        siparisler, giderler, uretilenEkmek, context),
                    _buildStatistics(siparisler, stokHareketleri, context),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard(Map<String, Map<String, int>> musteriVerisi) {
    final siralamaListesi = musteriVerisi.entries.toList();
    siralamaListesi
        .sort((a, b) => b.value['ekmek']!.compareTo(a.value['ekmek']!));

    if (siralamaListesi.isEmpty) {
      return const Center(
          child: Text('Bu tarih aralığında müşteri verisi yok.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: siralamaListesi.length,
      itemBuilder: (context, index) {
        final musteriAdi = siralamaListesi[index].key;
        final veri = siralamaListesi[index].value;
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
            rankColor = Colors.transparent; // Diğerleri için ikonu gösterme
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (rank <= 3) Icon(rankIcon, color: rankColor),
                Text('$rank.',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            title: Text(musteriAdi,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bakery_dining, size: 16, color: Colors.brown),
                const SizedBox(width: 4),
                Text('${veri['ekmek']} Ekmek',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                const Icon(Icons.list_alt, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 4),
                Text('${veri['siparis']} Sipariş'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFinancialSummary(List<Siparis> siparisler, List<Gider> giderler,
      int uretilenEkmek, BuildContext context) {
    double toplamGelir = siparisler.fold(0,
        (sum, s) => sum + (s.durum == SiparisDurum.TeslimEdildi ? s.tutar : 0));
    double toplamGider = giderler.fold(0, (sum, g) => sum + g.tutar);
    double netKar = toplamGelir - toplamGider;
    final toplamSatilanEkmek = siparisler
        .where((s) => s.durum == SiparisDurum.TeslimEdildi)
        .fold<int>(0, (sum, s) => sum + s.ekmekAdedi);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 210, // Orta boy
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    color: Colors.green,
                    value: toplamGelir,
                    title: 'Gelir\n₺${toplamGelir.toStringAsFixed(0)}',
                    radius: 75,
                    titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  PieChartSectionData(
                    color: Colors.red,
                    value: toplamGider,
                    title: 'Gider\n₺${toplamGider.toStringAsFixed(0)}',
                    radius: 75,
                    titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ],
                sectionsSpace: 2,
                centerSpaceRadius: 24,
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Divider(thickness: 1),
          const SizedBox(height: 16),
          _buildSummaryCard('Net Kar', '₺${netKar.toStringAsFixed(2)}',
              icon: Icons.account_balance_wallet,
              color: netKar >= 0 ? Colors.blue : Colors.orange),
          _buildSummaryCard('Toplam Satılan Ekmek', '$toplamSatilanEkmek Adet',
              icon: Icons.bakery_dining, color: Colors.brown),
          _buildSummaryCard('Toplam Üretilen Ekmek', '$uretilenEkmek Adet',
              icon: Icons.grain, color: Colors.purple),
        ],
      ),
    );
  }

  // _buildStatistics fonksiyonuna context parametresi ekle
  Widget _buildStatistics(List<Siparis> siparisler,
      List<StokHareketi> stokHareketleri, BuildContext context) {
    // Haftanın günlerine göre satılan ve üretilen ekmek adetlerini grupla
    final Map<int, int> haftalikSatilanEkmek = {
      1: 0,
      2: 0,
      3: 0,
      4: 0,
      5: 0,
      6: 0,
      7: 0
    };
    final Map<int, int> haftalikUretilenEkmek = {
      1: 0,
      2: 0,
      3: 0,
      4: 0,
      5: 0,
      6: 0,
      7: 0
    };

    for (var siparis in siparisler) {
      if (siparis.durum == SiparisDurum.TeslimEdildi) {
        haftalikSatilanEkmek.update(
            siparis.teslimTarihi.weekday, (value) => value + siparis.ekmekAdedi,
            ifAbsent: () => siparis.ekmekAdedi);
      }
    }

    for (var hareket in stokHareketleri) {
      if (hareket.tip == StokHareketiTipi.Uretim) {
        haftalikUretilenEkmek.update(
            hareket.tarih.weekday, (value) => value + hareket.adet,
            ifAbsent: () => hareket.adet);
      }
    }

    if (siparisler.isEmpty &&
        stokHareketleri
            .where((h) => h.tip == StokHareketiTipi.Uretim)
            .isEmpty) {
      return const Center(
          child: Text('Bu tarih aralığında istatistik verisi yok.'));
    }

    final double maxSatis = (haftalikSatilanEkmek.values.isEmpty
            ? 0
            : haftalikSatilanEkmek.values.reduce((a, b) => a > b ? a : b))
        .toDouble();
    final double maxUretim = (haftalikUretilenEkmek.values.isEmpty
            ? 0
            : haftalikUretilenEkmek.values.reduce((a, b) => a > b ? a : b))
        .toDouble();
    final double maxY = (maxSatis > maxUretim ? maxSatis : maxUretim) * 1.2;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text('Haftalık Satış ve Üretim Miktarı (Adet)',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceBetween,
                maxY: maxY == 0 ? 10 : maxY, // Eğer veri yoksa 10 olarak ayarla
                barGroups: List.generate(7, (index) {
                  final day = index + 1;
                  return BarChartGroupData(
                    x: day,
                    barRods: [
                      BarChartRodData(
                        toY: haftalikSatilanEkmek[day]!.toDouble(),
                        color: Colors.amber,
                        width: 15,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: haftalikUretilenEkmek[day]!.toDouble(),
                        color: Colors.green,
                        width: 15,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final style = TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                        );
                        String text;
                        switch (value.toInt()) {
                          case 1:
                            text = 'Pzt';
                            break;
                          case 2:
                            text = 'Sal';
                            break;
                          case 3:
                            text = 'Çar';
                            break;
                          case 4:
                            text = 'Per';
                            break;
                          case 5:
                            text = 'Cum';
                            break;
                          case 6:
                            text = 'Cmt';
                            break;
                          case 7:
                            text = 'Paz';
                            break;
                          default:
                            text = '';
                            break;
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 4.0,
                          child: Text(text, style: style),
                        );
                      },
                      reservedSize: 38,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.amber, 'Satılan'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.green, 'Üretilen'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }

  // _buildSummaryCard fonksiyonunda context parametresi kaldırıldı, Theme.of(context) fonksiyon içinde alınacak
  Widget _buildSummaryCard(String title, String value,
      {required IconData icon, required Color color}) {
    return Builder(
      builder: (context) => Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          leading: Icon(icon, color: color, size: 40),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall!
                  .copyWith(color: color)),
        ),
      ),
    );
  }
}
