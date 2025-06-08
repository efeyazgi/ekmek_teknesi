import 'package:ekmek_teknesi/helpers/db_helper.dart';
import 'package:ekmek_teknesi/models/musteri.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class AddCustomerScreen extends StatefulWidget {
  final Musteri? musteri;
  const AddCustomerScreen({super.key, this.musteri});
  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adSoyadController = TextEditingController();
  final _telefonController = TextEditingController();
  final _notlarController = TextEditingController();
  bool get _isEditing => widget.musteri != null;
  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _adSoyadController.text = widget.musteri!.adSoyad;
      _telefonController.text = widget.musteri!.telefon ?? '';
      _notlarController.text = widget.musteri!.notlar ?? '';
    }
  }

  void _kaydet() {
    if (!_formKey.currentState!.validate()) return;
    if (_isEditing) {
      final guncellenenMusteri = {
        'adSoyad': _adSoyadController.text,
        'telefon': _telefonController.text,
        'notlar': _notlarController.text,
      };
      DBHelper.update('musteriler', widget.musteri!.id, guncellenenMusteri);
    } else {
      final yeniMusteri = Musteri(
        id: const Uuid().v4(),
        adSoyad: _adSoyadController.text,
        telefon: _telefonController.text,
        notlar: _notlarController.text,
      );
      DBHelper.insert('musteriler', yeniMusteri.toMap());
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _adSoyadController.dispose();
    _telefonController.dispose();
    _notlarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Müşteriyi Düzenle' : 'Yeni Müşteri Ekle'),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _kaydet)],
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextFormField(
                  controller: _adSoyadController,
                  decoration: const InputDecoration(
                    labelText: 'Adı Soyadı',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Müşteri adı boş bırakılamaz.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _telefonController,
                  decoration: const InputDecoration(
                    labelText: 'Telefon (isteğe bağlı)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notlarController,
                  decoration: const InputDecoration(
                    labelText: 'Notlar (isteğe bağlı)',
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
