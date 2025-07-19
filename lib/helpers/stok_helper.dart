import 'package:ekmek_teknesi/models/siparis.dart';
import '../helpers/db_helper.dart';
import '../models/stok_hareketi.dart';

class StokHelper {
  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  static Future<Map<String, int>> calculateStock() async {
    // 1. Gerekli tüm verileri veritabanından çek
    final hareketlerData = await DBHelper.getData('stok_hareketleri');
    final hareketler =
        hareketlerData.map((e) => StokHareketi.fromMap(e)).toList();

    final siparislerData = await DBHelper.getData('siparisler');
    final siparisler =
        siparislerData.map((item) => Siparis.fromMap(item)).toList();

    final bugun = DateTime.now();
    final dun = bugun.subtract(const Duration(days: 1));

    // 2. Dünden devreden stoğu hesapla -> Bu, bugünün "Dünkü Stok" başlangıcı olacak
    final dunTazeGirisler = hareketler
        .where((h) =>
            _isSameDay(h.tarih, dun) &&
            h.ekmekTuru == EkmekTuru.Taze &&
            h.adet > 0)
        .fold(0, (t, h) => t + h.adet);
    final dunTazeCikislar = hareketler
        .where((h) =>
            _isSameDay(h.tarih, dun) &&
            h.ekmekTuru == EkmekTuru.Taze &&
            h.adet < 0)
        .fold(0, (t, h) => t + h.adet); // Bu değer negatif olacak
    final dunTeslimEdilenTaze = siparisler
        .where((s) =>
            s.durum == SiparisDurum.TeslimEdildi &&
            s.satilanEkmekTuru == EkmekTuru.Taze &&
            _isSameDay(s.teslimTarihi, dun))
        .fold(0, (t, s) => t + s.ekmekAdedi);

    final duneDevredenTazeStok =
        dunTazeGirisler + dunTazeCikislar - dunTeslimEdilenTaze;

    // 3. Bugünkü "Dünkü Stok" hareketlerini hesaba kat
    final bugunDunkuGirisler = hareketler
        .where((h) =>
            _isSameDay(h.tarih, bugun) &&
            h.ekmekTuru == EkmekTuru.Dunku &&
            h.adet > 0)
        .fold(0, (t, h) => t + h.adet);
    final bugunDunkuCikislar = hareketler
        .where((h) =>
            _isSameDay(h.tarih, bugun) &&
            h.ekmekTuru == EkmekTuru.Dunku &&
            h.adet < 0)
        .fold(0, (t, h) => t + h.adet); // negatif
    final bugunTeslimEdilenDunku = siparisler
        .where((s) =>
            s.durum == SiparisDurum.TeslimEdildi &&
            s.satilanEkmekTuru ==
                EkmekTuru.Dunku && // "Dünkü" yerine "Dunku" kullanılmalı
            _isSameDay(s.teslimTarihi, bugun))
        .fold(0, (t, s) => t + s.ekmekAdedi);

    final anlikDunkuStok = duneDevredenTazeStok +
        bugunDunkuGirisler +
        bugunDunkuCikislar -
        bugunTeslimEdilenDunku;

    // 4. Bugünkü "Taze Stok" hareketlerini hesaba kat
    final bugunTazeGirisler = hareketler
        .where((h) =>
            _isSameDay(h.tarih, bugun) &&
            h.ekmekTuru == EkmekTuru.Taze &&
            h.adet > 0)
        .fold(0, (t, h) => t + h.adet);
    final bugunTazeCikislar = hareketler
        .where((h) =>
            _isSameDay(h.tarih, bugun) &&
            h.ekmekTuru == EkmekTuru.Taze &&
            h.adet < 0)
        .fold(0, (t, h) => t + h.adet); // negatif
    final bugunTeslimEdilenTaze = siparisler
        .where((s) =>
            s.durum == SiparisDurum.TeslimEdildi &&
            s.satilanEkmekTuru == EkmekTuru.Taze &&
            _isSameDay(s.teslimTarihi, bugun))
        .fold(0, (t, s) => t + s.ekmekAdedi);

    final anlikTazeStok =
        bugunTazeGirisler + bugunTazeCikislar - bugunTeslimEdilenTaze;

    return {
      'tazeStok': anlikTazeStok.toInt(),
      'dunkuStok': anlikDunkuStok.toInt(),
    };
  }
}
