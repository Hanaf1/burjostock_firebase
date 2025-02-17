// models/product.dart
class Product {
  final int? id;
  final String nama;
  final double hargaBeli;
  final double hargaJual;

  Product({
    this.id,
    required this.nama,
    required this.hargaBeli,
    required this.hargaJual,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      nama: map['nama'],
      hargaBeli: map['harga_beli'],
      hargaJual: map['harga_jual'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'harga_beli': hargaBeli,
      'harga_jual': hargaJual,
    };
  }
}
