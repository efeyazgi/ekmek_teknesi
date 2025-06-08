import 'package:ekmek_teknesi/screens/add_customer_screen.dart';
import 'package:flutter/material.dart';
import '../helpers/db_helper.dart';
import '../models/musteri.dart';

class CustomersListScreen extends StatefulWidget {
  const CustomersListScreen({super.key});
  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  late Future<List<Musteri>> _musterilerFuture;
  @override
  void initState() {
    super.initState();
    _musterilerFuture = _verileriCek();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listeyiYenile();
  }

  Future<List<Musteri>> _verileriCek() async {
    final dataList = await DBHelper.getData('musteriler');
    return dataList.map((item) => Musteri.fromMap(item)).toList()
      ..sort((a, b) => a.adSoyad.compareTo(b.adSoyad));
  }

  void _listeyiYenile() {
    setState(() {
      _musterilerFuture = _verileriCek();
    });
  }

  void _yeniMusteriEkle() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (ctx) => const AddCustomerScreen()))
        .then((_) => _listeyiYenile());
  }

  void _musteriDuzenle(Musteri musteri) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (ctx) => AddCustomerScreen(musteri: musteri),
          ),
        )
        .then((_) => _listeyiYenile());
  }

  Future<void> _musteriSil(String id) async {
    await DBHelper.delete('musteriler', id);
    _listeyiYenile();
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Müşteri silindi.'),
          backgroundColor: Colors.green,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _yeniMusteriEkle,
        heroTag: 'musteri-ekle-fab',
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Musteri>>(
        future: _musterilerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(child: Text('Hata: ${snapshot.error}'));
          if (!snapshot.hasData || snapshot.data!.isEmpty)
            return const Center(
              child: Text(
                'Henüz müşteri eklenmemiş.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          final musteriler = snapshot.data!;
          return ListView.builder(
            itemCount: musteriler.length,
            itemBuilder: (ctx, index) {
              final musteri = musteriler[index];
              return Dismissible(
                key: ValueKey(musteri.id),
                background: Container(
                  color: Theme.of(context).colorScheme.error,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) => showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Emin misiniz?'),
                    content: const Text(
                      'Bu müşteriyi silmek istediğinizden emin misiniz?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Hayır'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Evet, Sil'),
                      ),
                    ],
                  ),
                ),
                onDismissed: (direction) => _musteriSil(musteri.id),
                child: Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: ListTile(
                    onTap: () => _musteriDuzenle(musteri),
                    leading: CircleAvatar(
                      child: Text(
                        musteri.adSoyad.isNotEmpty ? musteri.adSoyad[0] : '?',
                      ),
                    ),
                    title: Text(
                      musteri.adSoyad,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle:
                        musteri.telefon != null && musteri.telefon!.isNotEmpty
                        ? Text(musteri.telefon!)
                        : null,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
