import 'package:ekmek_teknesi/screens/add_expense_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../helpers/db_helper.dart';
import '../models/gider.dart';

class ExpensesListScreen extends StatefulWidget {
  const ExpensesListScreen({super.key});
  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
  late Future<List<Gider>> _giderlerFuture;
  @override
  void initState() {
    super.initState();
    _giderlerFuture = _verileriCek();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listeyiYenile();
  }

  Future<List<Gider>> _verileriCek() async {
    final dataList = await DBHelper.getData('giderler');
    return dataList.map((item) => Gider.fromMap(item)).toList()
      ..sort((a, b) => b.tarih.compareTo(a.tarih));
  }

  void _listeyiYenile() {
    setState(() {
      _giderlerFuture = _verileriCek();
    });
  }

  void _yeniGiderEkle() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (ctx) => const AddExpenseScreen()))
        .then((_) => _listeyiYenile());
  }

  void _giderDuzenle(Gider gider) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (ctx) => AddExpenseScreen(gider: gider)),
        )
        .then((_) => _listeyiYenile());
  }

  Future<void> _giderSil(String id) async {
    await DBHelper.delete('giderler', id);
    _listeyiYenile();
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gider silindi.'),
          backgroundColor: Colors.green,
        ),
      );
  }

  IconData _getGiderIcon(GiderTuru tur) {
    switch (tur) {
      case GiderTuru.Un:
        return Icons.grain_outlined;
      case GiderTuru.Maya:
        return Icons.bubble_chart_outlined;
      case GiderTuru.OdunSaman: // Güncellendi
        return Icons.local_fire_department_outlined;
      case GiderTuru.ElektrikFaturasi: // Güncellendi
        return Icons.electrical_services_outlined; // Daha spesifik bir ikon
      case GiderTuru.SuFaturasi:
        return Icons.water_drop_outlined;
      case GiderTuru.Kira:
        return Icons.house_outlined;
      case GiderTuru.Ambalaj:
        return Icons.inventory_2_outlined;
      case GiderTuru.Tuz:
        return Icons.eco_outlined; // Tuz için bir ikon (örnek)
      case GiderTuru.Diger:
      default:
        return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _yeniGiderEkle,
        heroTag: 'gider-ekle-fab',
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Gider>>(
        future: _giderlerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Henüz gider eklenmemiş.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }
          final giderler = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80), // FAB için boşluk
            itemCount: giderler.length,
            itemBuilder: (ctx, index) {
              final gider = giderler[index];
              return Dismissible(
                key: ValueKey(gider.id),
                background: Container(
                  color: Theme.of(context).colorScheme.error.withOpacity(0.75),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) => _giderSil(gider.id),
                child: Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6, // Dikey boşluk azaltıldı
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    onTap: () => _giderDuzenle(gider),
                    leading: Icon(
                      _getGiderIcon(gider.giderTuru),
                      size: 36,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      giderTuruToString(gider.giderTuru),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (gider.aciklama.isNotEmpty)
                          Padding(
                            padding:
                                const EdgeInsets.only(top: 2.0, bottom: 4.0),
                            child: Text(
                              gider.aciklama,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        Text(
                          DateFormat.yMMMMd('tr_TR').format(gider.tarih),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    trailing: Text(
                      '₺${gider.tutar.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                    isThreeLine:
                        gider.aciklama.isNotEmpty, // Dinamik olarak ayarlanacak
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
