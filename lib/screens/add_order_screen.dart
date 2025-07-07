import 'package:ekmek_teknesi/helpers/preferences_helper.dart';
import 'package:ekmek_teknesi/models/musteri.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../helpers/db_helper.dart';
import '../models/siparis.dart';

class AddOrderScreen extends StatefulWidget {
  final Siparis? siparis;
  const AddOrderScreen({super.key, this.siparis});
  @override
  State<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  Musteri? _seciliMusteri;
  final _musteriAdiController = TextEditingController();
  int _ekmekAdedi = 1;
  late DateTime _seciliTarih;
  bool _odemeAlindi = false;
  final _notlarController = TextEditingController();
  bool get _isEditing => widget.siparis != null;
  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final s = widget.siparis!;
      _musteriAdiController.text = s.musteriAdi;
      _ekmekAdedi = s.ekmekAdedi;
      _seciliTarih = s.teslimTarihi;
      _odemeAlindi = s.odemeAlindiMi;
      _notlarController.text = s.notlar ?? '';
    } else {
      _seciliTarih = DateTime.now();
    }
  }

  void _kaydetmeyiDene() async {
    if (!_formKey.currentState!.validate()) return;

    final ekmekFiyati = await PreferencesHelper.getEkmekFiyati();
    final tutar = _ekmekAdedi * ekmekFiyati;

    if (_isEditing) {
      final guncellenenSiparis = {
        'musteriAdi': _seciliMusteri?.adSoyad ?? _musteriAdiController.text,
        'musteriId': _seciliMusteri?.id,
        'ekmekAdedi': _ekmekAdedi,
        'teslimTarihi': _seciliTarih.toIso8601String(),
        'odemeAlindiMi': _odemeAlindi ? 1 : 0,
        'notlar': _notlarController.text,
        'tutar': tutar,
      };
      DBHelper.update('siparisler', widget.siparis!.id, guncellenenSiparis);
    } else {
      final yeniSiparis = Siparis(
        id: const Uuid().v4(),
        musteriId: _seciliMusteri?.id,
        musteriAdi: _seciliMusteri?.adSoyad ?? _musteriAdiController.text,
        ekmekAdedi: _ekmekAdedi,
        teslimTarihi: _seciliTarih,
        tutar: tutar,
        odemeAlindiMi: _odemeAlindi,
        notlar: _notlarController.text,
        durum: SiparisDurum.Bekliyor,
      );
      DBHelper.insert('siparisler', yeniSiparis.toMap());
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _musteriSecDialogGoster() async {
    final musteriler = (await DBHelper.getData(
      'musteriler',
    ))
        .map((e) => Musteri.fromMap(e))
        .toList();
    if (!mounted) return;
    final secilen = await showDialog<Musteri>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Müşteri Seç'),
        content: SizedBox(
          width: double.maxFinite,
          child: musteriler.isEmpty
              ? const Text('Kayıtlı müşteri bulunamadı.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: musteriler.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text(musteriler[index].adSoyad),
                    onTap: () => Navigator.of(context).pop(musteriler[index]),
                  ),
                ),
        ),
      ),
    );
    if (secilen != null)
      setState(() {
        _seciliMusteri = secilen;
        _musteriAdiController.text = secilen.adSoyad;
      });
  }

  @override
  void dispose() {
    _musteriAdiController.dispose();
    _notlarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Siparişi Düzenle' : 'Yeni Sipariş Ekle'),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _musteriAdiController,
                        decoration: const InputDecoration(
                          labelText: 'Müşteri Adı',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Müşteri adı giriniz.'
                            : null,
                        readOnly: _seciliMusteri != null,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.person_search),
                      tooltip: _seciliMusteri != null
                          ? 'Seçimi Temizle'
                          : 'Kayıtlı Müşterilerden Seç',
                      onPressed: () {
                        if (_seciliMusteri != null) {
                          setState(() {
                            _seciliMusteri = null;
                            _musteriAdiController.clear();
                          });
                        } else {
                          _musteriSecDialogGoster();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Ekmek Adedi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.remove_circle,
                        color: Colors.red,
                        size: 36,
                      ),
                      onPressed: () {
                        if (_ekmekAdedi > 1) setState(() => _ekmekAdedi--);
                      },
                    ),
                    Text(
                      '$_ekmekAdedi',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add_circle,
                        color: Colors.green,
                        size: 36,
                      ),
                      onPressed: () => setState(() => _ekmekAdedi++),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Teslim Tarihi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat.yMMMMd('tr_TR').format(_seciliTarih),
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
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (secilen != null)
                          setState(() => _seciliTarih = secilen);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SwitchListTile(
                  title: const Text(
                    'Ödemesi Peşin Alındı mı?',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  value: _odemeAlindi,
                  onChanged: (bool value) =>
                      setState(() => _odemeAlindi = value),
                  secondary: const Icon(Icons.attach_money),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _notlarController,
                  decoration: const InputDecoration(
                    labelText: 'Sipariş Notu (varsa)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
