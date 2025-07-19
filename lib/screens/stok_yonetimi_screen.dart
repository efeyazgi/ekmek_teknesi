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

  void _loadStok() {
    if (mounted) {
      setState(() {
        _stokFuture = StokHelper.calculateStock();
      });
    }
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
              // Hata durumunda kullanıcıya daha anlamlı bir mesaj gösterelim.
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Stok verileri yüklenirken bir hata oluştu.\nLütfen daha sonra tekrar deneyin.\n\nHata: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(child: Text('Stok verisi bulunamadı.'));
            }

            final tazeStok = snapshot.data!['tazeStok']!;
            final dunkuStok = snapshot.data!['dunkuStok']!;

            return Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStokKarti(
                      context,
                      'Taze Ekmek',
                      tazeStok,
                      Colors.teal.shade700,
                      Colors.teal.shade50,
                      () => _stokGuncelle(context, EkmekTuru.Taze, tazeStok),
                    ),
                    const SizedBox(height: 20),
                    _buildStokKarti(
                      context,
                      'Dünkü Ekmek',
                      dunkuStok,
                      Colors.amber.shade800,
                      Colors.amber.shade50,
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
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 6,
        color: cardBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 200,
          height: 150,
          padding: const EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: textColor.withOpacity(0.8))),
                  const SizedBox(height: 10),
                  Text(
                    adet.toString(),
                    style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: textColor),
                  ),
                ],
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Icon(
                  Icons.edit,
                  color: textColor.withOpacity(0.5),
                  size: 18,
                ),
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
      final adet = int.parse(_adetController.text);
      // Üretim ise stok artar (pozitif), diğer durumlarda stok azalır (negatif).
      final islemAdedi = _secilenTip == StokHareketiTipi.Uretim ? adet : -adet;

      final hareket = StokHareketi(
        tarih: DateTime.now(),
        adet: islemAdedi,
        tip: _secilenTip,
        ekmekTuru: _secilenTip == StokHareketiTipi.Uretim
            ? EkmekTuru.Taze // Üretim her zaman taze ekmektir
            : _secilenEkmekTuru,
        aciklama: _aciklamaController.text,
      );
      Navigator.of(context).pop(hareket);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_secilenTip == StokHareketiTipi.Uretim
          ? 'Üretim Ekle'
          : 'Stoktan Düş'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<StokHareketiTipi>(
                value: _secilenTip,
                items: StokHareketiTipi.values
                    .map((tip) {
                      // Sayım Düzeltme manuel olarak buradan eklenmemeli.
                      if (tip == StokHareketiTipi.SayimDuzeltme) {
                        return null;
                      }
                      return DropdownMenuItem(
                        value: tip,
                        child: Text(tip.displayName),
                      );
                    })
                    .whereType<DropdownMenuItem<StokHareketiTipi>>()
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _secilenTip = value;
                    });
                  }
                },
                decoration: const InputDecoration(labelText: 'Hareket Tipi'),
              ),
              // Üretim seçildiğinde ekmek türü seçeneğini gizle
              if (_secilenTip != StokHareketiTipi.Uretim)
                DropdownButtonFormField<EkmekTuru>(
                  value: _secilenEkmekTuru,
                  items: EkmekTuru.values.map((tur) {
                    return DropdownMenuItem(
                        value: tur, child: Text(tur.displayName));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null)
                      setState(() => _secilenEkmekTuru = value);
                  },
                  decoration: const InputDecoration(labelText: 'Ekmek Türü'),
                ),
              TextFormField(
                controller: _adetController,
                decoration: InputDecoration(
                    labelText: _secilenTip == StokHareketiTipi.Uretim
                        ? 'Üretilen Adet'
                        : 'Düşülecek Adet'),
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
          child: Text(_secilenTip == StokHareketiTipi.Uretim
              ? 'Üretimi Kaydet'
              : 'Stoktan Düş'),
        ),
      ],
    );
  }
}
