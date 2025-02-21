import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  // Fungsi untuk melakukan log out
  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pop(); // Kembali ke halaman sebelumnya setelah logout
  }

  @override
  Widget build(BuildContext context) {
    final String userEmail =
        FirebaseAuth.instance.currentUser?.email ?? 'No Email';

    return Scaffold(
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Settings',
                  style: GoogleFonts.poppins(
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(height: 12,),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey[300],
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          userEmail,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Menu Data Security
              ListTile(
                leading: const Icon(Icons.security, color: Colors.black54),
                title: Text(
                  'Data Security',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Aksi ketika "Data Security" ditekan
                  // Misal, Navigator.push ke halaman Data Security
                },
              ),
              // Menu Support Center
              ListTile(
                leading: const Icon(Icons.headset_mic, color: Colors.black54),
                title: Text(
                  'Support Center',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Aksi ketika "Support Center" ditekan
                  // Misal, Navigator.push ke halaman Support
                },
              ),

              // Tombol Log Out
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _logout(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Log Out',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
