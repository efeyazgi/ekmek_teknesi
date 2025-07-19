import 'package:uuid/uuid.dart';
import './siparis.dart'; // EkmekTuru enum'ı için import edildi

enum StokHareketiTipi {
  Uretim,
  KendiKullanim,
  UcretsizVerilen,
  Bozulan,
  SayimDuzeltme // Eklendi: Manuel stok güncellemesi için
}

extension StokHareketiTipiExtension on StokHareketiTipi {
  String get displayName {
    switch (this) {
      case StokHareketiTipi.Uretim:
        return 'Üretim';
      case StokHareketiTipi.KendiKullanim:
        return 'Kendi Kullanım';
      case StokHareketiTipi.UcretsizVerilen:
        return 'Ücretsiz Verilen';
      case StokHareketiTipi.Bozulan:
        return 'Bozulan';
      case StokHareketiTipi.SayimDuzeltme:
        return 'Sayım Düzeltme';
      default:
        return '';
    }
  }
}

class StokHareketi {
  final String id;
  final DateTime tarih;
  final int adet;
  final StokHareketiTipi tip;
  final EkmekTuru
      ekmekTuru; // Eklendi: Hareketin hangi ekmek türüyle ilgili olduğunu belirtir
  final String? aciklama;
  final double? birimFiyat;

  StokHareketi({
    String? id,
    required this.tarih,
    required this.adet,
    required this.tip,
    required this.ekmekTuru, // Eklendi
    this.aciklama,
    this.birimFiyat,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tarih': tarih.toIso8601String(),
      'adet': adet,
      'tip': tip.name,
      'ekmekTuru': ekmekTuru.name, // Eklendi
      'aciklama': aciklama,
      'birimFiyat': birimFiyat,
    };
  }

  factory StokHareketi.fromMap(Map<String, dynamic> map) {
    return StokHareketi(
      id: map['id'],
      tarih: DateTime.parse(map['tarih']),
      adet: map['adet'],
      tip: StokHareketiTipi.values.firstWhere(
        (e) => e.name == map['tip'],
      ),
      ekmekTuru: EkmekTuru.values.firstWhere(
        // Eklendi
        (e) => e.name == map['ekmekTuru'],
        orElse: () =>
            EkmekTuru.Dunku, // Eski kayıtlarda sorun olmaması için varsayılan
      ),
      aciklama: map['aciklama'],
      birimFiyat: map['birimFiyat'],
    );
  }
}
