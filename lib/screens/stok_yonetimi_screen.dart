import 'package:ekmek_teknesi/helpers/stok_helper.dart';
import 'package:ekmek_teknesi/models/siparis.dart';
import 'package:flutter/material.dart';
import '../helpers/db_helper.dart';
import '../models/stok_hareketi.dart';

class StokYonetimiScreen extends StatefulWidget {
  const StokYonetimiScreen({super.key});

  @override
  State<StokYonetimiScreen> createState() => _StokYonetimiScreenState();
}

class _StokYonetimiScreenState extends State<StokYonetimiScreen> {
  Future<Map<String, int>>? _stokFuture;

  @override
  void initState() {
    super.initState();
    _loadStok();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadStok();
  }

  void _loadStok() {
    if (mounted) {
      setState(() {
        _stokFuture = StokHelper.calculateStock();
      });
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Future<Map<String, int>> _getStok() async {
    final hareketlerData = await DBHelper.getData('stok_hareketleri');
    final hareketler =
        hareketlerData.map((e) => StokHareketi.fromMap(e)).toList();

    final bugun = DateTime.now();
    final dun = bugun.subtract(const Duration(days: 1));

    // Dünkü Stok
    final dunUretilen = hareketler
        .where(
            (h) => h.tip == StokHareketiTipi.Uretim && _isSameDay(h.tarih, dun))
        .fold(0, (sum, h) => sum + h.adet);
    final dunTazeCikis = hareketler
        .where((h) =>
            h.ekmekTuru == EkmekTuru.Taze &&
            h.tip != StokHareketiTipi.Uretim &&
            _isSameDay(h.tarih, dun))
        .fold(0, (sum, h) => sum + h.adet);
    final duneDevredenTazeStok = dunUretilen - dunTazeCikis;
    final bugunDunkuStokCikisi = hareketler
        .where((h) =>
            h.ekmekTuru == EkmekTuru.Dunku &&
            h.tip != StokHareketiTipi.Uretim &&
            _isSameDay(h.tarih, bugun))
        .fold(0, (sum, h) => sum + h.adet);
    final anlikDunkuStok = duneDevredenTazeStok - bugunDunkuStokCikisi;

    // Taze Stok
    final bugunUretilen = hareketler
        .where((h) =>
            h.tip == StokHareketiTipi.Uretim && _isSameDay(h.tarih, bugun))
        .fold(0, (sum, h) => sum + h.adet);
    final bugunTazeCikis = hareketler
        .where((h) =>
            h.ekmekTuru == EkmekTuru.Taze &&
            h.tip != StokHareketiTipi.Uretim &&
            _isSameDay(h.tarih, bugun))
        .fold(0, (sum, h) => sum + h.adet);
    final anlikTazeStok = bugunUretilen - bugunTazeCikis;

    return {'tazeStok': anlikTazeStok, 'dunkuStok': anlikDunkuStok};
  }

  Future<void> _stokGuncelle(
      BuildContext context, EkmekTuru tur, int mevcutAdet) async {
    final controller = TextEditingController();
    final yeniAdet = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${tur.name} Stoğunu Güncelle'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration:
              InputDecoration(labelText: 'Doğru Adet (Mevcut: $mevcutAdet)'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            child: const Text('İptal'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: const Text('Güncelle'),
            onPressed: () =>
                Navigator.of(ctx).pop(int.tryParse(controller.text)),
          ),
        ],
      ),
    );

    if (yeniAdet != null) {
      final fark = yeniAdet - mevcutAdet;
      if (fark == 0) return;

      final duzeltmeHareketi = StokHareketi(
        tarih: DateTime.now(),
        adet: fark,
        tip: StokHareketiTipi.SayimDuzeltme,
        ekmekTuru: tur,
        aciklama: 'Manuel sayım ile stok güncellendi.',
      );
      await DBHelper.insert('stok_hareketleri', duzeltmeHareketi.toMap());
      _loadStok();
    }
  }

