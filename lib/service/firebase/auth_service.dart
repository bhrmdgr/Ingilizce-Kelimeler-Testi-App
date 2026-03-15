import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ingilizce_kelime_testi/service/firebase/notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Mevcut kullanıcıyı takip eden stream (Giriş yapılmış mı kontrolü için)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 1. Email ve Şifre ile Kayıt Ol
  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return null;
    }
  }

  // 2. Email ve Şifre ile Giriş Yap
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return null;
    }
  }

  // 3. Misafir Girişi (Anonim)
  Future<UserCredential?> signInAnonymously() async {
    try {
      UserCredential userCredential = await _auth.signInAnonymously();
      return userCredential;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return null;
    }
  }

  // 4. Çıkış Yap
  Future<void> signOut() async {
    // ✅ Önce FCM token'ı sil, sonra oturumu kapat
    await NotificationService().deleteFcmToken();
    await _auth.signOut();
  }

  // --- TELEFON DOĞRULAMA GÜNCELLEMELERİ ---

  // 5. Telefon Numarasına Kod Gönder
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) codeSent,
    required Function(FirebaseAuthException e) verificationFailed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60), // Zaman aşımı eklemek iyidir
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Android'de bazen SMS'i otomatik okur ve direkt giriş yapar
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        // Burası çok kritik! Hatayı debug console'da görmeni sağlar.
        debugPrint("FIREBASE AUTH HATASI: ${e.code} - ${e.message}");
        verificationFailed(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        codeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Otomatik kod okuma zaman aşımına uğradığında
      },
    );
  }

  // 6. Telefon Kodu ve Email/Şifre ile Kaydı Tamamla
  Future<UserCredential?> signUpWithPhoneAndEmail({
    required String email,
    required String password,
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      // Önce email/şifre ile kullanıcıyı oluştur
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // ✅ KRİTİK GÜNCELLEME: Oluşturulan kullanıcıya telefon credential'ını bağla
      // Eğer bu işlem başarısız olursa (örn: numara başka hesapta), catch bloğuna düşer.
      if (userCredential.user != null) {
        await userCredential.user!.linkWithCredential(credential);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      // ✅ Hatayı logla ve ViewModel'in yakalaması için yukarı fırlat (rethrow)
      _handleAuthError(e);
      rethrow;
    } catch (e) {
      debugPrint("Beklenmedik Kayıt Hatası: $e");
      rethrow;
    }
  }

  // --- DATABASE GÜNCELLEMELERİ ---

  // 7. Normal Kullanıcı Verilerini 'users' Koleksiyonuna Kaydetme
  Future<void> saveUserToDatabase({
    required String uid,
    required String fullName, // Eklendi
    required String username,
    required String email,
    String? phoneNumber,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'fullName': fullName, // Firestore alanı
        'username': username,
        'email': email,
        'phoneNumber': phoneNumber ?? '',
        'userType': 'free',
        'createdAt': FieldValue.serverTimestamp(),
        'level': 'A1',
        'score': 0,
        'isGuest': false,
        'daily_goal': 0,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Firestore Users Kayıt Hatası: $e");
      rethrow;
    }
  }

  Future<void> saveGuestToDatabase({
    required String uid,
    required String username,
  }) async {
    try {
      await _firestore.collection('guestUsers').doc(uid).set({
        'uid': uid,
        'username': username,
        'userType': 'guest', // Kullanıcı tipi eklendi
        'createdAt': FieldValue.serverTimestamp(),
        'isGuest': true,
      });
    } catch (e) {
      debugPrint("Firestore GuestUsers Kayıt Hatası: $e");
      rethrow;
    }
  }

  // Firebase Hatalarını Yakalama
  void _handleAuthError(FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'user-not-found':
        message = "Bu e-posta ile kayıtlı kullanıcı bulunamadı.";
        break;
      case 'wrong-password':
        message = "Hatalı şifre girdiniz.";
        break;
      case 'email-already-in-use':
        message = "Bu e-posta adresi zaten kullanımda.";
        break;
      case 'invalid-email':
        message = "Geçersiz bir e-posta adresi girdiniz.";
        break;
      case 'weak-password':
        message = "Şifre çok zayıf.";
        break;
      case 'invalid-verification-code':
        message = "Girdiğiniz SMS kodu hatalı.";
        break;
      case 'invalid-phone-number':
        message = "Geçersiz bir telefon numarası girdiniz.";
        break;
      case 'credential-already-in-use':
        message = "Bu telefon numarası zaten başka bir hesaba bağlı.";
        break;
      default:
        message = "Bir hata oluştu: ${e.message}";
    }
    debugPrint("AUTH ERROR: $message");
  }


  Future<void> updateUserAvatar(String uid, String avatarPath) async {
    await _firestore.collection('users').doc(uid).update({
      'avatarPath': avatarPath,
    });
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      // Hatayı yukarı fırlatıyoruz ki ViewModel yakalayıp kullanıcıya göstersin
      throw Exception(e.toString());
    }
  }
}