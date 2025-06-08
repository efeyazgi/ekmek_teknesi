class UretimKaydi {
  final String id;
  final DateTime tarih;
  final int adet;
  UretimKaydi({required this.id, required this.tarih, required this.adet});
  Map<String, Object?> toMap() {
    return {'id': id, 'tarih': tarih.toIso8601String(), 'adet': adet};
  }

  static UretimKaydi fromMap(Map<String, dynamic> map) {
    return UretimKaydi(
      id: map['id'],
      tarih: DateTime.parse(map['tarih']),
      adet: map['adet'],
    );
  }
}
