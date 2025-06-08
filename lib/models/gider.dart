enum GiderTuru {
  Un,
  Tuz,
  Maya,
  OdunSaman,
  ElektrikFaturasi,
  SuFaturasi,
  Kira,
  Ambalaj,
  Diger,
}

String giderTuruToString(GiderTuru tur) {
  switch (tur) {
    case GiderTuru.Un:
      return 'Un';
    case GiderTuru.Tuz:
      return 'Tuz';
    case GiderTuru.Maya:
      return 'Maya';
    case GiderTuru.OdunSaman:
      return 'Odun / Saman';
    case GiderTuru.ElektrikFaturasi:
      return 'Elektrik Faturası';
    case GiderTuru.SuFaturasi:
      return 'Su Faturası';
    case GiderTuru.Kira:
      return 'Kira';
    case GiderTuru.Ambalaj:
      return 'Ambalaj Malzemesi';
    case GiderTuru.Diger:
      return 'Diğer';
  }
}

class Gider {
  final String id;
  final DateTime tarih;
  final GiderTuru giderTuru;
  final String aciklama;
  final double tutar;
  Gider({
    required this.id,
    required this.tarih,
    required this.giderTuru,
    required this.aciklama,
    required this.tutar,
  });
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'tarih': tarih.toIso8601String(),
      'giderTuru': giderTuru.name,
      'aciklama': aciklama,
      'tutar': tutar,
    };
  }

  factory Gider.fromMap(Map<String, dynamic> map) {
    return Gider(
      id: map['id'],
      tarih: DateTime.parse(map['tarih']),
      giderTuru: GiderTuru.values.firstWhere(
        (e) => e.name == map['giderTuru'],
        orElse: () => GiderTuru.Diger,
      ),
      aciklama: map['aciklama'],
      tutar: map['tutar'],
    );
  }
}
