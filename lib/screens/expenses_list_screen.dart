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
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(child: Text('Hata: ${snapshot.error}'));
          if (!snapshot.hasData || snapshot.data!.isEmpty)
            return const Center(
              child: Text(
                'Henüz gider eklenmemiş.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          final giderler = snapshot.data!;
          return ListView.builder(
            itemCount: giderler.length,
            itemBuilder: (ctx, index) {
              final gider = giderler[index];
              return Dismissible(
                key: ValueKey(gider.id),
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
                onDismissed: (direction) => _giderSil(gider.id),
                child: Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    onTap: () => _giderDuzenle(gider),
                    leading: CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: FittedBox(
                          child: Text(
                            '₺${gider.tutar.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      giderTuruToString(gider.giderTuru),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${gider.aciklama}\n${DateFormat.yMMMMd('tr_TR').format(gider.tarih)}',
                    ),
                    isThreeLine: gider.aciklama.isNotEmpty,
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
