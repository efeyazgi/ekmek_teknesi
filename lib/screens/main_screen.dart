import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'orders_list_screen.dart';
import 'customers_list_screen.dart';
import 'expenses_list_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'stok_yonetimi_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _seciliSayfaIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _sayfaGec(int index) {
    _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 200), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final List<String> sayfaBasliklari = [
      'Ekmek Teknesi',
      'Siparişler',
      'Müşteriler',
      'Giderler',
      'Stok',
      'Raporlar',
      'Ayarlar'
    ];
    return Scaffold(
      appBar: AppBar(
        title: _seciliSayfaIndex == 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/foreground_icon.png',
                      height: 40), // Değiştirildi
                  const SizedBox(width: 8),
                  Text(sayfaBasliklari[0]),
                ],
              )
            : Text(sayfaBasliklari[_seciliSayfaIndex]),
        centerTitle: true,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _seciliSayfaIndex = index),
        children: const [
          DashboardScreen(),
          OrdersListScreen(),
          CustomersListScreen(),
          ExpensesListScreen(),
          StokYonetimiScreen(),
          ReportsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: _sayfaGec,
        currentIndex: _seciliSayfaIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'Ana Ekran'),
          BottomNavigationBarItem(
              icon: Icon(Icons.list_alt), label: 'Siparişler'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people), label: 'Müşteriler'),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long), label: 'Giderler'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Stok'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart), label: 'Raporlar'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Ayarlar'),
        ],
      ),
    );
  }
}
