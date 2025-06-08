class Musteri {
  final String id;
  final String adSoyad;
  final String? telefon;
  final String? notlar;
  Musteri({required this.id, required this.adSoyad, this.telefon, this.notlar});
  Map<String, Object?> toMap() {
    return {'id': id, 'adSoyad': adSoyad, 'telefon': telefon, 'notlar': notlar};
  }

  static Musteri fromMap(Map<String, dynamic> map) {
    return Musteri(
      id: map['id'],
      adSoyad: map['adSoyad'],
      telefon: map['telefon'],
      notlar: map['notlar'],
    );
  }
}
