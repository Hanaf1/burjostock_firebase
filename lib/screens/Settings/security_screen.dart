import 'package:flutter/material.dart';

class DataSecurityPage extends StatelessWidget {
  const DataSecurityPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keamanan Data'),
        centerTitle: true,
        backgroundColor: const Color(0xFF8D6E63),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSecurityCard(
                title: 'Enkripsi Data',
                description: 'Semua data sensitif dienkripsi menggunakan standar industri untuk memastikan keamanan informasi Anda.',
                icon: Icons.security,
              ),
              const SizedBox(height: 16),

              _buildSecurityCard(
                title: 'Backup Data',
                description: 'Data Anda secara otomatis di-backup ke cloud storage yang aman untuk mencegah kehilangan data.',
                icon: Icons.backup,
              ),
              const SizedBox(height: 16),

              _buildSecurityCard(
                title: 'Akses Terkontrol',
                description: 'Hanya pengguna yang berwenang yang dapat mengakses data sensitif dengan sistem otentikasi multi-level.',
                icon: Icons.lock,
              ),
              const SizedBox(height: 16),

              _buildSecurityCard(
                title: 'Monitoring Aktivitas',
                description: 'Semua aktivitas pengguna dipantau dan dicatat untuk mencegah penyalahgunaan dan memudahkan audit.',
                icon: Icons.monitor,
              ),
              const SizedBox(height: 16),

              _buildSecurityCard(
                title: 'Pembaruan Keamanan',
                description: 'Sistem keamanan diperbarui secara berkala untuk melindungi dari ancaman keamanan terbaru.',
                icon: Icons.update,
              ),
              const SizedBox(height: 16),

              _buildSecurityCard(
                title: 'Kebijakan Privasi',
                description: 'Kami berkomitmen untuk melindungi privasi Anda sesuai dengan kebijakan privasi dan regulasi yang berlaku.',
                icon: Icons.privacy_tip,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityCard({
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: const Color(0xFF8D6E63),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}