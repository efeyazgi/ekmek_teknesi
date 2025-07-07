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
    final musteriler = dataList.map((item) => Musteri.fromMap(item)).toList();
    musteriler.sort((a, b) => a.adSoyad.compareTo(b.adSoyad));
    return musteriler;
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
        .push(MaterialPageRoute(
            builder: (ctx) => AddCustomerScreen(musteri: musteri)))
        .then((_) => _listeyiYenile());
  }

  Future<void> _musteriSil(String id) async {
    final eminMisin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emin misiniz?'),
        content: const Text(
            'Bu müşteriyi silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            child: const Text('Hayır'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text('Evet, Sil'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (eminMisin ?? false) {
      await DBHelper.delete('musteriler', id);
      _listeyiYenile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Müşteri silindi.'), backgroundColor: Colors.green));
      }
    }
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
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
                child: ListTile(
                  leading: Icon(
                    Icons.person_outline,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(musteri.adSoyad),
                  subtitle:
                      musteri.telefon != null && musteri.telefon!.isNotEmpty
                          ? Text(musteri.telefon!)
                          : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit,
                            color: Theme.of(context).primaryColor),
                        onPressed: () => _musteriDuzenle(musteri),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete,
                            color: Theme.of(context).colorScheme.error),
                        onPressed: () => _musteriSil(musteri.id),
                      ),
                    ],
                  ),
                  onTap: () => _musteriDuzenle(musteri),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
