class KeuanganHarian {
  final int? id;
  final int productId;
  final double modal;
  final double omset;
  final double laba;
  final DateTime tanggal; // Ubah ke DateTime

  KeuanganHarian({
    this.id,
    required this.productId,
    required this.modal,
    required this.omset,
    required this.laba,
    required this.tanggal,
  });

  factory KeuanganHarian.fromMap(Map<String, dynamic> map) {
    return KeuanganHarian(
      id: map['id'],
      productId: map['product_id'],
      modal: map['modal'],
      omset: map['omset'],
      laba: map['laba'],
      tanggal: DateTime.parse(map['tanggal']), // Konversi ke DateTime
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'modal': modal,
      'omset': omset,
      'laba': laba,
      'tanggal': tanggal.toIso8601String(), // Simpan sebagai ISO 8601 string
    };
  }
}