  void _stokHareketiEkle() async {
    final result = await showDialog<StokHareketi>(
      context: context,
      builder: (ctx) => const StokHareketiEkleDialog(),
    );

    if (result != null) {
      await DBHelper.insert('stok_hareketleri', result.toMap());
      _loadStok();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _stokHareketiEkle,
        label: const Text('Stok Hareketi Ekle'),
        icon: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadStok(),
        child: FutureBuilder<Map<String, int>>(
          future: _stokFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Hata: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(child: Text('Stok verisi bulunamadı.'));
            }

            final tazeStok = snapshot.data!['tazeStok']!;
            final dunkuStok = snapshot.data!['dunkuStok']!;

            return Padding(
              // Üstten boşluk için Padding eklendi
              padding: const EdgeInsets.only(top: 20.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStokKarti(
                      context,
                      'Taze Ekmek',
                      tazeStok,
                      Colors.teal.shade700, // Yazı rengi
                      Colors.teal.shade50, // Kart arka plan rengi
                      () => _stokGuncelle(context, EkmekTuru.Taze, tazeStok),
                    ),
                    const SizedBox(height: 20),
                    _buildStokKarti(
                      context,
                      'Dünkü Ekmek',
                      dunkuStok,
                      Colors.amber.shade800, // Yazı rengi
                      Colors.amber.shade50, // Kart arka plan rengi
                      () => _stokGuncelle(context, EkmekTuru.Dunku, dunkuStok),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStokKarti(BuildContext context, String title, int adet,
      Color textColor, Color cardBackgroundColor, VoidCallback onTap) {
    // cardBackgroundColor eklendi
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 6,
        color: cardBackgroundColor, // Kartın arka plan rengi ayarlandı
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 200,
          height: 150,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: textColor
                          .withOpacity(0.8) // Başlık için de uyumlu bir renk
                      )),
              const SizedBox(height: 10),
              Text(
                adet.toString(),
                style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: textColor), // textColor parametresi kullanılıyor
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StokHareketiEkleDialog extends StatefulWidget {
  const StokHareketiEkleDialog({super.key});

  @override
  State<StokHareketiEkleDialog> createState() => _StokHareketiEkleDialogState();
}

class _StokHareketiEkleDialogState extends State<StokHareketiEkleDialog> {
  final _formKey = GlobalKey<FormState>();
  StokHareketiTipi _secilenTip = StokHareketiTipi.KendiKullanim;
  EkmekTuru _secilenEkmekTuru = EkmekTuru.Taze;
  final _adetController = TextEditingController();
  final _aciklamaController = TextEditingController();

  void _kaydet() {
    if (_formKey.currentState!.validate()) {
      final hareket = StokHareketi(
        tarih: DateTime.now(),
        adet:
            -int.parse(_adetController.text), // Stoktan düşüleceği için negatif
        tip: _secilenTip,
        ekmekTuru: _secilenTip == StokHareketiTipi.Uretim
            ? EkmekTuru.Taze
            : _secilenEkmekTuru,
        aciklama: _aciklamaController.text,
      );
      Navigator.of(context).pop(hareket);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Stoktan Düş'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<StokHareketiTipi>(
                value: _secilenTip,
                items: [
                  StokHareketiTipi.KendiKullanim,
                  StokHareketiTipi.UcretsizVerilen,
                  StokHareketiTipi.Bozulan
                ].map((tip) {
                  return DropdownMenuItem(
                    value: tip,
                    child: Text(tip.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _secilenTip = value);
                },
                decoration: const InputDecoration(labelText: 'Hareket Tipi'),
              ),
              DropdownButtonFormField<EkmekTuru>(
                value: _secilenEkmekTuru,
                items: EkmekTuru.values.map((tur) {
                  return DropdownMenuItem(value: tur, child: Text(tur.name));
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _secilenEkmekTuru = value);
                },
                decoration: const InputDecoration(labelText: 'Ekmek Türü'),
              ),
              TextFormField(
                controller: _adetController,
                decoration: const InputDecoration(labelText: 'Düşülecek Adet'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null ||
                      value.isEmpty ||
                      int.tryParse(value) == null ||
                      int.parse(value) <= 0) {
                    return 'Lütfen geçerli bir adet giriniz';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _aciklamaController,
                decoration:
                    const InputDecoration(labelText: 'Açıklama (İsteğe Bağlı)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _kaydet,
          child: const Text('Stoktan Düş'),
        ),
      ],
    );
  }
}
