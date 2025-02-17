import '../models/stock.dart';
import '../models/product.dart';
import 'database_helper.dart';

class DummyDataGenerator {
  static Future<void> insertDummyData() async {
    try {
      final db = DatabaseHelper.instance;

      // Dummy Products
      final List<Product> dummyProducts = [
        Product(nama: 'Nasi Goreng', hargaBeli: 8000, hargaJual: 12000),
        Product(nama: 'Mie Goreng', hargaBeli: 7000, hargaJual: 10000),
        Product(nama: 'Es Teh', hargaBeli: 2000, hargaJual: 4000),
        Product(nama: 'Es Jeruk', hargaBeli: 3000, hargaJual: 5000),
      ];


      List<int> productIds = [];
      for (var product in dummyProducts) {
        int productId = await db.insertProduct(product);
        productIds.add(productId);
      }

      final List<Stock> dummyStocks = [
        Stock(
          productId: productIds[0],
          stokAwal: 50,
          stokBeli: 20,
          stokTerjual: 10,
          stokSisa: 60,
          tanggal: DateTime.now(),
        ),
        Stock(
          productId: productIds[1],
          stokAwal: 30,
          stokBeli: 15,
          stokTerjual: 5,
          stokSisa: 40,
          tanggal: DateTime.now(),
        ),
      ];


      for (var stock in dummyStocks) {
        await db.insertStock(stock);
      }

      print('Dummy data inserted successfully');
    } catch (e) {
      print('Error inserting dummy data: $e');
    }
  }
}
