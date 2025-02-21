// File: day_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class DayDetailScreen extends StatelessWidget {
  final String dateStr;
  final Map<String, dynamic> dayData;

  const DayDetailScreen({
    Key? key,
    required this.dateStr,
    required this.dayData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.parse(dateStr);
    final formatter = NumberFormat("#,##0", "id_ID");

    return Scaffold(
      appBar: AppBar(
        title: Text(
          DateFormat('EEEE, dd MMMM yyyy').format(dt),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.brown,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: dayData.length,
        itemBuilder: (context, index) {
          final productId = dayData.keys.elementAt(index);
          final productData = dayData[productId] as Map<String, dynamic>;

          final modal = (productData['modal'] as num?)?.toDouble() ?? 0;
          final laba = (productData['laba'] as num?)?.toDouble() ?? 0;
          final omset = (productData['omset'] as num?)?.toDouble() ?? 0;
          final laku = (productData['laku'] as num?)?.toInt() ?? 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Produk #$productId",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow("Modal", "Rp ${formatter.format(modal.toInt())}", Colors.blue),
                  _buildDetailRow("Laba", "Rp ${formatter.format(laba.toInt())}", Colors.green),
                  _buildDetailRow("Omset", "Rp ${formatter.format(omset.toInt())}", Colors.orange),
                  _buildDetailRow("Terjual", "${formatter.format(laku)} pcs", Colors.purple),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}