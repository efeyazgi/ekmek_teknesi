import 'package:uuid/uuid.dart';

enum SiparisDurum { Bekliyor, TeslimEdildi, Iptal }

enum EkmekTuru { Taze, Dunku }

extension EkmekTuruExtension on EkmekTuru {
  String get displayName {
    switch (this) {
      case EkmekTuru.Taze:
        return 'Taze';
      case EkmekTuru.Dunku:
        return 'Dünkü';
      default:
        return '';
    }
  }
}

class Siparis {
  final String id;
  final String? musteriId;
  final String musteriAdi;
  final int ekmekAdedi;
  final DateTime teslimTarihi;
  final bool odemeAlindiMi;
  final double tutar;
  final String? notlar;
  final SiparisDurum durum;
  final EkmekTuru? satilanEkmekTuru;
  final String? aciklama;

  Siparis({
    String? id,
    this.musteriId,
    required this.musteriAdi,
    required this.ekmekAdedi,
    required this.teslimTarihi,
    required this.tutar,
    this.odemeAlindiMi = false,
    this.notlar,
    this.durum = SiparisDurum.Bekliyor,
    this.satilanEkmekTuru,
    this.aciklama,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'musteriId': musteriId,
      'musteriAdi': musteriAdi,
      'ekmekAdedi': ekmekAdedi,
      'teslimTarihi': teslimTarihi.toIso8601String(),
      'odemeAlindiMi': odemeAlindiMi ? 1 : 0,
      'tutar': tutar,
      'notlar': notlar,
      'durum': durum.name,
      'satilanEkmekTuru': satilanEkmekTuru?.name,
      'aciklama': aciklama,
    };
  }

  factory Siparis.fromMap(Map<String, dynamic> map) {
    return Siparis(
      id: map['id'],
      musteriId: map['musteriId'],
      musteriAdi: map['musteriAdi'],
      ekmekAdedi: map['ekmekAdedi'],
      teslimTarihi: DateTime.parse(map['teslimTarihi']),
      odemeAlindiMi: map['odemeAlindiMi'] == 1,
      tutar: map['tutar'] ?? 0.0,
      notlar: map['notlar'],
      durum: SiparisDurum.values.firstWhere(
        (e) => e.name == map['durum'],
      ),
      satilanEkmekTuru: map['satilanEkmekTuru'] != null
          ? EkmekTuru.values.firstWhere(
              (e) => e.name == map['satilanEkmekTuru'],
            )
          : null,
      aciklama: map['aciklama'],
    );
  }
}
