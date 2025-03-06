import 'product.dart';
class Stock {
  final int? id;
  final int productId;
  final int stokAwal;
  final int stokBeli;
  final int stokTerjual;
  final int stokSisa;
  final DateTime tanggal;
  final Product? product;

  Stock({
    this.id,
    required this.productId,
    required this.stokAwal,
    required this.stokBeli,
    required this.stokTerjual,
    required this.stokSisa,
    required this.tanggal,
    this.product,
  });

  factory Stock.fromMap(Map<String, dynamic> map) {
    return Stock(
      id: map['id'],
      productId: map['product_id'],
      stokAwal: map['stok_awal'],
      stokBeli: map['stok_beli'],
      stokTerjual: map['stok_terjual'],
      stokSisa: map['stok_sisa'],
      tanggal: DateTime.parse(map['tanggal']), // Konversi String ke DateTime
      product: map.containsKey('nama_product')
          ? Product(
        id: map['product_id'],
        kategori: map['kategori'],
        nama: map['nama_product'],
        hargaBeli: map['harga_beli'],
        hargaJual: map['harga_jual'],
      )
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'stok_awal': stokAwal,
      'stok_beli': stokBeli,
      'stok_terjual': stokTerjual,
      'stok_sisa': stokSisa,
      'tanggal': tanggal.toIso8601String(),
    };
  }
}


