// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String role; // PEMILIK atau KARYAWAN
  final int lastLogin;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.lastLogin = 0,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      role: map['role'] ?? 'KARYAWAN',
      lastLogin: map['lastLogin'] ?? 0,
    );
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Mendapatkan user saat ini
  User? get currentUser => _auth.currentUser;

  // Stream untuk status autentikasi user
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Login dengan email dan password
  Future<UserModel?> signInWithEmailAndPassword(String email, String password) async {
    try {
      // Login dengan Firebase Authentication
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Mendapatkan user dari hasil authentication
      final User? user = result.user;

      if (user != null) {
        // Update waktu login terakhir
        await _database.ref().child('users/${user.uid}/lastLogin').set(ServerValue.timestamp);

        // Ambil data user dari Realtime Database
        return await getUserData(user.uid);
      }

      return null;
    } catch (e) {
      print('Error during sign in: $e');
      rethrow;
    }
  }

  // Mendapatkan data user dari Realtime Database
  Future<UserModel?> getUserData(String uid) async {
    try {
      final snapshot = await _database.ref().child('users/$uid').get();

      if (snapshot.exists) {
        Map<String, dynamic> userData = Map<String, dynamic>.from(
            snapshot.value as Map
        );
        return UserModel.fromMap(userData, uid);
      }

      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Cek apakah user adalah pemilik
  Future<bool> isPemilik() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final userData = await getUserData(user.uid);
    if (userData == null) return false;

    return userData.role == 'PEMILIK';
  }

  // Logout
  Future<void> signOut() async {
    try {
      return await _auth.signOut();
    } catch (e) {
      print('Error during sign out: $e');
      rethrow;
    }
  }
}