enum SiparisDurum { Bekliyor, TeslimEdildi, Iptal }

enum EkmekTuru { Taze, Dunku }

class Siparis {
  final String id;
  final String? musteriId;
  final String musteriAdi;
  final int ekmekAdedi;
  final DateTime teslimTarihi;
  final bool odemeAlindiMi;
  final String? notlar;
  final SiparisDurum durum;
  final EkmekTuru? satilanEkmekTuru; // YENİ EKLENDİ

  Siparis({
    required this.id,
    this.musteriId,
    required this.musteriAdi,
    required this.ekmekAdedi,
    required this.teslimTarihi,
    required this.odemeAlindiMi,
    this.notlar,
    this.durum = SiparisDurum.Bekliyor,
    this.satilanEkmekTuru, // YENİ EKLENDİ
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'musteriId': musteriId,
      'musteriAdi': musteriAdi,
      'ekmekAdedi': ekmekAdedi,
      'teslimTarihi': teslimTarihi.toIso8601String(),
      'odemeAlindiMi': odemeAlindiMi ? 1 : 0,
      'notlar': notlar,
      'durum': durum.name,
      'satilanEkmekTuru': satilanEkmekTuru?.name, // YENİ EKLENDİ
    };
  }

  static Siparis fromMap(Map<String, dynamic> map) {
    return Siparis(
      id: map['id'],
      musteriId: map['musteriId'],
      musteriAdi: map['musteriAdi'],
      ekmekAdedi: map['ekmekAdedi'],
      teslimTarihi: DateTime.parse(map['teslimTarihi']),
      odemeAlindiMi: map['odemeAlindiMi'] == 1,
      notlar: map['notlar'],
      durum: SiparisDurum.values.firstWhere(
        (e) => e.name == map['durum'],
        orElse: () => SiparisDurum.Bekliyor,
      ),
      // YENİ EKLENDİ: Veritabanındaki metni tekrar enum'a çeviriyoruz.
      satilanEkmekTuru: map['satilanEkmekTuru'] != null
          ? EkmekTuru.values.firstWhere(
              (e) => e.name == map['satilanEkmekTuru'],
            )
          : null,
    );
  }
}
