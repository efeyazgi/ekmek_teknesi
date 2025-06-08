import 'package:ekmek_teknesi/helpers/preferences_helper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../helpers/db_helper.dart';
import '../models/gider.dart';

class AddExpenseScreen extends StatefulWidget {
  final Gider? gider;
  const AddExpenseScreen({super.key, this.gider});
  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late GiderTuru _seciliGiderTuru;
  final _aciklamaController = TextEditingController();
  final _tutarController = TextEditingController();
  final _unAdetController = TextEditingController();
  late DateTime _seciliTarih;
  double _birimUnFiyati = 0.0;
  bool _ayarlarYukleniyor = true;
  bool get _isEditing => widget.gider != null;
  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final g = widget.gider!;
      _seciliGiderTuru = g.giderTuru;
      _aciklamaController.text = g.aciklama;
      _tutarController.text = g.tutar.toString();
      _seciliTarih = g.tarih;
    } else {
      _seciliGiderTuru = GiderTuru.Un;
      _unAdetController.text = '1';
      _seciliTarih = DateTime.now();
    }
    _unFiyatiniCek();
  }

  Future<void> _unFiyatiniCek() async {
    _birimUnFiyati = await PreferencesHelper.getUnFiyati();
    if (mounted) setState(() => _ayarlarYukleniyor = false);
  }

  void _kaydetmeyiDene() {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) return;
    double hesaplananTutar = 0;
    if (_seciliGiderTuru == GiderTuru.Un && !_isEditing) {
      final adet = int.parse(_unAdetController.text);
      hesaplananTutar = adet * _birimUnFiyati;
    } else {
      hesaplananTutar = double.parse(_tutarController.text);
    }
    if (_isEditing) {
      final guncellenenGider = {
        'giderTuru': _seciliGiderTuru.name,
        'aciklama': _aciklamaController.text,
        'tutar': hesaplananTutar,
        'tarih': _seciliTarih.toIso8601String(),
      };
      DBHelper.update('giderler', widget.gider!.id, guncellenenGider);
    } else {
      final yeniGider = Gider(
        id: const Uuid().v4(),
        tarih: _seciliTarih,
        giderTuru: _seciliGiderTuru,
        aciklama: _aciklamaController.text,
        tutar: hesaplananTutar,
      );
      DBHelper.insert('giderler', yeniGider.toMap());
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _aciklamaController.dispose();
    _tutarController.dispose();
    _unAdetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ayarlarYukleniyor)
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Gideri Düzenle' : 'Yeni Gider Ekle'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Gideri Düzenle' : 'Yeni Gider Ekle'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _kaydetmeyiDene),
        ],
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<GiderTuru>(
                  value: _seciliGiderTuru,
                  decoration: const InputDecoration(
                    labelText: 'Gider Türü',
                    border: OutlineInputBorder(),
                  ),
                  items: GiderTuru.values
                      .map(
                        (tur) => DropdownMenuItem(
                          value: tur,
                          child: Text(giderTuruToString(tur)),
                        ),
                      )
                      .toList(),
                  onChanged: (yeniDeger) =>
                      setState(() => _seciliGiderTuru = yeniDeger!),
                ),
                const SizedBox(height: 16),
                if (_seciliGiderTuru == GiderTuru.Un && !_isEditing) ...[
                  if (_birimUnFiyati > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Birim Fiyat: ₺$_birimUnFiyati (Ayarlar\'dan değiştirilebilir)',
                      ),
                    ),
                  TextFormField(
                    controller: _unAdetController,
                    decoration: const InputDecoration(
                      labelText: 'Miktar (Adet)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (int.tryParse(v ?? '') == null)
                        return 'Geçerli bir sayı girin.';
                      if (_birimUnFiyati <= 0)
                        return 'Lütfen Ayarlar\'dan un fiyatını belirleyin.';
                      return null;
                    },
                  ),
                ] else ...[
                  TextFormField(
                    controller: _tutarController,
                    decoration: const InputDecoration(
                      labelText: 'Toplam Tutar (TL)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (double.tryParse(v ?? '') == null)
                        return 'Geçerli bir sayı girin.';
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _aciklamaController,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama (isteğe bağlı)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tarih: ${DateFormat.yMMMMd('tr_TR').format(_seciliTarih)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Değiştir'),
                      onPressed: () async {
                        final secilen = await showDatePicker(
                          context: context,
                          initialDate: _seciliTarih,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (secilen != null)
                          setState(() => _seciliTarih = secilen);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
